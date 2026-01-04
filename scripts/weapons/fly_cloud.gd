# Fly Cloud - Damage aura that constantly hurts nearby enemies
extends Node
class_name FlyCloudWeapon

var player: Node3D = null

const BASE_DAMAGE := 5.0  # Per tick
const BASE_RADIUS := 3.5
const TICK_RATE := 0.5  # Damage every 0.5 seconds

var _tick_timer := 0.0
var _visual: GPUParticles3D = null

func _ready() -> void:
	# Create persistent particle effect
	await get_tree().process_frame
	_create_visual()

func _create_visual() -> void:
	if not player:
		return

	_visual = GPUParticles3D.new()
	_visual.amount = 30
	_visual.lifetime = 1.0
	_visual.explosiveness = 0.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = BASE_RADIUS * 0.8
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, 0, 0)
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	mat.color = Color(0.2, 0.2, 0.2, 0.8)
	_visual.process_material = mat

	# Fly mesh (tiny sphere)
	var fly_mesh := SphereMesh.new()
	fly_mesh.radius = 0.05
	fly_mesh.height = 0.1
	_visual.draw_pass_1 = fly_mesh

	player.add_child(_visual)
	_visual.position = Vector3(0, 1.0, 0)

func _physics_process(delta: float) -> void:
	if not player:
		return

	_tick_timer += delta
	if _tick_timer >= TICK_RATE:
		_tick_timer = 0.0
		_deal_damage()

func _deal_damage() -> void:
	if not EntityRegistry or EntityRegistry.is_empty():
		return

	var player_pos := player.global_position
	var damage := BASE_DAMAGE

	# Get damage multiplier from player stats
	if player.stats.has("fly_cloud_damage"):
		damage *= (1.0 + player.stats.fly_cloud_damage)

	# Also apply slime_damage multiplier
	if player.stats.has("slime_damage"):
		damage *= player.stats.slime_damage

	# Add aura damage if player has it
	if player.stats.has("aura_damage"):
		damage += player.stats.aura_damage * TICK_RATE

	# Use EntityRegistry for spatial query
	var enemies_in_range := EntityRegistry.get_enemies_in_range(player_pos, BASE_RADIUS)

	for enemy in enemies_in_range:
		var dist := player_pos.distance_to(enemy.global_position)
		if dist <= BASE_RADIUS:
			var final_damage := damage

			# Check crit
			if player.stats.has("crit_chance") and player.stats.crit_chance > 0:
				if randf() < player.stats.crit_chance:
					final_damage *= player.stats.get("crit_damage", 1.5)
					# Crit heal
					if player.stats.has("crit_heal") and player.stats.crit_heal > 0:
						if player.has_method("heal"):
							player.heal(player.stats.crit_heal)

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage)

			# Lifesteal
			if player.stats.has("lifesteal") and player.stats.lifesteal > 0:
				var heal_amount: float = final_damage * player.stats.lifesteal
				if player.has_method("heal"):
					player.heal(heal_amount)
