extends CharacterBody3D
class_name HeronBoss

# Preload XP orb
const XPOrb = preload("res://scripts/xp_orb.gd")

# Boss stats
const MAX_HEALTH: float = 2000.0
const SPEED: float = 4.0
const ACCELERATION: float = 8.0

# Attack ranges
const PECK_RANGE: float = 8.0
const PECK_RANGE_SQ: float = 64.0
const STOMP_RANGE: float = 5.0
const STOMP_RANGE_SQ: float = 25.0
const WING_GUST_RANGE: float = 12.0

# Attack damage
const PECK_DAMAGE: float = 35.0
const STOMP_DAMAGE: float = 25.0
const WING_GUST_DAMAGE: float = 15.0
const WING_GUST_KNOCKBACK: float = 20.0

# Attack cooldowns (seconds)
const PECK_COOLDOWN: float = 2.5
const STOMP_COOLDOWN: float = 4.0
const WING_GUST_COOLDOWN: float = 6.0

# XP rewards
const XP_DROP_COUNT: int = 15
const XP_VALUE_MIN: int = 20
const XP_VALUE_MAX: int = 50

# Phase thresholds
const PHASE_2_THRESHOLD: float = 0.6  # 60% HP
const PHASE_3_THRESHOLD: float = 0.3  # 30% HP

# Node references
@onready var model: Node3D = $BossModel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: Control = null  # Set by spawner

var player: CharacterBody3D = null
var _has_player: bool = false
var skeleton: Skeleton3D = null

# State
var health: float = MAX_HEALTH
var _is_dead := false
var _is_dying := false
var current_phase: int = 1

# Attack timers
var peck_timer: float = 0.0
var stomp_timer: float = 0.0
var wing_gust_timer: float = 0.0

# Attack state
var _is_attacking := false
var _current_attack: String = ""
var _attack_hit_dealt := false

# Animation state
var _peck_reversing := false
var _attack_animation_timer: float = 0.0
var _attack_animation_duration: float = 0.0

# Signals
signal died(boss: HeronBoss)
signal phase_changed(new_phase: int)
signal health_changed(current: float, maximum: float)

func _ready() -> void:
	add_to_group("bosses")
	add_to_group("enemies")  # So player can target

	# Find player
	await get_tree().process_frame
	_find_player()

	# Setup animations
	_setup_animations()

	# Emit initial health
	health_changed.emit(health, MAX_HEALTH)

func _find_player() -> void:
	var found := get_tree().get_first_node_in_group("player")
	if found is CharacterBody3D:
		player = found
		_has_player = true

func _setup_animations() -> void:
	if not model:
		return

	skeleton = _find_skeleton(model)

	if skeleton and animation_player:
		MixamoAnimationLoader.setup_boss_animations(animation_player, skeleton)
		_play_animation("boss/walk")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null

func _play_animation(anim_name: String, speed: float = 1.0) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, -1, speed)

func take_damage(amount: float, is_crit: bool = false, damage_type: String = "normal") -> void:
	if _is_dead:
		return

	health = maxf(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)

	# Spawn damage number
	var dmg_type := "crit" if is_crit else damage_type
	DamageNumber.spawn(amount, global_position + Vector3(0, 4.0, 0), is_crit, dmg_type)

	# Check phase transitions
	_check_phase_transition()

	if health <= 0.0:
		_die()

func _check_phase_transition() -> void:
	var health_percent := health / MAX_HEALTH

	if current_phase == 1 and health_percent <= PHASE_2_THRESHOLD:
		current_phase = 2
		phase_changed.emit(2)
		_on_phase_2_start()
	elif current_phase == 2 and health_percent <= PHASE_3_THRESHOLD:
		current_phase = 3
		phase_changed.emit(3)
		_on_phase_3_start()

func _on_phase_2_start() -> void:
	# Phase 2: Faster attacks, enable wing gust
	print("BOSS PHASE 2: The Heron is getting angry!")
	# Camera shake effect
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("_apply_camera_shake"):
		player_node._apply_camera_shake(0.3, 0.5)

func _on_phase_3_start() -> void:
	# Phase 3: Enraged - all attacks faster and stronger
	print("BOSS PHASE 3: The Heron is ENRAGED!")
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("_apply_camera_shake"):
		player_node._apply_camera_shake(0.5, 1.0)

func _die() -> void:
	if _is_dying:
		return

	_is_dying = true
	_is_dead = true
	remove_from_group("enemies")
	remove_from_group("bosses")

	# Disable collision
	collision_layer = 0
	collision_mask = 0

	# Play death animation
	_play_animation("boss/death")

	if animation_player and animation_player.has_animation("boss/death"):
		var death_length := animation_player.get_animation("boss/death").length
		await get_tree().create_timer(death_length).timeout
	else:
		await get_tree().create_timer(2.0).timeout

	# Spawn lots of XP
	_spawn_xp_orbs()

	died.emit(self)
	queue_free()

