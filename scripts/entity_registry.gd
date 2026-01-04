extends Node

# EntityRegistry Singleton
# Singleton for efficient entity management
# Eliminates O(n) tree searches and provides fast nearest-neighbor queries

# Cached references
var player: Node = null
var enemies: Array[Node] = []  # Flat array for fast iteration
var _enemy_count: int = 0

# Spatial partitioning grid for faster nearest-neighbor queries
# Grid cell size should be larger than typical engagement range
const GRID_SIZE: float = 20.0  # 20 units per grid cell
var _spatial_grid: Dictionary = {}  # Vector2i -> Array[Node]

# Performance tracking
var _last_query_count: int = 0
var _cache_hit_count: int = 0

# Signals
signal enemy_registered(enemy: Node)
signal enemy_unregistered(enemy: Node)
signal player_registered(player: Node)

func _ready() -> void:
	# Register as singleton
	pass

# ============ PLAYER REGISTRATION ============

func register_player(p: Node) -> void:
	if not player:
		player = p
		player_registered.emit(p)
		print("EntityRegistry: Player registered")

func unregister_player(_p: Node) -> void:
	player = null

func get_player() -> Node:
	return player

# ============ ENEMY REGISTRATION ============

func register_enemy(enemy: Node) -> void:
	if enemy in enemies:
		return

	enemies.append(enemy)
	_enemy_count += 1

	# Add to spatial grid
	var grid_pos = _world_to_grid(enemy.global_position)
	if not _spatial_grid.has(grid_pos):
		_spatial_grid[grid_pos] = []
	_spatial_grid[grid_pos].append(enemy)

	enemy_registered.emit(enemy)

func unregister_enemy(enemy: Node) -> void:
	var idx := enemies.find(enemy)
	if idx == -1:
		return

	enemies.remove_at(idx)
	_enemy_count -= 1

	# Remove from spatial grid - clean up all cells since enemy might have moved
	# This is safer than trying to access global_position on a freed object
	for grid_pos in _spatial_grid.keys():
		var cell_enemies = _spatial_grid[grid_pos]
		if enemy in cell_enemies:
			cell_enemies.erase(enemy)
			if cell_enemies.is_empty():
				_spatial_grid.erase(grid_pos)
			break  # Found and removed, no need to check other cells

	enemy_unregistered.emit(enemy)

# ============ QUERIES ============

func get_enemy_count() -> int:
	return _enemy_count

func get_all_enemies() -> Array[Node]:
	_cache_hit_count += 1
	return enemies

func is_empty() -> bool:
	return _enemy_count == 0

