extends Node
class_name ParticlePool

# Efficient particle pooling system for visual effects
# Reduces GC pressure by reusing particle systems

# Pool configurations
const POOL_SIZE: int = 30

# Pooled types
enum ParticleType {
	EXPLOSION_GREEN,
	EXPLOSION_ORANGE,
	DASH,
	JUMP,
	DODGE,
	POWERUP,
	POISON,
	CHAIN,
	DISINTEGRATION,
}

# Pre-configured particle templates
var _templates: Dictionary = {}
var _pools: Dictionary = {}
var _parent: Node = null

# Cache for frequently used materials
var _material_cache: Dictionary = {}

func _ready() -> void:
	_parent = get_tree().current_scene
	_init_templates()
	_init_pools()

func _init_templates() -> void:
	# Create reusable material templates
	_material_cache["green"] = _create_base_material(Color(0.2, 1.0, 0.3))
	_material_cache["orange"] = _create_base_material(Color(1.0, 0.5, 0.2))
	_material_cache["blue"] = _create_base_material(Color(0.3, 0.8, 1.0))
	_material_cache["yellow"] = _create_base_material(Color(1.0, 1.0, 0.5))
	_material_cache["purple"] = _create_base_material(Color(0.8, 0.0, 1.0))
	_material_cache["poison"] = _create_base_material(Color(0.3, 0.9, 0.2))

func _create_base_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _init_pools() -> void:
	for ptype in ParticleType.values():
		_pools[ptype] = []

# Spawn a particle effect at position
func spawn(ptype: ParticleType, position: Vector3, custom_color: Color = Color.WHITE) -> void:
	var particles := _get_particle(ptype)
	if not particles:
		return

	particles.global_position = position

	# Apply custom color if provided
	if custom_color != Color.WHITE and particles.process_material:
		var mat = particles.process_material as ParticleProcessMaterial
		if mat:
			mat.color = custom_color

	# Auto-cleanup after lifetime
	var lifetime := particles.lifetime + 0.2
	var cleanup_timer := get_tree().create_timer(lifetime)
	cleanup_timer.timeout.connect(_on_particle_done.bind(particles, ptype), CONNECT_ONE_SHOT)

func _get_particle(ptype: ParticleType) -> GPUParticles3D:
	# Try to get from pool
	var pool = _pools.get(ptype, [])
	while pool.size() > 0:
		var particles = pool.pop_back()
		if is_instance_valid(particles):
			particles.visible = true
			particles.emitting = true
			return particles

	# Pool exhausted, create new
	return _create_particle(ptype)

func _on_particle_done(particles: GPUParticles3D, ptype: ParticleType) -> void:
	if not is_instance_valid(particles):
		return

	# Return to pool
	particles.visible = false
	particles.emitting = false
	if _parent:
		particles.reparent(_parent)
	_pools[ptype].append(particles)

func _create_particle(ptype: ParticleType) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	_parent.add_child(particles)

	match ptype:
		ParticleType.EXPLOSION_GREEN:
			_configure_explosion(particles, Color(0.1, 1.0, 0.2))
		ParticleType.EXPLOSION_ORANGE:
			_configure_explosion(particles, Color(1.0, 0.5, 0.2))
		ParticleType.DASH:
			_configure_dash(particles)
		ParticleType.JUMP:
			_configure_jump(particles)
		ParticleType.DODGE:
			_configure_dodge(particles)
		ParticleType.POWERUP:
			_configure_powerup(particles)
		ParticleType.POISON:
			_configure_poison(particles)
		ParticleType.CHAIN:
			_configure_chain(particles)
		ParticleType.DISINTEGRATION:
			_configure_disintegration(particles)

	return particles

func _configure_explosion(particles: GPUParticles3D, color: Color) -> void:
	particles.amount = 30
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = color
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	particles.draw_pass_1 = mesh

func _configure_dash(particles: GPUParticles3D) -> void:
	particles.amount = 30
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(0.3, 0.8, 1.0, 0.6)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

func _configure_jump(particles: GPUParticles3D) -> void:
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(1.0, 1.0, 1.0, 0.6)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

func _configure_dodge(particles: GPUParticles3D) -> void:
	particles.amount = 20
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.color = Color(1.0, 1.0, 0.5, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

func _configure_powerup(particles: GPUParticles3D) -> void:
	particles.amount = 30
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.5, 0.0, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

func _configure_poison(particles: GPUParticles3D) -> void:
	particles.amount = 20
	particles.lifetime = 0.8
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(0.3, 0.9, 0.2, 0.6)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

func _configure_chain(particles: GPUParticles3D) -> void:
	particles.amount = 10
	particles.lifetime = 0.2
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(0.6, 0.3, 1.0, 0.8)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

func _configure_disintegration(particles: GPUParticles3D) -> void:
	particles.amount = 50
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 1.0, 0.5)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -5.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(0.6, 0.3, 0.2, 1.0)
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	particles.draw_pass_1 = mesh

# Static singleton access
static var _instance: ParticlePool = null

static func get_instance() -> ParticlePool:
	if not _instance:
		_instance = ParticlePool.new()
		get_tree().current_scene.add_child(_instance)
	return _instance
