extends Area3D
class_name Pickup

## Pickup items that drop from enemies

enum PickupType {
	HEALTH_SMALL,
	HEALTH_LARGE,
	XP_SMALL,
	XP_LARGE,
	SPEED_BOOST,
	DAMAGE_BOOST,
	RAPID_FIRE
}

const PICKUP_COLORS = {
	PickupType.HEALTH_SMALL: Color(1.0, 0.3, 0.3),
	PickupType.HEALTH_LARGE: Color(1.0, 0.0, 0.0),
	PickupType.XP_SMALL: Color(0.3, 0.8, 1.0),
	PickupType.XP_LARGE: Color(0.0, 0.5, 1.0),
	PickupType.SPEED_BOOST: Color(1.0, 1.0, 0.0),
	PickupType.DAMAGE_BOOST: Color(1.0, 0.5, 0.0),
	PickupType.RAPID_FIRE: Color(0.8, 0.0, 1.0)
}

const PICKUP_VALUES = {
	PickupType.HEALTH_SMALL: 15,
	PickupType.HEALTH_LARGE: 40,
	PickupType.XP_SMALL: 10,
	PickupType.XP_LARGE: 50,
	PickupType.SPEED_BOOST: 10.0,
	PickupType.DAMAGE_BOOST: 10.0,
	PickupType.RAPID_FIRE: 8.0
}

var pickup_type: PickupType = PickupType.XP_SMALL
var lifetime: float = 15.0  # Disappear after 15 seconds
var bob_speed: float = 2.0
var bob_amount: float = 0.3
var rotation_speed: float = 2.0
var base_y: float = 0.0
var time_offset: float = 0.0  # For bob animation

var player_ref: CharacterBody3D = null

func _ready() -> void:
	# Configure collision
	body_entered.connect(_on_body_entered)
	collision_layer = 8  # Pickups layer
	collision_mask = 1   # Collide with player

	# Find player
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")
	base_y = position.y

	# Create visual
	create_visual()

func _process(delta: float) -> void:
	# Countdown lifetime
	lifetime -= delta
	if lifetime <= 0:
		# Fade out before disappearing
		if $Visual.scale.x > 0:
			$Visual.scale -= Vector3(2.0 * delta, 2.0 * delta, 2.0 * delta)
			if $Visual.scale.x <= 0:
				queue_free()
		return

	# Bob up and down (use accumulated delta instead of get_time_elapsed)
	time_offset += delta
	position.y = base_y + sin(time_offset * bob_speed) * bob_amount

	# Rotate
	$Visual.rotation.y += rotation_speed * delta

	# Magnetic attraction to player
	if player_ref and global_position.distance_to(player_ref.global_position) < 6.0:
		var direction = (player_ref.global_position - global_position).normalized()
		var speed = 8.0 + (6.0 - global_position.distance_to(player_ref.global_position)) * 2.0
		global_position += direction * speed * delta

