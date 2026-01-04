# Frogog - Documentation Index

Welcome to the Frogog project documentation. This is a **Godot 4.5 3D action-survival game** where you control a frog character that auto-shoots projectiles at enemies while collecting XP orbs to level up and unlock abilities.

---

## Quick Links

| Document | Description |
|----------|-------------|
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Complete directory structure and component overview |
| [API_REFERENCE.md](API_REFERENCE.md) | Detailed API documentation for all systems |
| [CLAUDE.md](../CLAUDE.md) | Main project guide for AI assistants |

---

## Project Summary

**Game Name:** Frogog
**Engine:** Godot 4.5
**Language:** GDScript
**Genre:** 3D Action-Survival

### Core Features
- Auto-aiming projectile combat with multiple upgrade paths
- 5 unlockable abilities (Tongue Lash, Tadpole Swarm, Croak Blast, Fly Cloud, Amphibian Rage)
- 12-minute timer leading to endless mode
- Wave-based difficulty scaling
- Boss encounters
- Comprehensive upgrade system with 4 tiers (Common, Rare, Epic, Legendary)
- Object pooling and spatial partitioning for performance

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Main Scene                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Player    │  │ GameManager  │  │  EnemySpawner    │  │
│  │ (Combat)    │◄─┤ (Timer)      │──┤│ (Waves)          │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
│         │                                  │                │
│         │ emits                            │ spawns         │
│         ▼                                  ▼                │
│  ┌─────────────┐                   ┌──────────────┐       │
│  │     HUD     │                   │   Enemies    │       │
│  │ (Display)   │                   │  (AI/Drops)  │       │
│  └─────────────┘                   └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
         │                                                   │
         │ uses                                              │
         ▼                                                   ▼
┌────────────────────┐                            ┌──────────────────┐
│ EntityRegistry     │                            │  UpgradePopup    │
│ (Spatial Grid O1)  │                            │ (Progression)    │
└────────────────────┘                            └──────────────────┘
```

---

## Key Files Reference

### Core Game Files
- `scenes/main.tscn` - Root scene
- `scripts/player.gd` - Player controller (1193 lines)
- `scripts/game_manager.gd` - Game state singleton
- `scripts/entity_registry.gd` - Spatial queries singleton

### Combat Files
- `scripts/slime_projectile.gd` - Auto-targeting projectile
- `scripts/damage_number.gd` - Floating damage text
- `scripts/weapons/` - 5 ability scripts

### UI Files
- `scripts/hud.gd` - Main UI controller
- `scripts/upgrade_popup.gd` - Level-up screen

---

## Development Guidelines

### Performance Best Practices
1. Use `EntityRegistry` for entity queries (O(1) vs O(n))
2. Use `length_squared()` instead of `length()` for comparisons
3. Use object pooling for frequently spawned objects
4. Cache node references with `@onready`

### Code Patterns
- Factory methods: `SlimeProjectile.create()`, `XPOrb.create()`
- Signal-driven UI: HUD connects to player signals
- Singleton access: `GameManager.instance`, `EntityRegistry`
- Dictionary-based stats system for flexibility

---

## Stats Quick Reference

The player uses `player.stats` Dictionary for all modifiers.

| Category | Stats |
|----------|-------|
| **Combat** | `slime_damage`, `fire_rate`, `crit_chance`, `crit_damage`, `homing` |
| **Defense** | `max_health`, `health_regen`, `damage_resist`, `lifesteal` |
| **Movement** | `move_speed`, `jump_power`, `extra_jumps`, `dash_cooldown` |
| **Utility** | `xp_multiplier`, `pickup_range`, `luck`, `cooldown_reduction` |
| **Unlock** | `unlock_tongue_lash`, `unlock_tadpole_swarm`, `unlock_croak_blast`, `unlock_fly_cloud`, `unlock_amphibian_rage` |

---

## Running the Game

1. Open Godot 4.5
2. Open this project directory
3. Press F5 to run

### Controls
- **WASD** - Movement
- **Mouse** - Look around
- **Space** - Jump
- **Shift** - Dash
- **Escape** - Toggle mouse capture

---

## Documentation Last Updated

2025-01-05 - Complete project documentation generated
