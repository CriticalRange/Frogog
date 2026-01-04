extends Control
class_name UpgradePopup

# Signals
signal upgrade_selected(upgrade_data: Dictionary)  # Now passes {id, tier, multiplier}
signal popup_closed()

# References
var _panel: PanelContainer
var _title_label: Label
var _cards_container: HBoxContainer
var _cards: Array[Control] = []
var _selected_card_index: int = 0

# Background animation references
var _background_container: Control
var _particle_systems: Array[GPUParticles2D] = []
var _rotating_rings: Array[Node] = []
var _energy_waves: Array[CanvasItem] = []

# Available upgrades pool - now using icon paths instead of emojis
const ICON_PATH := "res://assets/icons/"

const UPGRADES = {
	# === SLIME BALL UPGRADES ===
	"slime_damage": {"name": "Toxic Spit", "desc": "+20% Slime Damage", "icon": "icon_toxic_spit.png", "category": "weapon", "stat": "slime_damage", "value": 0.2},
	"slime_speed": {"name": "Quick Spit", "desc": "+25% Projectile Speed", "icon": "icon_quick_spit.png", "category": "weapon", "stat": "slime_speed", "value": 0.25},
	"slime_size": {"name": "Big Blob", "desc": "+30% Slime Size", "icon": "icon_big_blob.png", "category": "weapon", "stat": "slime_size", "value": 0.3},
	"slime_pierce": {"name": "Piercing Slime", "desc": "+1 Pierce Count", "icon": "icon_piercing.png", "category": "weapon", "stat": "slime_pierce", "value": 1},
	"slime_count": {"name": "Multi-Shot", "desc": "+1 Projectile", "icon": "icon_multishot.png", "category": "weapon", "stat": "slime_count", "value": 1},
	"fire_rate": {"name": "Rapid Fire", "desc": "+15% Fire Rate", "icon": "icon_rapid_fire.png", "category": "weapon", "stat": "fire_rate", "value": 0.15},
	"slime_explode": {"name": "Exploding Slime", "desc": "+20% Explosion Radius", "icon": "icon_explosion.png", "category": "weapon", "stat": "explosion_radius", "value": 0.2},
	"slime_chain": {"name": "Chain Reaction", "desc": "+1 Chain Target", "icon": "icon_chain.png", "category": "weapon", "stat": "chain_count", "value": 1},
	"slime_homing": {"name": "Homing Slime", "desc": "+10% Homing Strength", "icon": "icon_homing.png", "category": "weapon", "stat": "homing", "value": 0.1},
	"slime_poison": {"name": "Lingering Poison", "desc": "+1s Poison Duration", "icon": "icon_poison.png", "category": "weapon", "stat": "poison_duration", "value": 1.0},
	
	# === MOVEMENT UPGRADES ===
	"move_speed": {"name": "Swift Feet", "desc": "+10% Movement Speed", "icon": "icon_speed.png", "category": "movement", "stat": "move_speed", "value": 0.1},
	"jump_power": {"name": "Frog Legs", "desc": "+15% Jump Height", "icon": "icon_jump.png", "category": "movement", "stat": "jump_power", "value": 0.15},
	"double_jump": {"name": "Air Hop", "desc": "+1 Extra Jump", "icon": "icon_double_jump.png", "category": "movement", "stat": "extra_jumps", "value": 1},
	"dash_cooldown": {"name": "Quick Dash", "desc": "-15% Dash Cooldown", "icon": "icon_dash.png", "category": "movement", "stat": "dash_cooldown", "value": -0.15},
	"air_control": {"name": "Wind Rider", "desc": "+20% Air Control", "icon": "icon_air_control.png", "category": "movement", "stat": "air_control", "value": 0.2},
	
	# === DEFENSE UPGRADES ===
	"max_health": {"name": "Thick Skin", "desc": "+20 Max Health", "icon": "icon_health.png", "category": "defense", "stat": "max_health", "value": 20},
	"health_regen": {"name": "Regeneration", "desc": "+1 HP/sec Regen", "icon": "icon_regen.png", "category": "defense", "stat": "health_regen", "value": 1.0},
	"damage_resist": {"name": "Iron Hide", "desc": "+10% Damage Resist", "icon": "icon_armor.png", "category": "defense", "stat": "damage_resist", "value": 0.1},
	"dodge_chance": {"name": "Slippery", "desc": "+5% Dodge Chance", "icon": "icon_dodge.png", "category": "defense", "stat": "dodge_chance", "value": 0.05},
	"thorns": {"name": "Thorns", "desc": "Reflect 10% Damage", "icon": "icon_thorns.png", "category": "defense", "stat": "thorns", "value": 0.1},
	"lifesteal": {"name": "Vampiric", "desc": "+5% Lifesteal", "icon": "icon_lifesteal.png", "category": "defense", "stat": "lifesteal", "value": 0.05},
	
	# === UTILITY UPGRADES ===
	"xp_gain": {"name": "Fast Learner", "desc": "+15% XP Gain", "icon": "icon_xp.png", "category": "utility", "stat": "xp_multiplier", "value": 0.15},
	"pickup_range": {"name": "Magnet", "desc": "+25% Pickup Range", "icon": "icon_magnet.png", "category": "utility", "stat": "pickup_range", "value": 0.25},
	"luck": {"name": "Lucky Charm", "desc": "+10% Luck", "icon": "icon_luck.png", "category": "utility", "stat": "luck", "value": 0.1},
	"cooldown_reduce": {"name": "Efficiency", "desc": "-10% All Cooldowns", "icon": "icon_cooldown.png", "category": "utility", "stat": "cooldown_reduction", "value": 0.1},
	
	# === CRITICAL UPGRADES ===
	"crit_chance": {"name": "Precision", "desc": "+5% Crit Chance", "icon": "icon_crit_chance.png", "category": "critical", "stat": "crit_chance", "value": 0.05},
	"crit_damage": {"name": "Brutality", "desc": "+25% Crit Damage", "icon": "icon_crit_damage.png", "category": "critical", "stat": "crit_damage", "value": 0.25},
	"crit_heal": {"name": "Bloodthirst", "desc": "Crits Heal 5 HP", "icon": "icon_crit_heal.png", "category": "critical", "stat": "crit_heal", "value": 5},
	
	# === SPECIAL UPGRADES ===
	"aura_damage": {"name": "Toxic Aura", "desc": "+5 Aura DPS", "icon": "icon_aura.png", "category": "special", "stat": "aura_damage", "value": 5},
	"orbital": {"name": "Orbiting Slime", "desc": "+1 Orbital", "icon": "icon_orbital.png", "category": "special", "stat": "orbitals", "value": 1},

	# === ABILITY UNLOCKS ===
	"unlock_tongue_lash": {"name": "Tongue Lash", "desc": "Unlock: Melee cone attack", "icon": "icon_tongue_lash.png", "category": "ability", "stat": "unlock_tongue_lash", "value": 1},
	"unlock_tadpole_swarm": {"name": "Tadpole Swarm", "desc": "Unlock: Summon AI allies", "icon": "icon_tadpole_swarm.png", "category": "ability", "stat": "unlock_tadpole_swarm", "value": 1},
	"unlock_croak_blast": {"name": "Croak Blast", "desc": "Unlock: AOE shockwave", "icon": "icon_croak_blast.png", "category": "ability", "stat": "unlock_croak_blast", "value": 1},
	"unlock_fly_cloud": {"name": "Fly Cloud", "desc": "Unlock: Damage aura", "icon": "icon_fly_cloud.png", "category": "ability", "stat": "unlock_fly_cloud", "value": 1},
	"unlock_amphibian_rage": {"name": "Amphibian Rage", "desc": "Unlock: Ultimate ability", "icon": "icon_amphibian_rage.png", "category": "ability", "stat": "unlock_amphibian_rage", "value": 1},

	# === ABILITY UPGRADES ===
	"tongue_lash_damage": {"name": "Stronger Tongue", "desc": "+25% Tongue Lash Damage", "icon": "icon_tongue_damage.png", "category": "ability", "stat": "tongue_lash_damage", "value": 0.25},
	"tadpole_count": {"name": "More Tadpoles", "desc": "+2 Tadpoles per swarm", "icon": "icon_tadpole_count.png", "category": "ability", "stat": "tadpole_count", "value": 2},
	"croak_blast_damage": {"name": "Louder Croak", "desc": "+30% Croak Blast Damage", "icon": "icon_croak_damage.png", "category": "ability", "stat": "croak_blast_damage", "value": 0.3},
	"fly_cloud_damage": {"name": "More Flies", "desc": "+25% Fly Cloud Damage", "icon": "icon_fly_damage.png", "category": "ability", "stat": "fly_cloud_damage", "value": 0.25},
	"rage_duration": {"name": "Longer Rage", "desc": "+2s Rage Duration", "icon": "icon_rage_duration.png", "category": "ability", "stat": "rage_duration", "value": 2.0},
}

