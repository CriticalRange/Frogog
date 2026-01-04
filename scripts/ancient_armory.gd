extends Interactable
class_name AncientArmory

## Ancient armory that guarantees a powerful upgrade selection

var _can_use: bool = true
var _glow_ring: MeshInstance3D = null
var _floating_particles: Array[Node3D] = []

func _ready() -> void:
	super._ready()
	interaction_prompt = "Press E for Ancient Armory"
	_create_visual()

func _create_visual() -> void:
	# Scale up the entire interactible
	scale = Vector3(1.2, 1.2, 1.2)

	# Stone base platform
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 2.0
	base_mesh.bottom_radius = 2.2
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position = Vector3(0, 0.25, 0)
	add_child(base)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.3, 0.25, 0.2)
	stone_mat.roughness = 0.9
	base.set_surface_override_material(0, stone_mat)

	# Main structure - stone chest
	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(2.0, 1.5, 1.2)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 1.25, 0)
	add_child(chest)

	var chest_mat := StandardMaterial3D.new()
	chest_mat.albedo_color = Color(0.2, 0.15, 0.1)
	chest_mat.roughness = 0.8
	chest.set_surface_override_material(0, chest_mat)

	# Gold trim
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(2.1, 0.2, 1.3)
	trim.mesh = trim_mesh
	trim.position = Vector3(0, 2.0, 0)
	add_child(trim)

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(1.0, 0.8, 0.3)
	gold_mat.metallic = 0.8
	gold_mat.roughness = 0.3
	trim.set_surface_override_material(0, gold_mat)

	# Lid
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(2.05, 0.3, 1.25)
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 2.0, 0)
	add_child(lid)
	lid.set_surface_override_material(0, gold_mat)

	# Pillars on corners
	for i in range(4):
		var x := 1.0 if i % 2 == 0 else -1.0
		var z := 0.6 if i < 2 else -0.6

		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.15
		pillar_mesh.bottom_radius = 0.2
		pillar_mesh.height = 2.5
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 1.5, z)
		add_child(pillar)

		var pillar_mat := StandardMaterial3D.new()
		pillar_mat.albedo_color = Color(0.8, 0.7, 0.5)
		pillar_mat.roughness = 0.6
		pillar.set_surface_override_material(0, pillar_mat)

	# Floating weapons above (visual only)
	_create_floating_weapon(Vector3(0, 3.5, 0), Color(1.0, 0.9, 0.3))  # Gold center

	# Glow ring at base
	var glow := TorusMesh.new()
	glow.inner_radius = 1.8
	glow.outer_radius = 2.2
	var glow_ring := MeshInstance3D.new()
	glow_ring.mesh = glow
	glow_ring.rotation.x = PI / 2
	glow_ring.position = Vector3(0, 0.1, 0)
	add_child(glow_ring)
	_glow_ring = glow_ring

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.5)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.8, 0.3)
	glow_mat.emission_energy_multiplier = 2.0
	glow_ring.set_surface_override_material(0, glow_mat)

	# Golden light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.6)
	light.light_energy = 3.0
	light.omni_range = 12
	light.position = Vector3(0, 3, 0)
	add_child(light)

func _create_floating_weapon(pos: Vector3, color: Color) -> void:
	var weapon := MeshInstance3D.new()
	var weapon_mesh := PrismMesh.new()
	weapon_mesh.size = Vector3(0.4, 1.5, 0.4)
	weapon.mesh = weapon_mesh
	weapon.position = pos
	add_child(weapon)
	_floating_particles.append(weapon)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	weapon.set_surface_override_material(0, mat)

func _process(delta: float) -> void:
	super._process(delta)

	# Rotate floating weapons
	for i in range(_floating_particles.size()):
		var weapon := _floating_particles[i]
		if weapon:
			weapon.rotation.y += delta * (0.5 + i * 0.2)
			var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.0 + i) * 0.15
			weapon.position.y = 3.5 + bob

	# Animate glow ring
	if _glow_ring and _can_use:
		_glow_ring.rotation.z += delta * 0.2

func _perform_interaction(player: Node3D) -> void:
	if not _can_use:
		return

	_can_use = false
	_play_activate_effect()
	_play_interaction_effect()

	# Trigger upgrade popup with guaranteed high-tier options
	_show_ancient_armory_upgrades(player)

	# Show notification
	_show_notification("ANCIENT ARMORY OPENED!", Color(1.0, 0.8, 0.3))

	# Remove after delay
	_remove_after_delay()

func _show_ancient_armory_upgrades(player: Node3D) -> void:
	# Get the upgrade popup node
	var upgrade_popup := get_tree().get_first_node_in_group("upgrade_popup")
	if not upgrade_popup:
		# Create popup if it doesn't exist
		var popup_script := preload("res://scripts/upgrade_popup.gd")
		if popup_script:
			upgrade_popup = Control.new()
			upgrade_popup.set_script(popup_script)
			get_tree().current_scene.add_child(upgrade_popup)

	if upgrade_popup and upgrade_popup.has_method("show_ancient_armory_upgrades"):
		upgrade_popup.show_ancient_armory_upgrades()
	elif upgrade_popup and upgrade_popup.has_method("show_upgrades"):
		# Fallback: show regular upgrades with higher tier
		upgrade_popup.show_upgrades()

func _remove_after_delay() -> void:
	# Chest opens and scales away (Node3D doesn't have modulate)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(queue_free).set_delay(1.0)

func _show_notification(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
