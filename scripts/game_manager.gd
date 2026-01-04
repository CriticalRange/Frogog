extends Node
class_name GameManager

# Singleton pattern
static var instance: GameManager = null

# Game timer
const GAME_DURATION: float = 720.0  # 12 minutes in seconds
var elapsed_time: float = 0.0
var game_running := true

# Endless mode (starts when timer goes below 0)
var endless_mode := false
var endless_time := 0.0  # Time spent in endless mode (negative elapsed_time)

# Difficulty scaling
var current_minute: int = 0
var difficulty_multiplier: float = 1.0

# Wave surge (increased spawn for 1 minute after wave)
var is_surge_active := false
var surge_end_minute: int = -1
const SURGE_SPAWN_MULTIPLIER := 8.0  # Increased from 5x to 8x

# In endless mode, horde is ALWAYS active
var horde_permanent := false

# TODO: Enemy type selection for endless mode
# When endless mode starts, we will spawn only ONE enemy type
# This will be selected randomly or configured
var endless_enemy_type: String = ""  # Empty = random selection when endless starts

# Scaling constants (NORMAL MODE - additive)
const BASE_ENEMY_HEALTH_MULT := 1.0
const BASE_ENEMY_DAMAGE_MULT := 1.0
const BASE_ENEMY_SPEED_MULT := 1.0
const BASE_SPAWN_RATE_MULT := 1.0
const BASE_BATCH_SIZE_MULT := 1.0

# Per-minute scaling (increased for harder difficulty)
const MINUTE_HEALTH_BUFF := 0.18      # +18% per minute (was +10%)
const MINUTE_DAMAGE_BUFF := 0.12      # +12% per minute (was +5%)
const MINUTE_SPEED_BUFF := 0.08       # +8% per minute (was +3%)
const MINUTE_SPAWN_BUFF := 0.08       # +8% spawn rate per minute (was +12%, slower ramp-up)
const MINUTE_BATCH_BUFF := 0.40       # +40% batch size per minute (was +15%, increased for noticeable growth)

# Every 3 minutes (significantly increased)
const WAVE_HEALTH_BUFF := 0.40        # +40% every 3 min (was +25%)
const WAVE_DAMAGE_BUFF := 0.30        # +30% every 3 min (was +15%)
const WAVE_SPEED_BUFF := 0.20         # +20% every 3 min (was +10%)
const WAVE_SPAWN_BUFF := 0.30         # +30% spawn rate every 3 min (was +20%)
const WAVE_BATCH_BUFF := 0.80         # +80% batch size every 3 min (was +50%, increased for noticeable jumps)

# ENDLESS MODE - Multilicative scaling (per 30 seconds in endless)
const ENDLESS_HEALTH_MULT := 1.15     # +15% every 30s (multiplicative)
const ENDLESS_DAMAGE_MULT := 1.12     # +12% every 30s (multiplicative)
const ENDLESS_SPEED_MULT := 1.08      # +8% every 30s (multiplicative)
const ENDLESS_SPAWN_MULT := 1.10      # +10% every 30s (multiplicative)
const ENDLESS_BATCH_MULT := 1.20      # +20% every 30s (multiplicative)
const ENDLESS_TICK_RATE := 30.0       # Apply scaling every 30 seconds

# Current enemy stats (multipliers)
var enemy_health_mult := 1.0
var enemy_damage_mult := 1.0
var enemy_speed_mult := 1.0
var spawn_rate_mult := 1.0
var batch_size_mult := 1.0

# Endless mode tracking
var endless_ticks: int = 0  # Number of 30-second periods in endless mode

# Signals
signal time_updated(elapsed: float, remaining: float)
signal minute_changed(minute: int)
signal wave_changed(wave: int)  # Every 3 minutes
signal surge_started()
signal surge_ended()
signal endless_mode_started()  # Fired when timer goes below 0
signal game_over(won: bool)
signal difficulty_changed(health_mult: float, damage_mult: float, speed_mult: float)

func _ready() -> void:
	instance = self
	add_to_group("game_manager")
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if not game_running:
		return

	elapsed_time += delta

	# Check if we entered endless mode
	if not endless_mode and elapsed_time >= GAME_DURATION:
		_start_endless_mode()

	# In endless mode, track endless-specific time
	if endless_mode:
		var new_endless_time := elapsed_time - GAME_DURATION
		var new_ticks := int(new_endless_time / ENDLESS_TICK_RATE)
		if new_ticks > endless_ticks:
			endless_ticks = new_ticks
			_recalculate_endless_difficulty()
	else:
		# Normal mode: check minute change
		var new_minute := int(elapsed_time / 60.0)
		if new_minute > current_minute:
			_on_minute_changed(new_minute)

	# Emit time update (remaining can be negative in endless mode)
	var remaining := GAME_DURATION - elapsed_time
	time_updated.emit(elapsed_time, remaining)

