extends CharacterBody3D
class_name Enemy

# Preload to avoid class loading issues
const XPOrb = preload("res://scripts/xp_orb.gd")

# Base stats (increased for harder difficulty)
const SPEED: float = 5.0  # Increased from 4.0
const ACCELERATION: float = 15.0  # Increased from 10.0 (faster acceleration)
const ATTACK_RANGE: float = 2.0
const ATTACK_RANGE_SQ: float = 4.0  # 2.0 * 2.0 - avoid sqrt!
const DAMAGE: float = 12.0  # Reduced for easier early game
const ATTACK_COOLDOWN: float = 1.0  # Slightly slower attacks
const MAX_HEALTH: float = 35.0  # Reduced for easier early game
const XP_DROP_MIN: int = 1
const XP_DROP_MAX: int = 3
const XP_VALUE_MIN: int = 5
const XP_VALUE_MAX: int = 15

@onready var model: Node3D = $EnemyModel
@onready var health_bar: Control = $HealthBar
@onready var ground_cast: RayCast3D = get_node_or_null("GroundCheck")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

# Animation
var skeleton: Skeleton3D = null
var _is_dying := false  # Track if death animation is playing

var player: CharacterBody3D = null  # Use base type to avoid circular dependency
var _has_player: bool = false
var terrain: Node = null  # Reference to terrain for height checking
var health: float = MAX_HEALTH
var attack_cooldown_timer := 0.0
var _is_dead := false

# Scaled stats (set on spawn based on difficulty)
var _scaled_max_health: float = MAX_HEALTH
var _scaled_damage: float = DAMAGE
var _scaled_speed: float = SPEED

# Poison system
var _poison_timer: float = 0.0
var _poison_damage: float = 0.0
var _poison_interval: float = 0.5
var _poison_interval_timer: float = 0.0

# Stun system
var _stun_timer: float = 0.0

# Knockback
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_timer := 0.0  # Track knockback duration

# Poison visual
var _poison_particles: GPUParticles3D = null

signal died(enemy: Enemy)

func _ready() -> void:
	add_to_group("enemies")
	_apply_difficulty_scaling()

	# Set up animations
	_setup_animations()

	# Single frame wait for scene setup
	await get_tree().process_frame
	_find_player()
	_find_terrain()

func _setup_animations() -> void:
	if not model:
		print("Enemy: Model not found!")
		return

	# Find skeleton
	skeleton = _find_skeleton(model)

	if not skeleton:
		print("Enemy: No skeleton found in model!")
		print("Enemy: Model children: ", _get_all_children_names(model))
		return

	print("Enemy: Skeleton found with ", skeleton.get_bone_count(), " bones")

	if skeleton and animation_player:
		MixamoAnimationLoader.setup_enemy_animations(animation_player, skeleton)
		_play_walk_animation()

func _get_all_children_names(node: Node, depth: int = 0) -> String:
	var result := ""
	var indent := "  ".repeat(depth)
	result += indent + node.name + " (" + node.get_class() + ")\n"
	for child in node.get_children():
		result += _get_all_children_names(child, depth + 1)
	return result

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null

func _play_walk_animation() -> void:
	if animation_player and animation_player.has_animation("enemy/walk"):
		animation_player.play("enemy/walk")
		animation_player.process_mode = Node.PROCESS_MODE_ALWAYS

func _apply_difficulty_scaling() -> void:
	# Get multipliers from GameManager
	var health_mult := GameManager.get_health_multiplier()
	var damage_mult := GameManager.get_damage_multiplier()
	var speed_mult := GameManager.get_speed_multiplier()

	# Apply scaling
	_scaled_max_health = MAX_HEALTH * health_mult
	_scaled_damage = DAMAGE * damage_mult
	_scaled_speed = SPEED * speed_mult

	# Set initial health to scaled max
	health = _scaled_max_health

func _find_player() -> void:
	var found := get_tree().get_first_node_in_group("player")
	if found is CharacterBody3D:
		player = found
		_has_player = true
	else:
		# Fallback to node path
		var main := get_tree().current_scene
		if main:
			found = main.get_node_or_null("Player")
			if found is CharacterBody3D:
				player = found
				_has_player = true

func _find_terrain() -> void:
	terrain = get_tree().get_first_node_in_group("terrain")