# Style colors
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_BORDER := Color(0.3, 0.8, 0.4)
const COLOR_CARD_BG := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_CARD_HOVER := Color(0.18, 0.25, 0.22, 1.0)
const COLOR_TITLE := Color(1.0, 0.9, 0.3)
const COLOR_ICON_BG := Color(0.2, 0.5, 0.3)

# Category colors (now secondary to tier colors)
const CATEGORY_COLORS = {
	"weapon": Color(0.9, 0.3, 0.3),
	"movement": Color(0.3, 0.7, 0.9),
	"defense": Color(0.3, 0.9, 0.4),
	"utility": Color(0.9, 0.8, 0.3),
	"critical": Color(0.9, 0.5, 0.2),
	"special": Color(0.8, 0.4, 0.9),
	"ability": Color(0.4, 0.95, 0.5),
}

# Tier system
enum Tier { COMMON, RARE, EPIC, LEGENDARY }

const TIER_DATA = {
	Tier.COMMON: {
		"name": "Common",
		"color": Color(0.85, 0.85, 0.85, 1.0),  # Light gray
		"border_color": Color(0.7, 0.7, 0.7, 1.0),
		"multiplier": 1.0,
		"badge_text": "",
		"badge_color": Color.TRANSPARENT,
	},
	Tier.RARE: {
		"name": "Rare",
		"color": Color(0.4, 0.7, 1.0, 1.0),  # Blue
		"border_color": Color(0.3, 0.5, 1.0, 1.0),
		"multiplier": 1.5,
		"badge_text": "RARE",
		"badge_color": Color(0.2, 0.4, 0.8, 0.9),
	},
	Tier.EPIC: {
		"name": "Epic",
		"color": Color(0.7, 0.4, 1.0, 1.0),  # Purple
		"border_color": Color(0.6, 0.2, 1.0, 1.0),
		"multiplier": 2.5,
		"badge_text": "EPIC",
		"badge_color": Color(0.5, 0.2, 0.9, 0.9),
	},
	Tier.LEGENDARY: {
		"name": "Legendary",
		"color": Color(1.0, 0.7, 0.2, 1.0),  # Gold/Orange
		"border_color": Color(1.0, 0.5, 0.0, 1.0),
		"multiplier": 4.0,
		"badge_text": "LEGENDARY",
		"badge_color": Color(1.0, 0.5, 0.0, 0.9),
	},
}

# Store tier for each card (upgrade_id -> tier)
var _card_tiers: Dictionary = {}

