extends CharacterBody3D
class_name Tadpole

const SPEED: float = 8.0
const DAMAGE: float = 10.0
const LIFETIME: float = 12.0
const ATTACK_RANGE: float = 1.5
const ATTACK_RANGE_SQ: float = 2.25
const ATTACK_COOLDOWN: float = 0.8

var _target: Node3D = null
var _lifetime_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _is_dead := false

# Visual components
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _tail_mesh: MeshInstance3D
var _trail_particles: GPUParticles3D
var _wobble_time: float = 0.0

func _ready() -> void:
	# Set up collision
	collision_layer = 2  # Ally layer
	collision_mask = 8   # Enemy layer

	# Create tadpole body
	_create_body()

	# Create tail
	_create_tail()

	# Create trail
	_create_trail()

	# Find target after one frame
	await get_tree().process_frame
	_find_target()

func _create_body() -> void:
	_mesh = MeshInstance3D.new()

	# Tadpole head - egg shape
	var head := SphereMesh.new()
	head.radius = 0.25
	head.height = 0.5
	_mesh.mesh = head

	# Tadpole material - green with transparency
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 0.4, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.6, 0.3)
	material.emission_energy_multiplier = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2
	_mesh.material_override = material

	# Offset mesh so origin is at the back
	_mesh.position.z = 0.2
	add_child(_mesh)

	# Eyes
	var left_eye := MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.05
	eye_sphere.height = 0.1
	left_eye.mesh = eye_sphere
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.1, 0.1, 0.1)
	left_eye.material_override = eye_material
	left_eye.position = Vector3(-0.1, 0.1, 0.35)
	_mesh.add_child(left_eye)

	var right_eye := left_eye.duplicate()
	right_eye.position = Vector3(0.1, 0.1, 0.35)
	_mesh.add_child(right_eye)

	# Collision shape
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 0.6
	_collision.shape = shape
	_collision.position.y = 0.0
	add_child(_collision)

func _create_tail() -> void:
	_tail_mesh = MeshInstance3D.new()

	# Tail - thin cone
	var tail := CylinderMesh.new()
	tail.top_radius = 0.02
	tail.bottom_radius = 0.15
	tail.height = 0.6
	tail.radial_segments = 6
	_tail_mesh.mesh = tail

	# Tail material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 0.4, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.6, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tail_mesh.material_override = material

	_tail_mesh.rotation_degrees.x = -90
	_tail_mesh.position.z = -0.3
	add_child(_tail_mesh)

func _create_trail() -> void:
	_trail_particles = GPUParticles3D.new()
	_trail_particles.amount = 25
	_trail_particles.lifetime = 0.6
	_trail_particles.explosiveness = 0.0
	_trail_particles.local_coords = false

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0, -1, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(0.3, 0.8, 0.5, 0.5)
	_trail_particles.process_material = mat

	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.04
	trail_mesh.height = 0.08
	_trail_particles.draw_pass_1 = trail_mesh

	add_child(_trail_particles)

func _find_target() -> void:
	# Use EntityRegistry for fast nearest enemy lookup
	if not EntityRegistry or EntityRegistry.is_empty():
		return

	_target = EntityRegistry.get_nearest_enemy(global_position, [], INF) as Node3D

func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	_wobble_time += delta * 10.0

	# Attack cooldown
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# Lifetime check
	if _lifetime_timer >= LIFETIME:
		_die()
		return

	# Find new target if we don't have one
	if not _target or not is_instance_valid(_target):
		_find_target()

	# Movement and attack
	if _target and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		var dist_sq := to_target.length_squared()

		# Face target
		if dist_sq > 0.01:
			var look_dir := to_target.normalized()
			look_at(global_position + look_dir, Vector3.UP)

		if dist_sq > ATTACK_RANGE_SQ:
			# Move toward target
			var direction := to_target.normalized()
			velocity = direction * SPEED
		else:
			# In range - attack
			velocity = velocity.lerp(Vector3.ZERO, 0.2)

			if _attack_cooldown <= 0:
				_attack()
	else:
		# No target - slow down
		velocity = velocity.lerp(Vector3.ZERO, 0.1)

	# Wobble animation
	if _mesh:
		_mesh.rotation.z = sin(_wobble_time) * 0.2
		_mesh.rotation.x = cos(_wobble_time * 0.7) * 0.1

	if _tail_mesh:
		_tail_mesh.rotation.z = sin(_wobble_time + 1.5) * 0.4

	# Float upward slightly
	velocity.y = sin(_wobble_time * 0.5) * 0.5

	move_and_slide()

func _attack() -> void:
	_attack_cooldown = ATTACK_COOLDOWN

	if _target and _target.has_method("take_damage"):
		var final_damage := DAMAGE
		var is_crit := false

		# Get player for stats using EntityRegistry
		var player = null
		if EntityRegistry:
			player = EntityRegistry.get_player()
		if not player:
			player = get_tree().get_first_node_in_group("player")

		# Check for critical hit
		if player and player.has_method("get"):
			if player.stats.has("crit_chance") and player.stats.crit_chance > 0:
				if randf() < player.stats.crit_chance:
					final_damage *= player.stats.get("crit_damage", 1.5)
					is_crit = true
					# Crit heal
					if player.stats.has("crit_heal") and player.stats.crit_heal > 0:
						if player.has_method("heal"):
							player.heal(player.stats.crit_heal)

			# Apply slime_damage multiplier
			if player.stats.has("slime_damage"):
				final_damage *= player.stats.slime_damage

		_target.take_damage(final_damage, is_crit)

		# Lifesteal
		if player and player.has_method("get"):
			if player.stats.has("lifesteal") and player.stats.lifesteal > 0:
				var heal_amount : float= final_damage * player.stats.lifesteal
				if player.has_method("heal"):
					player.heal(heal_amount)

	# Spawn bite effect
	_spawn_bite_effect()

func _spawn_bite_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = global_position + global_transform.basis.z * 0.3

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(0.8, 1.0, 0.5, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Death particles
	_spawn_death_effect()
	queue_free()

func _spawn_death_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.color = Color(0.3, 0.8, 0.5, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(spawn_position: Vector3) -> Tadpole:
	var tadpole := Tadpole.new()
	tadpole.global_position = spawn_position
	return tadpole