# Helper to check if an enemy reference is still valid
func _is_valid_enemy(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion()

# Find nearest enemy to a position - O(1) for nearby, O(n) worst case
# Uses spatial grid to avoid checking all enemies
func get_nearest_enemy(to_position: Vector3, exclude: Array[Node] = [], max_range: float = INF) -> Node:
	if _enemy_count == 0:
		return null

	var closest: Node = null
	var closest_dist_sq := max_range if max_range != INF else INF

	# Check nearby grid cells first (3x3 grid around position)
	var center_grid = _world_to_grid(to_position)
	var checked_enemies: Dictionary = {}  # Avoid checking same enemy twice
	var stale_indices: Array[Vector2i] = []  # Track cells with stale enemies

	# Search nearby cells in spiral order
	for radius in range(0, 4):  # Check up to 4 cells out
		var found_in_radius := false

		for x_offset in range(-radius, radius + 1):
			for z_offset in range(-radius, radius + 1):
				# Only check perimeter cells for radius > 0
				if radius > 0 and abs(x_offset) != radius and abs(z_offset) != radius:
					continue

				var grid_pos = Vector2i(center_grid.x + x_offset, center_grid.y + z_offset)

				if not _spatial_grid.has(grid_pos):
					continue

				var cell_enemies = _spatial_grid[grid_pos]
				var has_stale := false

				for enemy in cell_enemies:
					# Skip invalid/freed enemies
					if not _is_valid_enemy(enemy):
						has_stale = true
						continue

					if enemy in exclude:
						continue
					if checked_enemies.has(enemy):
						continue
					checked_enemies[enemy] = true

					var dist_sq := to_position.distance_squared_to(enemy.global_position)
					if dist_sq < closest_dist_sq:
						closest_dist_sq = dist_sq
						closest = enemy
						found_in_radius = true

				# Mark cell for cleanup if it has stale entries
				if has_stale:
					stale_indices.append(grid_pos)

		# If we found something and max_range is limited, we might be done
		if closest and max_range != INF:
			# For limited range, we can stop after checking nearby cells
			if radius >= ceil(max_range / GRID_SIZE):
				break

	# Cleanup stale references from grid cells we checked
	_cleanup_stale_cells(stale_indices)

	return closest

# Get all enemies within range of a position
func get_enemies_in_range(position: Vector3, range_radius: float) -> Array[Node]:
	var result: Array[Node] = []
	var range_sq := range_radius * range_radius

	var center_grid = _world_to_grid(position)
	var grid_radius: int = int(ceil(range_radius / GRID_SIZE)) + 1
	var stale_indices: Array[Vector2i] = []

	for x_offset in range(-grid_radius, grid_radius + 1):
		for z_offset in range(-grid_radius, grid_radius + 1):
			var grid_pos = Vector2i(center_grid.x + x_offset, center_grid.y + z_offset)

			if not _spatial_grid.has(grid_pos):
				continue

			var cell_enemies = _spatial_grid[grid_pos]
			var has_stale := false
			var valid_cell_enemies: Array[Node] = []

			for enemy in cell_enemies:
				# Skip invalid/freed enemies
				if not _is_valid_enemy(enemy):
					has_stale = true
					continue

				var dist_sq := position.distance_squared_to(enemy.global_position)
				if dist_sq <= range_sq:
					result.append(enemy)
				valid_cell_enemies.append(enemy)

			# Update cell with only valid enemies if we found stale ones
			if has_stale:
				_spatial_grid[grid_pos] = valid_cell_enemies
				if valid_cell_enemies.is_empty():
					stale_indices.append(grid_pos)

	# Remove empty cells
	for grid_pos in stale_indices:
		_spatial_grid.erase(grid_pos)

	return result

# Clean up stale references from specific grid cells
func _cleanup_stale_cells(cell_indices: Array[Vector2i]) -> void:
	for grid_pos in cell_indices:
		if not _spatial_grid.has(grid_pos):
			continue

		var cell_enemies = _spatial_grid[grid_pos]
		var valid_enemies: Array[Node] = []

		for enemy in cell_enemies:
			if _is_valid_enemy(enemy):
				valid_enemies.append(enemy)

		if valid_enemies.is_empty():
			_spatial_grid.erase(grid_pos)
		else:
			_spatial_grid[grid_pos] = valid_enemies

# ============ SPATIAL GRID HELPERS ============

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / GRID_SIZE)),
		int(floor(world_pos.z / GRID_SIZE))
	)

# Update enemy's grid position (call when enemy moves significantly)
func update_enemy_position(enemy: Node, old_pos: Vector3, new_pos: Vector3) -> void:
	var old_grid = _world_to_grid(old_pos)
	var new_grid = _world_to_grid(new_pos)

	if old_grid != new_grid:
		# Remove from old cell
		if _spatial_grid.has(old_grid):
			_spatial_grid[old_grid].erase(enemy)
			if _spatial_grid[old_grid].is_empty():
				_spatial_grid.erase(old_grid)

		# Add to new cell
		if not _spatial_grid.has(new_grid):
			_spatial_grid[new_grid] = []
		_spatial_grid[new_grid].append(enemy)

# ============ DEBUG ============

func get_stats() -> Dictionary:
	return {
		"enemy_count": _enemy_count,
		"grid_cells": _spatial_grid.size(),
		"cache_hits": _cache_hit_count
	}

func reset_stats() -> void:
	_cache_hit_count = 0
