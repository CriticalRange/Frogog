extends CharacterBody3D
class_name Player

# Preload ability scripts to avoid class loading issues
const SlimeProjectileScript = preload("res://scripts/slime_projectile.gd")
const TongueLashClass = preload("res://scripts/tongue_lash.gd")
const TadpoleClass = preload("res://scripts/tadpole.gd")
const CroakBlastClass = preload("res://scripts/croak_blast.gd")
const FlyCloudClass = preload("res://scripts/fly_cloud.gd")
const AmphibianRageClass = preload("res://scripts/amphibian_rage.gd")
const FrogNukeClass = preload("res://scripts/frog_nuke.gd")
const AnimationSetupClass = preload("res://scripts/animation_setup.gd")

# Movement constants
const BASE_SPEED: float = 10.0
const ACCELERATION: float = 20.0
const FRICTION: float = 20.0
const ROTATION_SPEED: float = 15.0
const MOUSE_SENSITIVITY: float = 0.003

# Pre-calculated radian limits (avoid deg_to_rad every frame!)
const CAMERA_PITCH_MIN: float = -1.2217  # deg_to_rad(-70)
const CAMERA_PITCH_MAX: float = 1.2217   # deg_to_rad(70)

const BASE_JUMP_VELOCITY: float = 8.0
const GRAVITY: float = 15.0  # Reduced from 20.0

# Floor detection
const FLOOR_MAX_ANGLE: float = deg_to_rad(45)  # Max slope to consider as floor

const BASE_MAX_HEALTH: float = 100.0

# Auto-shooting
const BASE_SHOOT_COOLDOWN: float = 0.6  # ~1.7 shots per second

# Dash
const DASH_SPEED: float = 20.0
const DASH_DURATION: float = 0.2
const BASE_DASH_COOLDOWN: float = 1.5

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var model: Node3D = $CharacterModel
@onready var hurtbox: Area3D = get_node_or_null("Hurtbox")
@onready var ground_cast: RayCast3D = get_node_or_null("GroundCheck")

# Object pool for projectiles
var _projectile_pool: ObjectPool = null
const PROJECTILE_POOL_SIZE: int = 50

# Skeleton reference for animations
var skeleton: Skeleton3D = null

# Camera nodes - cached for performance
var camera_pivot: Node3D = null
var camera_pitch_node: Node3D = null
var camera: Camera3D = null
var _has_camera: bool = false  # Cached check

var is_moving := false
var camera_yaw := 0.0
var camera_pitch_angle := 0.0
var shoot_cooldown_timer := 0.0

# Dash state
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var is_dashing := false

# Jump state - simple
var jumps_remaining := 1  # Start with 1 ground jump
var _jump_input_locked := false  # Prevent input repeat

# Ability cooldowns (in seconds) - base values
const TONGUE_LASH_BASE_COOLDOWN: float = 1.5
const TADPOLE_SWARM_BASE_COOLDOWN: float = 10.0
const CROAK_BLAST_BASE_COOLDOWN: float = 5.0
const FLY_CLOUD_BASE_COOLDOWN: float = 12.0
const FROG_NUKE_COOLDOWN: float = 180.0  # 3 minutes

var tongue_lash_timer := 0.0
var tadpole_swarm_timer := 0.0
var croak_blast_timer := 0.0
var fly_cloud_timer := 0.0
var frog_nuke_timer := 0.0

# Camera shake
var camera_shake_intensity := 0.0
var camera_shake_duration := 0.0
var camera_shake_timer := 0.0
var _original_camera_offset := Vector3.ZERO

# Active abilities
var _fly_cloud_active: FlyCloud = null
var _amphibian_rage: AmphibianRage = null
var _orbitals: Array[Node3D] = []
var _aura_damage_timer := 0.0

var health: float = BASE_MAX_HEALTH
var _is_dead := false

# Animation state tracking
var _current_anim: String = ""
var _was_moving := false

# Level system
var level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 100

# Upgrade popup
var _upgrade_popup: Control = null

# Health regen timer
var _regen_timer := 0.0

