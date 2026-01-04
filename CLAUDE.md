# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Frogog** is a **Godot 4.5 3D action-survival game** using GDScript. The player controls a frog character that auto-shoots projectiles at enemies while collecting XP orbs to level up and unlock abilities. The game features a 12-minute timer leading to endless mode, wave-based difficulty scaling, boss encounters, and a comprehensive upgrade system.

---

## Running the Project

- **Open Project:** Launch Godot 4.5 and open this project directory
- **Run Game:** Press F5 or click the Play button in the Godot editor
- **Run Specific Scene:** Open a scene and press F6 (Run Current Scene)

---

## Building/Exporting

Godot uses its built-in export system:
1. Go to **Project > Export** in the Godot editor
2. Add export presets for target platforms (Windows, macOS, Linux, Android, Web)
3. Click **Export** to build for the selected platform

---

## Code Architecture

### Singletons (Autoload)

| Singleton | Purpose |
|-----------|---------|
| `EntityRegistry` | O(1) spatial queries via grid-based indexing |
| `GameManager` | Global game state, timer, waves, difficulty scaling |

### Scene Organization

| Scene | Description |
|-------|-------------|
| `main.tscn` | Root scene: Player, GameManager, EnemySpawner, BossSpawner, HUD |
| `player.tscn` | Player character with 3D model, camera pivot, AnimationTree |
| `enemy.tscn` | Enemy with AI, health system, XP drops |
| `heron_boss.tscn` | Boss encounter with multi-phase attacks |
| `hud.tscn` | UI: health/XP bars, timer, objectives, notifications |
| `upgrade_popup.tscn` | Level-up upgrade selection with tier system |

### Entity Scripts (`res://scripts/`)

#### Core Systems

**Player (`player.gd`)** - `CharacterBody3D`
- WASD movement with camera-relative direction
- Mouse-look camera (ESC to toggle capture)
- Auto-shoots at nearest enemy using EntityRegistry (O(1) query)
- Jump with Spacebar, dash with Shift
- Health system (max 100 HP base) with `take_damage()` / `heal()`
- XP/leveling system with `add_xp()` method
- 5 unlockable abilities (Tongue Lash, Tadpole Swarm, Croak Blast, Fly Cloud, Amphibian Rage)
- Dictionary-based stats system (see Stats System below)
- Signals: `health_changed`, `died`, `xp_changed`, `level_up`

**GameManager (`game_manager.gd`)** - Singleton
- 12-minute game timer → endless mode transition
- Wave-based difficulty scaling (increases spawn rate, enemy HP/damage)
- Surge events (5x enemy spawns for limited time)
- Boss spawning at timer end
- Signals: `time_updated`, `wave_changed`, `surge_started`, `surge_ended`, `endless_mode_started`, `game_over`

**EntityRegistry (`entity_registry.gd`)** - Singleton
- Grid-based spatial partitioning for O(1) nearest-enemy queries
- Methods: `get_nearest_enemy()`, `get_enemies_in_range()`, `register_enemy()`, `unregister_enemy()`

**Enemy (`enemy.gd`)** - `CharacterBody3D`
- Chases player when outside attack range (2 units)
- Stops and attacks when in range (15 damage base, 1 sec cooldown)
- Drops XP orbs on death (1-3 orbs, 5-15 XP each)
- Supports poison, stun, knockback effects
- Emits `died` signal before `queue_free()`

**EnemySpawner (`enemy_spawner.gd`)**
- Spawns enemies in circle around player (12-30 unit radius)
- Batch spawning (3 enemies base, scales with difficulty)
- Integrates with GameManager for difficulty scaling

**HeronBoss (`heron_boss.gd`)**
- Multi-phase boss encounter
- Emits `boss_defeated` signal for game victory

#### Combat & Projectiles

