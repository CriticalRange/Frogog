extends Node3D
class_name FrogNuke

## Frog Nuke - Devours all enemies and pulls their XP to the player
## Activated ability that clears the entire map

const COOLDOWN: float = 180.0  # 3 minutes
const CAST_TIME: float = 1.5   # Time before nuke goes off
const PULL_DURATION: float = 1.0  # Time to pull XP after kill

var _owner: Node3D = null
var _is_on_cooldown: bool = false
var _cooldown_timer: float = 0.0
var _is_casting: bool = false
var _cast_timer: float = 0.0

signal nuke_started()
signal nuke_detonated()
signal nuke_finished()
signal cooldown_ready()

static func cast(owner_node: Node3D) -> FrogNuke:
	var nuke := FrogNuke.new()
	nuke._owner = owner_node
	nuke.global_position = owner_node.global_position
	owner_node.get_tree().current_scene.add_child(nuke)
	nuke.start_cast()
	return nuke

func start_cast() -> void:
	_is_casting = true
	_cast_timer = CAST_TIME
	nuke_started.emit()

	# Create casting visual effect
	_create_casting_effect()

	print("🐸 FROG NUKE CASTING! All enemies will be devoured!")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Handle cooldown
	if _is_on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_is_on_cooldown = false
			_cooldown_timer = 0.0
			cooldown_ready.emit()
			print("Frog Nuke is ready again!")

	# Handle casting
	if _is_casting:
		_cast_timer -= delta

		# Update casting visual
		_update_casting_effect()

		if _cast_timer <= 0:
			_detonate()

func _create_casting_effect() -> void:
	# Giant croaking sound wave indicator
	var indicator := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.2
	indicator.mesh = ring

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.3, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator.material_override = mat

	indicator.name = "CastingIndicator"
	add_child(indicator)
	indicator.global_position = global_position

	# Expand ring animation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "scale", Vector3(50, 50, 50), CAST_TIME)
	tween.tween_property(indicator, "modulate:a", 0.3, CAST_TIME)

func _update_casting_effect() -> void:
	# Spawn floating ripples
	if randf() < 0.1:
		_spawn_ripple()

func _spawn_ripple() -> void:
	var ripple := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.6
	ripple.mesh = ring

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.4, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple.material_override = mat

	get_tree().current_scene.add_child(ripple)
	ripple.global_position = global_position + Vector3(0, 0.5, 0)

	# Expand and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector3(3, 3, 3), 0.5)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ripple.queue_free).set_delay(0.5)

func _detonate() -> void:
	_is_casting = false
	nuke_detonated.emit()

	print("🐸 *CROAAAAAK!* FROG NUKE DETONATES! 🐸")

	# Start cooldown
	_is_on_cooldown = true
	_cooldown_timer = COOLDOWN

	# Create massive visual and audio effect
	_create_nuke_effect()

	# Kill all enemies and pull XP
	_devour_all_enemies()

	# Finish
	await get_tree().create_timer(2.0).timeout
	nuke_finished.emit()
	queue_free()

func _create_nuke_effect() -> void:
	# Giant expanding green shockwave
	var shockwave := GPUParticles3D.new()
	shockwave.amount = 200
	shockwave.lifetime = 2.0
	shockwave.one_shot = true
	shockwave.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.5
	mat.scale_max = 2.0
	mat.color = Color(0.3, 1.0, 0.3, 1.0)
	shockwave.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	shockwave.draw_pass_1 = mesh

	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position

	# Ground ripple effect
	var ground_ripple := MeshInstance3D.new()
	var ripple_mesh := TorusMesh.new()
	ripple_mesh.inner_radius = 1.0
	ripple_mesh.outer_radius = 1.5
	ground_ripple.mesh = ripple_mesh

	var ripple_mat := StandardMaterial3D.new()
	ripple_mat.albedo_color = Color(0.2, 0.8, 0.2, 0.8)
	ripple_mat.emission_enabled = true
	ripple_mat.emission = Color(0.2, 1.0, 0.2) * 3.0
	ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground_ripple.material_override = ripple_mat

	get_tree().current_scene.add_child(ground_ripple)
	ground_ripple.global_position = global_position
	ground_ripple.rotation.x = PI / 2

	# Expand ripple massively
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ground_ripple, "scale", Vector3(200, 200, 200), 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(ground_ripple, "modulate:a", 0.0, 1.5)
	tween.tween_callback(ground_ripple.queue_free).set_delay(1.5)

	# Screen shake effect
	if _owner and _owner.has_method("_apply_camera_shake"):
		_owner._apply_camera_shake(0.8, 0.5)

func _devour_all_enemies() -> void:
	# Use EntityRegistry for direct array access instead of tree search
	var enemies := []
	if EntityRegistry:
		enemies = EntityRegistry.get_all_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	var xp_orbs_created := 0

	for enemy in enemies:
		if enemy is Node3D and enemy.has_method("take_damage"):
			# Instant kill
			enemy.take_damage(99999, true, "nuke")
			xp_orbs_created += 1

	print("🐸 Devoured ", xp_orbs_created, " enemies!")

	# Pull all XP orbs to player
	_pull_xp_orbs()

func _pull_xp_orbs() -> void:
	var orbs := get_tree().get_nodes_in_group("xp_orbs")

	for orb in orbs:
		if orb is Node3D:
			# Instant teleport to player
			if _owner:
				orb.global_position = _owner.global_position + Vector3(0, 1, 0)

	print("✨ Pulled ", orbs.size(), " XP orbs to player!")

func get_cooldown_progress() -> float:
	if _is_on_cooldown:
		return 1.0 - (_cooldown_timer / COOLDOWN)
	return 1.0

func is_ready() -> bool:
	return not _is_on_cooldown