# Player stats (modified by upgrades)
var stats := {
	# Weapon stats
	"slime_damage": 1.0,        # Multiplier
	"slime_speed": 1.0,         # Multiplier
	"slime_size": 1.0,          # Multiplier
	"slime_pierce": 0,          # Count
	"slime_count": 1,           # Projectile count
	"fire_rate": 1.0,           # Multiplier (higher = faster)
	"explosion_radius": 0.0,    # Multiplier (0 = no explosion)
	"chain_count": 0,           # Count
	"homing": 0.0,              # Strength
	"poison_duration": 0.0,     # Seconds

	# Movement stats
	"move_speed": 1.0,          # Multiplier
	"jump_power": 1.0,          # Multiplier
	"extra_jumps": 0,           # Count (0 = single jump, 1 = double jump, etc.)
	"dash_cooldown": 1.0,       # Multiplier (lower = faster)
	"air_control": 1.0,         # Multiplier

	# Defense stats
	"max_health": 0.0,          # Bonus HP
	"health_regen": 0.0,        # HP per second
	"damage_resist": 0.0,       # Percentage
	"dodge_chance": 0.0,        # Percentage
	"thorns": 0.0,              # Percentage reflected
	"lifesteal": 0.0,           # Percentage

	# Utility stats
	"xp_multiplier": 1.0,       # Multiplier
	"pickup_range": 1.0,        # Multiplier
	"luck": 0.0,                # Bonus percentage
	"cooldown_reduction": 0.0,  # Percentage

	# Critical stats
	"crit_chance": 0.05,        # Base 5%
	"crit_damage": 1.5,         # Base 150%
	"crit_heal": 0.0,           # HP on crit

	# Special stats
	"aura_damage": 0.0,         # DPS
	"orbitals": 0,              # Count

	# Ability unlocks
	"unlock_tongue_lash": 0,    # 0 = locked, 1 = unlocked
	"unlock_tadpole_swarm": 0,
	"unlock_croak_blast": 0,
	"unlock_fly_cloud": 0,
	"unlock_amphibian_rage": 0,

	# Ability stats
	"tongue_lash_damage": 0.0,  # Bonus multiplier (not base)
	"tadpole_count": 0,         # Bonus count
	"croak_blast_damage": 0.0,  # Bonus multiplier
	"fly_cloud_damage": 0.0,    # Bonus multiplier
	"rage_duration": 0.0,       # Bonus seconds
}

signal health_changed(new_health: float)
signal died()
signal xp_changed(current: int, required: int)
signal level_up(new_level: int)

# Ability cooldown signals (for HUD)
signal tongue_lash_cooldown_changed(remaining: float, max_cooldown: float)
signal tadpole_swarm_cooldown_changed(remaining: float, max_cooldown: float)
signal croak_blast_cooldown_changed(remaining: float, max_cooldown: float)
signal fly_cloud_cooldown_changed(remaining: float, max_cooldown: float)
signal ultimate_cooldown_changed(remaining: float, max_cooldown: float)
signal ultimate_activated()
signal rage_active_changed(is_active: bool)

func get_max_health() -> float:
	return BASE_MAX_HEALTH + stats.max_health

func take_damage(amount: float) -> void:
	if _is_dead:
		return

	# Check dodge
	if stats.dodge_chance > 0.0 and randf() < stats.dodge_chance:
		# Dodged!
		_spawn_dodge_effect()
		return

	# Apply damage resistance
	var final_damage := amount
	if stats.damage_resist > 0.0:
		final_damage = amount * (1.0 - minf(stats.damage_resist, 0.8))  # Cap at 80% reduction

	health = maxf(health - final_damage, 0.0)
	health_changed.emit(health)

	if health <= 0.0:
		_is_dead = true
		died.emit()

func heal(amount: float) -> void:
	health = minf(health + amount, get_max_health())
	health_changed.emit(health)

func get_health_percent() -> float:
	return health / get_max_health()

func add_xp(amount: int) -> void:
	# Apply XP multiplier
	var actual_xp := int(float(amount) * stats.xp_multiplier)
	current_xp += actual_xp

	# Check for level up (can level up multiple times)
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _calculate_xp_for_level(level)
		level_up.emit(level)
		print("LEVEL UP! Now level ", level)

		# Show upgrade popup
		_show_upgrade_popup()

	xp_changed.emit(current_xp, xp_to_next_level)

func _calculate_xp_for_level(lvl: int) -> int:
	# XP required scales: 100, 150, 200, 250, 300...
	return 50 + (lvl * 50)

func _show_upgrade_popup() -> void:
	# Create popup if it doesn't exist
	if not _upgrade_popup:
		_upgrade_popup = UpgradePopup.new()
		get_tree().current_scene.add_child(_upgrade_popup)
		_upgrade_popup.upgrade_selected.connect(_on_upgrade_selected)

	_upgrade_popup.show_upgrades()

func _on_upgrade_selected(upgrade_data: Dictionary) -> void:
	apply_upgrade(upgrade_data.id, upgrade_data.multiplier)