**SlimeProjectile (`slime_projectile.gd`)** - `Area3D`
- Created via static `create(direction, player_stats)` factory method
- Auto-targeting with homing (cached target for performance)
- Upgrade paths: pierce, explosion, chain lightning, poison
- Object pooling support via `reset()` method
- Travels at 25 units/sec with slight gravity arc
- Deals 20 base damage, self-cleanup after 3 seconds

**DamageNumber (`damage_number.gd`)** - `Label3D`
- Floating damage text with crit/headshot styling
- Factory: `spawn(damage, position, is_crit, damage_type)`

#### Weapons (Abilities)

| Script | Class | Type | Description |
|--------|-------|------|-------------|
| `weapons/tongue_lash.gd` | `TongueLashWeapon` | Melee cone | 60° cone, 4 range, 30 damage |
| `weapons/tadpole_swarm.gd` | `TadpoleSwarmWeapon` | Summon | Spawns AI tadpoles |
| `weapons/croak_blast.gd` | `CroakBlastWeapon` | AOE | 8-unit shockwave |
| `weapons/fly_cloud.gd` | `FlyCloudWeapon` | Passive aura | 3-unit damage aura |
| `weapons/amphibian_rage.gd` | `AmphibianRageWeapon` | Ultimate | Transformation mode |

#### UI & Progression

**HUD (`hud.gd`)** - `Control`
- Health/XP bars with animated transitions
- Timer with countdown (MM:SS format)
- Wave/surge notifications
- Objectives system (countdowns, progress bars)
- Notification system for rewards/events

**UpgradePopup (`upgrade_popup.gd`)** - `Control`
- 3 upgrade choices per level-up
- Tier system: Common (1x), Rare (1.5x), Epic (2.5x), Legendary (4x)
- Luck increases higher tier chances
- Keyboard navigation (arrow keys, Enter/Esc)

**AncientArmory (`ancient_armory.gd`)**
- Guaranteed Epic/Legendary upgrades
- Limited use interactable

#### Pickups & Objects

**XPOrb (`xp_orb.gd`)** - `Area3D`
- Factory: `create(value)`
- Magnetic attraction (5 units * pickup_range stat)
- Auto-collect at 1 unit * pickup_range

**Pickup (`pickup.gd`)** - `Area3D`
- Types: HEALTH_SMALL/LARGE, XP_SMALL/LARGE, SPEED_BOOST, DAMAGE_BOOST, RAPID_FIRE
- 15-second lifetime with fade-out
- Magnetic attraction to player

**Tadpole (`tadpole.gd`)**
- AI-summoned ally from Tadpole Swarm
- Auto-attacks nearby enemies

#### Interactables

| Script | Description |
|--------|-------------|
| `reward_statue.gd` | Grants rewards on interaction |
| `difficulty_tomb.gd` | Increases spawn rate + XP gain |
| `smuggler.gd` | Trading NPC |
| `time_freeze_obelisk.gd` | Temporal power-up |

#### Utilities

**ObjectPool (`object_pool.gd`)**
- Static methods: `get_pool()`, `get_pool_for_script()`
- Reuses objects to reduce GC pressure

**WeaponManager (`weapon_manager.gd`)**
- Coordinates weapon system
- Manages ability cooldowns

---

## Groups for Cross-Entity Communication

| Group | Purpose |
|-------|---------|
| `"player"` | Singleton player reference |
| `"enemies"` | All enemy instances |
| `"hud"` | UI elements |
| `"xp_orbs"` | XP orb entities (for Frog Nuke) |
| `"terrain"` | Terrain height queries |

---

## Stats System

The player uses a Dictionary-based stats system accessed via `player.stats`. All stats can be modified through upgrades.

### Combat Stats
- `slime_damage` - Slime ball damage multiplier
- `slime_speed` - Projectile velocity multiplier
- `slime_size` - Projectile size multiplier
- `slime_pierce` - Enemies to pass through (+1 per upgrade)
- `fire_rate` - Attack speed increase
- `explosion_radius` - AOE size on impact
- `chain_count` - Lightning jump targets
- `homing` - Projectile turn rate
- `poison_duration` - DoT duration in seconds
- `crit_chance` - Critical hit probability (0-1)
- `crit_damage` - Critical damage multiplier
- `crit_heal` - HP restored on crit

