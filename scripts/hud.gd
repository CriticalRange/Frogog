extends Control

@onready var health_bar = $HealthBarContainer/HealthBar
@onready var health_label = $HealthBarContainer/HealthLabel

var player: CharacterBody3D = null

# XP UI elements (created dynamically)
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_label: Label = null

# Store original XP bar style for level up flash effect
var _xp_fill_style_normal: StyleBoxFlat = null
var _xp_fill_style_flash: StyleBoxFlat = null
var _level_up_flash_active: bool = false
var _continuous_flash_tween: Tween = null
var _original_xp_value: float = 0.0

# Store tween for proper cleanup
var _fill_tween: Tween = null

# Timer UI elements
var timer_label: Label = null
var wave_label: Label = null
var _game_manager: Node = null

# Objective UI elements
var _objectives_container: VBoxContainer = null
var _active_objectives: Dictionary = {}  # id -> objective data

func _ready() -> void:
	# Add to hud group for easy access
	add_to_group("hud")

	# Create UI elements
	_create_timer_ui()
	_create_xp_ui()
	_create_objectives_ui()

	# Wait ONE frame for the scene tree to be ready
	await get_tree().process_frame
	_connect_to_player()
	_connect_to_game_manager()

func _input(event: InputEvent) -> void:
	# Debug: Press K to add 100 XP
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		_on_debug_xp()
	# Debug: Press L to skip 1 minute
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		_on_debug_skip_minute()

func _create_timer_ui() -> void:
	# Timer container at top center
	var timer_container := VBoxContainer.new()
	timer_container.name = "TimerContainer"
	timer_container.anchor_left = 0.5
	timer_container.anchor_right = 0.5
	timer_container.anchor_top = 0.0
	timer_container.anchor_bottom = 0.0
	timer_container.offset_left = -100
	timer_container.offset_right = 100
	timer_container.offset_top = 10
	timer_container.offset_bottom = 80
	add_child(timer_container)
	
	# Timer label (big, centered)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "12:00"
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_container.add_child(timer_label)
	
	# Wave label (smaller, below timer)
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.text = ""
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_container.add_child(wave_label)

func _connect_to_game_manager() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	if _game_manager:
		_game_manager.time_updated.connect(_on_time_updated)
		_game_manager.wave_changed.connect(_on_wave_changed)
		_game_manager.surge_started.connect(_on_surge_started)
		_game_manager.surge_ended.connect(_on_surge_ended)
		_game_manager.endless_mode_started.connect(_on_endless_mode_started)
		_game_manager.game_over.connect(_on_game_over)

