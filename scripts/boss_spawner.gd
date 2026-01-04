extends Node3D
class_name BossSpawner

## Boss Spawner
##
## Spawns the Heron Boss based on various conditions:
## - Time elapsed
## - Player level reached
## - Manual trigger (for testing)

@export var boss_scene: PackedScene
@export var spawn_after_time: float = 180.0  # Spawn after 3 minutes
@export var spawn_distance: float = 25.0  # Distance from player to spawn
@export var spawn_height_offset: float = 0.0

var player: CharacterBody3D = null
var _has_player: bool = false
var _boss_active: bool = false
var _boss_instance: Node = null
var _boss_health_bar: Control = null
var _boss_spawned_this_game: bool = false

signal boss_spawned(boss: Node)
signal boss_defeated()

func _ready() -> void:
	add_to_group("boss_spawner")

	# Load boss scene if not set
	if not boss_scene:
		boss_scene = load("res://scenes/heron_boss.tscn")

	# Find player
	await get_tree().process_frame
	_find_player()

func _find_player() -> void:
	var found := get_tree().get_first_node_in_group("player")
	if found is CharacterBody3D:
		player = found
		_has_player = true

func _physics_process(delta: float) -> void:
	if not _has_player or _boss_spawned_this_game:
		return

	# Use GameManager's elapsed time for synchronization with debug skip
	var game_time := GameManager.get_elapsed_time()
	if game_time >= spawn_after_time:
		spawn_boss()

## Spawn the boss at a position relative to the player
func spawn_boss() -> void:
	if _boss_active or _boss_spawned_this_game:
		print("Boss already active or already spawned this game!")
		return

	if not boss_scene:
		push_error("BossSpawner: No boss scene assigned!")
		return

	if not _has_player:
		push_error("BossSpawner: No player found!")
		return

	_boss_spawned_this_game = true
	_boss_active = true

	# Calculate spawn position (in front of player)
	var spawn_pos := _calculate_spawn_position()

	# Instantiate boss
	_boss_instance = boss_scene.instantiate()
	get_tree().current_scene.add_child(_boss_instance)
	_boss_instance.global_position = spawn_pos

	# Connect to boss signals
	if _boss_instance.has_signal("died"):
		_boss_instance.died.connect(_on_boss_died)

	# Create and attach health bar UI
	_create_boss_health_bar()

	# Announce boss spawn
	print("BOSS SPAWNED: Giant Heron!")
	boss_spawned.emit(_boss_instance)

	# Camera shake effect
	if player.has_method("_apply_camera_shake"):
		player._apply_camera_shake(0.5, 1.0)

func _calculate_spawn_position() -> Vector3:
	# Get player's forward direction
	var forward := Vector3.FORWARD
	if player.has_node("CameraPivot"):
		var pivot := player.get_node("CameraPivot")
		forward = -pivot.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()

	# Spawn in front of player
	var spawn_pos := player.global_position + forward * spawn_distance

	# Get terrain height if available
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("get_height_at"):
		spawn_pos.y = terrain.get_height_at(spawn_pos.x, spawn_pos.z) + spawn_height_offset
	else:
		spawn_pos.y = player.global_position.y + spawn_height_offset

	return spawn_pos

func _create_boss_health_bar() -> void:
	if not _boss_instance:
		return

	# Create health bar
	_boss_health_bar = BossHealthBar.new()

	# Add to canvas layer for UI
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10  # Above other UI
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(_boss_health_bar)

	# Connect to boss
	_boss_health_bar.connect_to_boss(_boss_instance)

func _on_boss_died(_boss: Node) -> void:
	_boss_active = false
	_boss_instance = null

	print("BOSS DEFEATED: Giant Heron!")
	boss_defeated.emit()

	# Victory effects could go here
	if _has_player and player.has_method("_apply_camera_shake"):
		player._apply_camera_shake(0.3, 0.5)

## Manual spawn trigger (for testing or special events)
func force_spawn_boss() -> void:
	_boss_spawned_this_game = false  # Allow re-spawn
	spawn_boss()

## Check if boss is currently active
func is_boss_active() -> bool:
	return _boss_active

## Get the current boss instance
func get_boss() -> Node:
	return _boss_instance