func apply_upgrade(upgrade_id: String, tier_multiplier: float = 1.0) -> void:
	var data: Dictionary = UpgradePopup.get_upgrade_data(upgrade_id)

	if data.is_empty():
		push_warning("Unknown upgrade: ", upgrade_id)
		return

	var stat_name: String = data.stat
	var base_value = data.value
	var value = base_value * tier_multiplier  # Apply tier multiplier

	if stats.has(stat_name):
		# Apply the upgrade
		if value is float and stats[stat_name] is float:
			stats[stat_name] += value
		elif value is int and stats[stat_name] is int:
			stats[stat_name] += value
		else:
			stats[stat_name] += value

		print("Upgraded ", stat_name, " by ", value, " (tier x", tier_multiplier, ") -> Now: ", stats[stat_name])

		# Special handling for ability unlocks
		if stat_name.begins_with("unlock_") and stats[stat_name] >= 1:
			_on_ability_unlocked(stat_name)

		# Update orbitals if count changed
		if stat_name == "orbitals":
			_update_orbitals()

		# Update max health immediately
		if stat_name == "max_health":
			health = minf(health, get_max_health())
			health_changed.emit(health)

## Called by interactables to show upgrade selection
func show_upgrade_selection() -> void:
	_show_upgrade_popup()

## Called by smugglers/reward statues to grant permanent stat boosts
func grant_upgrade(stat_name: String, value: float) -> void:
	if stat_name == "all":
		# Grant small boost to all combat stats
		var all_stats = ["slime_damage", "slime_speed", "fire_rate", "max_health", "move_speed"]
		for stat in all_stats:
			if stats.has(stat):
				var current = stats[stat]
				stats[stat] = current + value
		print("Granted +", value * 100, "% to all stats!")
	else:
		if stats.has(stat_name):
			stats[stat_name] += value
			print("Granted ", stat_name, " +", value)

	# Update max health if changed
	if stat_name in ["max_health", "all"]:
		health = minf(health, get_max_health())
		health_changed.emit(health)

# Weapon manager reference
var _weapon_manager: Node = null

func _on_ability_unlocked(ability_stat: String) -> void:
	# Create weapon manager if it doesn't exist
	if not _weapon_manager:
		var WeaponManagerClass = preload("res://scripts/weapon_manager.gd")
		_weapon_manager = WeaponManagerClass.new()
		_weapon_manager.player = self
		add_child(_weapon_manager)

	# Unlock the weapon
	_weapon_manager.unlock_weapon(ability_stat)

	var ability_names: Dictionary = {
		"unlock_tongue_lash": "👅 Tongue Lash",
		"unlock_tadpole_swarm": "🐸 Tadpole Swarm",
		"unlock_croak_blast": "🔊 Croak Blast",
		"unlock_fly_cloud": "🪰 Fly Cloud",
		"unlock_amphibian_rage": "😤 Amphibian Rage",
	}
	var weapon_name: String = ability_names.get(ability_stat, "New Weapon")
	print("🔓 WEAPON UNLOCKED: ", weapon_name, " - Auto-fires!")


func _ready() -> void:
	# Ensure we're in the player group (failsafe)
	add_to_group("player")

	# Register with EntityRegistry for efficient queries
	if EntityRegistry:
		EntityRegistry.register_player(self)

	# Cache camera nodes once
	camera_pivot = get_node_or_null("CameraPivot")
	if camera_pivot:
		camera_pitch_node = camera_pivot.get_node_or_null("CameraPitch")
		if camera_pitch_node:
			camera = camera_pitch_node.get_node_or_null("Camera3D")
			_has_camera = camera != null

	if camera:
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	# Set up animations
	_setup_animations()

	# Initialize projectile pool deferred to avoid "busy setting up children" error
	_init_projectile_pool_deferred.call_deferred()

func _init_projectile_pool_deferred() -> void:
	# Initialize projectile pool
	_projectile_pool = ObjectPool.get_pool_for_script(SlimeProjectileScript, PROJECTILE_POOL_SIZE, get_tree().current_scene)

func _on_hurtbox_body_entered(_body: Node3D) -> void:
	# Enemies handle their own damage dealing
	pass