func _create_xp_ui() -> void:
	# Create XP bar container
	var xp_container := HBoxContainer.new()
	xp_container.name = "XPBarContainer"
	xp_container.anchor_left = 0.0
	xp_container.anchor_right = 1.0
	xp_container.anchor_top = 0.0
	xp_container.anchor_bottom = 0.0
	xp_container.offset_left = 20
	xp_container.offset_right = -20
	xp_container.offset_top = 60
	xp_container.offset_bottom = 90
	add_child(xp_container)
	
	# Level label
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "LVL 1"
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	level_label.custom_minimum_size = Vector2(80, 0)
	xp_container.add_child(level_label)
	
	# XP Bar
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 25)
	
	# Style the XP bar
	var xp_style_bg := StyleBoxFlat.new()
	xp_style_bg.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	xp_style_bg.corner_radius_top_left = 4
	xp_style_bg.corner_radius_top_right = 4
	xp_style_bg.corner_radius_bottom_right = 4
	xp_style_bg.corner_radius_bottom_left = 4
	xp_bar.add_theme_stylebox_override("background", xp_style_bg)

	# Normal fill style (cyan)
	_xp_fill_style_normal = StyleBoxFlat.new()
	_xp_fill_style_normal.bg_color = Color(0.2, 0.8, 1.0)  # Cyan XP color
	_xp_fill_style_normal.corner_radius_top_left = 4
	_xp_fill_style_normal.corner_radius_top_right = 4
	_xp_fill_style_normal.corner_radius_bottom_right = 4
	_xp_fill_style_normal.corner_radius_bottom_left = 4

	# Flash fill style (golden yellow) for level up
	_xp_fill_style_flash = StyleBoxFlat.new()
	_xp_fill_style_flash.bg_color = Color(1.0, 0.9, 0.2)  # Gold
	_xp_fill_style_flash.corner_radius_top_left = 4
	_xp_fill_style_flash.corner_radius_top_right = 4
	_xp_fill_style_flash.corner_radius_bottom_right = 4
	_xp_fill_style_flash.corner_radius_bottom_left = 4

	xp_bar.add_theme_stylebox_override("fill", _xp_fill_style_normal)
	
	xp_container.add_child(xp_bar)
	
	# XP Label
	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "0/100 XP"
	xp_label.add_theme_font_size_override("font_size", 16)
	xp_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	xp_label.custom_minimum_size = Vector2(100, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_container.add_child(xp_label)

func _connect_to_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		player.died.connect(_on_player_died)
		player.xp_changed.connect(_on_xp_changed)
		player.level_up.connect(_on_level_up)

		# Initialize displays
		_on_health_changed(player.health)
		_on_xp_changed(player.current_xp, player.xp_to_next_level)
		_update_level_display(player.level)
	else:
		push_warning("HUD: Player not found in 'player' group!")

func _on_health_changed(new_health: float) -> void:
	if health_bar:
		health_bar.value = new_health
	if health_label:
		health_label.text = "HP: %d/%d" % [int(new_health), 100]

func _on_player_died() -> void:
	if health_label:
		health_label.text = "YOU DIED!"

func _on_xp_changed(current: int, required: int) -> void:
	if xp_bar:
		xp_bar.max_value = required
		xp_bar.value = current
	if xp_label:
		xp_label.text = "%d/%d XP" % [current, required]

func _on_level_up(new_level: int) -> void:
	_update_level_display(new_level)

	# Play initial level up effects (label scale, etc)
	_play_initial_level_up_effects()

func _play_initial_level_up_effects() -> void:
	# Store original XP value
	_original_xp_value = xp_bar.value if xp_bar else 0.0

	# Scale up the level label with bounce
	if level_label:
		var label_tween := create_tween()
		label_tween.set_parallel(true)
		label_tween.tween_property(level_label, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		label_tween.tween_property(level_label, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.2)

		# Scale back down
		label_tween.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN).set_delay(0.2)
		label_tween.tween_property(level_label, "modulate", Color.WHITE, 0.4).set_delay(0.2)

# Called by upgrade popup when it appears
func start_xp_bar_animation() -> void:
	if not xp_bar:
		return

	# Store the actual current XP value so we can restore it later
	_original_xp_value = xp_bar.value

	# Kill any existing tweens first to prevent infinite loop buildup
	_stop_all_xp_tweens()

	# Set bar to 0 first, then animate filling
	xp_bar.value = 0.0

	# Apply initial flash style (golden yellow)
	_set_flash_style_on()

	# Fill animation - bar fills from 0 to max and stays there
	_fill_tween = create_tween()
	_fill_tween.set_parallel(true)

	# Fill up to max with a satisfying animation
	_fill_tween.tween_property(xp_bar, "value", xp_bar.max_value, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Scale the XP bar slightly when filling
	_fill_tween.tween_property(xp_bar, "scale:y", 1.3, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_fill_tween.tween_property(xp_bar, "scale:y", 1.0, 0.75).set_ease(Tween.EASE_IN).set_delay(0.75)

	# Continuous color pulse effect (loops while popup is open)
	_continuous_flash_tween = create_tween()
	_continuous_flash_tween.set_loops()
	_continuous_flash_tween.set_parallel(false)

	# Pulse between bright gold and slightly dimmer gold - use method tweening
	_continuous_flash_tween.tween_method(_update_flash_pulse, 0.0, 1.0, 1.0)

func _update_flash_pulse(progress: float) -> void:
	if not xp_bar:
		return
	# Use sine wave for smooth pulsing (0 = bright, 1 = dim, then back)
	var pulse := (sin(progress * TAU) + 1.0) / 2.0  # 0 to 1
	if pulse < 0.5:
		_set_flash_style_on()
	else:
		_set_flash_style_off()

func _stop_all_xp_tweens() -> void:
	if _continuous_flash_tween and is_instance_valid(_continuous_flash_tween):
		_continuous_flash_tween.kill()
		_continuous_flash_tween = null

	if _fill_tween and is_instance_valid(_fill_tween):
		_fill_tween.kill()
		_fill_tween = null

# Called by upgrade popup when it closes
func stop_xp_bar_animation() -> void:
	# Kill all tweens
	_stop_all_xp_tweens()

	# Restore normal style
	_restore_xp_style()

	# Reset XP bar to the original value (where it was before animation)
	if xp_bar:
		xp_bar.value = _original_xp_value

func _set_flash_style_on() -> void:
	if not xp_bar:
		return
	var flash_style := _xp_fill_style_flash.duplicate()
	flash_style.shadow_color = Color(1.0, 0.8, 0.2, 0.8)
	flash_style.shadow_size = 15
	xp_bar.add_theme_stylebox_override("fill", flash_style)

func _set_flash_style_off() -> void:
	if not xp_bar:
		return
	var dim_style := _xp_fill_style_flash.duplicate()
	dim_style.bg_color = Color(0.85, 0.75, 0.15)  # Slightly dimmer gold
	dim_style.shadow_color = Color(1.0, 0.7, 0.1, 0.5)
	dim_style.shadow_size = 10
	xp_bar.add_theme_stylebox_override("fill", dim_style)

func _restore_xp_style() -> void:
	if not xp_bar:
		return
	xp_bar.add_theme_stylebox_override("fill", _xp_fill_style_normal)

func _update_level_display(lvl: int) -> void:
	if level_label:
		level_label.text = "LVL %d" % lvl

func _on_time_updated(elapsed: float, remaining: float) -> void:
	if timer_label:
		# Check if in endless mode (negative remaining)
		if remaining < 0:
			# Format as -MM:SS for endless mode
			var endless_seconds: float = abs(remaining)
			var mins: int = int(endless_seconds) / 60
			var secs: int = int(endless_seconds) % 60
			timer_label.text = "-%d:%02d" % [mins, secs]
			# Red color for endless mode
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4))
		else:
			# Format as MM:SS for normal mode
			var mins: int = int(remaining) / 60
			var secs: int = int(remaining) % 60
			timer_label.text = "%d:%02d" % [mins, secs]

			# Change color when time is running low
			if remaining < 60:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			elif remaining < 180:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
			else:
				timer_label.add_theme_color_override("font_color", Color.WHITE)

func _on_wave_changed(wave: int) -> void:
	if wave_label:
		wave_label.text = "⚠️ WAVE %d - Enemies Stronger! ⚠️" % wave
		# Fade out after a few seconds
		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(func(): wave_label.text = "Wave %d" % wave)

func _on_game_over(won: bool) -> void:
	if timer_label:
		if won:
			timer_label.text = "BOSS TIME!"
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.8))
		else:
			timer_label.text = "GAME OVER"
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _on_surge_started() -> void:
	if wave_label:
		wave_label.text = "🌊 SURGE! 5x ENEMIES! 🌊"
		wave_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		
		# Pulse animation
		var tween := create_tween().set_loops()
		tween.tween_property(wave_label, "modulate:a", 0.5, 0.3)
		tween.tween_property(wave_label, "modulate:a", 1.0, 0.3)

