extends Node3D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var base_spawn_interval: float = 2.5  # Slower early game (was 1.2)
@export var min_spawn_interval: float = 0.2
@export var spawn_radius: float = 30.0  # Smaller circle around player
@export var min_spawn_distance: float = 12.0  # Don't spawn too close
@export var max_enemies: int = 100
@export var batch_size: int = 3  # Start with more per batch

var player: CharacterBody3D = null
var _has_player: bool = false
var _enemy_count: int = 0
var _spawn_timer := 0.0
var _current_spawn_interval: float = 3.0
var _current_batch_size: int = 3

func _ready() -> void:
	# Find player
	await get_tree().process_frame
	_find_player()
	
	if _has_player:
		_current_spawn_interval = base_spawn_interval
		print("EnemySpawner: Started! Base spawn interval: ", base_spawn_interval, "s")
	else:
		push_warning("EnemySpawner: No player found, spawning disabled!")

func _find_player() -> void:
	var found := get_tree().get_first_node_in_group("player")
	if found is CharacterBody3D:
		player = found
		_has_player = true
		print("EnemySpawner: Found player!")

func _physics_process(delta: float) -> void:
	if not _has_player:
		return

	# Update spawn interval and batch size based on GameManager
	_update_spawn_interval()
	_update_batch_size()

	# Countdown and spawn
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_try_spawn_enemy()
		_spawn_timer = _current_spawn_interval

func _update_spawn_interval() -> void:
	# Get spawn rate multiplier from GameManager
	var spawn_mult := GameManager.get_spawn_rate_multiplier()

	# Higher multiplier = faster spawns (lower interval)
	# spawn_mult of 2.0 means half the time between spawns
	_current_spawn_interval = maxf(base_spawn_interval / spawn_mult, min_spawn_interval)

func _update_batch_size() -> void:
	# Get batch size multiplier from GameManager
	var batch_mult := GameManager.get_batch_size_multiplier()

	# Higher multiplier = more enemies per batch
	_current_batch_size = int(ceil(batch_size * batch_mult))

func _try_spawn_enemy() -> void:
	if not _has_player:
		return

	# Get terrain for spawning
	var terrain_node = get_tree().get_first_node_in_group("terrain")

	# Spawn a batch of enemies
	var enemies_to_spawn := mini(_current_batch_size, max_enemies - _enemy_count)
	for i in enemies_to_spawn:
		# Calculate spawn position for each enemy
		var angle := randf() * TAU
		var distance := randf_range(min_spawn_distance, spawn_radius)

		# Calculate spawn height based on position
		var enemy_height = player.global_position.y
		if terrain_node and terrain_node.has_method("get_height_at"):
			var ex = player.global_position.x + cos(angle) * distance
			var ez = player.global_position.z + sin(angle) * distance
			enemy_height = terrain_node.get_height_at(ex, ez)

		var spawn_pos := Vector3(
			player.global_position.x + cos(angle) * distance,
			enemy_height,
			player.global_position.z + sin(angle) * distance
		)

		# Instantiate and add to scene
		var enemy := enemy_scene.instantiate()
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = spawn_pos

		_enemy_count += 1

func _on_enemy_died(_enemy: Node) -> void:
	_enemy_count = maxi(_enemy_count - 1, 0)

# Debug: Get current spawn rate
func get_current_interval() -> float:
	return _current_spawn_interval