func _input(event: InputEvent) -> void:
	# Early exit pattern - check type first
	if event is InputEventMouseMotion:
		if _has_camera:
			var motion := event as InputEventMouseMotion
			camera_yaw -= motion.relative.x * MOUSE_SENSITIVITY
			camera_pitch_angle = clampf(
				camera_pitch_angle - motion.relative.y * MOUSE_SENSITIVITY,
				CAMERA_PITCH_MIN,
				CAMERA_PITCH_MAX
			)
			camera_pivot.rotation.y = camera_yaw
			camera_pitch_node.rotation.x = camera_pitch_angle
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	# Dash input (Shift) - using shift key directly to avoid conflict with jump
	if event is InputEventKey and event.pressed and event.keycode == KEY_SHIFT and dash_cooldown_timer <= 0 and not is_dashing:
		_start_dash()

	# Ability inputs
	if event.is_action_pressed("ui_page_down") and tongue_lash_timer <= 0:  # Key: 1
		_use_tongue_lash()
	if event.is_action_pressed("ui_page_up") and tadpole_swarm_timer <= 0:  # Key: 2
		_use_tadpole_swarm()
	if event.is_action_pressed("ui_home") and croak_blast_timer <= 0:  # Key: 3
		_use_croak_blast()
	if event.is_action_pressed("ui_end") and fly_cloud_timer <= 0:  # Key: 4
		_use_fly_cloud()
	if event.is_action_pressed("ui_text_backspace"):  # Key: R - Ultimate
		_use_amphibian_rage()

	# Frog Nuke - Key: N
	if event is InputEventKey and event.pressed and event.keycode == KEY_N and frog_nuke_timer <= 0:
		_use_frog_nuke()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = DASH_DURATION

	var cooldown: float = BASE_DASH_COOLDOWN * stats.dash_cooldown
	dash_cooldown_timer = _apply_cooldown_reduction(cooldown)

	# Spawn dash effect
	_spawn_dash_effect()

func _spawn_dash_effect() -> void:
	var particles := GPUParticles3D.new()
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

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.5, 0)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _spawn_dodge_effect() -> void:
	var particles := GPUParticles3D.new()
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

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1.0, 0)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _apply_cooldown_reduction(base_cooldown: float) -> float:
	if stats.cooldown_reduction > 0.0:
		return base_cooldown * (1.0 - minf(stats.cooldown_reduction, 0.7))  # Max 70% reduction
	return base_cooldown

func _shoot_slime() -> bool:
	# Use EntityRegistry for O(1) spatial query instead of O(n) group iteration
	var closest_enemy: Node3D = null
	if EntityRegistry and not EntityRegistry.is_empty():
		closest_enemy = EntityRegistry.get_nearest_enemy(global_position, [], INF) as Node3D

	if not closest_enemy:
		return false  # No enemies to shoot at

	# Calculate base direction to enemy
	var target_pos := closest_enemy.global_position + Vector3(0, 1.0, 0)
	var spawn_pos := global_position + Vector3(0, 1.5, 0)
	var base_dir := (target_pos - spawn_pos).normalized()

	# Multi-shot
	var projectile_count := int(stats.slime_count)
	var spread_angle := 0.1  # Radians between shots

	for i in range(projectile_count):
		var shoot_dir := base_dir
		# Apply spread for multiple projectiles
		if projectile_count > 1:
			var offset := (float(i) - float(projectile_count - 1) / 2.0) * spread_angle
			# Rotate direction around Y axis
			var rot := Basis(Vector3.UP, offset)
			shoot_dir = rot * base_dir

		# Get projectile from pool
		var slime: SlimeProjectile = _projectile_pool.get_object() as SlimeProjectile
		if not slime:
			slime = SlimeProjectile.new()
			get_tree().current_scene.add_child(slime)

		# Set pool reference and owner
		slime._pool = _projectile_pool
		slime.player_owner = self

		# Build stats dictionary for reset
		var player_stats := {
			slime_damage = stats.slime_damage,
			slime_speed = stats.slime_speed,
			slime_size = stats.slime_size,
			slime_pierce = stats.slime_pierce,
			explosion_radius = stats.explosion_radius,
			chain_count = stats.chain_count,
			homing = stats.homing,
			poison_duration = stats.poison_duration,
			crit_chance = stats.crit_chance,
			crit_damage = stats.crit_damage,
			crit_heal = stats.crit_heal
		}

		# Reset state and set position
		slime.reset(shoot_dir, player_stats)
		slime.global_position = spawn_pos + shoot_dir * 0.5

	return true

# ============ ABILITY FUNCTIONS ============

