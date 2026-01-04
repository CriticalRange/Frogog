extends Area3D
class_name SlimeProjectile

# Pool reference
var _pool: ObjectPool = null

# Use centralized config
const BASE_SPEED: float = GameConfig.SLIME_PROJECTILE.base_speed
const BASE_DAMAGE: float = GameConfig.SLIME_PROJECTILE.base_damage
const LIFETIME: float = GameConfig.SLIME_PROJECTILE.lifetime
const GRAVITY: float = GameConfig.SLIME_PROJECTILE.gravity

# Stat-modified properties
var damage: float = BASE_DAMAGE
var speed_multiplier: float = 1.0
var size_multiplier: float = 1.0
var pierce_count: int = 0
var explosion_radius: float = 0.0
var chain_count: int = 0
var homing_strength: float = 0.0
var poison_duration: float = 0.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var crit_heal: float = 0.0

# Owner reference for lifesteal and crit heal
var player_owner: Node3D = null

var direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var _lifetime_timer: float = 0.0
var _pierced_enemies: Array[Node3D] = []
var _chained_targets: Array[Node3D] = []
var _has_hit: bool = false
var _is_pooled: bool = false  # Track if returned to pool

# Cached homing target for performance
var _homing_target: Node3D = null
var _target_update_timer: float = 0.0
const TARGET_UPDATE_INTERVAL: float = GameConfig.SLIME_PROJECTILE.target_update_interval

# Visual components (created in code - no scene needed!)
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _trail_particles: GPUParticles3D

func _ready() -> void:
	# Set up collision
	collision_layer = 4  # Projectile layer
	collision_mask = 8   # Enemy layer

	# Create mesh and collision
	_create_mesh()
	_create_collision()

	# Create trail particles
	_create_trail_particles()

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Initial velocity
	velocity = direction * BASE_SPEED * speed_multiplier

func _create_trail_particles() -> void:
	_trail_particles = GPUParticles3D.new()
	_trail_particles.amount = 20
	_trail_particles.lifetime = 0.5
	_trail_particles.explosiveness = 0.0
	_trail_particles.local_coords = false

	# Particle material
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1 * size_multiplier
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.5 * size_multiplier
	mat.scale_max = 1.0 * size_multiplier

	# Use centralized color helper
	var base_color := GameConfig.get_projectile_color(
		explosion_radius > 0.0, poison_duration > 0.0,
		chain_count > 0, homing_strength > 0.0
	)
	base_color.a = 0.8
	mat.color = base_color
	_trail_particles.process_material = mat

	# Trail mesh (small spheres)
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.05 * size_multiplier
	trail_mesh.height = 0.1 * size_multiplier
	_trail_particles.draw_pass_1 = trail_mesh

	add_child(_trail_particles)

func _physics_process(delta: float) -> void:
	# Stop processing if returned to pool
	if _is_pooled:
		return

	# Homing behavior with cached target (performance optimization)
	if homing_strength > 0.0 and not _has_hit:
		_target_update_timer += delta

		# Only update target periodically, not every frame
		if _target_update_timer >= TARGET_UPDATE_INTERVAL or not is_instance_valid(_homing_target):
			_target_update_timer = 0.0
			_homing_target = _find_nearest_enemy()

		if _homing_target and is_instance_valid(_homing_target):
			var to_target := (_homing_target.global_position - global_position).normalized()
			# Steer towards target
			var current_dir := velocity.normalized()
			var steer := (to_target - current_dir).normalized() * homing_strength * delta * 10.0
			direction = (direction + steer).normalized()
			velocity = direction * BASE_SPEED * speed_multiplier

	# Apply slight gravity for arc
	velocity.y -= GRAVITY * delta

	# Move
	global_position += velocity * delta

	# Rotate for cool effect
	_mesh.rotate_y(delta * 10.0)
	_mesh.rotate_x(delta * 7.0)

	# Lifetime
	_lifetime_timer += delta
	if _lifetime_timer >= LIFETIME:
		_explode(false)

func _find_nearest_enemy() -> Node3D:
	if not EntityRegistry or EntityRegistry.is_empty():
		return null

	# Use EntityRegistry for spatial query
	var exclude_array: Array[Node] = []
	for e in _pierced_enemies:
		exclude_array.append(e)
	for e in _chained_targets:
		exclude_array.append(e)

	return EntityRegistry.get_nearest_enemy(global_position, exclude_array, INF) as Node3D

