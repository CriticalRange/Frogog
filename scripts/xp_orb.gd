extends Area3D
class_name XPOrb

# Use centralized config
const FLOAT_HEIGHT: float = GameConfig.XP_ORB.float_height
const BASE_MAGNET_RANGE: float = GameConfig.XP_ORB.base_magnet_range
const BASE_COLLECT_RANGE: float = GameConfig.XP_ORB.base_collect_range
const SPEED: float = GameConfig.XP_ORB.speed
const BOB_SPEED: float = GameConfig.XP_ORB.bob_speed
const BOB_AMOUNT: float = GameConfig.XP_ORB.bob_amount
const SPIN_SPEED: float = GameConfig.XP_ORB.spin_speed

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
	sphere.radius = GameConfig.XP_ORB.mesh_radius
	sphere.height = GameConfig.XP_ORB.mesh_height
	_mesh.mesh = sphere

	# Use centralized glowing material
	_mesh.material_override = VisualEffects.create_glowing_material(
		GameConfig.COLORS.xp_orb,
		GameConfig.COLORS.xp_orb_emission,
		3.0
	)
	add_child(_mesh)

	# Create collision shape (for physics queries if needed)
	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = GameConfig.XP_ORB.collision_radius
	_collision.shape = shape
	add_child(_collision)

	# Add a small light for glow effect
	_light = OmniLight3D.new()
	_light.light_color = GameConfig.COLORS.xp_orb
	_light.light_energy = GameConfig.XP_ORB.light_energy
	_light.omni_range = GameConfig.XP_ORB.light_range
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
	VisualEffects.spawn_particles(VisualEffects.EffectType.PICKUP_COLLECT, pos, get_tree())

# Factory function
static func create(value: int = 10) -> XPOrb:
	var orb := XPOrb.new()
	orb.xp_value = value
	return orb