func _update_ability_cooldowns(delta: float) -> void:
	# Tongue Lash
	if tongue_lash_timer > 0:
		tongue_lash_timer = maxf(0, tongue_lash_timer - delta)
		var max_cd := _apply_cooldown_reduction(TONGUE_LASH_BASE_COOLDOWN)
		tongue_lash_cooldown_changed.emit(tongue_lash_timer, max_cd)

	# Tadpole Swarm
	if tadpole_swarm_timer > 0:
		tadpole_swarm_timer = maxf(0, tadpole_swarm_timer - delta)
		var max_cd := _apply_cooldown_reduction(TADPOLE_SWARM_BASE_COOLDOWN)
		tadpole_swarm_cooldown_changed.emit(tadpole_swarm_timer, max_cd)

	# Croak Blast
	if croak_blast_timer > 0:
		croak_blast_timer = maxf(0, croak_blast_timer - delta)
		var max_cd := _apply_cooldown_reduction(CROAK_BLAST_BASE_COOLDOWN)
		croak_blast_cooldown_changed.emit(croak_blast_timer, max_cd)

	# Fly Cloud
	if fly_cloud_timer > 0:
		fly_cloud_timer = maxf(0, fly_cloud_timer - delta)
		var max_cd := _apply_cooldown_reduction(FLY_CLOUD_BASE_COOLDOWN)
		fly_cloud_cooldown_changed.emit(fly_cloud_timer, max_cd)

	# Frog Nuke
	if frog_nuke_timer > 0:
		frog_nuke_timer = maxf(0, frog_nuke_timer - delta)
		var max_cd := _apply_cooldown_reduction(FROG_NUKE_COOLDOWN)
		# Emit signal for UI (reusing ultimate cooldown for now)
		ultimate_cooldown_changed.emit(frog_nuke_timer, max_cd)

func _use_tongue_lash() -> void:
	if stats.unlock_tongue_lash == 0:
		return  # Not unlocked yet

	# Get forward direction from camera
	var forward_dir := Vector3.FORWARD
	if camera_pivot:
		var cam_basis := camera_pivot.global_transform.basis
		forward_dir = -cam_basis.z
		forward_dir.y = 0
		forward_dir = forward_dir.normalized()

	var lash := TongueLashClass.create(self, forward_dir)
	# Apply damage multiplier (base 35 + bonus)
	lash.damage *= (1.0 + stats.tongue_lash_damage)
	get_tree().current_scene.add_child(lash)

	var cooldown := _apply_cooldown_reduction(TONGUE_LASH_BASE_COOLDOWN)
	tongue_lash_timer = cooldown
	tongue_lash_cooldown_changed.emit(tongue_lash_timer, cooldown)

func _use_tadpole_swarm() -> void:
	if stats.unlock_tadpole_swarm == 0:
		return  # Not unlocked yet

	var base_count := 5
	var num_tadpoles := base_count + int(stats.tadpole_count)
	if _amphibian_rage and _amphibian_rage.is_active():
		num_tadpoles += 3  # More tadpoles during rage

	var spawn_angle := 0.0
	var angle_step := TAU / float(num_tadpoles)

	for i in range(num_tadpoles):
		var offset := Vector3(cos(spawn_angle) * 2.0, 0, sin(spawn_angle) * 2.0)
		var tadpole := TadpoleClass.create(global_position + offset)
		get_tree().current_scene.add_child(tadpole)
		spawn_angle += angle_step

	var cooldown := _apply_cooldown_reduction(TADPOLE_SWARM_BASE_COOLDOWN)
	tadpole_swarm_timer = cooldown
	tadpole_swarm_cooldown_changed.emit(tadpole_swarm_timer, cooldown)

func _use_croak_blast() -> void:
	if stats.unlock_croak_blast == 0:
		return  # Not unlocked yet

	var blast := CroakBlastClass.create(self)
	# Apply damage multiplier
	blast.damage *= (1.0 + stats.croak_blast_damage)
	get_tree().current_scene.add_child(blast)

	var cooldown := _apply_cooldown_reduction(CROAK_BLAST_BASE_COOLDOWN)
	if _amphibian_rage and _amphibian_rage.is_active():
		cooldown *= AmphibianRageClass.AOE_COOLDOWN_REDUCTION

	croak_blast_timer = cooldown
	croak_blast_cooldown_changed.emit(croak_blast_timer, cooldown)

func _use_fly_cloud() -> void:
	if stats.unlock_fly_cloud == 0:
		return  # Not unlocked yet

	# Remove existing cloud if any
	if _fly_cloud_active and is_instance_valid(_fly_cloud_active):
		_fly_cloud_active.queue_free()

	_fly_cloud_active = FlyCloudClass.create(self)
	# Apply damage multiplier
	_fly_cloud_active.damage *= (1.0 + stats.fly_cloud_damage)
	get_tree().current_scene.add_child(_fly_cloud_active)

	var cooldown := _apply_cooldown_reduction(FLY_CLOUD_BASE_COOLDOWN)
	fly_cloud_timer = cooldown
	fly_cloud_cooldown_changed.emit(fly_cloud_timer, cooldown)

