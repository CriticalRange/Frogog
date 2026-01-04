# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Godot 4.5 3D action-survival game** using GDScript. The player controls a character that auto-shoots projectiles at enemies while collecting XP orbs to level up. The game features an enemy spawner, health system, and HUD.

## Running the Project

- **Open Project:** Launch Godot 4.5 and open this project directory
- **Run Game:** Press F5 or click the Play button in the Godot editor
- **Run Specific Scene:** Open a scene and press F6 (Run Current Scene)

## Building/Exporting

Godot uses its built-in export system:
1. Go to **Project > Export** in the Godot editor
2. Add export presets for target platforms (Windows, macOS, Linux, Android, Web)
3. Click **Export** to build for the selected platform

## Code Architecture

### Scene Organization

The game is organized into five main scenes in `res://scenes/`:
- `main.tscn` - Root scene containing Player, EnemySpawner, and HUD
- `player.tscn` - Player character with 3D model, camera pivot, and hurtbox
- `enemy.tscn` - Enemy with 3D model and health bar
- `hud.tscn` - UI overlay for health/XP display
- `enemy_health_bar.tscn` - Floating health bar above enemies

### Entity Scripts (`res://scripts/`)

**Player (`player.gd`)** - `CharacterBody3D`
- WASD movement with camera-relative direction
- Mouse-look camera (capture with ESC to toggle)
- Auto-shoots slime projectiles at nearest enemy (3 times/sec)
- Jump with Spacebar
- Health system (max 100 HP) with damage/heal methods
- XP/leveling system with `add_xp()` method
- Emits signals: `health_changed`, `died`, `xp_changed`, `level_up`
- Uses AnimationTree state machine for idle/walk transitions

**Enemy (`enemy.gd`)** - `CharacterBody3D`
- Chases player when outside attack range (2 units)
- Stops and attacks when in range (15 damage, 1 sec cooldown)
- Drops XP orbs on death (1-3 orbs, 5-15 XP each)
- Health bar updates via `health_percent` setter
- Emits `died` signal before `queue_free()`

**SlimeProjectile (`slime_projectile.gd`)** - `Area3D`
- Created via static `create(direction)` factory method
- Travels at 25 units/sec with slight gravity arc
- Deals 20 damage on enemy collision
- Creates particle explosion on impact
- Self-deletes after 3 seconds

**XPOrb (`xp_orb.gd`)** - `Area3D`
- Created via static `create(value)` factory method
- Bobs and spins when idle
- Magnetically attracted to player within 5 units
- Collected when within 1 unit, calls `player.add_xp()`

**HUD (`hud.gd`)** - `Control`
- Displays health bar and HP label
- Creates XP bar, level label, and XP label dynamically
- Connects to player signals via `get_tree().get_first_node_in_group("player")`

**EnemySpawner (`enemy_spawner.gd`)** - `Node3D`
- Spawns enemies at random angles around player
- Configurable: interval, radius, min/max distance, max enemies
- Tracks enemy count via `died` signal connections

### Groups for Cross-Entity Communication

- `"player"` - Player character (singleton access pattern)
- `"enemies"` - All enemy instances for auto-targeting

### Key Patterns Used

- **Static factory methods** for projectiles and XP orbs (creates visuals programmatically)
- **Signal-based UI updates** - HUD subscribes to player signals
- **Group-based entity lookup** - `get_tree().get_first_node_in_group("player")`
- **@onready caching** - Scene node references cached in _ready()
- **Preloaded classes** - `preload()` used to avoid circular dependencies
- **Performance optimizations** - `length_squared()` instead of `length()`, pre-calculated radians

### Project Settings

- Input actions: `ui_accept` (jump), `ui_cancel` (mouse toggle), `ui_up/down/left/right` (movement)
- Main scene: `res://scenes/main.tscn`
- Rendering: Forward Plus