func _on_body_entered(body: Node3D) -> void:
	if _is_pooled:
		return  # Already returned to pool

	if body.is_in_group("enemies"):
		if body in _pierced_enemies:
			return
		_pierced_enemies.append(body)

		var final_damage := damage
		var is_crit := false

		# Critical hit check
		if crit_chance > 0.0 and randf() < crit_chance:
			final_damage *= crit_damage
			is_crit = true
			# Crit heal
			if crit_heal > 0.0 and player_owner and player_owner.has_method("heal"):
				player_owner.heal(crit_heal)

		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(final_damage, is_crit)

		# Apply poison if configured
		if poison_duration > 0.0 and body.has_method("apply_poison"):
			body.apply_poison(damage * 0.3, poison_duration)

		# Apply knockback
		if body.has_method("apply_knockback"):
			var knock_dir := velocity.normalized()
			body.apply_knockback(knock_dir * 5.0)

		# Lifesteal
		if player_owner and player_owner.has_method("get"):
			if player_owner.stats.has("lifesteal") and player_owner.stats.lifesteal > 0.0:
				var heal_amount: float = final_damage * player_owner.stats.lifesteal
				if player_owner.has_method("heal"):
					player_owner.heal(heal_amount)

		# Handle piercing
		if pierce_count > 0:
			pierce_count -= 1
			if pierce_count <= 0:
				_explode(true, body)
			# Continue flying if we still have pierce
		else:
			_explode(true, body)

		# Handle chain lightning
		if chain_count > 0:
			_chain_damage(body, chain_count)

	elif not body.is_in_group("player"):
		# Hit ground or wall
		_explode(false)

func _on_area_entered(_area: Area3D) -> void:
	pass

func _chain_damage(source_enemy: Node3D, remaining_chains: int) -> void:
	if remaining_chains <= 0:
		return

	if not EntityRegistry or EntityRegistry.is_empty():
		return

	# Use EntityRegistry for spatial query
	var exclude_array: Array[Node] = []
	for e in _chained_targets:
		exclude_array.append(e)
	for e in _pierced_enemies:
		exclude_array.append(e)
	exclude_array.append(source_enemy)

	var closest := EntityRegistry.get_nearest_enemy(source_enemy.global_position, exclude_array, GameConfig.SLIME_PROJECTILE.chain_max_distance) as Node3D

	if closest:
		_chained_targets.append(closest)
		var chain_damage := damage * GameConfig.SLIME_PROJECTILE.chain_damage_multiplier

		# Create chain visual
		_create_chain_visual(source_enemy.global_position, closest.global_position)

		if closest.has_method("take_damage"):
			closest.take_damage(chain_damage, false, "normal")

		# Continue chain
		_chain_damage(closest, remaining_chains - 1)

func _create_chain_visual(from: Vector3, to: Vector3) -> void:
	VisualEffects.create_beam(from, to, get_tree())

func _explode(hit_enemy: bool = false, hit_target: Node3D = null) -> void:
	if _is_pooled:
		return  # Already returned to pool
	_is_pooled = true
	_has_hit = true

	var explode_pos := global_position

	# Explosion damage - use EntityRegistry for spatial query
	if explosion_radius > 0.0 and EntityRegistry:
		var nearby_enemies := EntityRegistry.get_enemies_in_range(explode_pos, explosion_radius)
		var radius_sq := explosion_radius * explosion_radius
		for enemy in nearby_enemies:
			if enemy == hit_target or enemy in _pierced_enemies or enemy in _chained_targets:
				continue
			var dist_sq := explode_pos.distance_squared_to(enemy.global_position)
			if dist_sq <= radius_sq:
				var dist := sqrt(dist_sq)  # Only sqrt once per hit enemy
				var falloff := 1.0 - (dist / explosion_radius) * 0.5
				var explosion_damage := damage * falloff * GameConfig.SLIME_PROJECTILE.explosion_damage_multiplier
				if enemy.has_method("take_damage"):
					enemy.take_damage(explosion_damage, false, "normal")

	# Create explosion effect
	var effect_type := VisualEffects.EffectType.EXPLOSION_LARGE if explosion_radius > 0.0 else VisualEffects.EffectType.EXPLOSION_SLIME
	VisualEffects.spawn_particles(effect_type, explode_pos, get_tree())

	# Return to pool or queue_free if not pooled
	if _pool:
		_pool.return_object(self)
	else:
		queue_free()