func _use_amphibian_rage() -> void:
	if stats.unlock_amphibian_rage == 0:
		return  # Not unlocked yet
	# Create rage instance if it doesn't exist
	if not _amphibian_rage or not is_instance_valid(_amphibian_rage):
		_amphibian_rage = AmphibianRageClass.create(self)
		# Apply rage duration bonus
		if stats.rage_duration > 0:
			_amphibian_rage.duration += stats.rage_duration
		get_tree().current_scene.add_child(_amphibian_rage)
		_amphibian_rage.rage_started.connect(_on_rage_started)
		_amphibian_rage.rage_ended.connect(_on_rage_ended)
		_amphibian_rage.cooldown_changed.connect(_on_rage_cooldown_changed)

	if _amphibian_rage.activate():
		ultimate_activated.emit()

func _on_rage_started() -> void:
	rage_active_changed.emit(true)

func _on_rage_ended() -> void:
	rage_active_changed.emit(false)

func _on_rage_cooldown_changed(remaining: float, max_cooldown: float) -> void:
	ultimate_cooldown_changed.emit(remaining, max_cooldown)

func _use_frog_nuke() -> void:
	# Set cooldown
	frog_nuke_timer = _apply_cooldown_reduction(FROG_NUKE_COOLDOWN)

	# Cast the nuke
	FrogNuke.cast(self)

	# Visual feedback
	_show_notification("🐸 FROG NUKE! 🐸", Color(0.3, 1.0, 0.3))
	_create_powerup_effect(Color(0.3, 1.0, 0.3))

func get_tongue_lash_cooldown_percent() -> float:
	if tongue_lash_timer <= 0:
		return 1.0
	var max_cd := _apply_cooldown_reduction(TONGUE_LASH_BASE_COOLDOWN)
	return 1.0 - (tongue_lash_timer / max_cd)

func get_tadpole_swarm_cooldown_percent() -> float:
	if tadpole_swarm_timer <= 0:
		return 1.0
	var max_cd := _apply_cooldown_reduction(TADPOLE_SWARM_BASE_COOLDOWN)
	return 1.0 - (tadpole_swarm_timer / max_cd)

func get_croak_blast_cooldown_percent() -> float:
	if croak_blast_timer <= 0:
		return 1.0
	var max_cd := _apply_cooldown_reduction(CROAK_BLAST_BASE_COOLDOWN)
	return 1.0 - (croak_blast_timer / max_cd)

func get_fly_cloud_cooldown_percent() -> float:
	if fly_cloud_timer <= 0:
		return 1.0
	var max_cd := _apply_cooldown_reduction(FLY_CLOUD_BASE_COOLDOWN)
	return 1.0 - (fly_cloud_timer / max_cd)

func get_ultimate_cooldown_percent() -> float:
	if _amphibian_rage:
		return _amphibian_rage.get_cooldown_percent()
	return 1.0

# ============ ORBITALS ============

func _update_orbitals() -> void:
	var target_count := int(stats.orbitals)

	# Remove excess orbitals
	while _orbitals.size() > target_count:
		var orbital: Node3D = _orbitals.pop_back()
		if is_instance_valid(orbital):
			orbital.queue_free()

	# Add new orbitals
	while _orbitals.size() < target_count:
		var orbital: Node3D = _create_orbital(_orbitals.size())
		_orbitals.append(orbital)

func _create_orbital(index: int) -> Node3D:
	var orbital := Node3D.new()

	# Orbital mesh (slime ball)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 1.0, 0.4, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 0.3)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	orbital.add_child(mesh)

	# Collision for damage
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 8  # Enemy layer
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	area.add_child(collision)
	orbital.add_child(area)

	# Store orbital data
	orbital.set_meta("index", index)
	orbital.set_meta("angle", (float(index) / float(max(1, stats.orbitals))) * TAU)
	orbital.set_meta("distance", 2.5)
	orbital.set_meta("speed", 2.0)
	orbital.set_meta("damage_timer", 0.0)

	# Connect using a lambda to capture the orbital reference
	area.body_entered.connect(func(body: Node3D): _on_orbital_hit(orbital, body))

	add_child(orbital)
	return orbital

func _on_orbital_hit(orbital: Node3D, body: Node3D) -> void:
	if body.is_in_group("enemies"):
		var damage_timer: float = orbital.get_meta("damage_timer")
		if damage_timer <= 0.0:
			var damage: float = 10.0 * stats.slime_damage
			if body.has_method("take_damage"):
				body.take_damage(damage, false, "normal")
			orbital.set_meta("damage_timer", 0.5)  # Damage cooldown

func _update_orbitals_process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	for orbital in _orbitals:
		if not is_instance_valid(orbital):
			continue

		# Update damage timer
		var damage_timer: float = orbital.get_meta("damage_timer")
		if damage_timer > 0:
			orbital.set_meta("damage_timer", damage_timer - delta)

		# Orbital motion
		var angle: float = orbital.get_meta("angle")
		var distance: float = orbital.get_meta("distance")
		var speed: float = orbital.get_meta("speed")

		angle += speed * delta
		orbital.set_meta("angle", angle)

		var x: float = cos(angle) * distance
		var z: float = sin(angle) * distance
		orbital.position = Vector3(x, 1.0, z)

