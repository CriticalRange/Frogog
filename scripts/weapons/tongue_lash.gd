# Tongue Lash - Melee cone attack that damages all enemies in front
extends Node
class_name TongueLashWeapon

var player: Node3D = null

const BASE_DAMAGE := 30.0
const BASE_RANGE := 4.0
const BASE_ANGLE := 60.0  # Cone angle in degrees
const BASE_COOLDOWN := 1.5

var _cooldown_timer := 0.0

func _physics_process(delta: float) -> void:
	if not player:
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_attack()
		# Apply cooldown reduction
		var cooldown := BASE_COOLDOWN
		if player.stats.has("cooldown_reduction"):
			cooldown = BASE_COOLDOWN * (1.0 - min(player.stats.cooldown_reduction, 0.7))
		_cooldown_timer = cooldown

func _attack() -> void:
	if not EntityRegistry or EntityRegistry.is_empty():
		return

	var player_pos := player.global_position
	var player_forward := -player.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()

	var hit_count := 0
	var damage := BASE_DAMAGE

	# Get damage multiplier from player stats
	if player.stats.has("tongue_lash_damage"):
		damage *= (1.0 + player.stats.tongue_lash_damage)

	# Also apply slime_damage multiplier
	if player.stats.has("slime_damage"):
		damage *= player.stats.slime_damage

	# Use EntityRegistry for spatial query
	var enemies_in_range := EntityRegistry.get_enemies_in_range(player_pos, BASE_RANGE)

	for enemy in enemies_in_range:
		var to_enemy: Vector3 = enemy.global_position - player_pos
		to_enemy.y = 0
		var dist := to_enemy.length()

		if dist > BASE_RANGE:
			continue

		# Check if within cone angle
		var angle := rad_to_deg(player_forward.angle_to(to_enemy.normalized()))
		if angle <= BASE_ANGLE / 2.0:
			if enemy.has_method("take_damage"):
				# Check crit
				var final_damage := damage
				if player.stats.has("crit_chance") and player.stats.crit_chance > 0:
					if randf() < player.stats.crit_chance:
						final_damage *= player.stats.get("crit_damage", 1.5)
						# Crit heal
						if player.stats.has("crit_heal") and player.stats.crit_heal > 0:
							if player.has_method("heal"):
								player.heal(player.stats.crit_heal)

				enemy.take_damage(final_damage)

				# Lifesteal
				if player.stats.has("lifesteal") and player.stats.lifesteal > 0:
					var heal_amount: float = final_damage * player.stats.lifesteal
					if player.has_method("heal"):
						player.heal(heal_amount)

				hit_count += 1

	# Visual effect
	if hit_count > 0:
		_spawn_tongue_visual()

func _spawn_tongue_visual() -> void:
	# Create a quick tongue mesh that extends and retracts
	var tongue := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.1
	mesh.height = BASE_RANGE
	tongue.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.2, 0.3)
	mat.emission_energy_multiplier = 1.5
	tongue.material_override = mat

	player.get_tree().current_scene.add_child(tongue)

	# Position in front of player
	var forward := -player.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	tongue.global_position = player.global_position + Vector3(0, 1.0, 0) + forward * (BASE_RANGE / 2.0)
	tongue.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	tongue.rotate_object_local(Vector3.RIGHT, PI / 2)

	# Animate and delete
	var tween := tongue.create_tween()
	tween.tween_property(tongue, "scale", Vector3(1.5, 0.1, 1.5), 0.15)
	tween.tween_callback(tongue.queue_free)