func take_damage(amount: float, is_crit: bool = false, damage_type: String = "normal") -> void:
	if _is_dead:
		return

	health = maxf(health - amount, 0.0)
	if health_bar:
		health_bar.health_percent = health / _scaled_max_health

	# Spawn damage number
	var dmg_type := "crit" if is_crit else damage_type
	DamageNumber.spawn(amount, global_position + Vector3(0, 1.5, 0), is_crit, dmg_type)

	if health <= 0.0:
		_die()

func apply_poison(damage_per_second: float, duration: float) -> void:
	_poison_damage = damage_per_second
	_poison_timer = duration
	_poison_interval_timer = 0.0

	# Create poison visual if not exists
	if not _poison_particles:
		_create_poison_visual()

func _create_poison_visual() -> void:
	_poison_particles = GPUParticles3D.new()
	_poison_particles.amount = 20
	_poison_particles.lifetime = 0.8
	_poison_particles.emitting = true

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
	_poison_particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	_poison_particles.draw_pass_1 = mesh

	add_child(_poison_particles)
	_poison_particles.position = Vector3(0, 0.5, 0)

func apply_stun(duration: float) -> void:
	_stun_timer = duration

func freeze(duration: float) -> void:
	# Freeze is just a longer stun with visual effect
	print("Enemy ", name, " frozen for ", duration, " seconds")
	_stun_timer = duration
	# Add freeze visual effect - turn model blue/icy
	if model:
		# Find any MeshInstance3D in the model hierarchy
		var mesh_instance = _find_mesh_instance(model)
		if mesh_instance:
			var freeze_mat = StandardMaterial3D.new()
			freeze_mat.albedo_color = Color(0.6, 0.9, 1.0)
			freeze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			freeze_mat.albedo_color.a = 0.6
			freeze_mat.emission_enabled = true
			freeze_mat.emission = Color(0.3, 0.8, 1.0) * 0.5
			mesh_instance.material_overlay = freeze_mat
			# Remove overlay after freeze duration
			get_tree().create_timer(duration).timeout.connect(func():
				if is_instance_valid(self) and is_instance_valid(mesh_instance):
					mesh_instance.material_overlay = null
			, CONNECT_ONE_SHOT)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func apply_knockback(force: Vector3) -> void:
	# Zero out Y component so enemies don't fly upward
	_knockback_velocity = Vector3(force.x, 0.0, force.z)
	_knockback_timer = 0.2  # Knockback lasts 0.2 seconds

func _die() -> void:
	if _is_dying:
		return  # Already dying

	_is_dying = true
	_is_dead = true
	remove_from_group("enemies")

	# Disable collision and hide model
	collision_layer = 0
	collision_mask = 0
	if model:
		model.visible = false
	if health_bar:
		health_bar.visible = false

	# Play disintegration effect
	_play_disintegration_effect()

	# Wait a moment for the effect
	await get_tree().create_timer(0.5).timeout

	# Spawn XP orbs!
	_spawn_xp_orbs()

	# Spawn random pickup
	_spawn_pickup()

	died.emit(self)
	queue_free()

func _play_disintegration_effect() -> void:
	# Create particle explosion effect
	var particles := GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true

	# Set up particle material
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
	mat.color = Color(0.6, 0.3, 0.2, 1.0)  # Brownish-red enemy color
	particles.process_material = mat

	# Use box particles for chunky disintegration look
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1.0, 0)

	# Create second burst - smaller pieces
	var particles2 := GPUParticles3D.new()
	particles2.amount = 30
	particles2.lifetime = 0.6
	particles2.one_shot = true
	particles2.emitting = true

	var mat2 := ParticleProcessMaterial.new()
	mat2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat2.emission_box_extents = Vector3(0.4, 0.8, 0.4)
	mat2.direction = Vector3(0, 1, 0)
	mat2.spread = 60.0
	mat2.initial_velocity_min = 3.0
	mat2.initial_velocity_max = 7.0
	mat2.gravity = Vector3(0, -8.0, 0)
	mat2.scale_min = 0.05
	mat2.scale_max = 0.15
	mat2.color = Color(0.8, 0.4, 0.3, 1.0)
	particles2.process_material = mat2

	var mesh2 := BoxMesh.new()
	mesh2.size = Vector3(0.08, 0.08, 0.08)
	particles2.draw_pass_1 = mesh2

	get_tree().current_scene.add_child(particles2)
	particles2.global_position = global_position + Vector3(0, 1.0, 0)

	# Auto-cleanup particles using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
		if is_instance_valid(particles2):
			particles2.queue_free()
	)