# ============ AURA DAMAGE ============

func _update_aura_damage(delta: float) -> void:
	if stats.aura_damage <= 0.0:
		return

	_aura_damage_timer += delta
	if _aura_damage_timer >= 1.0:  # Deal damage every second
		_aura_damage_timer = 0.0
		_deal_aura_damage()

func _deal_aura_damage() -> void:
	# Use EntityRegistry for spatial query instead of O(n) group iteration
	if not EntityRegistry or EntityRegistry.is_empty():
		return

	var nearby_enemies := EntityRegistry.get_enemies_in_range(global_position, 3.0)
	for enemy in nearby_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(stats.aura_damage, false, "normal")

# ============ END ABILITY FUNCTIONS ============

func _physics_process(delta: float) -> void:
	# Update ability cooldowns
	_update_ability_cooldowns(delta)

	# Update powerup timers
	_update_powerups(delta)

	# Update health regen
	if stats.health_regen > 0.0 and health < get_max_health():
		_regen_timer += delta
		if _regen_timer >= 1.0:
			_regen_timer = 0.0
			heal(stats.health_regen)

	# Calculate rage multipliers
	var rage_active := _amphibian_rage and _amphibian_rage.is_active()
	var fire_rate_mult := AmphibianRageClass.RANGED_COOLDOWN_REDUCTION if rage_active else 1.0

	# Auto-shoot cooldown - only reset timer if we actually shot
	if shoot_cooldown_timer > 0.0:
		shoot_cooldown_timer -= delta
	else:
		if _shoot_slime():
			var fire_rate: float = stats.fire_rate * fire_rate_mult
			shoot_cooldown_timer = BASE_SHOOT_COOLDOWN / fire_rate

	# Update orbitals
	_update_orbitals_process(delta)

	# Update camera shake
	_update_camera_shake(delta)

	# Update aura damage
	_update_aura_damage(delta)

	# Handle dash
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			velocity = velocity * 0.3  # Slow down after dash
	else:
		# Dash cooldown
		if dash_cooldown_timer > 0:
			dash_cooldown_timer -= delta

	# === SIMPLE JUMP MECHANICS ===
	
	# Use built-in floor detection
	var on_floor := is_on_floor()
	var jumped_this_frame := false
	
	# Reset jumps when on floor
	if on_floor and velocity.y <= 0:
		jumps_remaining = 1 + int(stats.extra_jumps)
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept"):
		if on_floor:
			# Ground jump
			jumps_remaining = int(stats.extra_jumps)
			velocity.y = BASE_JUMP_VELOCITY * stats.jump_power
			jumped_this_frame = true
		elif jumps_remaining > 0:
			# Air jump (double jump)
			jumps_remaining -= 1
			velocity.y = BASE_JUMP_VELOCITY * stats.jump_power
			jumped_this_frame = true
			_spawn_jump_effect()
	
	# Apply gravity
	if not jumped_this_frame:
		if velocity.y > 0 or not on_floor:
			velocity.y -= GRAVITY * delta

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Early exit if no camera - use default directions
	var forward: Vector3
	var right: Vector3

	if camera_pivot:
		var cam_basis := camera_pivot.global_transform.basis
		forward = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		right = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	else:
		forward = Vector3.FORWARD
		right = Vector3.RIGHT

	var direction := (forward * -input_dir.y + right * input_dir.x)

	# Calculate current speed
	var current_speed: float = BASE_SPEED * stats.move_speed
	if is_dashing:
		current_speed = DASH_SPEED

	if direction.length_squared() > 0.001:  # Use length_squared, avoid sqrt
		is_moving = true
		direction = direction.normalized()

		# Apply air control modifier
		var accel := ACCELERATION
		if not is_on_floor():
			accel = ACCELERATION * stats.air_control

		velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta)

		# Smooth rotation with lerp_angle
		if model:
			var target_rot := atan2(direction.x, direction.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_rot, ROTATION_SPEED * delta)
	else:
		is_moving = false
		var friction := FRICTION
		if not is_on_floor():
			friction = FRICTION * stats.air_control
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# Set floor max angle for slope handling
	floor_max_angle = FLOOR_MAX_ANGLE

	# Move and apply physics
	move_and_slide()

	# Update animation state
	_update_animation_state()