## Reset projectile for reuse (called by pool)
func reset(shoot_direction: Vector3, player_stats: Dictionary = {}) -> void:
	# Reset state
	_is_pooled = false  # Clear pooled flag so projectile can be used again
	direction = shoot_direction.normalized()
	velocity = direction * BASE_SPEED
	_lifetime_timer = 0.0
	_has_hit = false
	_pierced_enemies.clear()
	_chained_targets.clear()
	_homing_target = null  # Clear cached target
	_target_update_timer = 0.0
	visible = true

	# Reset stats
	if player_stats:
		damage = 20.0 * player_stats.get("slime_damage", 1.0)
		speed_multiplier = player_stats.get("slime_speed", 1.0)
		size_multiplier = player_stats.get("slime_size", 1.0)
		pierce_count = int(player_stats.get("slime_pierce", 0))
		explosion_radius = 2.0 * player_stats.get("explosion_radius", 0.0)
		chain_count = int(player_stats.get("chain_count", 0))
		homing_strength = player_stats.get("homing", 0.0)
		poison_duration = player_stats.get("poison_duration", 0.0)
		crit_chance = player_stats.get("crit_chance", 0.05)
		crit_damage = player_stats.get("crit_damage", 1.5)
		crit_heal = player_stats.get("crit_heal", 0.0)
	else:
		damage = BASE_DAMAGE
		speed_multiplier = 1.0
		size_multiplier = 1.0
		pierce_count = 0
		explosion_radius = 0.0
		chain_count = 0
		homing_strength = 0.0
		poison_duration = 0.0
		crit_chance = 0.05
		crit_damage = 1.5
		crit_heal = 0.0

	# Re-enable physics and processing
	set_physics_process(true)
	set_process(true)

	# Recreate mesh with new size
	if _mesh:
		_mesh.queue_free()
	_create_mesh()

	# Recreate collision with new size
	if _collision:
		_collision.queue_free()
	_create_collision()

	# Recreate trail particles with new size and color
	if _trail_particles:
		_trail_particles.queue_free()
	_create_trail_particles()

# Recreate mesh with current size
func _create_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = GameConfig.SLIME_PROJECTILE.base_radius * size_multiplier
	sphere.height = GameConfig.SLIME_PROJECTILE.base_height * size_multiplier
	_mesh.mesh = sphere

	# Use centralized color helper and glowing material
	var base_color := GameConfig.get_projectile_color(
		explosion_radius > 0.0, poison_duration > 0.0,
		chain_count > 0, homing_strength > 0.0
	)
	base_color.a = 0.9

	var material := VisualEffects.create_glowing_material(base_color)
	_mesh.material_override = material
	add_child(_mesh)

# Recreate collision with current size
func _create_collision() -> void:
	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = GameConfig.SLIME_PROJECTILE.collision_radius * size_multiplier
	_collision.shape = shape
	add_child(_collision)

# Factory function to create and shoot a slime ball
static func create(shoot_direction: Vector3, player_stats: Dictionary = {}) -> SlimeProjectile:
	var projectile := SlimeProjectile.new()
	projectile.direction = shoot_direction.normalized()

	if player_stats:
		projectile.damage = 20.0 * player_stats.get("slime_damage", 1.0)
		projectile.speed_multiplier = player_stats.get("slime_speed", 1.0)
		projectile.size_multiplier = player_stats.get("slime_size", 1.0)
		projectile.pierce_count = int(player_stats.get("slime_pierce", 0))
		projectile.explosion_radius = 2.0 * player_stats.get("explosion_radius", 0.0)
		projectile.chain_count = int(player_stats.get("chain_count", 0))
		projectile.homing_strength = player_stats.get("homing", 0.0)
		projectile.poison_duration = player_stats.get("poison_duration", 0.0)
		projectile.crit_chance = player_stats.get("crit_chance", 0.05)
		projectile.crit_damage = player_stats.get("crit_damage", 1.5)
		projectile.crit_heal = player_stats.get("crit_heal", 0.0)

	return projectile
