# Amphibian Rage - Ultimate ability that buffs all weapons temporarily
# Note: This is the auto-fire version that provides passive buffs when rage is active
# The actual activation is handled by the player manually
extends Node
class_name AmphibianRageWeapon

var player: Node3D = null

const BASE_DURATION := 5.0

# Only track rage state, don't auto-activate
var _rage_active := false
var _rage_duration_remaining := 0.0
var _rage_visual: GPUParticles3D = null

signal rage_started()
signal rage_ended()

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Check if player has active rage from manual activation
	var player_rage_active := false
	if player.has_method("get"):
		if player._amphibian_rage and is_instance_valid(player._amphibian_rage):
			player_rage_active = player._amphibian_rage.is_active()

	# Sync our state with player's rage state
	if player_rage_active and not _rage_active:
		_start_rage_visuals()
	elif not player_rage_active and _rage_active:
		_end_rage_visuals()

	# Update visual effects
	if _rage_active:
		_update_rage_visuals(delta)

func _start_rage_visuals() -> void:
	_rage_active = true

	# Get duration bonus from player stats
	var duration := BASE_DURATION
	if player.stats.has("rage_duration"):
		duration += player.stats.rage_duration
	_rage_duration_remaining = duration

	# Create visual effect
	_create_rage_visual()

	print("🔥 AMPHIBIAN RAGE VISUALS ACTIVE! 🔥")
	rage_started.emit()

func _end_rage_visuals() -> void:
	_rage_active = false

	# Remove visual
	if _rage_visual:
		_rage_visual.queue_free()
		_rage_visual = null

	print("Rage visuals ended...")
	rage_ended.emit()

func _create_rage_visual() -> void:
	if _rage_visual and is_instance_valid(_rage_visual):
		return

	_rage_visual = GPUParticles3D.new()
	_rage_visual.amount = 30
	_rage_visual.lifetime = 0.6
	_rage_visual.explosiveness = 0.0
	_rage_visual.process_mode = Node.PROCESS_MODE_INHERIT

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.8
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(1.0, 0.5, 0.1, 0.7)
	_rage_visual.process_material = mat

	# Fire particle mesh
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.12
	fire_mesh.height = 0.24
	_rage_visual.draw_pass_1 = fire_mesh

	player.add_child(_rage_visual)
	_rage_visual.position = Vector3(0, 0.5, 0)

func _update_rage_visuals(_delta: float) -> void:
	if _rage_visual and is_instance_valid(_rage_visual):
		# Pulse the emission
		_rage_visual.amount = 25 + int(sin(Time.get_ticks_msec() / 100.0) * 10)

func is_raging() -> bool:
	return _rage_active