func _spawn_jump_effect() -> void:
	var particles := GPUParticles3D.new()
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

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _setup_animations() -> void:
	if not model:
		push_error("Player: Model bulunamadı!")
		return

	# Skeleton'ı bul
	skeleton = _find_skeleton(model)

	if not skeleton:
		push_error("Player: Skeleton bulunamadı!")
		return

	# Debug: Skeleton bone'larını yazdır
	AnimationSetupClass.print_skeleton_bones(skeleton)

	# Mixamo animasyonlarını yükle ve işle
	if animation_player:
		var lib := AnimationSetupClass.setup_player_animations(animation_player, skeleton)
		
		if lib and lib.get_animation_list().size() > 0:
			# İlk animasyonu başlat
			_play_animation("player/idle", true)
			print("Player: Animasyonlar hazır!")
		else:
			push_error("Player: Animasyonlar yüklenemedi!")
	else:
		push_error("Player: AnimationPlayer bulunamadı!")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null

func _update_animation_state() -> void:
	if not animation_player:
		return

	# Yeni animasyon adları (player library'den)
	var idle_anim := "player/idle"
	var walk_anim := "player/walk"
	var stop_anim := "player/stop"

	# Transition: hareket başladı
	if is_moving and not _was_moving:
		_play_animation(walk_anim, true)
	# Transition: hareket durdu
	elif not is_moving and _was_moving:
		# Durma animasyonunu oynat, sonra idle'a geç
		_play_animation(stop_anim, false)
		if not animation_player.animation_finished.is_connected(_on_stopping_finished):
			animation_player.animation_finished.connect(_on_stopping_finished, CONNECT_ONE_SHOT)

	_was_moving = is_moving

# Animasyon oynatma helper'ı
func _play_animation(anim_name: String, _loop: bool = false) -> void:
	if not animation_player:
		return

	if _current_anim == anim_name:
		return  # Zaten bu animasyon oynatılıyor

	_current_anim = anim_name

	# Animasyon var mı kontrol et ve oynat
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		push_warning("Animasyon bulunamadı: ", anim_name)

# Durma animasyonu bittiğinde idle'a geç
func _on_stopping_finished(_anim_name: String) -> void:
	if not is_moving:
		_play_animation("player/idle", true)

# ============ PICKUP POWER-UPS ============

var speed_boost_timer := 0.0
var damage_boost_timer := 0.0
var rapid_fire_timer := 0.0

func apply_speed_boost(duration: float) -> void:
	speed_boost_timer = duration
	stats.move_speed += 0.5  # +50% speed
	# Create effect
	_create_powerup_effect(Color(1.0, 1.0, 0.0))

func apply_damage_boost(duration: float) -> void:
	damage_boost_timer = duration
	stats.slime_damage += 0.5  # +50% damage
	# Create effect
	_create_powerup_effect(Color(1.0, 0.5, 0.0))

func apply_rapid_fire(duration: float) -> void:
	rapid_fire_timer = duration
	stats.fire_rate += 1.0  # Double fire rate
	# Create effect
	_create_powerup_effect(Color(0.8, 0.0, 1.0))

func _update_powerups(delta: float) -> void:
	# Speed boost
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0:
			stats.move_speed -= 0.5

	# Damage boost
	if damage_boost_timer > 0:
		damage_boost_timer -= delta
		if damage_boost_timer <= 0:
			stats.slime_damage -= 0.5

	# Rapid fire
	if rapid_fire_timer > 0:
		rapid_fire_timer -= delta
		if rapid_fire_timer <= 0:
			stats.fire_rate -= 1.0

func _create_powerup_effect(color: Color) -> void:
	var particles := GPUParticles3D.new()
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
	mat.color = color
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1.0, 0)

	# Auto-delete using scene tree timer
	var cleanup_timer := get_tree().create_timer(0.7)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

## Apply camera shake effect
## intensity: Shake magnitude (0.1 - 1.0)
## duration: How long the shake lasts in seconds
func _apply_camera_shake(intensity: float, duration: float) -> void:
	camera_shake_intensity = intensity
	camera_shake_duration = duration
	camera_shake_timer = duration

func _update_camera_shake(delta: float) -> void:
	if camera_shake_timer > 0:
		camera_shake_timer -= delta

		# Store original offset on first frame
		if camera_shake_timer >= camera_shake_duration - delta:
			if camera_pivot:
				_original_camera_offset = camera_pivot.position

		# Calculate shake offset
		var shake_amount := camera_shake_intensity * (camera_shake_timer / camera_shake_duration)
		var shake_offset := Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

		# Apply shake to camera pivot
		if camera_pivot:
			camera_pivot.position = _original_camera_offset + shake_offset

		# Reset when done
		if camera_shake_timer <= 0:
			if camera_pivot:
				camera_pivot.position = _original_camera_offset

## Show notification via HUD
func _show_notification(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
