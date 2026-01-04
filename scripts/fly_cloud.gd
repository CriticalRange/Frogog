extends Area3D
class_name FlyCloud

var damage: float = 8.0  # Settable via stats
const RADIUS: float = 4.0
const TICK_RATE: float = 0.5
const DURATION: float = 15.0
const FLY_COUNT: int = 12

var _owner: Node3D = null
var _duration_timer: float = 0.0
var _damage_timer: float = 0.0
var _flies: Array = []  # Array of fly nodes

# Visual components
var _cloud_particles: GPUParticles3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	# Set up collision
	collision_layer = 0
	collision_mask = 8  # Enemy layer

	# Create visual elements
	_create_cloud_particles()
	_create_collision()
	_spawn_flies()

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _create_cloud_particles() -> void:
	_cloud_particles = GPUParticles3D.new()
	_cloud_particles.amount = 50
	_cloud_particles.lifetime = 2.0
	_cloud_particles.emission_shape_radius = RADIUS
	_cloud_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = RADIUS * 0.8
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -0.5, 0)
	mat.tangential_accel_min = 1.0
	mat.tangential_accel_max = 3.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.4, 0.35, 0.3, 0.4)
	_cloud_particles.process_material = mat

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	_cloud_particles.draw_pass_1 = particle_mesh

	add_child(_cloud_particles)

func _create_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	_collision_shape.shape = shape
	add_child(_collision_shape)

func _spawn_flies() -> void:
	for i in range(FLY_COUNT):
		var fly := _create_fly()
		_flies.append(fly)
		add_child(fly)

func _create_fly() -> Node3D:
	var fly := Node3D.new()

	# Random orbit parameters
	var orbit_radius := randf_range(1.0, RADIUS)
	var orbit_speed := randf_range(1.5, 3.0)
	var orbit_height := randf_range(0.5, 2.0)
	var orbit_offset := randf() * TAU

	fly.set_meta("orbit_radius", orbit_radius)
	fly.set_meta("orbit_speed", orbit_speed)
	fly.set_meta("orbit_height", orbit_height)
	fly.set_meta("orbit_offset", orbit_offset)
	fly.set_meta("wing_phase", randf() * TAU)

	# Fly body
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.03
	body_mesh.height = 0.08
	body.mesh = body_mesh

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.15, 0.12, 0.1)
	body.material_override = body_material
	fly.add_child(body)

	# Wings
	var wings := MeshInstance3D.new()
	var wing_mesh := QuadMesh.new()
	wing_mesh.size = Vector2(0.15, 0.08)
	wings.mesh = wing_mesh

	var wing_material := StandardMaterial3D.new()
	wing_material.albedo_color = Color(0.9, 0.9, 0.85, 0.6)
	wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_material.no_depth_test = true
	wings.material_override = wing_material
	fly.add_child(wings)

	fly.set_meta("wings_node", wings)

	return fly

func _physics_process(delta: float) -> void:
	_duration_timer += delta
	_damage_timer += delta

	# Update flies
	_update_flies(delta)

	# Damage tick
	if _damage_timer >= TICK_RATE:
		_damage_timer = 0.0
		_damage_enemies_in_range()

	# Follow owner
	if _owner and is_instance_valid(_owner):
		global_position = _owner.global_position + Vector3(0, 1.5, 0)

	# Duration check
	if _duration_timer >= DURATION:
		_end_cloud()

func _update_flies(delta: float) -> void:
	var time := _duration_timer

	for fly in _flies:
		if not is_instance_valid(fly):
			continue

		var orbit_radius: float = fly.get_meta("orbit_radius")
		var orbit_speed: float = fly.get_meta("orbit_speed")
		var orbit_height: float = fly.get_meta("orbit_height")
		var orbit_offset: float = fly.get_meta("orbit_offset")
		var wing_phase: float = fly.get_meta("wing_phase")

		# Orbit position
		var angle := time * orbit_speed + orbit_offset
		var x := cos(angle) * orbit_radius
		var z := sin(angle) * orbit_radius
		var y := orbit_height + sin(time * 2.0 + orbit_offset) * 0.5

		fly.position = Vector3(x, y, z)

		# Wing flap animation
		wing_phase += delta * 30.0
		fly.set_meta("wing_phase", wing_phase)

		var wings: Node3D = fly.get_meta("wings_node")
		if wings and is_instance_valid(wings):
			wings.rotation.y = sin(wing_phase) * 0.5

func _damage_enemies_in_range() -> void:
	var bodies := get_overlapping_bodies()
	for body in bodies:
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

			_spawn_damage_tick(body.global_position)

func _spawn_damage_tick(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = pos

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(0.3, 0.25, 0.2, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		_spawn_damage_tick(body.global_position)

func _on_area_entered(_area: Area3D) -> void:
	pass

func _end_cloud() -> void:
	# Fade out effect
	_spawn_end_effect()
	queue_free()

func _spawn_end_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = RADIUS
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(0.4, 0.35, 0.3, 0.5)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(owner_node: Node3D) -> FlyCloud:
	var cloud := FlyCloud.new()
	cloud._owner = owner_node
	cloud.global_position = owner_node.global_position + Vector3(0, 1.5, 0)
	return cloud