func _on_surge_ended() -> void:
	if wave_label:
		wave_label.text = ""
		wave_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		wave_label.modulate.a = 1.0

func _on_endless_mode_started() -> void:
	if wave_label:
		wave_label.text = "☠️ ENDLESS MODE - SURVIVE! ☠️"
		wave_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.3))

		# Pulse animation for endless mode
		var tween := create_tween().set_loops()
		tween.tween_property(wave_label, "modulate:a", 0.4, 0.4)
		tween.tween_property(wave_label, "modulate:a", 1.0, 0.4)

func _on_debug_xp() -> void:
	if player and player.has_method("add_xp"):
		player.add_xp(100)
		print("Debug: Added 100 XP")

func _on_debug_skip_minute() -> void:
	if GameManager.instance:
		GameManager.instance.elapsed_time += 60.0
		print("Debug: Skipped 1 minute")

# ============ OBJECTIVES SYSTEM ============

func _create_objectives_ui() -> void:
	# Objectives container - positioned below XP bar, left aligned
	_objectives_container = VBoxContainer.new()
	_objectives_container.name = "ObjectivesContainer"
	_objectives_container.anchor_left = 0.0
	_objectives_container.anchor_right = 0.4  # Take up 40% of screen width
	_objectives_container.anchor_top = 0.0
	_objectives_container.anchor_bottom = 0.0
	_objectives_container.offset_left = 20
	_objectives_container.offset_right = 0
	_objectives_container.offset_top = 95  # Just below XP bar
	_objectives_container.offset_bottom = 250
	_objectives_container.add_theme_constant_override("separation", 8)
	add_child(_objectives_container)

	# Initially empty, objectives will be added dynamically

