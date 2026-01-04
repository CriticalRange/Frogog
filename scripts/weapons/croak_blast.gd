# Croak Blast - AOE shockwave centered on the player
extends Node
class_name CroakBlastWeapon

var player: Node3D = null

const BASE_DAMAGE := 25.0
const BASE_RADIUS := 6.0
const BASE_COOLDOWN := 5.0
const KNOCKBACK_FORCE := 10.0

var _cooldown_timer := 0.0

func _physics_process(delta: float) -> void:
	if not player:
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		if EntityRegistry and not EntityRegistry.is_empty():
			_blast()
			# Apply cooldown reduction
			var cooldown := BASE_COOLDOWN
			if player.stats.has("cooldown_reduction"):
				cooldown = BASE_COOLDOWN * (1.0 - min(player.stats.cooldown_reduction, 0.7))
			_cooldown_timer = cooldown

func _blast() -> void:
	if not EntityRegistry or EntityRegistry.is_empty():
		return

	var player_pos := player.global_position
	var damage := BASE_DAMAGE

	# Get damage multiplier from player stats
	if player.stats.has("croak_blast_damage"):
		damage *= (1.0 + player.stats.croak_blast_damage)

	# Also apply slime_damage multiplier
	if player.stats.has("slime_damage"):
		damage *= player.stats.slime_damage

	# Check for Amphibian Rage buff
	var rage_bonus := 1.0
	if player._amphibian_rage and is_instance_valid(player._amphibian_rage):
		if player._amphibian_rage.is_active():
			rage_bonus = AmphibianRage.AOE_COOLDOWN_REDUCTION  # Reuse as damage multiplier too
	damage *= rage_bonus

	var hit_count := 0

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

			# Damage falls off with distance
			var falloff := 1.0 - (dist / BASE_RADIUS) * 0.5
			enemy.take_damage(final_damage * falloff)

			# Knockback
			if enemy.has_method("apply_knockback"):
				var direction: Vector3 = (enemy.global_position - player_pos).normalized()
				enemy.apply_knockback(direction * KNOCKBACK_FORCE)

			# Lifesteal
			if player.stats.has("lifesteal") and player.stats.lifesteal > 0:
				var heal_amount: float = final_damage * player.stats.lifesteal
				if player.has_method("heal"):
					player.heal(heal_amount)

			hit_count += 1

	# Always show visual
	_spawn_shockwave()

func _spawn_shockwave() -> void:
	# Expanding ring effect
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.5
	mesh.outer_radius = 1.0
	ring.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.9, 0.5, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat

	player.get_tree().current_scene.add_child(ring)
	ring.global_position = player.global_position + Vector3(0, 0.5, 0)
	ring.rotation.x = PI / 2  # Lay flat

	# Animate expansion
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(BASE_RADIUS, BASE_RADIUS, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