### Movement Stats
- `move_speed` - Movement speed multiplier
- `jump_power` - Jump height multiplier
- `extra_jumps` - Additional mid-air jumps
- `dash_cooldown` - Reduction (negative = faster cooldown)
- `air_control` - Air maneuverability

### Defense Stats
- `max_health` - Maximum HP increase
- `health_regen` - HP per second
- `damage_resist` - Damage reduction (0-1)
- `dodge_chance` - Miss probability (0-1)
- `thorns` - Damage reflection
- `lifesteal` - Heal on hit percentage

### Utility Stats
- `xp_multiplier` - XP gain multiplier
- `pickup_range` - Collection radius multiplier
- `luck` - Better upgrade tier chances
- `cooldown_reduction` - Ability cooldown reduction (max 70%)

### Special Stats
- `aura_damage` - Passive AOE DPS

### Ability Unlocks (0 = locked, 1+ = unlocked)
- `unlock_tongue_lash` - Melee cone attack
- `unlock_tadpole_swarm` - Summon allies
- `unlock_croak_blast` - AOE shockwave
- `unlock_fly_cloud` - Damage aura
- `unlock_amphibian_rage` - Ultimate ability

### Ability Upgrades
- `tongue_lash_damage` - Tongue Lash damage multiplier
- `tadpole_count` - Additional tadpoles per swarm
- `croak_blast_damage` - Shockwave damage multiplier
- `fly_cloud_damage` - Aura DPS increase
- `rage_duration` - Ultimate duration increase

---

## Key Patterns Used

- **Static factory methods** for projectiles and XP orbs (creates visuals programmatically)
- **Signal-based UI updates** - HUD subscribes to player/game signals
- **Singleton access** - `EntityRegistry`, `GameManager` for global state
- **Group-based entity lookup** - `get_tree().get_first_node_in_group("player")`
- **@onready caching** - Scene node references cached in `_ready()`
- **Object pooling** - `ObjectPool` class for projectile reuse
- **Spatial partitioning** - EntityRegistry grid for O(1) queries
- **Performance optimizations** - `length_squared()` instead of `length()`, pre-calculated radians

---

## Performance Guidelines

When writing new code:

1. **Use EntityRegistry for entity queries**
   ```gdscript
   # GOOD: O(1) spatial query
   var closest = EntityRegistry.get_nearest_enemy(position, [], INF)

   # BAD: O(n) group iteration
   var enemies = get_tree().get_nodes_in_group("enemies")
   ```

2. **Use length_squared() for distance comparisons**
   ```gdscript
   # GOOD: No sqrt
   if (target.position - position).length_squared() < range * range:

   # BAD: Unnecessary sqrt
   if (target.position - position).length() < range:
   ```

3. **Use object pooling for frequently spawned objects**
   ```gdscript
   var pool = ObjectPool.get_pool_for_script(MyClass, 50, self)
   var obj = pool.get_object()
   ```

4. **Cache node references with @onready**
   ```gdscript
   @onready var _mesh = $MeshInstance3D
   ```

---

## Project Settings

- **Input actions:**
  - `ui_accept` - Space/Enter (jump/confirm)
  - `ui_cancel` - Escape (mouse toggle/back)
  - `ui_up/down/left/right` - WASD/Arrows (movement)
- **Main scene:** `res://scenes/main.tscn`
- **Rendering:** Forward Plus
- **Resolution:** 1920x1080 (viewport stretch)

---

## Debug Features

- **K key** - Add 100 XP (debug level up)
- **L key** - Skip 1 minute (debug timer)

Wrap these in `OS.is_debug_build()` checks for production.