func _spawn_xp_orbs() -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	var luck_value := 0.0
	if player_node and player_node.has_method("get"):
		if player_node.stats.has("luck"):
			luck_value = player_node.stats.luck

	# Luck affects both orb count and XP value
	var luck_bonus := int(luck_value * 2)  # Each 1.0 luck = +2 max orbs
	var num_orbs := randi_range(XP_DROP_MIN, XP_DROP_MAX + luck_bonus)

	for i in range(num_orbs):
		var base_value := randi_range(XP_VALUE_MIN, XP_VALUE_MAX)
		# Luck increases XP value
		var xp_value := base_value + int(base_value * luck_value * 0.5)

		var orb := XPOrb.create(xp_value)
		get_tree().current_scene.add_child(orb)
		# Spawn at enemy position with slight random offset
		var offset := Vector3(
			randf_range(-0.5, 0.5),
			randf_range(0.5, 1.5),
			randf_range(-0.5, 0.5)
		)
		orb.global_position = global_position + offset

func _spawn_pickup() -> void:
	# Get player luck for better drops
	var player_node := get_tree().get_first_node_in_group("player")
	var luck_value := 0.0
	if player_node and player_node.has_method("get"):
		if player_node.stats.has("luck"):
			luck_value = player_node.stats.luck

	# Spawn random pickup at enemy position
	Pickup.spawn_random(global_position + Vector3(0, 0.5, 0), luck_value)

func _physics_process(delta: float) -> void:
	if not _has_player or _is_dead or _is_dying:
		return

	# Handle stun
	if _stun_timer > 0.0:
		_stun_timer -= delta
		# Can't move or attack while stunned
		velocity = velocity.lerp(Vector3.ZERO, ACCELERATION * delta)
		move_and_slide()
		# Update poison visual
		_update_poison_visual(delta)
		return

	# Handle poison
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_interval_timer += delta
		if _poison_interval_timer >= _poison_interval:
			_poison_interval_timer = 0.0
			take_damage(_poison_damage * _poison_interval, false, "poison")

		if _poison_particles:
			_poison_particles.emitting = true
	else:
		if _poison_particles:
			_poison_particles.emitting = false

	# Attack cooldown
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# Direction to player (only calculate once!)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist_sq := to_player.length_squared()  # No sqrt!

	if dist_sq > ATTACK_RANGE_SQ:
		# Move towards player (use scaled speed!)
		var direction := to_player.normalized()
		velocity.x = move_toward(velocity.x, direction.x * _scaled_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * _scaled_speed, ACCELERATION * delta)

		# Face player while moving
		if model and dist_sq > 0.01:
			model.rotation.y = atan2(to_player.x, to_player.z)
	else:
		# In range - stop and attack
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)

		if attack_cooldown_timer <= 0.0:
			attack_cooldown_timer = ATTACK_COOLDOWN
			if player.has_method("take_damage"):
				var final_damage: float = _scaled_damage
				# Check for thorns on player
				if player.has_method("get"):
					if player.stats.has("thorns") and player.stats.thorns > 0.0:
						var thorns_damage: float = final_damage * player.stats.thorns
						take_damage(thorns_damage)
				player.take_damage(final_damage)

	# Apply knockback
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		# Apply knockback velocity directly (as impulse)
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		# Decay knockback
		_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, delta * 10.0)
		if _knockback_timer <= 0.0:
			_knockback_velocity = Vector3.ZERO

	# Follow terrain height - set Y velocity before move_and_slide
	# Use RayCast3D for reliable ground detection, fallback to terrain height method
	var is_grounded := is_on_floor() or (ground_cast and ground_cast.is_colliding())
	if is_grounded:
		# Grounded - minimal Y velocity, let physics handle floor snapping
		velocity.y = minf(velocity.y, 0.0)  # Prevent upward drift
	elif terrain and terrain.has_method("get_height_at"):
		var target_height = terrain.get_height_at(global_position.x, global_position.z)
		var height_diff = target_height - global_position.y
		# Add upward/downward velocity to follow terrain (stronger than typical gravity)
		velocity.y = height_diff * 10.0
	else:
		# Default gravity if no terrain
		velocity.y -= 9.8 * delta

	move_and_slide()

	# Apply floor snap for better terrain adherence
	floor_snap_length = 0.1
	floor_max_angle = deg_to_rad(45)
	apply_floor_snap()

func _update_poison_visual(delta: float) -> void:
	if _poison_particles:
		pass  # Particles update automatically
