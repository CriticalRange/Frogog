extends Node
class_name GameConfig

## Centralized game configuration for better maintainability.
## This file consolidates magic numbers and constants from across the codebase.

# ============================================================================
# PLAYER CONFIGURATION
# ============================================================================

const PLAYER := {
	# Movement
	base_speed = 10.0,
	acceleration = 20.0,
	friction = 20.0,
	rotation_speed = 15.0,
	mouse_sensitivity = 0.003,

	# Jump
	base_jump_velocity = 8.0,
	gravity = 15.0,
	floor_max_angle = deg_to_rad(45),

	# Camera (pre-calculated radians to avoid deg_to_rad every frame)
	camera_pitch_min = -1.2217,  # deg_to_rad(-70)
	camera_pitch_max = 1.2217,   # deg_to_rad(70)

	# Health
	base_max_health = 100.0,

	# Combat
	base_shoot_cooldown = 0.6,  # ~1.7 shots per second

	# Dash
	dash_speed = 20.0,
	dash_duration = 0.2,
	base_dash_cooldown = 1.5,
	projectile_pool_size = 50,
}

# Default player stats (used for initialization)
const PLAYER_DEFAULT_STATS := {
	# Weapon stats
	slime_damage = 1.0,
	slime_speed = 1.0,
	slime_size = 1.0,
	slime_pierce = 0,
	slime_count = 1,
	fire_rate = 1.0,
	explosion_radius = 0.0,
	chain_count = 0,
	homing = 0.0,
	poison_duration = 0.0,

	# Movement stats
	move_speed = 1.0,
	jump_power = 1.0,
	extra_jumps = 0,
	dash_cooldown = 1.0,
	air_control = 1.0,

	# Defense stats
	max_health = 0.0,
	health_regen = 0.0,
	damage_resist = 0.0,
	dodge_chance = 0.0,
	thorns = 0.0,
	lifesteal = 0.0,

	# Utility stats
	xp_multiplier = 1.0,
	pickup_range = 1.0,
	luck = 0.0,
	cooldown_reduction = 0.0,

	# Critical stats
	crit_chance = 0.05,  # Base 5%
	crit_damage = 1.5,   # Base 150%
	crit_heal = 0.0,

	# Special stats
	aura_damage = 0.0,
	orbitals = 0,

	# Ability unlocks (0 = locked, 1 = unlocked)
	unlock_tongue_lash = 0,
	unlock_tadpole_swarm = 0,
	unlock_croak_blast = 0,
	unlock_fly_cloud = 0,
	unlock_amphibian_rage = 0,

	# Ability stats
	tongue_lash_damage = 0.0,
	tadpole_count = 0,
	croak_blast_damage = 0.0,
	fly_cloud_damage = 0.0,
	rage_duration = 0.0,
}

# ============================================================================
# ENEMY CONFIGURATION
# ============================================================================

const ENEMY := {
	speed = 5.0,
	acceleration = 15.0,
	attack_range = 2.0,
	attack_range_squared = 4.0,  # 2.0 * 2.0 - avoid sqrt!
	damage = 12.0,
	attack_cooldown = 1.0,
	max_health = 35.0,

	# XP drops
	xp_drop_min = 1,
	xp_drop_max = 3,
	xp_value_min = 5,
	xp_value_max = 15,

	# Combat
	poison_interval = 0.5,
	knockback_duration = 0.2,
}

# ============================================================================
# PROJECTILE CONFIGURATION
# ============================================================================

const SLIME_PROJECTILE := {
	base_speed = 25.0,
	base_damage = 20.0,
	lifetime = 3.0,
	gravity = 5.0,
	target_update_interval = 0.15,  # Update homing target every 150ms

	# Visual
	base_radius = 0.2,
	base_height = 0.4,
	collision_radius = 0.25,

	# Chain lightning
	chain_damage_multiplier = 0.7,
	chain_max_distance = 10.0,

	# Explosion
	explosion_damage_multiplier = 0.5,
}

# ============================================================================
# XP ORB CONFIGURATION
# ============================================================================

const XP_ORB := {
	float_height = 0.5,
	base_magnet_range = 5.0,
	base_collect_range = 1.0,
	speed = 15.0,
	bob_speed = 3.0,
	bob_amount = 0.2,
	spin_speed = 4.0,

	# Visual
	mesh_radius = 0.15,
	mesh_height = 0.3,
	collision_radius = 0.2,
	light_energy = 0.5,
	light_range = 2.0,
}

