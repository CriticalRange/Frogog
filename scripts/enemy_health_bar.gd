extends Control

@onready var background = $Background
@onready var fill = $Fill

var health_percent: float = 1.0:
	set(value):
		health_percent = clamp(value, 0.0, 1.0)
		if is_inside_tree():
			_update_fill()

# Create StyleBox objects ONCE and reuse them (not every frame like a maniac!)
var _bg_style: StyleBoxFlat
var _fill_style: StyleBoxFlat

func _ready():
	# Create styles ONCE in _ready, not every time health changes!
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	_bg_style.corner_radius_top_left = 2
	_bg_style.corner_radius_top_right = 2
	_bg_style.corner_radius_bottom_right = 2
	_bg_style.corner_radius_bottom_left = 2
	background.add_theme_stylebox_override("panel", _bg_style)

	_fill_style = StyleBoxFlat.new()
	_fill_style.corner_radius_top_left = 2
	_fill_style.corner_radius_top_right = 2
	_fill_style.corner_radius_bottom_right = 2
	_fill_style.corner_radius_bottom_left = 2
	fill.add_theme_stylebox_override("panel", _fill_style)

	_update_fill()

func _update_fill():
	if fill:
		# Use anchor_right to control fill width (cleaner than setting size)
		fill.anchor_left = 0.0
		fill.anchor_right = health_percent
		fill.offset_left = 0.0
		fill.offset_right = 0.0
		_update_color()

func _update_color():
	if not _fill_style:
		return

	# Just update the color on the EXISTING fill_style - no need to create new objects!
	if health_percent > 0.6:
		_fill_style.bg_color = Color(0.2, 0.8, 0.2)  # Green
	elif health_percent > 0.3:
		_fill_style.bg_color = Color(0.8, 0.6, 0.2)  # Yellow
	else:
		_fill_style.bg_color = Color(0.8, 0.2, 0.2)  # Red