func _spawn_xp_orbs() -> void:
	for i in range(XP_DROP_COUNT):
		var xp_value := randi_range(XP_VALUE_MIN, XP_VALUE_MAX)
		var orb := XPOrb.create(xp_value)
		get_tree().current_scene.add_child(orb)

		# Spawn in a circle around boss
		var angle := (float(i) / float(XP_DROP_COUNT)) * TAU
		var offset := Vector3(
			cos(angle) * randf_range(1.0, 3.0),
			randf_range(0.5, 2.0),
			sin(angle) * randf_range(1.0, 3.0)
		)
		orb.global_position = global_position + offset

func _physics_process(delta: float) -> void:
	if not _has_player or _is_dead or _is_dying:
		return

	# Update attack cooldowns
	if peck_timer > 0:
		peck_timer -= delta
	if stomp_timer > 0:
		stomp_timer -= delta
	if wing_gust_timer > 0:
		wing_gust_timer -= delta

	# Get phase-based multipliers
	var speed_mult := _get_phase_speed_multiplier()
	var cooldown_mult := _get_phase_cooldown_multiplier()

	# Direction to player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist_sq := to_player.length_squared()

	# Face player
	if model and dist_sq > 0.01:
		var target_rot := atan2(to_player.x, to_player.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rot, 5.0 * delta)

	# Attack logic (if not already attacking)
	if not _is_attacking:
		# Choose attack based on range and cooldowns
		if dist_sq <= STOMP_RANGE_SQ and stomp_timer <= 0:
			_start_stomp_attack(cooldown_mult)
		elif dist_sq <= PECK_RANGE_SQ and peck_timer <= 0:
			_start_peck_attack(cooldown_mult)
		elif current_phase >= 2 and wing_gust_timer <= 0:
			_start_wing_gust_attack(cooldown_mult)
		else:
			# Move towards player
			_move_towards_player(to_player, delta, speed_mult)

	# Handle attack animations
	_update_attack_state(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= 15.0 * delta

	move_and_slide()

func _get_phase_speed_multiplier() -> float:
	match current_phase:
		2: return 1.2
		3: return 1.5
		_: return 1.0

func _get_phase_cooldown_multiplier() -> float:
	match current_phase:
		2: return 0.8
		3: return 0.6
		_: return 1.0

func _get_phase_damage_multiplier() -> float:
	match current_phase:
		2: return 1.2
		3: return 1.5
		_: return 1.0

func _move_towards_player(to_player: Vector3, delta: float, speed_mult: float) -> void:
	var direction := to_player.normalized()
	var target_speed := SPEED * speed_mult

	velocity.x = move_toward(velocity.x, direction.x * target_speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, ACCELERATION * delta)

	# Play walk animation if not attacking
	if not _is_attacking and animation_player:
		if not animation_player.is_playing() or animation_player.current_animation != "boss/walk":
			_play_animation("boss/walk")

func _start_peck_attack(cooldown_mult: float) -> void:
	_is_attacking = true
	_current_attack = "peck"
	_attack_hit_dealt = false
	_peck_reversing = false
	peck_timer = PECK_COOLDOWN * cooldown_mult

	# Stop movement
	velocity.x = 0
	velocity.z = 0

	# Play peck down animation and set duration
	var speed := 1.5
	_play_animation("boss/peck", speed)
	if animation_player and animation_player.has_animation("boss/peck"):
		_attack_animation_duration = animation_player.get_animation("boss/peck").length / speed
		_attack_animation_timer = 0.0

func _start_stomp_attack(cooldown_mult: float) -> void:
	_is_attacking = true
	_current_attack = "stomp"
	_attack_hit_dealt = false
	_peck_reversing = false
	stomp_timer = STOMP_COOLDOWN * cooldown_mult

	velocity.x = 0
	velocity.z = 0

	# Use peck animation for stomp too (ground pound)
	var speed := 2.0
	_play_animation("boss/peck", speed)
	if animation_player and animation_player.has_animation("boss/peck"):
		_attack_animation_duration = animation_player.get_animation("boss/peck").length / speed
		_attack_animation_timer = 0.0

func _start_wing_gust_attack(cooldown_mult: float) -> void:
	_is_attacking = true
	_current_attack = "wing_gust"
	_attack_hit_dealt = false
	wing_gust_timer = WING_GUST_COOLDOWN * cooldown_mult

	velocity.x = 0
	velocity.z = 0

	# Create wing gust effect
	_create_wing_gust_effect()

func _update_attack_state(delta: float) -> void:
	if not _is_attacking:
		return

	match _current_attack:
		"peck":
			_update_peck_attack(delta)
		"stomp":
			_update_stomp_attack(delta)
		"wing_gust":
			_update_wing_gust_attack()

func _update_peck_attack(delta: float) -> void:
	if not animation_player:
		_end_attack()
		return

	_attack_animation_timer += delta

	# Calculate progress
	var progress := _attack_animation_timer / _attack_animation_duration

	# Deal damage at the peak of the peck (around 80% through)
	if not _attack_hit_dealt and progress >= 0.8:
		_attack_hit_dealt = true
		_deal_peck_damage()

	# When peck down finishes, reverse it
	if not _peck_reversing and _attack_animation_timer >= _attack_animation_duration:
		_peck_reversing = true
		_attack_animation_timer = 0.0
		# Play the animation in reverse
		var speed := 1.5
		_play_animation("boss/peck", -speed)
		if animation_player and animation_player.has_animation("boss/peck"):
			_attack_animation_duration = animation_player.get_animation("boss/peck").length / speed

	# End attack when reverse completes
	if _peck_reversing and _attack_animation_timer >= _attack_animation_duration:
		_end_attack()

func _update_stomp_attack(delta: float) -> void:
	if not animation_player:
		_end_attack()
		return

	_attack_animation_timer += delta

	# Calculate progress
	var progress := _attack_animation_timer / _attack_animation_duration

	# Deal damage at impact
	if not _attack_hit_dealt and progress >= 0.7:
		_attack_hit_dealt = true
		_deal_stomp_damage()

	# When animation finishes, reverse and end
	if not _peck_reversing and _attack_animation_timer >= _attack_animation_duration:
		_peck_reversing = true
		_attack_animation_timer = 0.0
		var speed := 2.0
		_play_animation("boss/peck", -speed)
		if animation_player and animation_player.has_animation("boss/peck"):
			_attack_animation_duration = animation_player.get_animation("boss/peck").length / speed

	if _peck_reversing and _attack_animation_timer >= _attack_animation_duration:
		_end_attack()

func _update_wing_gust_attack() -> void:
	# Wing gust is instant effect
	if not _attack_hit_dealt:
		_attack_hit_dealt = true
		_deal_wing_gust_damage()

	# Short delay then end
	await get_tree().create_timer(0.5).timeout
	_end_attack()

func _deal_peck_damage() -> void:
	if not _has_player:
		return

	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq <= PECK_RANGE_SQ:
		var damage := PECK_DAMAGE * _get_phase_damage_multiplier()
		if player.has_method("take_damage"):
			player.take_damage(damage)

		# Camera shake on hit
		if player.has_method("_apply_camera_shake"):
			player._apply_camera_shake(0.2, 0.3)

	# Spawn peck effect
	_create_peck_effect()

func _deal_stomp_damage() -> void:
	# AoE damage around boss
	var damage := STOMP_DAMAGE * _get_phase_damage_multiplier()

	if _has_player:
		var dist_sq := global_position.distance_squared_to(player.global_position)
		if dist_sq <= STOMP_RANGE_SQ:
			if player.has_method("take_damage"):
				player.take_damage(damage)

			# Knockback player
			var knockback_dir := (player.global_position - global_position).normalized()
			player.velocity += knockback_dir * 10.0 + Vector3.UP * 5.0

	# Create stomp effect
	_create_stomp_effect()

	# Camera shake
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("_apply_camera_shake"):
		player_node._apply_camera_shake(0.4, 0.4)

func _deal_wing_gust_damage() -> void:
	var damage := WING_GUST_DAMAGE * _get_phase_damage_multiplier()

	if _has_player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= WING_GUST_RANGE:
			if player.has_method("take_damage"):
				player.take_damage(damage)

			# Strong knockback away from boss
			var knockback_dir := (player.global_position - global_position).normalized()
			var knockback_strength := WING_GUST_KNOCKBACK * (1.0 - dist / WING_GUST_RANGE)
			player.velocity += knockback_dir * knockback_strength + Vector3.UP * 3.0

func _end_attack() -> void:
	_is_attacking = false
	_current_attack = ""
	_attack_hit_dealt = false
	_peck_reversing = false
	_attack_animation_timer = 0.0
	_attack_animation_duration = 0.0

	# Return to walk animation
	_play_animation("boss/walk")

func _create_peck_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.color = Color(1.0, 0.8, 0.2, 1.0)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.5, 0) + model.basis.z * -3.0

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _create_stomp_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0, 1, 0)
	mat.emission_ring_height = 0.1
	mat.emission_ring_radius = 3.0
	mat.emission_ring_inner_radius = 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = Color(0.6, 0.4, 0.2, 1.0)
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _create_wing_gust_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.color = Color(0.8, 0.9, 1.0, 0.6)
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 3.0, 0)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

# Apply poison (bosses take reduced poison damage)
func apply_poison(damage_per_second: float, duration: float) -> void:
	# Boss takes 50% poison damage
	var reduced_damage := damage_per_second * 0.5
	# Create a simple poison tick
	var ticks := int(duration / 0.5)
	for i in range(ticks):
		await get_tree().create_timer(0.5).timeout
		if _is_dead:
			break
		take_damage(reduced_damage * 0.5, false, "poison")

# Apply stun (bosses have reduced stun duration)
func apply_stun(duration: float) -> void:
	# Boss stun is 30% effective
	var reduced_duration := duration * 0.3
	_is_attacking = false
	await get_tree().create_timer(reduced_duration).timeout

# Apply knockback (bosses resist knockback)
func apply_knockback(force: Vector3) -> void:
	# Boss takes 20% knockback
	velocity += force * 0.2
