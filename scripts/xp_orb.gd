extends Area3D
class_name XPOrb

const FLOAT_HEIGHT: float = 0.5
const BASE_MAGNET_RANGE: float = 5.0
const BASE_COLLECT_RANGE: float = 1.0
const SPEED: float = 15.0
const BOB_SPEED: float = 3.0
const BOB_AMOUNT: float = 0.2
const SPIN_SPEED: float = 4.0

var xp_value: int = 10
var _player: Node3D = null
var _base_y: float = 0.0
var _time: float = 0.0

# Visual components
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _light: OmniLight3D

func _ready() -> void:
	# Add to xp_orbs group for frog nuke and other systems to find
	add_to_group("xp_orbs")

	# Set up collision
	collision_layer = 0
	collision_mask = 0  # We'll handle collection manually

	# Store base height for bobbing
	_base_y = global_position.y + FLOAT_HEIGHT

	# Use EntityRegistry for fast player lookup
	await get_tree().process_frame
	if EntityRegistry:
		_player = EntityRegistry.get_player()
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	# Create the orb mesh
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	_mesh.mesh = sphere

	# Glowing cyan/green XP material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.9, 1.0, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.7, 0.9)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = material
	add_child(_mesh)

	# Create collision shape (for physics queries if needed)
	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	_collision.shape = shape
	add_child(_collision)

	# Add a small light for glow effect
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 0.9, 1.0)
	_light.light_energy = 0.5
	_light.omni_range = 2.0
	_light.omni_attenuation = 2.0
	add_child(_light)

func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_time += delta

	# Get pickup range from player stats
	var magnet_range := BASE_MAGNET_RANGE
	var collect_range := BASE_COLLECT_RANGE

	if _player.has_method("get"):
		if _player.stats.has("pickup_range"):
			var multiplier: float = _player.stats.pickup_range
			magnet_range *= multiplier
			collect_range *= multiplier

	var magnet_range_sq := magnet_range * magnet_range
	var collect_range_sq := collect_range * collect_range

	# Calculate distance to player
	var to_player := _player.global_position - global_position
	var dist_sq := to_player.length_squared()

	# Check for collection
	if dist_sq < collect_range_sq:
		_collect()
		return

	# Magnet effect - move towards player when close
	if dist_sq < magnet_range_sq:
		var direction := to_player.normalized()
		# Speed increases as we get closer
		var speed := SPEED * (1.0 + (1.0 - dist_sq / magnet_range_sq))
		global_position += direction * speed * delta
	else:
		# Bobbing animation when not being pulled
		global_position.y = _base_y + sin(_time * BOB_SPEED) * BOB_AMOUNT

	# Always spin
	if _mesh:
		_mesh.rotate_y(SPIN_SPEED * delta)

func _collect() -> void:
	# Store position before queue_free (can't access global_position after)
	var collect_pos := global_position

	# Give XP to player
	if _player and _player.has_method("add_xp"):
		_player.add_xp(xp_value)

	# Collection effect - pass position before queue_free
	_spawn_collect_effect(collect_pos)

	queue_free()

func _spawn_collect_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true

	# Add to scene FIRST before setting global_position
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

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
	mat.color = Color(0.2, 0.9, 1.0, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function
static func create(value: int = 10) -> XPOrb:
	var orb := XPOrb.new()
	orb.xp_value = value
	return orb
