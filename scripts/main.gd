extends Node3D

@onready var player = $Player
@onready var game_manager = $GameManager
@onready var boss_spawner = $BossSpawner

func _ready() -> void:
	# Connect boss defeat to game victory
	if boss_spawner:
		boss_spawner.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	# Game won - boss defeated!
	if game_manager:
		game_manager.game_running = false
		game_manager.game_over.emit(true)
