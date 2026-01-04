extends Node3D
class_name AmphibianRage

var duration: float = 8.0  # Base duration, can be modified by upgrades
const DAMAGE_MULTIPLIER: float = 2.0
const SPEED_MULTIPLIER: float = 1.5
const COOLDOWN: float = 45.0

# Buff values
const RANGED_COOLDOWN_REDUCTION: float = 0.5  # 50% faster shooting
const MELEE_COOLDOWN_REDUCTION: float = 0.4   # 60% faster melee
const AOE_COOLDOWN_REDUCTION: float = 0.3     # 70% faster AOE

signal rage_started()
signal rage_ended()
signal cooldown_changed(remaining: float, max_cooldown: float)

var _owner: Node3D = null
var _duration_timer: float = 0.0
var _is_active := false
var _cooldown_timer: float = 0.0
var _is_on_cooldown := false

# Visual components
var _aura_particles: GPUParticles3D
var _ground_ring: MeshInstance3D
var _energy_swirls: Array = []

func _ready() -> void:
	_create_visuals()

func _create_visuals() -> void:
	# Main aura particles
	_aura_particles = GPUParticles3D.new()
	_aura_particles.amount = 100
	_aura_particles.lifetime = 1.5
	_aura_particles.emission_shape_radius = 1.5
	_aura_particles.emitting = false  # Start off

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.0
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -2, 0)
	mat.tangential_accel_min = 2.0
	mat.tangential_accel_max = 5.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.2, 1.0, 0.3, 0.7)
	_aura_particles.process_material = mat

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.08
	particle_mesh.height = 0.16
	_aura_particles.draw_pass_1 = particle_mesh

	add_child(_aura_particles)

	# Ground ring
	_ground_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.4
	torus.outer_radius = 1.6
	torus.rings = 24
	torus.radial_segments = 48
	_ground_ring.mesh = torus

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.2, 1.0, 0.3, 0.5)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.1, 0.8, 0.2)
	ring_material.emission_energy_multiplier = 3.0
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_ring.material_override = ring_material

	_ground_ring.rotation_degrees.x = 90
	_ground_ring.visible = false
	add_child(_ground_ring)

	# Energy swirls (vertical rising particles)
	for i in range(3):
		var swirl := GPUParticles3D.new()
		swirl.amount = 30
		swirl.lifetime = 1.0
		swirl.emission_shape_radius = 0.5
		swirl.emitting = false

		var swirl_mat := ParticleProcessMaterial.new()
		swirl_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		swirl_mat.emission_sphere_radius = 0.3
		swirl_mat.direction = Vector3(0, 1, 0)
		swirl_mat.spread = 15.0
		swirl_mat.initial_velocity_min = 3.0
		swirl_mat.initial_velocity_max = 5.0
		swirl_mat.gravity = Vector3(0, 0, 0)
		swirl_mat.tangential_accel_min = 5.0
		swirl_mat.tangential_accel_max = 10.0
		swirl_mat.scale_min = 0.3
		swirl_mat.scale_max = 0.8
		swirl_mat.color = Color(0.3, 1.0, 0.5, 0.8)
		swirl.process_material = swirl_mat

		var swirl_mesh := SphereMesh.new()
		swirl_mesh.radius = 0.05
		swirl_mesh.height = 0.1
		swirl.draw_pass_1 = swirl_mesh

		var angle := (float(i) / 3.0) * TAU
		swirl.position = Vector3(cos(angle) * 1.2, 0, sin(angle) * 1.2)
		swirl.set_meta("orbit_angle", angle)
		swirl.set_meta("orbit_speed", 2.0 + i * 0.5)

		add_child(swirl)
		_energy_swirls.append(swirl)

func _physics_process(delta: float) -> void:
	# Follow owner
	if _owner and is_instance_valid(_owner):
		global_position = _owner.global_position

	# Handle active state
	if _is_active:
		_duration_timer += delta

		# Animate
		_animate_active(delta)

		if _duration_timer >= duration:
			_deactivate()

	# Handle cooldown
	if _is_on_cooldown:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_cooldown_timer = 0
			_is_on_cooldown = false
		else:
			cooldown_changed.emit(_cooldown_timer, COOLDOWN)

func _animate_active(delta: float) -> void:
	var progress := _duration_timer / duration
	var intensity := 1.0 - (progress * 0.3)  # Fade slightly over duration

	# Pulse the ring
	if _ground_ring:
		var pulse := 1.0 + sin(_duration_timer * 8.0) * 0.1
		_ground_ring.scale = Vector3(pulse, pulse, 1.0)

	# Rotate swirls
	var time := _duration_timer
	for i in range(_energy_swirls.size()):
		var swirl: GPUParticles3D = _energy_swirls[i]
		if is_instance_valid(swirl):
			var base_angle: float = swirl.get_meta("orbit_angle")
			var speed: float = swirl.get_meta("orbit_speed")
			var angle := base_angle + time * speed
			var radius := 1.2 + sin(time * 3.0 + i) * 0.2
			swirl.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)

func activate() -> bool:
	if _is_active or _is_on_cooldown:
		return false

	_is_active = true
	_duration_timer = 0.0

	# Enable visuals
	_aura_particles.emitting = true
	_ground_ring.visible = true
	for swirl in _energy_swirls:
		if is_instance_valid(swirl):
			swirl.emitting = true

	# Spawn activation effect
	_spawn_activation_effect()

	rage_started.emit()
	return true

func _deactivate() -> void:
	_is_active = false

	# Disable visuals
	_aura_particles.emitting = false
	_ground_ring.visible = false
	for swirl in _energy_swirls:
		if is_instance_valid(swirl):
			swirl.emitting = false

	# Start cooldown
	_is_on_cooldown = true
	_cooldown_timer = COOLDOWN
	cooldown_changed.emit(_cooldown_timer, COOLDOWN)

	# Spawn deactivation effect
	_spawn_deactivation_effect()

	rage_ended.emit()

func is_active() -> bool:
	return _is_active

func get_cooldown_percent() -> float:
	if not _is_on_cooldown:
		return 1.0
	return 1.0 - (_cooldown_timer / COOLDOWN)

func _spawn_activation_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 80
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.3, 1.0, 0.4, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _spawn_deactivation_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true
	particles.global_position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = Color(0.2, 0.8, 0.3, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.2)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(owner_node: Node3D) -> AmphibianRage:
	var rage := AmphibianRage.new()
	rage._owner = owner_node
	rage.global_position = owner_node.global_position
	return rage