func _ready() -> void:
	add_to_group("upgrade_popup")
	# Make it fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks behind
	process_mode = Node.PROCESS_MODE_ALWAYS  # Work while paused!
	visible = false

	# Set up input handling for arrow keys and Enter/Esc
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Handle keyboard navigation
	if event.is_action_pressed("ui_left"):
		_navigate_cards(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_navigate_cards(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		# Enter/Space to select
		if _cards.size() > 0 and _selected_card_index < _cards.size():
			_select_card(_selected_card_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# Esc to close (select first card as default)
		if _cards.size() > 0:
			_select_card(0)
		get_viewport().set_input_as_handled()

func _navigate_cards(direction: int) -> void:
	if _cards.is_empty():
		return

	# Remove highlight from current card
	if _selected_card_index < _cards.size():
		_set_card_highlight(_selected_card_index, false)

	# Navigate with wrap-around
	_selected_card_index = (_selected_card_index + direction) % _cards.size()
	if _selected_card_index < 0:
		_selected_card_index = _cards.size() - 1

	# Add highlight to new card
	_set_card_highlight(_selected_card_index, true)

	# Focus the card
	_cards[_selected_card_index].grab_focus()

func _set_card_highlight(index: int, highlighted: bool) -> void:
	if index >= _cards.size():
		return

	var card: Button = _cards[index]
	var tier: Tier = card.get_meta("tier", Tier.COMMON)
	var tier_data: Dictionary = TIER_DATA[tier]
	var tier_color: Color = tier_data.border_color

	if highlighted:
		# Add glowing border effect for selected card (uses tier color)
		var highlight_style := StyleBoxFlat.new()
		highlight_style.bg_color = COLOR_CARD_BG
		highlight_style.border_color = tier_color  # Use tier color
		highlight_style.border_width_top = 5
		highlight_style.border_width_bottom = 5
		highlight_style.border_width_left = 5
		highlight_style.border_width_right = 5
		highlight_style.corner_radius_top_left = 12
		highlight_style.corner_radius_top_right = 12
		highlight_style.corner_radius_bottom_right = 12
		highlight_style.corner_radius_bottom_left = 12
		highlight_style.shadow_color = tier_color
		highlight_style.shadow_color.a = 0.7
		highlight_style.shadow_size = 15
		card.add_theme_stylebox_override("normal", highlight_style)
		card.scale = Vector2(1.0, 1.0)
	else:
		# Restore normal style with tier color
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = COLOR_CARD_BG
		card_style.border_color = tier_color  # Use tier color
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_right = 12
		card_style.corner_radius_bottom_left = 12
		card_style.shadow_color = Color(0, 0, 0, 0.5)
		card_style.shadow_size = 10
		card.add_theme_stylebox_override("normal", card_style)
		card.scale = Vector2(1.0, 1.0)

func _select_card(index: int) -> void:
	if index >= _cards.size():
		return

	var card: Button = _cards[index]
	var upgrade_id: String = card.get_meta("upgrade_id", "")
	if not upgrade_id.is_empty():
		_on_card_selected(upgrade_id)

func show_upgrades(choices: Array = []) -> void:
	# Clear previous cards and backgrounds
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_selected_card_index = 0
	_card_tiers.clear()

	# Clear old background effects
	for particles in _particle_systems:
		if is_instance_valid(particles):
			particles.queue_free()
	_particle_systems.clear()

	for ring in _rotating_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_rotating_rings.clear()

	for wave in _energy_waves:
		if is_instance_valid(wave):
			wave.queue_free()
	_energy_waves.clear()

	# If no choices provided, pick 3 random upgrades from filtered pool
	if choices.is_empty():
		choices = _get_filtered_upgrades(3)

	# Assign random tiers to each choice
	var choices_with_tiers: Array = []
	for upgrade_id in choices:
		var tier := _get_random_tier()
		choices_with_tiers.append({"id": upgrade_id, "tier": tier})
		_card_tiers[upgrade_id] = tier

	# Build UI (includes animated background)
	_build_ui_with_tiers(choices_with_tiers)

	# Create animated background effects
	_create_animated_background()

	# Show and pause game
	visible = true
	get_tree().paused = true

	# Release mouse cursor!
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Force panel center after one frame (when viewport size is ready)
	await get_tree().process_frame
	if _panel:
		var viewport_size := get_viewport_rect().size
		_panel.position = Vector2(viewport_size.x / 2 - 325, viewport_size.y / 2 - 190)

	# Select first card by default
	if _cards.size() > 0:
		_set_card_highlight(0, true)

	# Start XP bar animation on HUD
	_start_hud_xp_animation()

	# Play entrance animation
	_play_entrance_animation()

func show_ancient_armory_upgrades() -> void:
	# Ancient Armory guarantees high-tier upgrades (Epic or Legendary only)
	_clear_ui()

	# Get 3 random upgrade IDs
	var choices := _get_filtered_upgrades(3)

	# Assign guaranteed high tiers (Epic or Legendary only, with bias toward Epic)
	var choices_with_tiers: Array = []
	for upgrade_id in choices:
		# 70% Epic, 30% Legendary (no Common or Rare)
		var tier := Tier.EPIC if randf() < 0.7 else Tier.LEGENDARY
		choices_with_tiers.append({"id": upgrade_id, "tier": tier})
		_card_tiers[upgrade_id] = tier

	# Build UI with ancient armory theme (golden)
	_build_ui_with_tiers(choices_with_tiers)

	# Create golden animated background
	_create_ancient_armory_background()

	# Show and pause game
	visible = true
	get_tree().paused = true

	# Release mouse cursor!
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Force panel center after one frame (when viewport size is ready)
	await get_tree().process_frame
	if _panel:
		var viewport_size := get_viewport_rect().size
		_panel.position = Vector2(viewport_size.x / 2 - 325, viewport_size.y / 2 - 190)

	# Select first card by default
	if _cards.size() > 0:
		_set_card_highlight(0, true)

	# Start XP bar animation on HUD
	_start_hud_xp_animation()

	# Play entrance animation
	_play_entrance_animation()

func _clear_ui() -> void:
	# Clear previous cards and backgrounds
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_selected_card_index = 0
	_card_tiers.clear()

	# Clear old background effects
	for particles in _particle_systems:
		if is_instance_valid(particles):
			particles.queue_free()
	_particle_systems.clear()

	for ring in _rotating_rings:
		if is_instance_valid(ring):
			ring.queue_free()
		_rotating_rings.clear()

	for wave in _energy_waves:
		if is_instance_valid(wave):
			wave.queue_free()
		_energy_waves.clear()

func _create_ancient_armory_background() -> void:
	# Golden glowing background for Ancient Armory
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.08, 0.02, 0.85)  # Dark golden-brown tint
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Create rotating golden rings
	for i in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.5 + i * 0.3
		torus.outer_radius = 1.6 + i * 0.3
		ring.mesh = torus

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.3, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mat.emission_energy_multiplier = 2.0
		ring.set_surface_override_material(0, mat)

		add_child(ring)
		_rotating_rings.append(ring)

		# Store rotation speed for manual animation in _process
		ring.set_meta("rotation_speed_x", 2 * PI / (3.0 + i))
		ring.set_meta("rotation_speed_y", 2 * PI / (4.0 + i))

func _start_hud_xp_animation() -> void:
	# Find HUD and start the XP bar animation
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("start_xp_bar_animation"):
		hud.start_xp_bar_animation()

func _stop_hud_xp_animation() -> void:
	# Find HUD and stop the XP bar animation
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("stop_xp_bar_animation"):
		hud.stop_xp_bar_animation()

func _get_filtered_upgrades(count: int) -> Array:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Fallback: return random upgrades
		var all_keys := UPGRADES.keys()
		all_keys.shuffle()
		return all_keys.slice(0, count)
	
	var available: Array = []
	var player_stats: Dictionary = player.stats
	
	for upgrade_id in UPGRADES.keys():
		var data: Dictionary = UPGRADES[upgrade_id]
		var stat_name: String = data.stat
		
		# Check if this is an unlock upgrade
		if stat_name.begins_with("unlock_"):
			# Only show if not already unlocked
			if player_stats.has(stat_name) and player_stats[stat_name] == 0:
				available.append(upgrade_id)
			continue
		
		# Check if this is an ability upgrade (needs ability unlocked first)
		var ability_upgrade_map := {
			"tongue_lash_damage": "unlock_tongue_lash",
			"tadpole_count": "unlock_tadpole_swarm",
			"croak_blast_damage": "unlock_croak_blast",
			"fly_cloud_damage": "unlock_fly_cloud",
			"rage_duration": "unlock_amphibian_rage",
		}
		
		if ability_upgrade_map.has(stat_name):
			var required_unlock: String = ability_upgrade_map[stat_name]
			# Only show if ability is unlocked
			if player_stats.has(required_unlock) and player_stats[required_unlock] >= 1:
				available.append(upgrade_id)
			continue
		
		# Regular upgrade - always available
		available.append(upgrade_id)
	
	# Shuffle and return
	available.shuffle()
	return available.slice(0, count)

func hide_popup() -> void:
	# Play exit animation then hide
	_play_exit_animation()

func _finish_hide() -> void:
	visible = false
	get_tree().paused = false
	
	# Recapture mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	popup_closed.emit()

func _play_entrance_animation() -> void:
	if not _panel:
		return
	
	# Get overlay (first child)
	var overlay = get_child(0) if get_child_count() > 0 else null
	
	# Animate overlay fade in
	if overlay and overlay is ColorRect:
		overlay.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	
	# Animate panel scale with bounce
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.5, 0.5)
	_panel.modulate.a = 0.0
	
	var panel_tween := create_tween()
	panel_tween.set_parallel(true)
	panel_tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	panel_tween.tween_property(_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	
	# Animate cards slide in with stagger
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		card.modulate.a = 0.0
		card.position.y += 50
		
		var card_tween := create_tween()
		card_tween.set_parallel(true)
		card_tween.tween_property(card, "position:y", card.position.y - 50, 0.4).set_delay(0.2 + i * 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.2 + i * 0.1).set_ease(Tween.EASE_OUT)

func _play_exit_animation() -> void:
	if not _panel:
		_finish_hide()
		return

	# Stop XP bar animation on HUD
	_stop_hud_xp_animation()

	# Animate panel scale out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)

	# Get overlay
	var overlay = get_child(0) if get_child_count() > 0 else null
	if overlay and overlay is ColorRect:
		tween.tween_property(overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)

	# Fade out background effects
	_fade_out_background_effects(0.2)

	tween.chain().tween_callback(_finish_hide)

func _build_ui(choices: Array) -> void:
	# Clear existing UI
	for child in get_children():
		child.queue_free()

	# Create background container (behind everything)
	_background_container = Control.new()
	_background_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_container.z_index = -10  # Behind everything
	add_child(_background_container)

	# Semi-transparent overlay for darkening
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)  # 75% opacity overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Main panel - positioned in center using explicit anchors
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(650, 380)
	# Set anchors to center of screen
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	# Set offsets to center the panel (half size in each direction)
	_panel.offset_left = -325
	_panel.offset_top = -190
	_panel.offset_right = 325
	_panel.offset_bottom = 190
	
	# Panel style with proper padding
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BG
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 10
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)  # Add panel directly to popup (already centered via anchors)
	
	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "⬆️ LEVEL UP! ⬆️"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Choose an upgrade:"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	# Cards container
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 20)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)
	
	# Create cards
	for upgrade_id in choices:
		var card := _create_card(upgrade_id)
		_cards_container.add_child(card)
		_cards.append(card)