func create_visual() -> void:
	var visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var color = PICKUP_COLORS.get(pickup_type, Color.WHITE)

	# Create main shape based on type
	var mesh_instance: MeshInstance3D

	match pickup_type:
		PickupType.HEALTH_SMALL, PickupType.HEALTH_LARGE:
			# Cross shape for health
			var cross_h = BoxMesh.new()
			cross_h.size = Vector3(0.4, 0.15, 0.15)
			var mesh1 = MeshInstance3D.new()
			mesh1.mesh = cross_h

			var cross_v = BoxMesh.new()
			cross_v.size = Vector3(0.15, 0.15, 0.4)
			var mesh2 = MeshInstance3D.new()
			mesh2.mesh = cross_v

			visual.add_child(mesh1)
			visual.add_child(mesh2)

			for m in [mesh1, mesh2]:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = color
				mat.emission = color * 0.5
				m.set_surface_override_material(0, mat)

		PickupType.XP_SMALL, PickupType.XP_LARGE:
			# Diamond shape for XP
			var diamond = BoxMesh.new()
			diamond.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = diamond
			visual.add_child(mesh_instance)

			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission = color * 0.6
			mesh_instance.set_surface_override_material(0, mat)

		_:
			# Sphere for power-ups
			var sphere = SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.4
			mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = sphere
			visual.add_child(mesh_instance)

			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission = color * 0.7
			mesh_instance.set_surface_override_material(0, mat)

	# Add glow ring for rare pickups
	if pickup_type in [PickupType.HEALTH_LARGE, PickupType.XP_LARGE, PickupType.SPEED_BOOST, PickupType.DAMAGE_BOOST, PickupType.RAPID_FIRE]:
		var ring = TorusMesh.new()
		ring.inner_radius = 0.25
		ring.outer_radius = 0.35
		var ring_instance = MeshInstance3D.new()
		ring_instance.mesh = ring
		ring_instance.rotation.x = PI / 2
		visual.add_child(ring_instance)

		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = color
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.5
		ring_instance.set_surface_override_material(0, ring_mat)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# Apply pickup effect
	apply_pickup(body)

	# Create pickup effect
	create_pickup_effect()

	# Remove pickup
	queue_free()

func apply_pickup(player: CharacterBody3D) -> void:
	match pickup_type:
		PickupType.HEALTH_SMALL, PickupType.HEALTH_LARGE:
			if player.has_method("heal"):
				player.heal(PICKUP_VALUES[pickup_type])

		PickupType.XP_SMALL, PickupType.XP_LARGE:
			if player.has_method("add_xp"):
				player.add_xp(PICKUP_VALUES[pickup_type])

		PickupType.SPEED_BOOST:
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(PICKUP_VALUES[pickup_type])

		PickupType.DAMAGE_BOOST:
			if player.has_method("apply_damage_boost"):
				player.apply_damage_boost(PICKUP_VALUES[pickup_type])

		PickupType.RAPID_FIRE:
			if player.has_method("apply_rapid_fire"):
				player.apply_rapid_fire(PICKUP_VALUES[pickup_type])

func create_pickup_effect() -> void:
	# Simple particle burst
	var particles = GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.5
	particles.process_material = ParticleProcessMaterial.new()

	var mat = particles.process_material
	mat.gravity = Vector3(0, -5, 0)
	var color = PICKUP_COLORS.get(pickup_type, Color.WHITE)
	mat.color = Color(color.r, color.g, color.b, 1.0)

	particles.emitting = true
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	# Auto-remove after particles finish - use callback instead of await
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Factory function to spawn a pickup at position
static func spawn(pos: Vector3, type: PickupType) -> Pickup:
	var pickup = preload("res://scenes/pickup.tscn").instantiate()
	pickup.pickup_type = type
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(pickup)
		pickup.global_position = pos
	return pickup

# Roll a random pickup based on weights
static func spawn_random(pos: Vector3, luck_boost: float = 0.0) -> Pickup:
	var rand_val = randf() + luck_boost * 0.1

	# 40% nothing
	if rand_val < 0.4:
		return null

	# 35% small XP
	elif rand_val < 0.75:
		return spawn(pos, PickupType.XP_SMALL)

	# 15% small health
	elif rand_val < 0.90:
		return spawn(pos, PickupType.HEALTH_SMALL)

	# 8% large XP
	elif rand_val < 0.98:
		return spawn(pos, PickupType.XP_LARGE)

	# 2% power-up or large health
	else:
		var powerup_roll = randf()
		if powerup_roll < 0.4:
			return spawn(pos, PickupType.HEALTH_LARGE)
		elif powerup_roll < 0.6:
			return spawn(pos, PickupType.SPEED_BOOST)
		elif powerup_roll < 0.8:
			return spawn(pos, PickupType.DAMAGE_BOOST)
		else:
			return spawn(pos, PickupType.RAPID_FIRE)
