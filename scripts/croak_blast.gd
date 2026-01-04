extends Area3D
class_name CroakBlast

var damage: float = 25.0  # Settable via stats
const MAX_RADIUS: float = 10.0
const EXPAND_TIME: float = 0.5
const STUN_DURATION: float = 1.5
const KNOCKBACK: float = 12.0

var _expand_timer: float = 0.0
var _hit_enemies: Array = []  # Track hit enemies to prevent multiple hits
var _owner: Node3D = null

# Visual components
var _ring_mesh: MeshInstance3D
var _collision_shape: CollisionShape3D
var _particles: GPUParticles3D
var _inner_glow: MeshInstance3D

func _ready() -> void:
	# Set up collision
	collision_layer = 0
	collision_mask = 8  # Enemy layer

	# Create the shockwave ring
	_create_ring()

	# Create collision
	_create_collision()

	# Create particles
	_create_particles()

	# Connect signals
	body_entered.connect(_on_body_entered)

func _create_ring() -> void:
	# Expanding ring
	_ring_mesh = MeshInstance3D.new()

	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.radial_segments = 48
	_ring_mesh.mesh = torus

	# Shockwave material - translucent cyan/white
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.9, 1.0, 0.6)
	material.emission_enabled = true
	material.emission = Color(0.5, 0.8, 1.0)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	_ring_mesh.material_override = material

	_ring_mesh.rotation_degrees.x = 90
	add_child(_ring_mesh)

	# Inner glow
	_inner_glow = MeshInstance3D.new()
	var inner_torus := TorusMesh.new()
	inner_torus.inner_radius = 0.3
	inner_torus.outer_radius = 0.5
	inner_torus.rings = 24
	inner_torus.radial_segments = 32
	_inner_glow.mesh = inner_torus

	var inner_material := StandardMaterial3D.new()
	inner_material.albedo_color = Color(0.9, 0.95, 1.0, 0.8)
	inner_material.emission_enabled = true
	inner_material.emission = Color(0.7, 0.9, 1.0)
	inner_material.emission_energy_multiplier = 3.0
	inner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_material.no_depth_test = true
	_inner_glow.material_override = inner_material

	_inner_glow.rotation_degrees.x = 90
	add_child(_inner_glow)

func _create_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 3.0
	_collision_shape.shape = shape
	_collision_shape.position.y = 0.0
	add_child(_collision_shape)

func _create_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 60
	_particles.lifetime = 0.8
	_particles.explosiveness = 0.5
	_particles.local_coords = false
	_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = Color(0.7, 0.9, 1.0, 0.7)
	_particles.process_material = mat

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.08
	particle_mesh.height = 0.16
	_particles.draw_pass_1 = particle_mesh

	add_child(_particles)

func _physics_process(delta: float) -> void:
	_expand_timer += delta

	var progress := _expand_timer / EXPAND_TIME
	var current_radius := _ease_out_back(progress) * MAX_RADIUS

	# Expand ring
	if _ring_mesh:
		var scale_val := current_radius
		_ring_mesh.scale = Vector3(scale_val, scale_val, 1.0)
		# Fade out as it expands
		var alpha := 1.0 - pow(progress, 2)
		if _ring_mesh.material_override is StandardMaterial3D:
			var mat := _ring_mesh.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.7, 0.9, 1.0, alpha * 0.6)

	if _inner_glow:
		var inner_scale := current_radius * 0.3
		_inner_glow.scale = Vector3(inner_scale, inner_scale, 1.0)
		var alpha := 1.0 - progress
		if _inner_glow.material_override is StandardMaterial3D:
			var mat := _inner_glow.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.9, 0.95, 1.0, alpha * 0.8)

	# Update collision
	if _collision_shape:
		if _collision_shape.shape is CylinderShape3D:
			var shape := _collision_shape.shape as CylinderShape3D
			shape.radius = current_radius

	if _expand_timer >= EXPAND_TIME:
		queue_free()

func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _on_body_entered(body: Node3D) -> void:
	# Check if we already hit this enemy
	if body in _hit_enemies:
		return

	if body.is_in_group("enemies"):
		_hit_enemies.append(body)

		var final_damage := damage
		var is_crit := false

		# Check for critical hit if owner is player
		if _owner and _owner.has_method("get"):
			if _owner.stats.has("crit_chance") and _owner.stats.crit_chance > 0:
				if randf() < _owner.stats.crit_chance:
					final_damage *= _owner.stats.get("crit_damage", 1.5)
					is_crit = true
					# Crit heal
					if _owner.stats.has("crit_heal") and _owner.stats.crit_heal > 0:
						if _owner.has_method("heal"):
							_owner.heal(_owner.stats.crit_heal)

		if body.has_method("take_damage"):
			body.take_damage(final_damage, is_crit)

		# Lifesteal
		if _owner and _owner.has_method("get"):
			if _owner.stats.has("lifesteal") and _owner.stats.lifesteal > 0:
				var heal_amount : float = final_damage * _owner.stats.lifesteal
				if _owner.has_method("heal"):
					_owner.heal(heal_amount)

		# Apply knockback
		var direction := (body.global_position - global_position).normalized()
		direction.y = 0.3  # Slight upward lift

		if body.has_method("apply_knockback"):
			body.apply_knockback(direction * KNOCKBACK)
		elif body is CharacterBody3D:
			body.velocity = direction * KNOCKBACK

		# Apply stun (enemy would need to handle this)
		if body.has_method("apply_stun"):
			body.apply_stun(STUN_DURATION)

		# Spawn hit effect
		_spawn_hit_effect(body.global_position)

func _spawn_hit_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = pos

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(0.8, 0.95, 1.0, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.8)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(owner_node: Node3D) -> CroakBlast:
	var blast := CroakBlast.new()
	blast._owner = owner_node
	blast.global_position = owner_node.global_position
	return blast