## Add or update an objective
## id: Unique identifier for this objective
## title: Display name
## duration: Total duration in seconds
## color: Color for the progress fill
func add_objective(id: String, title: String, duration: float, color: Color = Color(1.0, 0.6, 0.2)) -> void:
	# Check if objective already exists
	if _active_objectives.has(id):
		_update_objective(id, title, duration, color)
		return

	# Create new objective widget
	var objective_widget := _create_objective_widget(id, title, duration, color)
	_objectives_container.add_child(objective_widget)
	_active_objectives[id] = {
		"widget": objective_widget,
		"title": title,
		"duration": duration,
		"remaining": duration,
		"color": color,
		"progress_ring": objective_widget.get_node("ProgressRing"),
		"time_label": objective_widget.get_node("TimeLabel")
	}

	# Start update timer
	_update_objective_progress(id)

## Remove an objective
func remove_objective(id: String) -> void:
	if not _active_objectives.has(id):
		return

	var data = _active_objectives[id]
	if is_instance_valid(data.widget):
		# Animate out
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(data.widget, "modulate:a", 0.0, 0.2)
		tween.tween_property(data.widget, "offset_left", -20, 0.2)
		await tween.finished
		data.widget.queue_free()

	_active_objectives.erase(id)

## Update an existing objective
func _update_objective(id: String, title: String, duration: float, color: Color) -> void:
	if not _active_objectives.has(id):
		return

	var data = _active_objectives[id]
	data.title = title
	data.duration = duration
	data.remaining = duration
	data.color = color

	# Update label
	var title_label = data.widget.get_node("TitleLabel")
	if title_label:
		title_label.text = title

	# Update progress ring color
	var progress_ring = data.progress_ring
	if progress_ring:
		_update_progress_ring_color(progress_ring, color, 0.0)

func _create_objective_widget(id: String, title: String, duration: float, color: Color) -> Control:
	var container := HBoxContainer.new()
	container.name = "Objective_" + id
	container.add_theme_constant_override("separation", 10)
	container.custom_minimum_size = Vector2(0, 35)

	# Progress ring (left-to-right fill circle)
	var progress_ring := TextureRect.new()
	progress_ring.name = "ProgressRing"
	progress_ring.custom_minimum_size = Vector2(30, 30)
	_create_progress_ring_texture(progress_ring, color)
	container.add_child(progress_ring)

	# Title and time container
	var text_container := VBoxContainer.new()
	text_container.add_theme_constant_override("separation", 2)
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(text_container)

	# Title label
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_container.add_child(title_label)

	# Time label
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.text = _format_time(duration)
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_container.add_child(time_label)

	return container

func _create_progress_ring_texture(texture_rect: TextureRect, color: Color) -> void:
	# Create a circular progress texture that fills left-to-right
	# Using a custom drawn texture

	var progress_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)

	# Draw the ring
	for y in range(32):
		for x in range(32):
			var dx := x - 15.5
			var dy := y - 15.5
			var dist := sqrt(dx*dx + dy*dy)

			# Outer ring (dark background)
			if dist > 10.0 and dist < 14.0:
				progress_image.set_pixel(x, y, Color(0.15, 0.15, 0.2, 0.8))
			# Inner fill area (initially empty - dark)
			elif dist < 10.0:
				progress_image.set_pixel(x, y, Color(0.1, 0.1, 0.15, 0.6))

	var texture := ImageTexture.new()
	texture.set_image(progress_image)
	texture_rect.texture = texture

	# Store fill color in metadata for updates
	texture_rect.set_meta("fill_color", color)
	texture_rect.set_meta("progress", 0.0)

func _update_progress_ring_color(texture_rect: TextureRect, color: Color, progress: float) -> void:
	texture_rect.set_meta("fill_color", color)
	_update_progress_ring(texture_rect, progress)

