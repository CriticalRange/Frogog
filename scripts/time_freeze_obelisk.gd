extends Interactable
class_name TimeFreezeObelisk

## Ancient obelisk that freezes all enemies in place for a duration

var _can_use: bool = true
var _freeze_duration: float = 8.0  # Seconds enemies stay frozen
var _glow_ring: MeshInstance3D = null
var _crystal: MeshInstance3D = null
var _crystal_mat: StandardMaterial3D = null

func _ready() -> void:
	super._ready()
	interaction_prompt = "Press E to Freeze Time"
	_create_visual()

func _create_visual() -> void:
	# Scale up the entire interactible
	scale = Vector3(1.2, 1.2, 1.2)

	# Stone base
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.0
	base_mesh.bottom_radius = 1.2
	base_mesh.height = 0.4
	base.mesh = base_mesh
	base.position = Vector3(0, 0.2, 0)
	add_child(base)
	
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.25, 0.25, 0.3)
	stone_mat.roughness = 0.9
	base.set_surface_override_material(0, stone_mat)
	
	# Main obelisk pillar
	var pillar := MeshInstance3D.new()
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.6, 4.0, 0.6)
	pillar.mesh = pillar_mesh
	pillar.position = Vector3(0, 2.4, 0)
	add_child(pillar)
	
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.15, 0.15, 0.2)
	pillar_mat.roughness = 0.85
	pillar.set_surface_override_material(0, pillar_mat)
	
	# Glowing runes on pillar
	for i in range(4):
		var rune := MeshInstance3D.new()
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.7, 0.1, 0.1)
		rune.mesh = rune_mesh
		rune.position = Vector3(0, 1.0 + i * 0.8, 0.35)
		add_child(rune)
		
		var rune_mat := StandardMaterial3D.new()
		rune_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.9)
		rune_mat.emission_enabled = true
		rune_mat.emission = Color(0.3, 0.8, 1.0)
		rune_mat.emission_energy_multiplier = 2.0
		rune.set_surface_override_material(0, rune_mat)
	
	# Floating crystal at top
	var crystal := MeshInstance3D.new()
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(0.8, 1.2, 0.8)
	crystal.mesh = crystal_mesh
	crystal.position = Vector3(0, 5.0, 0)
	crystal.rotation.x = PI  # Point downward
	add_child(crystal)
	_crystal = crystal
	
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.8)
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.3, 0.8, 1.0)
	crystal_mat.emission_energy_multiplier = 3.0
	crystal.set_surface_override_material(0, crystal_mat)
	_crystal_mat = crystal_mat
	
	# Glow ring at base
	var glow := TorusMesh.new()
	glow.inner_radius = 0.9
	glow.outer_radius = 1.1
	var glow_ring := MeshInstance3D.new()
	glow_ring.mesh = glow
	glow_ring.rotation.x = PI / 2
	glow_ring.position = Vector3(0, 0.1, 0)
	add_child(glow_ring)
	_glow_ring = glow_ring
	
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.6)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.3, 0.8, 1.0)
	glow_mat.emission_energy_multiplier = 1.5
	glow_ring.set_surface_override_material(0, glow_mat)
	
	# Ambient light
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 1.0)
	light.light_energy = 2.0
	light.omni_range = 8
	light.position = Vector3(0, 3, 0)
	add_child(light)

func _process(delta: float) -> void:
	super._process(delta)
	
	# Animate crystal floating and rotating
	if _crystal and _can_use:
		_crystal.rotation.y += delta * 0.5
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.1
		_crystal.position.y = 5.0 + bob
		
		# Pulse glow
		if _crystal_mat:
			var pulse := (sin(Time.get_ticks_msec() / 500.0) + 1.0) / 2.0
			_crystal_mat.emission_energy_multiplier = 2.0 + pulse * 2.0
	
	# Animate glow ring
	if _glow_ring and _can_use:
		_glow_ring.rotation.z += delta * 0.3

func _perform_interaction(player: Node3D) -> void:
	if not _can_use:
		return
	
	_can_use = false
	_play_activate_effect()
	_play_interaction_effect()
	
	# Freeze all enemies
	_freeze_all_enemies()
	
	# Show notification
	_show_notification("TIME FROZEN FOR " + str(int(_freeze_duration)) + " SECONDS!", Color(0.3, 0.8, 1.0))
	
	# Create shockwave effect
	_create_freeze_shockwave()
	
	# Remove obelisk after use
	_remove_after_delay()

func _freeze_all_enemies() -> void:
	# Use EntityRegistry for O(n) iteration instead of tree search
	var enemies := []
	if EntityRegistry:
		enemies = EntityRegistry.get_all_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	print("Time Freeze: Freezing ", enemies.size(), " enemies for ", _freeze_duration, " seconds")

	for enemy in enemies:
		if enemy.has_method("freeze"):
			enemy.freeze(_freeze_duration)
			print("  - Froze enemy: ", enemy.name)
		else:
			# Fallback: just set a property if method doesn't exist
			if "is_frozen" in enemy:
				enemy.is_frozen = true
				# Schedule unfreeze
				get_tree().create_timer(_freeze_duration).timeout.connect(func():
					if is_instance_valid(enemy) and "is_frozen" in enemy:
						enemy.is_frozen = false
				)

func _create_freeze_shockwave() -> void:
	# Create expanding ring effect
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 1.0
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2
	ring.position = global_position + Vector3(0, 1, 0)
	get_tree().current_scene.add_child(ring)
	
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.8)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.3, 0.8, 1.0)
	ring_mat.emission_energy_multiplier = 3.0
	ring.set_surface_override_material(0, ring_mat)
	
	# Expand and fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(50, 50, 1), 1.0)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_callback(ring.queue_free).set_delay(1.0)

func _remove_after_delay() -> void:
	# Crystal shatters and obelisk crumbles
	if _crystal:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_crystal, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
		tween.tween_property(self, "global_position:y", global_position.y - 3, 0.8).set_delay(0.3)
		tween.tween_callback(queue_free).set_delay(1.0)

func _show_notification(text: String, color: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
