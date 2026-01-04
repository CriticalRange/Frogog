# Tadpole Swarm - Summons tadpoles that seek and attack enemies
extends Node
class_name TadpoleSwarmWeapon

var player: Node3D = null

const BASE_TADPOLE_COUNT := 5  # Matches player's base count
const BASE_DAMAGE := 8.0
const BASE_COOLDOWN := 10.0
const TADPOLE_SPEED := 8.0
const TADPOLE_LIFETIME := 12.0  # Matches actual Tadpole class lifetime

var _cooldown_timer := 0.0

func _physics_process(delta: float) -> void:
	if not player:
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_spawn_swarm()
		_cooldown_timer = BASE_COOLDOWN

func _spawn_swarm() -> void:
	# Get total count (base + bonus from stats)
	var count := BASE_TADPOLE_COUNT
	if player.stats.has("tadpole_count"):
		count += int(player.stats.tadpole_count)

	# Apply cooldown reduction if available
	var cooldown := BASE_COOLDOWN
	if player.stats.has("cooldown_reduction"):
		cooldown = BASE_COOLDOWN * (1.0 - min(player.stats.cooldown_reduction, 0.7))
	_cooldown_timer = cooldown

	for i in range(count):
		var angle := (TAU / count) * i
		var offset := Vector3(cos(angle), 0.5, sin(angle)) * 1.0
		_spawn_tadpole(player.global_position + offset)

func _spawn_tadpole(spawn_pos: Vector3) -> void:
	var tadpole := Area3D.new()
	tadpole.collision_layer = 4
	tadpole.collision_mask = 8

	# Mesh
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 0.2)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	tadpole.add_child(mesh)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	tadpole.add_child(col)

	# Add script behavior - using EntityRegistry for optimized lookups
	var script := GDScript.new()
	script.source_code = """
extends Area3D

var target: Node3D = null
var speed := %f
var damage := %f
var lifetime := %f
var _timer := 0.0
var attack_cooldown := 0.8
var attack_timer := 0.0

func _ready():
	body_entered.connect(_on_hit)

func _physics_process(delta):
	_timer += delta
	attack_timer -= delta

	if _timer >= lifetime:
		queue_free()
		return

	# Find target using EntityRegistry for fast lookup
	if not target or not is_instance_valid(target):
		if EntityRegistry and not EntityRegistry.is_empty():
			target = EntityRegistry.get_nearest_enemy(global_position, [], INF)

	# Move towards target
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > 1.5:
			var dir = (target.global_position - global_position).normalized()
			global_position += dir * speed * delta
		elif attack_timer <= 0.0:
			# Attack!
			if target.has_method("take_damage"):
				target.take_damage(damage)
			attack_timer = attack_cooldown

func _on_hit(body):
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
""" % [TADPOLE_SPEED, BASE_DAMAGE, TADPOLE_LIFETIME]
	script.reload()
	tadpole.set_script(script)

	player.get_tree().current_scene.add_child(tadpole)
	tadpole.global_position = spawn_pos
