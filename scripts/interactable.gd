extends Node3D
class_name Interactable

## Base class for all interactable objects on the terrain

signal interacted(player: Node3D)

@export var interaction_prompt: String = "Press E to interact"
@export var interaction_range: float = 3.0
@export var auto_show_prompt: bool = true

var _player_ref: CharacterBody3D = null
var _in_range: bool = false
var _prompt_label: Label3D = null

func _ready() -> void:
	add_to_group("interactables")
	_create_prompt_label()

func _create_prompt_label() -> void:
	if not auto_show_prompt:
		return

	_prompt_label = Label3D.new()
	_prompt_label.text = interaction_prompt
	_prompt_label.pixel_size = 0.005
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.modulate = Color(1.0, 1.0, 0.5)
	_prompt_label.outline_size = 4
	_prompt_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	_prompt_label.position = Vector3(0, 2.5, 0)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _process(delta: float) -> void:
	if not _player_ref:
		_find_player()
		return

	var dist_sq := global_position.distance_squared_to(_player_ref.global_position)
	var was_in_range := _in_range
	_in_range = dist_sq < interaction_range * interaction_range

	# Show/hide prompt
	if _prompt_label and _in_range != was_in_range:
		_prompt_label.visible = _in_range

func _input(event: InputEvent) -> void:
	if not _in_range or not _player_ref:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			_on_interact()

func _find_player() -> void:
	_player_ref = get_tree().get_first_node_in_group("player")

func _on_interact() -> void:
	interacted.emit(_player_ref)
	_perform_interaction(_player_ref)

## Override this in subclasses to implement specific behavior
func _perform_interaction(player: Node3D) -> void:
	pass

## Play interaction effect
func _play_interaction_effect() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 0.8
	particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = Color(1.0, 1.0, 0.5, 0.8)

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	add_child(particles)

	# Auto-remove
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Play activation sound effect (visual feedback mainly)
func _play_activate_effect() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15).set_ease(Tween.EASE_IN).set_delay(0.15)