# ============================================================================
# ABILITY COOLDOWNS (seconds)
# ============================================================================

const ABILITY_COOLDOWNS := {
	tongue_lash = 1.5,
	tadpole_swarm = 10.0,
	croak_blast = 5.0,
	fly_cloud = 12.0,
	frog_nuke = 180.0,  # 3 minutes
	amphibian_rage = 60.0,
}

# ============================================================================
# VISUAL EFFECT COLORS
# ============================================================================

const COLORS := {
	# Projectile colors
	slime_normal = Color(0.2, 1.0, 0.3, 0.9),
	slime_explosion = Color(1.0, 0.5, 0.2, 0.9),
	slime_poison = Color(0.5, 0.9, 0.2, 0.9),
	slime_chain = Color(0.5, 0.3, 1.0, 0.9),
	slime_homing = Color(0.2, 0.5, 1.0, 0.9),

	# XP colors
	xp_orb = Color(0.2, 0.9, 1.0, 0.9),
	xp_orb_emission = Color(0.1, 0.7, 0.9),

	# Effect colors
	poison = Color(0.3, 0.9, 0.2, 0.6),
	freeze = Color(0.6, 0.9, 1.0, 0.6),
	dodge = Color(1.0, 1.0, 0.5, 0.8),
	dash = Color(0.3, 0.8, 1.0, 0.6),

	# Enemy colors
	enemy_base = Color(0.6, 0.3, 0.2, 1.0),
	enemy_light = Color(0.8, 0.4, 0.3, 1.0),

	# UI colors
	xp_bar_normal = Color(0.2, 0.8, 1.0),
	xp_bar_flash = Color(1.0, 0.9, 0.2),
	level_text = Color(1.0, 0.9, 0.3),

	# Health bar colors
	health_high = Color(0.3, 1.0, 0.3),
	health_medium = Color(1.0, 0.8, 0.3),
	health_low = Color(1.0, 0.3, 0.3),
}

# ============================================================================
# COLLISION LAYERS
# ============================================================================

const COLLISION := {
	# Layer bit assignments
	player = 1,
	enemy = 2,
	projectile = 4,
	enemy_hurtbox = 8,
}

# ============================================================================
# SPAWNING CONFIGURATION
# ============================================================================

const SPAWNING := {
	default_spawn_interval = 2.0,
	default_spawn_radius = 30.0,
	default_min_distance = 15.0,
	default_max_distance = 25.0,
	default_max_enemies = 50,
	surge_multiplier = 5,
}

# ============================================================================
# LEVELING CONFIGURATION
# ============================================================================

const LEVELING := {
	base_xp_requirement = 100,
	xp_per_level = 50,  # XP required = base_xp_requirement + (level * xp_per_level)
}

# ============================================================================
# LIMITS AND CAPS
# ============================================================================

const LIMITS := {
	max_damage_resist = 0.8,  # Cap at 80% reduction
	max_cooldown_reduction = 0.7,  # Cap at 70% reduction
	max_cooldown = 180.0,  # 3 minutes for longest cooldowns
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Calculate XP required for a given level
static func calculate_xp_for_level(lvl: int) -> int:
	return LEVELING.base_xp_requirement + (lvl * LEVELING.xp_per_level)


## Get base color for projectile based on modifiers
static func get_projectile_color(has_explosion: bool, has_poison: bool,
								has_chain: bool, has_homing: bool) -> Color:
	if has_explosion:
		return COLORS.slime_explosion
	elif has_poison:
		return COLORS.slime_poison
	elif has_chain:
		return COLORS.slime_chain
	elif has_homing:
		return COLORS.slime_homing
	return COLORS.slime_normal


## Apply cooldown reduction to base value
static func apply_cooldown_reduction(base: float, reduction_percent: float) -> float:
	if reduction_percent > 0.0:
		return base * (1.0 - minf(reduction_percent, LIMITS.max_cooldown_reduction))
	return base


## Apply damage resistance to incoming damage
static func apply_damage_resist(damage: float, resist_percent: float) -> float:
	if resist_percent > 0.0:
		return damage * (1.0 - minf(resist_percent, LIMITS.max_damage_resist))
	return damage
