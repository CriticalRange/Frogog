extends Control
class_name BossHealthBar

# UI References
var name_label: Label
var health_bar: ProgressBar
var health_label: Label
var phase_label: Label
var background: Panel

# Animation
var _target_health: float = 1.0
var _current_display_health: float = 1.0
const LERP_SPEED: float = 5.0

# Boss reference
var boss: Node = null

func _ready() -> void:
	_create_ui()
	hide()  # Start hidden until boss spawns

func _create_ui() -> void:
	# Main container at top of screen
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -300
	offset_right = 300
	offset_top = 20
	offset_bottom = 100

	# Background panel
	background = Panel.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	bg_style.border_width_bottom = 2
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_color = Color(0.8, 0.2, 0.2, 1.0)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	background.add_theme_stylebox_override("panel", bg_style)
	add_child(background)

	# Boss name label
	name_label = Label.new()
	name_label.text = "GIANT HERON"
	name_label.anchor_left = 0.5
	name_label.anchor_right = 0.5
	name_label.offset_left = -150
	name_label.offset_right = 150
	name_label.offset_top = 5
	name_label.offset_bottom = 30
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	add_child(name_label)

	# Phase label
	phase_label = Label.new()
	phase_label.text = "Phase 1"
	phase_label.anchor_left = 1.0
	phase_label.anchor_right = 1.0
	phase_label.offset_left = -80
	phase_label.offset_right = -10
	phase_label.offset_top = 5
	phase_label.offset_bottom = 25
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	add_child(phase_label)

	# Health bar background
	var bar_bg := Panel.new()
	bar_bg.anchor_left = 0.05
	bar_bg.anchor_right = 0.95
	bar_bg.anchor_top = 0.0
	bar_bg.anchor_bottom = 0.0
	bar_bg.offset_top = 35
	bar_bg.offset_bottom = 60
	var bar_bg_style := StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.2, 0.1, 0.1, 1.0)
	bar_bg_style.corner_radius_top_left = 4
	bar_bg_style.corner_radius_top_right = 4
	bar_bg_style.corner_radius_bottom_left = 4
	bar_bg_style.corner_radius_bottom_right = 4
	bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
	add_child(bar_bg)

	# Health bar
	health_bar = ProgressBar.new()
	health_bar.anchor_left = 0.05
	health_bar.anchor_right = 0.95
	health_bar.anchor_top = 0.0
	health_bar.anchor_bottom = 0.0
	health_bar.offset_top = 35
	health_bar.offset_bottom = 60
	health_bar.min_value = 0.0
	health_bar.max_value = 1.0
	health_bar.value = 1.0
	health_bar.show_percentage = false

	# Health bar style
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.8, 0.1, 0.1, 1.0)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_empty := StyleBoxFlat.new()
	bar_empty.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	health_bar.add_theme_stylebox_override("background", bar_empty)

	add_child(health_bar)

	# Health text
	health_label = Label.new()
	health_label.text = "2000 / 2000"
	health_label.anchor_left = 0.5
	health_label.anchor_right = 0.5
	health_label.offset_left = -100
	health_label.offset_right = 100
	health_label.offset_top = 65
	health_label.offset_bottom = 85
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	add_child(health_label)

func connect_to_boss(boss_node: Node) -> void:
	boss = boss_node

	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase_changed)
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died)

	show()
	_animate_intro()

func _on_boss_health_changed(current: float, maximum: float) -> void:
	_target_health = current / maximum
	health_label.text = "%d / %d" % [int(current), int(maximum)]

	# Update bar color based on health
	var bar_fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_fill:
		if _target_health <= 0.3:
			bar_fill.bg_color = Color(1.0, 0.2, 0.0, 1.0)  # Orange-red
		elif _target_health <= 0.6:
			bar_fill.bg_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange
		else:
			bar_fill.bg_color = Color(0.8, 0.1, 0.1, 1.0)  # Red

func _on_boss_phase_changed(new_phase: int) -> void:
	phase_label.text = "Phase %d" % new_phase

	# Flash effect
	var tween := create_tween()
	tween.tween_property(phase_label, "modulate", Color(1.0, 1.0, 0.0, 1.0), 0.1)
	tween.tween_property(phase_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	# Update border color per phase
	var bg_style := background.get_theme_stylebox("panel") as StyleBoxFlat
	if bg_style:
		match new_phase:
			2:
				bg_style.border_color = Color(1.0, 0.5, 0.0, 1.0)
			3:
				bg_style.border_color = Color(1.0, 0.0, 0.0, 1.0)

func _on_boss_died(_boss_ref: Node) -> void:
	_animate_outro()

func _animate_intro() -> void:
	modulate.a = 0.0
	offset_top = -50
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "offset_top", 20.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_outro() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	# Smooth health bar animation
	_current_display_health = lerpf(_current_display_health, _target_health, LERP_SPEED * delta)
	health_bar.value = _current_display_health