func _create_card(upgrade_id: String) -> Control:
	var data: Dictionary = UPGRADES.get(upgrade_id, {})
	if data.is_empty():
		return Control.new()

	# Card button (so it's clickable)
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 400)
	card.flat = true
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta("upgrade_id", upgrade_id)  # Store for keyboard selection

	# Card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.border_color = CATEGORY_COLORS.get(data.category, COLOR_BORDER)
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12
	card_style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("normal", card_style)

	# Hover style
	var hover_style := card_style.duplicate()
	hover_style.bg_color = COLOR_CARD_HOVER
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)
	card.add_theme_stylebox_override("focus", hover_style)

	# Background icon (as card background) - inside a clipped container
	var bg_container := Control.new()
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.z_index = -1
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.clip_contents = true
	card.add_child(bg_container)

	var bg_icon := TextureRect.new()
	bg_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_icon.modulate = Color(1, 1, 1, 0.12)  # Faint background

	# Load icon texture
	var icon_path: String = ICON_PATH + data.icon
	if ResourceLoader.exists(icon_path):
		bg_icon.texture = load(icon_path)

	bg_container.add_child(bg_icon)

	# Card content
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Spacer top
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_top)

	# Category label
	var category_label := Label.new()
	category_label.text = data.category.to_upper()
	category_label.add_theme_font_size_override("font_size", 12)
	category_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(data.category, COLOR_BORDER))
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(category_label)

	# Icon container (centered TextureRect)
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(icon_container)

	var icon_texture := TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(110, 110)
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Load icon texture
	if ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)
	else:
		# Fallback: show icon name as text
		var fallback_label := Label.new()
		fallback_label.text = data.icon.get_basename().replace("icon_", "").replace("_", " ").capitalize()
		fallback_label.add_theme_font_size_override("font_size", 14)
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_container.add_child(fallback_label)

	icon_container.add_child(icon_texture)

	# Name
	var name_label := Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = data.desc
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Connect click
	card.pressed.connect(func(): _on_card_selected(upgrade_id))

	return card

func _on_card_selected(upgrade_id: String) -> void:
	var tier: Tier = _card_tiers.get(upgrade_id, Tier.COMMON)
	var tier_data: Dictionary = TIER_DATA[tier]
	var upgrade_data := {
		"id": upgrade_id,
		"tier": tier,
		"multiplier": tier_data.multiplier
	}
	upgrade_selected.emit(upgrade_data)
	hide_popup()

# ============ ANIMATED BACKGROUND ============

func _create_animated_background() -> void:
	if not _background_container or not is_instance_valid(_background_container):
		return

	var viewport_size := get_viewport_rect().size
	var center := viewport_size / 2

	# Create MUCH simpler particle effects (no white dots, no big backgrounds)
	_create_rising_sparkles()
	_create_falling_particles()
	_create_colorful_confetti()

