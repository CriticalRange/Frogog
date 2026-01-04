extends Interactable
class_name DifficultyTomb

## Ancient tomb that increases difficulty in exchange for better rewards

var _current_difficulty_level: int = 0
var _can_use: bool = true
var _glow_light: OmniLight3D = null

const DIFFICULTY_REWARDS = {
	1: "Enemies deal +25% damage, +15% XP",
	2: "Enemies deal +50% damage, +30% XP",
	3: "Enemies deal +75% damage, +50% XP, +1 random stat",
	4: "Enemies deal +100% damage, +75% XP, +2 random stats, rare drops",
	5: "CHAOS: Maximum danger, Maximum rewards"
}

func _ready() -> void:
	super._ready()
	interaction_prompt = "Press E to Challenge Fate"
	_create_visual()

func _create_visual() -> void:
	# Scale up the entire interactible
	scale = Vector3(1.2, 1.2, 1.2)

	# Tomb base
	var base := MeshInstance3D.new()
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(3, 0.5, 3)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.25, 0)
	add_child(base)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.3, 0.25, 0.2)
	stone_mat.roughness = 0.95
	base.set_surface_override_material(0, stone_mat)

	# Tomb body
	var body := MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(2.5, 2, 2.5)
	body.mesh = body_mesh
	body.position = Vector3(0, 1.5, 0)
	add_child(body)

	body.set_surface_override_material(0, stone_mat)

	# Tomb top (slanted roof)
	var roof := MeshInstance3D.new()
	var roof_mesh = PrismMesh.new()
	roof_mesh.size = Vector3(3, 3, 2.5)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 2.75, 0)
	add_child(roof)

	roof.set_surface_override_material(0, stone_mat)

	# Entrance (dark opening)
	var entrance := MeshInstance3D.new()
	var entrance_mesh = BoxMesh.new()
	entrance_mesh.size = Vector3(1, 1.5, 0.3)
	entrance.mesh = entrance_mesh
	entrance.position = Vector3(0, 1.25, 1.3)
	add_child(entrance)

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.05, 0.05, 0.08)
	dark_mat.roughness = 1.0
	entrance.set_surface_override_material(0, dark_mat)

	# Skull decoration
	var skull := MeshInstance3D.new()
	var skull_mesh = SphereMesh.new()
	skull_mesh.radius = 0.3
	skull_mesh.height = 0.5
	skull.mesh = skull_mesh
	skull.position = Vector3(0, 2.2, 1.4)
	skull.scale = Vector3(1, 0.8, 1)
	add_child(skull)

	var skull_mat := StandardMaterial3D.new()
	skull_mat.albedo_color = Color(0.9, 0.85, 0.7)
	skull_mat.roughness = 0.7
	skull.set_surface_override_material(0, skull_mat)

	# Eye sockets
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.0, 0.0)
	eye_mat.emission = Color(0.8, 0.2, 0.0) * 0.5

	var eye_left := MeshInstance3D.new()
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.08
	eye_left.mesh = eye_mesh
	eye_left.position = Vector3(-0.1, 2.25, 1.6)
	add_child(eye_left)
	eye_left.set_surface_override_material(0, eye_mat)

	var eye_right := MeshInstance3D.new()
	eye_right.mesh = eye_mesh.duplicate()
	eye_right.position = Vector3(0.1, 2.25, 1.6)
	add_child(eye_right)
	eye_right.set_surface_override_material(0, eye_mat)

	# Warning glow
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.0)
	glow.light_energy = 0.5
	glow.omni_range = 5
	glow.position = Vector3(0, 1.5, 0)
	add_child(glow)

	_glow_light = glow

func _process(delta: float) -> void:
	super._process(delta)

	# Pulsing warning glow
	if _glow_light:
		var pulse := (sin(Time.get_ticks_msec() / 1000.0 * 2.0) + 1.0) / 2.0
		_glow_light.light_energy = 0.3 + pulse * 0.4
		_glow_light.omni_range = 4 + pulse * 2

	# Update prompt based on difficulty level
	if _in_range:
		var next_level = _current_difficulty_level + 1
		if next_level <= 5:
			interaction_prompt = "Press E to Enter Difficulty %d" % next_level
			if DIFFICULTY_REWARDS.has(next_level):
				interaction_prompt += "\n" + DIFFICULTY_REWARDS[next_level]
		else:
			interaction_prompt = "MAXIMUM DIFFICULTY REACHED"
			_can_use = false

func _perform_interaction(player: Node3D) -> void:
	if not _can_use or _current_difficulty_level >= 5:
		return

	_current_difficulty_level += 1
	_can_use = false
	_play_activate_effect()
	_play_interaction_effect()

	# Apply difficulty increase
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("increase_difficulty"):
		game_manager.increase_difficulty()

	# Show confirmation
	_show_difficulty_confirmation(player)

	# Remove tomb after delay
	_remove_after_delay()

func _remove_after_delay() -> void:
	# Collapse into ground
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.5)
	tween.tween_property(self, "global_position:y", global_position.y - 1.5, 0.5)
	tween.tween_callback(func(): queue_free()).set_delay(0.5)

func _show_difficulty_confirmation(player: Node3D) -> void:
	var colors = [Color.YELLOW, Color.ORANGE, Color.RED, Color.MAGENTA, Color(0.5, 0.0, 1.0)]
	var color = colors[min(_current_difficulty_level - 1, 4)]

	# Show HUD notification
	_show_notification("DIFFICULTY %d ACTIVATED!" % _current_difficulty_level, color)

	# Screen shake effect
	if player.has_method("_apply_camera_shake"):
		player._apply_camera_shake(0.3, 5.0)

func _show_notification(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
