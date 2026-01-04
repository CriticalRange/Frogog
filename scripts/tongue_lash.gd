extends Area3D
class_name TongueLash

var damage: float = 35.0  # Settable via stats
const RANGE: float = 5.0
const CONE_ANGLE: float = 90.0  # Degrees
const DURATION: float = 0.3
const COOLDOWN: float = 1.5
const KNOCKBACK: float = 8.0

var _lifetime_timer: float = 0.0
var _owner: Node3D = null

# Visual components
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _whip_line: MeshInstance3D
var _particles: GPUParticles3D

func _ready() -> void:
	# Set up collision - tongue layer
	collision_layer = 0
	collision_mask = 8  # Enemy layer

	# Create the tongue whip visual (cone mesh)
	_create_tongue_mesh()

	# Create collision shape
	_create_collision()

	# Create particles
	_create_particles()

	# Connect signals
	body_entered.connect(_on_body_entered)

func _create_tongue_mesh() -> void:
	# Main tongue body - segmented cone
	_mesh_instance = MeshInstance3D.new()

	# Create a cone shape for the tongue lash
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 1.5
	cone.height = RANGE
	cone.radial_segments = 8
	cone.rings = 1
	_mesh_instance.mesh = cone

	# Rotate to point forward
	_mesh_instance.rotation_degrees.x = -90
	_mesh_instance.position.z = RANGE * 0.5

	# Tongue material - wet pink/red
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.4, 0.5, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.2, 0.3)
	material.emission_energy_multiplier = 1.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.3
	material.metallic = 0.1
	_mesh_instance.material_override = material

	add_child(_mesh_instance)

	# Whip line effect (central spine)
	_whip_line = MeshInstance3D.new()
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = 0.05
	line_mesh.bottom_radius = 0.15
	line_mesh.height = RANGE
	line_mesh.radial_segments = 6
	_whip_line.mesh = line_mesh
	_whip_line.rotation_degrees.x = -90
	_whip_line.position.z = RANGE * 0.5

	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 0.6, 0.7, 0.9)
	line_material.emission_enabled = true
	line_material.emission = Color(1.0, 0.3, 0.4)
	line_material.emission_energy_multiplier = 2.0
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_whip_line.material_override = line_material

	add_child(_whip_line)

func _create_collision() -> void:
	_collision_shape = CollisionShape3D.new()

	# Use a box shape for the cone area (simpler than cone collision)
	var shape := BoxShape3D.new()
	shape.size = Vector3(RANGE * 0.8, 1.0, RANGE)
	_collision_shape.shape = shape
	_collision_shape.position.z = RANGE * 0.5

	add_child(_collision_shape)

func _create_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 40
	_particles.lifetime = 0.4
	_particles.explosiveness = 0.3
	_particles.local_coords = false
	_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = RANGE * 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.color = Color(1.0, 0.5, 0.6, 0.6)
	_particles.process_material = mat

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	_particles.draw_pass_1 = particle_mesh

	add_child(_particles)

func _physics_process(delta: float) -> void:
	_lifetime_timer += delta

	# Animate the whip
	if _mesh_instance and _whip_line:
		var progress := _lifetime_timer / DURATION
		if progress <= 0.3:
			# Extend phase
			var extend := progress / 0.3
			_mesh_instance.scale.z = extend
			_whip_line.scale.z = extend
		else:
			# Retract phase
			var retract := 1.0 - ((progress - 0.3) / 0.7)
			_mesh_instance.scale.z = retract
			_whip_line.scale.z = retract
			_mesh_instance.transparency = 1.0 - retract

	# Rotate the whole thing for dynamic feel
	_mesh_instance.rotation.z += delta * 15.0

	if _lifetime_timer >= DURATION:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
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
		if body.has_method("apply_knockback"):
			var direction := (body.global_position - global_position).normalized()
			body.apply_knockback(direction * KNOCKBACK)

		# Spawn hit effect
		_spawn_hit_effect(body.global_position)

func _spawn_hit_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = pos

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(1.0, 0.7, 0.8, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(owner_node: Node3D, forward_direction: Vector3) -> TongueLash:
	var lash := TongueLash.new()
	lash._owner = owner_node

	# Position at owner's location with slight offset
	lash.global_position = owner_node.global_position + Vector3(0, 1.0, 0)

	# Rotate to face forward direction
	var forward_flat := forward_direction
	forward_flat.y = 0
	if forward_flat.length_squared() > 0.001:
		lash.look_at(lash.global_position + forward_flat, Vector3.UP)

	return lash