func _create_rising_sparkles() -> void:
	# Gold and cyan sparkles rising from bottom
	for i in range(15):
		var particles := GPUParticles2D.new()
		particles.position = Vector2(randf() * get_viewport_rect().size.x, get_viewport_rect().size.y + 20)
		particles.amount = 40
		particles.lifetime = 3.0 + randf() * 2.0
		particles.emitting = true

		var process_mat := ParticleProcessMaterial.new()
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_mat.emission_box_extents = Vector3(get_viewport_rect().size.x / 2, 10, 0)
		process_mat.direction = Vector3(0, -1, 0)
		process_mat.spread = 15.0
		process_mat.initial_velocity_min = 30.0
		process_mat.initial_velocity_max = 80.0
		process_mat.gravity = Vector3(0, -5, 0)
		process_mat.scale_min = 0.05
		process_mat.scale_max = 0.2

		var colors := [
			Color(1.0, 0.9, 0.2, 1.0),  # Gold
			Color(1.0, 0.6, 0.1, 1.0),  # Orange
			Color(0.2, 0.9, 1.0, 1.0),  # Cyan
			Color(0.5, 0.3, 1.0, 1.0),  # Purple
			Color(0.3, 1.0, 0.5, 1.0),  # Green
		]
		process_mat.color = colors[randi() % colors.size()]

		particles.process_material = process_mat

		var texture := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color.WHITE)
		gradient.add_point(1.0, Color.TRANSPARENT)
		texture.gradient = gradient
		particles.texture = texture

		_background_container.add_child(particles)
		_particle_systems.append(particles)

func _create_falling_particles() -> void:
	# Multi-colored falling particles
	for i in range(12):
		var particles := GPUParticles2D.new()
		particles.position = Vector2(randf() * get_viewport_rect().size.x, -20)
		particles.amount = 25
		particles.lifetime = 4.0 + randf() * 2.0
		particles.emitting = true

		var process_mat := ParticleProcessMaterial.new()
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_mat.emission_box_extents = Vector3(get_viewport_rect().size.x / 3, 20, 0)
		process_mat.direction = Vector3(0, 1, 0)
		process_mat.spread = 20.0
		process_mat.initial_velocity_min = 40.0
		process_mat.initial_velocity_max = 100.0
		process_mat.gravity = Vector3(0, 20, 0)
		process_mat.angular_velocity_min = -360.0
		process_mat.angular_velocity_max = 360.0
		process_mat.scale_min = 0.08
		process_mat.scale_max = 0.25

		var colors := [
			Color(1.0, 0.3, 0.5, 1.0),  # Pink
			Color(0.3, 0.5, 1.0, 1.0),  # Blue
			Color(1.0, 1.0, 0.3, 1.0),  # Yellow
			Color(0.5, 1.0, 0.8, 1.0),  # Teal
		]
		process_mat.color = colors[randi() % colors.size()]

		particles.process_material = process_mat
		particles.texture = _create_circle_texture()

		_background_container.add_child(particles)
		_particle_systems.append(particles)

