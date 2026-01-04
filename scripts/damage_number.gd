extends Label3D
class_name DamageNumber

# Damage colors
const COLOR_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)       # White
const COLOR_CRIT: Color = Color(1.0, 0.2, 0.2, 1.0)         # Red
const COLOR_HEADSHOT: Color = Color(1.0, 0.8, 0.0, 1.0)     # Gold
const COLOR_POISON: Color = Color(0.3, 0.9, 0.3, 1.0)       # Green

# Animation settings
const RISE_SPEED: float = 3.0
const LIFETIME: float = 1.0
const RANDOM_OFFSET: float = 0.5

var _lifetime_timer: float = 0.0
var _is_crit: bool = false
var _target_position: Vector3  # Store position to set after entering tree

# Factory function to create a damage number
static func spawn(damage_value: float, spawn_pos: Vector3, is_crit: bool = false, damage_type: String = "normal") -> DamageNumber:
	var dmg_num := DamageNumber.new()

	# Store target position (will be applied after entering tree)
	var random_offset := Vector3(
		randf_range(-RANDOM_OFFSET, RANDOM_OFFSET),
		randf_range(0.0, RANDOM_OFFSET),
		randf_range(-RANDOM_OFFSET, RANDOM_OFFSET)
	)
	dmg_num._target_position = spawn_pos + random_offset

	# Format damage text
	var damage_text := str(int(damage_value))
	if is_crit:
		damage_text = "✦ " + damage_text + " ✦"
	elif damage_type == "poison":
		damage_text = "☠ " + damage_text

	dmg_num.text = damage_text
	dmg_num._is_crit = is_crit

	# Set font size
	if is_crit:
		dmg_num.font_size = 60
	else:
		dmg_num.font_size = 40

	# Set color based on type
	match damage_type:
		"crit":
			dmg_num.modulate = COLOR_CRIT
		"headshot":
			dmg_num.modulate = COLOR_HEADSHOT
		"poison":
			dmg_num.modulate = COLOR_POISON
		_:
			dmg_num.modulate = COLOR_NORMAL

	# Make text face camera by default (billboard)
	dmg_num.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Add outline for better visibility
	dmg_num.outline_size = 4
	if is_crit:
		dmg_num.outline_modulate = Color(0.3, 0.0, 0.0, 0.8)
	else:
		dmg_num.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)

	# Add to scene tree FIRST (this triggers _enter_tree() and _ready())
	# Get the scene tree - try to get it from the main scene or first node
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(dmg_num)

	return dmg_num

func _ready() -> void:
	# Set global position now that we're in the tree
	global_position = _target_position

func _process(delta: float) -> void:
	_lifetime_timer += delta

	# Rise upward
	global_position.y += RISE_SPEED * delta

	# Fade out based on lifetime
	var alpha := 1.0 - (_lifetime_timer / LIFETIME)
	modulate.a = alpha

	# Scale up slightly for crits
	if _is_crit and _lifetime_timer < 0.2:
		var scale_value := 1.0 + (_lifetime_timer / 0.2) * 0.3
		var scale_vec := Vector3(scale_value, scale_value, scale_value)
		transform.basis = Basis().scaled(scale_vec)

	# Remove when lifetime ends
	if _lifetime_timer >= LIFETIME:
		queue_free()