func _start_endless_mode() -> void:
	endless_mode = true
	endless_time = 0.0
	endless_ticks = 0
	horde_permanent = true  # Horde is ALWAYS active in endless mode

	print("\n")
	print("╔═══════════════════════════════════════════════════════════════╗")
	print("║           ☠️  ENDLESS SURVIVAL MODE BEGUN  ☠️                   ║")
	print("║                                                                 ║")
	print("║  The real game starts now. Survive as long as you can...      ║")
	print("║  Enemies will grow MULTIPLICATIVELY stronger.                 ║")
	print("║  Horde is now PERMANENTLY active.                              ║")
	print("╚═══════════════════════════════════════════════════════════════╝")
	print("\n")

	endless_mode_started.emit()

	# Select random enemy type for endless mode (TODO: expand this system)
	# For now, empty means "current enemy" - we'll add more enemy types later
	if endless_enemy_type.is_empty():
		endless_enemy_type = "basic"  # Default to basic enemy

	# Initial endless difficulty calculation
	_recalculate_endless_difficulty()

func _on_minute_changed(new_minute: int) -> void:
	current_minute = new_minute
	minute_changed.emit(current_minute)

	# Check if surge should end
	if is_surge_active and current_minute >= surge_end_minute:
		_end_surge()

	# Calculate new difficulty
	_recalculate_difficulty()

	# Check for wave change (every 3 minutes)
	if current_minute > 0 and current_minute % 3 == 0:
		var wave := current_minute / 3
		wave_changed.emit(wave)
		print("=== WAVE ", wave, " === Enemies are getting stronger!")

		# Start surge!
		_start_surge()

func _start_surge() -> void:
	is_surge_active = true
	surge_end_minute = current_minute + 1  # Surge lasts 1 minute
	surge_started.emit()
	print("🌊 WAVE SURGE! 8x spawn rate for 1 minute! 🌊")
	_recalculate_difficulty()

func _end_surge() -> void:
	is_surge_active = false
	surge_ended.emit()
	print("Wave surge ended.")
	_recalculate_difficulty()

## Called by Difficulty Tomb to manually increase difficulty
func increase_difficulty() -> void:
	enemy_health_mult += 0.25
	enemy_damage_mult += 0.25
	enemy_speed_mult += 0.15
	_recalculate_difficulty()
	print("=== DIFFICULTY INCREASED via Tomb ===")

func _recalculate_difficulty() -> void:
	# NORMAL MODE: Base + per-minute scaling (additive)
	var minutes := float(current_minute)

	# Calculate minute bonuses
	var minute_health := minutes * MINUTE_HEALTH_BUFF
	var minute_damage := minutes * MINUTE_DAMAGE_BUFF
	var minute_speed := minutes * MINUTE_SPEED_BUFF
	var minute_spawn := minutes * MINUTE_SPAWN_BUFF
	var minute_batch := minutes * MINUTE_BATCH_BUFF

	# Calculate wave bonuses (every 3 minutes)
	var waves := float(current_minute / 3)
	var wave_health := waves * WAVE_HEALTH_BUFF
	var wave_damage := waves * WAVE_DAMAGE_BUFF
	var wave_speed := waves * WAVE_SPEED_BUFF
	var wave_spawn := waves * WAVE_SPAWN_BUFF
	var wave_batch := waves * WAVE_BATCH_BUFF

	# Apply total
	enemy_health_mult = BASE_ENEMY_HEALTH_MULT + minute_health + wave_health
	enemy_damage_mult = BASE_ENEMY_DAMAGE_MULT + minute_damage + wave_damage
	enemy_speed_mult = BASE_ENEMY_SPEED_MULT + minute_speed + wave_speed
	spawn_rate_mult = BASE_SPAWN_RATE_MULT + minute_spawn + wave_spawn
	batch_size_mult = BASE_BATCH_SIZE_MULT + minute_batch + wave_batch

	# Apply surge multiplier if active
	if is_surge_active:
		spawn_rate_mult *= SURGE_SPAWN_MULTIPLIER

	# Overall difficulty for display
	difficulty_multiplier = (enemy_health_mult + enemy_damage_mult + enemy_speed_mult) / 3.0

	difficulty_changed.emit(enemy_health_mult, enemy_damage_mult, enemy_speed_mult)

	var surge_text := " [SURGE!]" if is_surge_active else ""
	print("Minute ", current_minute, " - Difficulty: HP x", snapped(enemy_health_mult, 0.01),
		  ", DMG x", snapped(enemy_damage_mult, 0.01),
		  ", SPD x", snapped(enemy_speed_mult, 0.01),
		  ", SPAWN x", snapped(spawn_rate_mult, 0.01),
		  ", BATCH x", snapped(batch_size_mult, 0.01), surge_text)