func _create_floating_shapes() -> void:
	# Floating geometric shapes (squares, triangles, diamonds)
	var shapes = ["square", "triangle", "diamond", "circle"]
	var colors = [
		Color(1.0, 0.8, 0.2, 0.8),  # Gold
		Color(0.2, 0.8, 1.0, 0.8),  # Cyan
		Color(1.0, 0.4, 0.6, 0.8),  # Pink
		Color(0.6, 0.3, 1.0, 0.8),  # Purple
		Color(0.3, 1.0, 0.5, 0.8),  # Green
	]

	for i in range(20):
		var shape := Polygon2D.new()
		var shape_type: String = shapes[randi() % shapes.size()]
		var size := 6.0 + randf() * 12.0

		var points: PackedVector2Array = []
		if shape_type == "square":
			points = [
				Vector2(-size, -size), Vector2(size, -size),
				Vector2(size, size), Vector2(-size, size)
			]
		elif shape_type == "triangle":
			var h := size * sqrt(3)
			points = [
				Vector2(0, -h/2), Vector2(size/2, h/2),
				Vector2(-size/2, h/2)
			]
		elif shape_type == "diamond":
			points = [
				Vector2(0, -size), Vector2(size, 0),
				Vector2(0, size), Vector2(-size, 0)
			]
		else:  # circle approximation
			var segments := 8
			for j in range(segments):
				var angle := (TAU / segments) * j
				points.append(Vector2(cos(angle) * size, sin(angle) * size))

		shape.polygon = points
		shape.color = colors[randi() % colors.size()]
		shape.position = Vector2(
			randf() * get_viewport_rect().size.x,
			randf() * get_viewport_rect().size.y
		)
		shape.rotation = randf() * TAU

		# Float and rotate animation
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(shape, "position:y", shape.position.y - 50, 4.0 + randf() * 3.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(shape, "position:y", shape.position.y + 50, 4.0 + randf() * 3.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(shape, "rotation", shape.rotation + PI, 3.0 + randf() * 2.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(shape, "rotation", shape.rotation - PI, 3.0 + randf() * 2.0).set_ease(Tween.EASE_IN_OUT)

		# Pulse opacity
		var opacity_tween := create_tween()
		opacity_tween.set_parallel(true)
		opacity_tween.set_loops()
		opacity_tween.tween_property(shape, "modulate:a", 0.3, 1.0 + randf()).set_ease(Tween.EASE_IN_OUT)
		opacity_tween.tween_property(shape, "modulate:a", 1.0, 1.0 + randf()).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(shape)
		_energy_waves.append(shape)

func _create_spiral_particles() -> void:
	# Spiral emitters from corners
	var corners = [
		Vector2(0, 0),
		Vector2(get_viewport_rect().size.x, 0),
		Vector2(0, get_viewport_rect().size.y),
		Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y)
	]

	for corner in corners:
		var particles := GPUParticles2D.new()
		particles.position = corner
		particles.amount = 50
		particles.lifetime = 3.0
		particles.emitting = true

		var process_mat := ParticleProcessMaterial.new()
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		process_mat.direction = Vector3(0, 0, 0)
		process_mat.spread = 360.0
		process_mat.initial_velocity_min = 60.0
		process_mat.initial_velocity_max = 120.0
		process_mat.gravity = Vector3(0, 0, 0)
		process_mat.scale_min = 0.05
		process_mat.scale_max = 0.15
		process_mat.tangential_accel_min = 10.0
		process_mat.tangential_accel_max = 30.0

		var corner_colors := {
			Vector2(0, 0): Color(1.0, 0.4, 0.6, 1.0),  # Pink
			Vector2(1, 0): Color(0.4, 0.8, 1.0, 1.0),  # Blue
			Vector2(0, 1): Color(1.0, 0.9, 0.3, 1.0),  # Gold
			Vector2(1, 1): Color(0.6, 0.3, 1.0, 1.0),  # Purple
		}
		process_mat.color = corner_colors.get(corner, Color.WHITE)

		particles.process_material = process_mat
		particles.texture = _create_circle_texture()

		_background_container.add_child(particles)
		_particle_systems.append(particles)

func _create_burst_emitters() -> void:
	# Periodic burst emitters from center
	var center := get_viewport_rect().size / 2

	for i in range(4):
		var particles := GPUParticles2D.new()
		particles.position = center
		particles.amount = 60
		particles.lifetime = 2.5
		particles.emitting = true

		var process_mat := ParticleProcessMaterial.new()
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		process_mat.direction = Vector3(0, 0, 0)
		process_mat.spread = 360.0
		process_mat.initial_velocity_min = 80.0
		process_mat.initial_velocity_max = 150.0
		process_mat.gravity = Vector3(0, 0, 0)
		process_mat.scale_min = 0.03
		process_mat.scale_max = 0.12
		process_mat.damping_min = 0.5
		process_mat.damping_max = 0.8

		var burst_colors = [
			Color(1.0, 0.7, 0.1, 1.0),  # Orange-gold
			Color(0.1, 0.8, 0.9, 1.0),  # Cyan
			Color(1.0, 0.3, 0.5, 1.0),  # Magenta
			Color(0.4, 1.0, 0.4, 1.0),  # Lime
		]
		process_mat.color = burst_colors[i % burst_colors.size()]

		particles.process_material = process_mat
		particles.texture = _create_star_texture()

		_background_container.add_child(particles)
		_particle_systems.append(particles)

func _create_energy_waves() -> void:
	# Expanding color waves from center
	var center := get_viewport_rect().size / 2

	for i in range(6):
		var wave := ColorRect.new()
		wave.size = Vector2(10, 10)
		wave.position = center - Vector2(5, 5)
		wave.pivot_offset = Vector2(5, 5)
		wave.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var hue := 0.6 + (i * 0.08)
		wave.color = Color.from_hsv(hue, 0.8, 1.0, 0.3)

		# Create expanding animation
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(wave, "scale", Vector2(100, 100), 3.0 + i * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave, "scale", Vector2(20, 20), 3.0 + i * 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(wave, "modulate:a", 0.0, 3.0 + i * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave, "modulate:a", 0.4, 3.0 + i * 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(wave, "rotation", PI * 2, 5.0 + i).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(wave)
		_energy_waves.append(wave)

func _create_rotating_polygons() -> void:
	# Large rotating polygons in background
	var center := get_viewport_rect().size / 2
	var sides = [3, 4, 5, 6, 8]

	for i in range(sides.size()):
		var poly := Polygon2D.new()
		var num_sides: int = sides[i]
		var radius := 200.0 + i * 70.0

		var points: PackedVector2Array = []
		for j in range(num_sides):
			var angle: float = (TAU / num_sides) * j - PI / 2
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

		poly.polygon = points

		var hue := 0.55 + (i * 0.07)
		poly.color = Color.from_hsv(hue, 0.6, 1.0, 0.15)
		poly.position = center

		var rotator := Node2D.new()
		rotator.position = center
		rotator.add_child(poly)
		poly.position = Vector2.ZERO

		rotator.set_meta("rotation_speed", 0.15 + i * 0.08)
		rotator.set_meta("clockwise", i % 2 == 0)
		_background_container.add_child(rotator)
		_rotating_rings.append(rotator)

func _create_pulsing_rings() -> void:
	# Pulsing rings
	var center := get_viewport_rect().size / 2

	for i in range(4):
		var ring := Control.new()
		ring.position = center
		ring.pivot_offset = Vector2(150 + i * 40, 150 + i * 40)

		var ring_sprite := ColorRect.new()
		ring_sprite.size = Vector2(300 + i * 80, 300 + i * 80)
		ring_sprite.position = -(ring_sprite.size / 2)

		# Create ring shape using style with border only
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color.from_hsv(0.5 + i * 0.1, 0.8, 1.0, 0.4)
		style.corner_radius_top_left = int(150 + i * 40)
		style.corner_radius_top_right = int(150 + i * 40)
		style.corner_radius_bottom_left = int(150 + i * 40)
		style.corner_radius_bottom_right = int(150 + i * 40)
		ring_sprite.add_theme_stylebox_override("panel", style)

		ring.add_child(ring_sprite)

		# Pulse animation
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(ring, "scale", Vector2(1.1, 1.1), 1.5 + i * 0.2).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ring, "scale", Vector2(0.95, 0.95), 1.5 + i * 0.2).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ring, "modulate:a", 0.2, 2.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ring, "modulate:a", 0.6, 2.0).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(ring)
		_energy_waves.append(ring)

func _create_drifting_stars() -> void:
	# Drifting stars with trails
	for i in range(40):
		var star := ColorRect.new()
		star.size = Vector2(3, 3)
		star.position = Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y)
		star.pivot_offset = star.size / 2

		var brightness = 0.5 + randf() * 0.5
		star.color = Color(brightness, brightness, brightness, 1.0)

		# Drift animation
		var drift_x := (randf() - 0.5) * 100
		var drift_y := (randf() - 0.5) * 100
		var duration := 5.0 + randf() * 5.0

		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(star, "position:x", star.position.x + drift_x, duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(star, "position:x", star.position.x - drift_x, duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(star, "position:y", star.position.y + drift_y, duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(star, "position:y", star.position.y - drift_y, duration).set_ease(Tween.EASE_IN_OUT)

		# Twinkle
		var twinkle := create_tween()
		twinkle.set_parallel(true)
		twinkle.set_loops()
		twinkle.tween_property(star, "modulate:a", 0.2, 0.5 + randf()).set_ease(Tween.EASE_IN_OUT)
		twinkle.tween_property(star, "modulate:a", 1.0, 0.5 + randf()).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(star)
		_energy_waves.append(star)

func _create_colorful_confetti() -> void:
	# Colorful confetti pieces falling from top (one-time, no looping)
	var confetti_colors = [
		Color(1.0, 0.2, 0.3, 1.0),  # Red
		Color(1.0, 0.8, 0.2, 1.0),  # Yellow
		Color(0.2, 0.8, 0.4, 1.0),  # Green
		Color(0.2, 0.5, 1.0, 1.0),  # Blue
		Color(0.8, 0.2, 1.0, 1.0),  # Purple
		Color(1.0, 0.5, 0.0, 1.0),  # Orange
	]

	for i in range(30):
		var confetti := ColorRect.new()
		confetti.size = Vector2(4 + randf() * 6, 8 + randf() * 6)
		confetti.position = Vector2(randf() * get_viewport_rect().size.x, -20 - randf() * 200)  # Staggered start heights
		confetti.pivot_offset = confetti.size / 2
		confetti.color = confetti_colors[randi() % confetti_colors.size()]
		confetti.rotation = randf() * PI

		# Falling animation with rotation (one-time, no loop)
		var duration := 4.0 + randf() * 3.0
		var end_y := get_viewport_rect().size.y + 50
		var rotate_amount := (randf() - 0.5) * PI * 4

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(confetti, "position:y", end_y, duration).set_ease(Tween.EASE_IN)
		tween.tween_property(confetti, "rotation", confetti.rotation + rotate_amount, duration)
		tween.tween_property(confetti, "modulate:a", 0.0, duration).set_delay(duration * 0.8)

		_background_container.add_child(confetti)
		_energy_waves.append(confetti)

# Removed _reset_confetti - confetti now falls once only

func _create_streamers() -> void:
	# Wavy streamers from sides
	var streamer_colors = [
		Color(1.0, 0.7, 0.2, 0.6),
		Color(0.3, 0.8, 1.0, 0.6),
		Color(1.0, 0.4, 0.6, 0.6),
	]

	for i in range(8):
		var streamer := ColorRect.new()
		streamer.size = Vector2(3, 80 + randf() * 120)
		streamer.color = streamer_colors[randi() % streamer_colors.size()]

		var from_left := i % 2 == 0
		streamer.position = Vector2(
			-20 if from_left else get_viewport_rect().size.x + 20,
			100 + i * 80
		)

		# Wavy motion
		var amplitude := 30.0 + randf() * 30.0
		var frequency := 2.0 + randf() * 2.0
		var phase := randf() * TAU
		var duration := 4.0 + randf() * 2.0
		var direction := 1.0 if from_left else -1.0

		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(streamer, "position:x", streamer.position.x + direction * 200, duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(streamer, "position:x", streamer.position.x, duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(streamer, "rotation", sin(phase) * amplitude * 0.01, duration * 0.5).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(streamer, "rotation", -sin(phase) * amplitude * 0.01, duration * 0.5).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(streamer)
		_energy_waves.append(streamer)

func _create_glowing_orbs() -> void:
	# Large glowing orbs floating in background
	for i in range(8):
		var orb := ColorRect.new()
		var orb_size := 30.0 + randf() * 40.0
		orb.size = Vector2(orb_size, orb_size)
		orb.position = Vector2(
			randf() * get_viewport_rect().size.x,
			randf() * get_viewport_rect().size.y
		)
		orb.pivot_offset = orb.size / 2

		# Create glow effect with style
		var style := StyleBoxFlat.new()
		var hue := randf()
		style.bg_color = Color.from_hsv(hue, 0.7, 1.0, 0.3)
		style.shadow_color = Color.from_hsv(hue, 0.8, 1.0, 0.5)
		style.shadow_size = 20 + orb_size
		style.corner_radius_top_left = int(orb_size / 2)
		style.corner_radius_top_right = int(orb_size / 2)
		style.corner_radius_bottom_left = int(orb_size / 2)
		style.corner_radius_bottom_right = int(orb_size / 2)
		orb.add_theme_stylebox_override("panel", style)

		# Slow float animation
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_loops()
		tween.tween_property(orb, "position", orb.position + Vector2(randf() * 60 - 30, randf() * 60 - 30), 6.0 + randf() * 4.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(orb, "position", orb.position, 6.0 + randf() * 4.0).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(orb, "scale", Vector2(1.3, 1.3), 3.0 + randf()).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(orb, "scale", Vector2(0.8, 0.8), 3.0 + randf()).set_ease(Tween.EASE_IN_OUT)

		_background_container.add_child(orb)
		_energy_waves.append(orb)

func _create_circle_texture() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.5))
	gradient.add_point(1.0, Color.TRANSPARENT)
	texture.gradient = gradient
	texture.width = 16
	texture.height = 16
	texture.set_meta("is_circle", true)
	return texture

func _create_star_texture() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.3, Color(1.0, 1.0, 0.8, 0.8))
	gradient.add_point(1.0, Color.TRANSPARENT)
	texture.gradient = gradient
	texture.width = 12
	texture.height = 12
	return texture

func _rotate_rings_animation() -> void:
	# Ring rotation is now handled in _process for better performance
	pass

func _process(delta: float) -> void:
	# Animate rotating 3D rings
	for ring in _rotating_rings:
		if not is_instance_valid(ring):
			continue

		# Handle 3D rings (MeshInstance3D)
		if ring is MeshInstance3D:
			var rot_speed_x: float = ring.get_meta("rotation_speed_x", 0.0)
			var rot_speed_y: float = ring.get_meta("rotation_speed_y", 0.0)
			if rot_speed_x > 0:
				ring.rotation.x += rot_speed_x * delta
			if rot_speed_y > 0:
				ring.rotation.y += rot_speed_y * delta
		# Handle 2D rings (Node2D with rotation)
		elif ring.has_meta("rotation_speed"):
			var rotation_speed: float = ring.get_meta("rotation_speed", 0.2)
			var clockwise: bool = ring.get_meta("clockwise", true)
			var direction: float = 1.0 if clockwise else -1.0
			if "rotation" in ring:
				ring.rotation += direction * rotation_speed * delta

func _fade_out_background_effects(duration: float) -> void:
	# Fade out all background effects
	var all_effects := _particle_systems + _rotating_rings + _energy_waves

	for effect in all_effects:
		if not is_instance_valid(effect):
			continue

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(effect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

# Get upgrade data
static func get_upgrade_data(upgrade_id: String) -> Dictionary:
	return UPGRADES.get(upgrade_id, {})

# ============ TIER SYSTEM ============

func _get_random_tier() -> Tier:
	# Get player luck stat
	var player_luck := 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player and player.stats.has("luck"):
		player_luck = player.stats.luck

	# Luck increases higher tier chances
	# Base: Common 50%, Rare 35%, Epic 12%, Legendary 3%
	# Each 1% luck adds 0.15% to Legendary, 0.3% to Epic, 0.55% to Rare
	# and removes from Common

	var luck_bonus := player_luck  # 0.0 to 1.0+ (0% to 100%+)

	var legendary_chance := 0.03 + (luck_bonus * 0.15)   # 3% → up to 18%+
	var epic_chance := 0.12 + (luck_bonus * 0.30)       # 12% → up to 42%+
	var rare_chance := 0.35 + (luck_bonus * 0.55)       # 35% → up to 90%+

	# Normalize (ensure total = 1.0)
	var total := legendary_chance + epic_chance + rare_chance
	var common_remainder := 1.0 - total

	var roll := randf()

	# Check from rarest to common
	if roll < legendary_chance:
		return Tier.LEGENDARY
	elif roll < legendary_chance + epic_chance:
		return Tier.EPIC
	elif roll < legendary_chance + epic_chance + rare_chance:
		return Tier.RARE
	else:
		return Tier.COMMON

func _build_ui_with_tiers(choices: Array) -> void:
	# Clear existing UI
	for child in get_children():
		child.queue_free()

	# Create background container (behind everything)
	_background_container = Control.new()
	_background_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_container.z_index = -10  # Behind everything
	add_child(_background_container)

	# Semi-transparent overlay for darkening
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)  # 75% opacity overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Main panel - positioned in center using explicit anchors
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(650, 380)
	# Set anchors to center of screen
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	# Set offsets to center the panel (half size in each direction)
	_panel.offset_left = -325
	_panel.offset_top = -190
	_panel.offset_right = 325
	_panel.offset_bottom = 190

	# Panel style with proper padding
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BG
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 10
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "⬆️ LEVEL UP! ⬆️"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Choose an upgrade:"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Cards container
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 20)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)

	# Create cards with tiers
	for choice_data in choices:
		var upgrade_id: String = choice_data.id
		var tier: Tier = choice_data.tier
		var card := _create_card_with_tier(upgrade_id, tier)
		_cards_container.add_child(card)
		_cards.append(card)

func _create_card_with_tier(upgrade_id: String, tier: Tier) -> Control:
	var data: Dictionary = UPGRADES.get(upgrade_id, {})
	if data.is_empty():
		return Control.new()

	var tier_data: Dictionary = TIER_DATA[tier]
	var tier_color: Color = tier_data.border_color
	var tier_multiplier: float = tier_data.multiplier

	# Calculate actual value with tier multiplier
	var base_value = data.value
	var actual_value = base_value * tier_multiplier
	var value_text := _format_value(actual_value, data.stat)

	# Card button (so it's clickable)
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 400)
	card.flat = true
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta("upgrade_id", upgrade_id)  # Store for keyboard selection
	card.set_meta("tier", tier)  # Store tier for highlight

	# Card style with tier color
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.border_color = tier_color  # Use tier color for border
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_right = 12
	card_style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("normal", card_style)

	# Hover style
	var hover_style := card_style.duplicate()
	hover_style.bg_color = COLOR_CARD_HOVER
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)
	card.add_theme_stylebox_override("focus", hover_style)

	# Background icon (as card background) - inside a clipped container
	var bg_container := Control.new()
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.z_index = -1
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.clip_contents = true
	card.add_child(bg_container)

	var bg_icon := TextureRect.new()
	bg_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_icon.modulate = tier_data.color
	bg_icon.modulate.a = 0.1  # Very faint, tinted by tier color

	# Load icon texture
	var icon_path: String = ICON_PATH + data.icon
	if ResourceLoader.exists(icon_path):
		bg_icon.texture = load(icon_path)

	bg_container.add_child(bg_icon)

	# Card content
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Spacer top
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_top)

	# Tier badge (if not common)
	if tier != Tier.COMMON:
		var tier_badge := Label.new()
		tier_badge.text = tier_data.badge_text
		tier_badge.add_theme_font_size_override("font_size", 14)
		tier_badge.add_theme_color_override("font_color", Color.WHITE)
		tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_badge.z_index = 1

		# Badge background
		var badge_bg := PanelContainer.new()
		badge_bg.add_theme_stylebox_override("panel", _create_badge_style(tier_data.badge_color))

		var badge_vbox := VBoxContainer.new()
		badge_vbox.add_child(tier_badge)
		badge_bg.add_child(badge_vbox)

		var badge_center := CenterContainer.new()
		badge_center.add_child(badge_bg)
		vbox.add_child(badge_center)

	# Category label
	var category_label := Label.new()
	category_label.text = data.category.to_upper()
	category_label.add_theme_font_size_override("font_size", 12)
	category_label.add_theme_color_override("font_color", tier_color)
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(category_label)

	# Icon container (centered TextureRect)
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(icon_container)

	var icon_texture := TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(100, 100)
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Load icon texture
	if ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)
	else:
		# Fallback: show icon name as text
		var fallback_label := Label.new()
		fallback_label.text = data.icon.get_basename().replace("icon_", "").replace("_", " ").capitalize()
		fallback_label.add_theme_font_size_override("font_size", 14)
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_container.add_child(fallback_label)

	icon_container.add_child(icon_texture)

	# Name
	var name_label := Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", tier_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Description with tier-multiplied value
	var desc_label := Label.new()
	desc_label.text = data.desc.replace(str(_format_base_value(base_value, data.stat)), value_text)
	if desc_label.text == data.desc:
		# If replacement didn't work, append tier info
		desc_label.text = data.desc + " [" + value_text + "]"
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", tier_color)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Connect click
	card.pressed.connect(func(): _on_card_selected(upgrade_id))

	return card

func _create_badge_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _format_value(value: float, stat: String) -> String:
	# Format value based on stat type
	if stat == "max_health" or stat.contains("damage") or stat == "aura_damage":
		return str(int(value))
	elif stat.contains("chance") or stat.contains("resist") or stat.contains("lifesteal") or stat.contains("speed") or stat.contains("duration"):
		return str(int(value * 100)) + "%"
	elif stat.contains("count") or stat == "orbitals" or stat.contains("jump"):
		return str(int(value))
	else:
		return str(snapped(value, 0.01))

func _format_base_value(value: float, stat: String) -> String:
	# Try to match the format in original desc
	if stat.contains("chance") or stat.contains("resist") or stat.contains("lifesteal"):
		return str(int(value * 100)) + "%"
	elif stat == "max_health" or stat.contains("damage") or stat == "aura_damage":
		return str(int(value))
	elif stat.contains("count") or stat == "orbitals" or stat.contains("jump"):
		return str(int(value))
	else:
		return str(snapped(value, 0.01))