func _update_progress_ring(texture_rect: TextureRect, progress: float) -> void:
	# Clamp progress
	progress = clampf(progress, 0.0, 1.0)
	texture_rect.set_meta("progress", progress)

	var fill_color: Color = texture_rect.get_meta("fill_color")

	var progress_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var fill_angle_start := PI  # Start from left
	var fill_angle_end = PI + (progress * TAU)  # Sweep clockwise to right

	for y in range(32):
		for x in range(32):
			var dx := (x - 15.5) / 15.5
			var dy := (y - 15.5) / 15.5
			var dist := sqrt(dx*dx + dy*dy)

			# Background ring
			if dist > 0.6 and dist < 0.85:
				progress_image.set_pixel(x, y, Color(0.15, 0.15, 0.2, 0.9))
			# Inner area
			elif dist < 0.6:
				# Calculate angle for this pixel
				var angle := atan2(dy, dx)  # -PI to PI

				# Convert to 0-2PI range starting from left (PI)
				var normalized_angle := angle + PI  # 0 to 2PI

				# Check if this pixel should be filled
				var fill_limit := progress * TAU
				var should_fill := normalized_angle <= fill_limit

				if should_fill:
					# Gradient fill based on angle
					var gradient := normalized_angle / TAU
					var fill_alpha = 0.6 + gradient * 0.4
					progress_image.set_pixel(x, y, Color(
						fill_color.r,
						fill_color.g,
						fill_color.b,
						fill_alpha
					))
				else:
					# Empty (dark)
					progress_image.set_pixel(x, y, Color(0.1, 0.1, 0.15, 0.6))

	var texture := ImageTexture.new()
	texture.set_image(progress_image)
	texture_rect.texture = texture

func _update_objective_progress(id: String) -> void:
	if not _active_objectives.has(id):
		return

	var data = _active_objectives[id]

	# Update remaining time
	var delta := get_process_delta_time()
	data.remaining -= delta

	# Calculate progress (1.0 = just started, 0.0 = ending)
	var progress: float = data.remaining / data.duration

	# Update progress ring
	_update_progress_ring(data.progress_ring, progress)

	# Update time label
	if data.time_label:
		if data.remaining <= 0:
			data.time_label.text = "COMPLETE"
			data.time_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			data.time_label.text = _format_time(data.remaining)

	# Continue updating or remove when complete
	if data.remaining > 0:
		# Schedule next update (on next frame for smooth animation)
		await get_tree().process_frame
		_update_objective_progress(id)
	else:
		# Auto-remove after a brief delay showing "COMPLETE"
		await get_tree().create_timer(0.5).timeout
		remove_objective(id)

func _format_time(seconds: float) -> String:
	if seconds >= 60:
		var mins := int(seconds) / 60
		var secs := int(seconds) % 60
		return "%d:%02d" % [mins, secs]
	else:
		return "%.1fs" % seconds

## Show a countdown objective (e.g., "Horde incoming in 60s")
func show_countdown_objective(id: String, title: String, seconds: float, color: Color = Color(1.0, 0.3, 0.3)) -> void:
	add_objective(id, title, seconds, color)

## Show a progress objective (e.g., "Kill 10 enemies")
func show_progress_objective(id: String, title: String, current: int, total: int, color: Color = Color(0.3, 1.0, 0.5)) -> void:
	var progress := float(current) / float(total) if total > 0 else 0.0
	var widget_id := id + "_progress"

	if current >= total:
		# Complete!
		if _active_objectives.has(widget_id):
			var data = _active_objectives[widget_id]
			data.remaining = 0.1  # Short delay before removal
		return

	# For progress objectives, we store current/total
	if _active_objectives.has(widget_id):
		var data = _active_objectives[widget_id]
		data.widget.get_node("TitleLabel").text = "%s: %d/%d" % [title, current, total]
		_update_progress_ring(data.progress_ring, progress)
		data.widget.get_node("TimeLabel").text = ""
	else:
		add_objective(widget_id, "%s: %d/%d" % [title, current, total], 1.0, color)
		# Immediately update the progress
		if _active_objectives.has(widget_id):
			_update_progress_ring(_active_objectives[widget_id].progress_ring, progress)
			_active_objectives[widget_id].widget.get_node("TimeLabel").text = ""

# ============ REWARD NOTIFICATION SYSTEM ============

var _notification_container: VBoxContainer = null

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	# Create notification label
	var notification := Label.new()
	notification.text = text
	notification.add_theme_font_size_override("font_size", 24)
	notification.add_theme_color_override("font_color", color)
	notification.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	notification.add_theme_constant_override("shadow_offset_x", 2)
	notification.add_theme_constant_override("shadow_offset_y", 2)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at center-top of screen
	notification.anchor_left = 0.5
	notification.anchor_right = 0.5
	notification.anchor_top = 0.15
	notification.anchor_bottom = 0.15
	notification.offset_left = -200
	notification.offset_right = 200
	notification.offset_top = 0
	notification.offset_bottom = 40

	add_child(notification)

	# Animate in
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.3).from(0.0)
	tween.tween_property(notification, "offset_top", -20, 0.3).from(20)

	# Wait, animate out, then remove
	await get_tree().create_timer(2.5).timeout
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.tween_property(notification, "offset_top", -60, 0.3)
	await tween.finished
	notification.queue_free()