func _recalculate_endless_difficulty() -> void:
	# ENDLESS MODE: Multilicative scaling
	# Each 30-second tick multiplies enemy stats

	# Start from final normal mode values
	var base_health := BASE_ENEMY_HEALTH_MULT + (12.0 * MINUTE_HEALTH_BUFF) + (4.0 * WAVE_HEALTH_BUFF)
	var base_damage := BASE_ENEMY_DAMAGE_MULT + (12.0 * MINUTE_DAMAGE_BUFF) + (4.0 * WAVE_DAMAGE_BUFF)
	var base_speed := BASE_ENEMY_SPEED_MULT + (12.0 * MINUTE_SPEED_BUFF) + (4.0 * WAVE_SPEED_BUFF)
	var base_spawn := BASE_SPAWN_RATE_MULT + (12.0 * MINUTE_SPAWN_BUFF) + (4.0 * WAVE_SPAWN_BUFF)
	var base_batch := BASE_BATCH_SIZE_MULT + (12.0 * MINUTE_BATCH_BUFF) + (4.0 * WAVE_BATCH_BUFF)

	# Apply multiplicative scaling based on endless ticks
	enemy_health_mult = base_health * pow(ENDLESS_HEALTH_MULT, endless_ticks)
	enemy_damage_mult = base_damage * pow(ENDLESS_DAMAGE_MULT, endless_ticks)
	enemy_speed_mult = base_speed * pow(ENDLESS_SPEED_MULT, endless_ticks)
	spawn_rate_mult = base_spawn * pow(ENDLESS_SPAWN_MULT, endless_ticks)
	batch_size_mult = base_batch * pow(ENDLESS_BATCH_MULT, endless_ticks)

	# In endless mode, surge is always active (horde permanent)
	spawn_rate_mult *= SURGE_SPAWN_MULTIPLIER

	# Overall difficulty for display
	difficulty_multiplier = (enemy_health_mult + enemy_damage_mult + enemy_speed_mult) / 3.0

	difficulty_changed.emit(enemy_health_mult, enemy_damage_mult, enemy_speed_mult)

	var endless_time_str := format_endless_time(endless_time)
	print("⏱ ENDLESS ", endless_time_str, " (Tick ", endless_ticks, ") - HP x", snapped(enemy_health_mult, 0.01),
		  ", DMG x", snapped(enemy_damage_mult, 0.01),
		  ", SPD x", snapped(enemy_speed_mult, 0.01),
		  ", SPAWN x", snapped(spawn_rate_mult, 0.01),
		  ", BATCH x", snapped(batch_size_mult, 0.01), " [HORDE ACTIVE]")

func _on_time_up() -> void:
	# No longer spawns boss - instead enters endless mode
	print("=== TIME'S UP! === ENTERING ENDLESS MODE!")
	_start_endless_mode()

# Static getters for enemies to use
static func get_health_multiplier() -> float:
	if instance:
		return instance.enemy_health_mult
	return 1.0

static func get_damage_multiplier() -> float:
	if instance:
		return instance.enemy_damage_mult
	return 1.0

static func get_speed_multiplier() -> float:
	if instance:
		return instance.enemy_speed_mult
	return 1.0

static func get_spawn_rate_multiplier() -> float:
	if instance:
		return instance.spawn_rate_mult
	return 1.0

static func get_batch_size_multiplier() -> float:
	if instance:
		return instance.batch_size_mult
	return 1.0

static func is_surge() -> bool:
	if instance:
		# In endless mode, surge (horde) is always active
		return instance.is_surge_active or instance.horde_permanent
	return false

static func is_endless_mode() -> bool:
	if instance:
		return instance.endless_mode
	return false

static func get_endless_ticks() -> int:
	if instance:
		return instance.endless_ticks
	return 0

static func get_elapsed_time() -> float:
	if instance:
		return instance.elapsed_time
	return 0.0

static func get_current_minute() -> int:
	if instance:
		return instance.current_minute
	return 0

static func get_endless_enemy_type() -> String:
	if instance:
		return instance.endless_enemy_type
	return ""

static func set_endless_enemy_type(enemy_type: String) -> void:
	if instance:
		instance.endless_enemy_type = enemy_type
		print("Endless mode enemy type set to: ", enemy_type)

static func format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]

static func format_endless_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "-%d:%02d" % [mins, secs]  # Negative time to show endless mode
