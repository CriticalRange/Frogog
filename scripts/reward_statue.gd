extends Interactable
class_name RewardStatue

## Ancient statue that grants random rewards

enum RewardType {
	HEAL,
	EXPERIENCE,
	TEMPORARY_BOOST,
	PERMANENT_BUFF,
	RANDOM_UPGRADE
}

var _reward_cooldown: float = 60.0  # Can only use once per minute
var _can_use: bool = true
var _glow_ring: MeshInstance3D = null
var _glow_mat: StandardMaterial3D = null

const REWARD_CHOICES = [
	"slime_damage", "slime_speed", "slime_size", "slime_pierce", "slime_count",
	"fire_rate", "max_health", "move_speed", "crit_chance", "crit_damage"
]

func _ready() -> void:
	super._ready()
	interaction_prompt = "Press E for Ancient Blessing"
	_create_visual()

func _create_visual() -> void:
	# Scale up the entire interactible
	scale = Vector3(1.2, 1.2, 1.2)

	# Moai-like statue base
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 1.2
	base_mesh.bottom_radius = 1.5
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position = Vector3(0, 0.25, 0)
	add_child(base)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.4, 0.35, 0.3)
	base_mat.roughness = 0.9
	base.set_surface_override_material(0, base_mat)

	# Main body (Moai head shape)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.8
	body_mesh.height = 2.5
	body.mesh = body_mesh
	body.position = Vector3(0, 1.75, 0)
	body.rotation.x = PI / 2
	add_child(body)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.6, 0.5, 0.4)
	body_mat.roughness = 0.85
	body.set_surface_override_material(0, body_mat)

	# Face features (simple)
	var face := MeshInstance3D.new()
	face.name = "Face"
	var face_mesh = BoxMesh.new()
	face_mesh.size = Vector3(0.6, 0.4, 0.2)
	face.mesh = face_mesh
	face.position = Vector3(0, 2.2, 0.7)
	add_child(face)

	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.3, 0.25, 0.2)
	face.set_surface_override_material(0, face_mat)

	# Eyes
	var eye_left := MeshInstance3D.new()
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.08
	eye_mesh.height = 0.16
	eye_left.mesh = eye_mesh
	eye_left.position = Vector3(-0.15, 2.3, 0.85)
	add_child(eye_left)

	var eye_right := MeshInstance3D.new()
	eye_right.mesh = eye_mesh.duplicate()
	eye_right.position = Vector3(0.15, 2.3, 0.85)
	add_child(eye_right)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.8, 0.7, 0.3)
	eye_mat.emission = Color(0.8, 0.7, 0.3) * 0.3
	eye_left.set_surface_override_material(0, eye_mat)
	eye_right.set_surface_override_material(0, eye_mat)

	# Glow ring when usable
	var glow := TorusMesh.new()
	glow.inner_radius = 1.8
	glow.outer_radius = 2.0
	var glow_ring := MeshInstance3D.new()
	glow_ring.mesh = glow
	glow_ring.rotation.x = PI / 2
	glow_ring.position = Vector3(0, 0.3, 0)
	add_child(glow_ring)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.5)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_ring.set_surface_override_material(0, glow_mat)

	# Store reference to glow for animation
	_glow_ring = glow_ring
	_glow_mat = glow_mat

func _process(delta: float) -> void:
	super._process(delta)

	# Animate glow ring
	if _glow_ring and _can_use:
		_glow_ring.rotation.y += delta
		var pulse := (sin(Time.get_ticks_msec() / 1000.0 * 3.0) + 1.0) / 2.0
		_glow_mat.albedo_color.a = 0.3 + pulse * 0.3

func _perform_interaction(player: Node3D) -> void:
	if not _can_use:
		return

	_can_use = false

	if _glow_mat:
		_glow_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.3)

	_play_activate_effect()
	_play_interaction_effect()

	# Grant random reward
	_grant_random_reward(player)

	# Remove statue after a delay
	_remove_after_delay()

func _remove_after_delay() -> void:
	# Shrink and disappear
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.5)
	tween.tween_property(self, "global_position:y", global_position.y - 2, 0.5)
	tween.tween_callback(func(): queue_free()).set_delay(0.5)

func _grant_random_reward(player: Node3D) -> void:
	var reward_type := randi() % 5

	match reward_type:
		0:  # HEAL
			if player.has_method("heal"):
				player.heal(50)
			_show_notification("+50 HP", Color(0.2, 1.0, 0.3))

		1:  # EXPERIENCE
			if player.has_method("add_xp"):
				player.add_xp(100)
			_show_notification("+100 XP", Color(0.3, 0.8, 1.0))

		2:  # TEMPORARY BOOST
			var boosts = ["SPEED", "DAMAGE", "RAPID FIRE"]
			var boost = boosts[randi() % boosts.size()]
			match boost:
				"SPEED":
					if player.has_method("apply_speed_boost"):
						player.apply_speed_boost(15.0)
					_show_notification("SPEED BOOST!", Color(1.0, 1.0, 0.0))
				"DAMAGE":
					if player.has_method("apply_damage_boost"):
						player.apply_damage_boost(15.0)
					_show_notification("DAMAGE BOOST!", Color(1.0, 0.3, 0.0))
				"RAPID FIRE":
					if player.has_method("apply_rapid_fire"):
						player.apply_rapid_fire(15.0)
					_show_notification("RAPID FIRE!", Color(0.8, 0.0, 1.0))

		3:  # PERMANENT BUFF (small)
			var buff = REWARD_CHOICES[randi() % REWARD_CHOICES.size()]
			if player.has_method("grant_upgrade"):
				player.grant_upgrade(buff, 0.5)  # 50% of normal value
			# Format stat name for display
			var display_name = buff.capitalize().replace("_", " ")
			_show_notification("PERMANENT: +%s" % display_name, Color(1.0, 0.9, 0.3))

		4:  # RANDOM UPGRADE SELECTION
			if player.has_method("show_upgrade_selection"):
				player.show_upgrade_selection()
			_show_notification("CHOOSE YOUR REWARD!", Color(1.0, 0.9, 0.3))

func _show_notification(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
