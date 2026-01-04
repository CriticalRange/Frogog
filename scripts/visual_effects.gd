extends Node
class_name VisualEffects

## Utility class for creating common visual effects across the game.
## Consolidates duplicated particle effect and material creation code.

# ============================================================================
# PARTICLE EFFECT PRESETS
# ============================================================================

enum EffectType {
	EXPLOSION_SLIME,
	EXPLOSION_LARGE,
	POISON,
	FREEZE,
	DODGE,
	DASH,
	JUMP,
	PICKUP_COLLECT,
	DISINTEGRATION,
	COLLECT_SPIRAL,
}

# ============================================================================
# SIMPLE PARTICLE CREATION
# ============================================================================

## Create a basic particle system with common settings
static func create_basic_particles(amount: int, lifetime: float, one_shot: bool = true) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.emitting = one_shot
	return particles


## Create standard particle material
static func create_particle_material(color: Color, gravity: Vector3 = Vector3(0, -10, 0),
								   spread: float = 45.0, speed_min: float = 2.0,
								   speed_max: float = 5.0) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = spread
	mat.initial_velocity_min = speed_min
	mat.initial_velocity_max = speed_max
	mat.gravity = gravity
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.color = color
	return mat


## Attach sphere mesh to particles
static func attach_sphere_mesh(particles: GPUParticles3D, radius: float = 0.08) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	particles.draw_pass_1 = mesh


## Attach box mesh to particles
static func attach_box_mesh(particles: GPUParticles3D, size: Vector3 = Vector3(0.1, 0.1, 0.1)) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	particles.draw_pass_1 = mesh


## Spawn particles at position with auto-cleanup
static func spawn_particles(effect_type: EffectType, position: Vector3,
						   scene_tree: SceneTree) -> GPUParticles3D:
	var particles := create_effect(effect_type)
	if particles:
		scene_tree.current_scene.add_child(particles)
		particles.global_position = position
	return particles


## Create a predefined effect type
static func create_effect(effect_type: EffectType) -> GPUParticles3D:
	match effect_type:
		EffectType.EXPLOSION_SLIME:
			return _create_slime_explosion()
		EffectType.EXPLOSION_LARGE:
			return _create_large_explosion()
		EffectType.POISON:
			return _create_poison_effect()
		EffectType.DODGE:
			return _create_dodge_effect()
		EffectType.DASH:
			return _create_dash_effect()
		EffectType.JUMP:
			return _create_jump_effect()
		EffectType.PICKUP_COLLECT:
			return _create_collect_effect()
		EffectType.DISINTEGRATION:
			return _create_disintegration_effect()
		_:
			push_warning("Unknown effect type: %s" % effect_type)
			return null


# ============================================================================
# SPECIFIC EFFECTS
# ============================================================================

static func _create_slime_explosion() -> GPUParticles3D:
	var particles := create_basic_particles(30, 0.4)
	var mat := create_particle_material(Color(0.1, 1.0, 0.2, 1.0), Vector3(0, -10, 0), 180.0, 3.0, 6.0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.08)
	_setup_auto_cleanup(particles, 1.0)
	return particles


static func _create_large_explosion() -> GPUParticles3D:
	var particles := create_basic_particles(50, 0.4)
	var mat := create_particle_material(Color(1.0, 0.5, 0.2, 1.0), Vector3(0, -10, 0), 180.0, 3.0, 6.0)
	mat.emission_sphere_radius = 0.6
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.08)
	_setup_auto_cleanup(particles, 1.0)
	return particles


static func _create_poison_effect() -> GPUParticles3D:
	var particles := create_basic_particles(20, 0.8, false)
	var mat := create_particle_material(GameConfig.COLORS.poison, Vector3(0, -2, 0), 45.0, 0.5, 1.5)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.04)
	return particles


static func _create_dodge_effect() -> GPUParticles3D:
	var particles := create_basic_particles(20, 0.3)
	var mat := create_particle_material(GameConfig.COLORS.dodge, Vector3(0, -2, 0), 90.0, 1.0, 3.0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.04)
	_setup_auto_cleanup(particles, 0.5)
	return particles


static func _create_dash_effect() -> GPUParticles3D:
	var particles := create_basic_particles(30, 0.3)
	var mat := create_particle_material(GameConfig.COLORS.dash, Vector3(0, -3, 0), 60.0, 2.0, 4.0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.05)
	_setup_auto_cleanup(particles, 0.5)
	return particles


static func _create_jump_effect() -> GPUParticles3D:
	var particles := create_basic_particles(15, 0.3)
	var mat := create_particle_material(Color(1.0, 1.0, 1.0, 0.6), Vector3(0, -3, 0), 90.0, 1.0, 2.0)
	mat.emission_sphere_radius = 0.2
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.04)
	_setup_auto_cleanup(particles, 0.5)
	return particles


static func _create_collect_effect() -> GPUParticles3D:
	var particles := create_basic_particles(15, 0.3)
	var mat := create_particle_material(GameConfig.COLORS.xp_orb, Vector3(0, -5, 0), 60.0, 2.0, 4.0)
	mat.emission_sphere_radius = 0.1
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	particles.process_material = mat
	attach_sphere_mesh(particles, 0.05)
	_setup_auto_cleanup(particles, 0.5)
	return particles


static func _create_disintegration_effect() -> GPUParticles3D:
	# Returns the primary burst, caller should add secondary burst if needed
	var particles := create_basic_particles(50, 0.8)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 1.0, 0.5)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -5.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.3
	mat.color = GameConfig.COLORS.enemy_base
	particles.process_material = mat
	attach_box_mesh(particles, Vector3(0.15, 0.15, 0.15))
	_setup_auto_cleanup(particles, 1.5)
	return particles


# ============================================================================
# MATERIAL CREATION
# ============================================================================

## Create a glowing material for orbs and projectiles
static func create_glowing_material(base_color: Color, emission_color: Color = Color(),
								   emission_energy: float = 2.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = emission_color if emission_color != Color() else base_color * 0.8
	material.emission_energy_multiplier = emission_energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## Create a freeze material overlay
static func create_freeze_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = GameConfig.COLORS.freeze
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.6
	material.emission_enabled = true
	material.emission = Color(0.3, 0.8, 1.0) * 0.5
	return material


## Create a beam material for chain lightning
static func create_beam_material(color: Color = Color(0.6, 0.3, 1.0, 0.8)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(0.5, 0.2, 1.0)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# ============================================================================
# CHAIN/BEAM VISUALS
# ============================================================================

## Create a beam effect between two points
static func create_beam(from: Vector3, to: Vector3, scene_tree: SceneTree,
					   color: Color = Color(0.6, 0.3, 1.0, 0.8),
					   thickness: float = 0.05, duration: float = 0.3) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = thickness
	cylinder.bottom_radius = thickness

	var diff := to - from
	cylinder.height = sqrt(diff.length_squared())
	beam.mesh = cylinder

	beam.material_override = create_beam_material(color)

	scene_tree.current_scene.add_child(beam)
	beam.global_position = (from + to) / 2.0
	beam.look_at(from, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2)

	# Fade out and remove
	var tween := beam.create_tween()
	tween.parallel().tween_property(beam.material_override, "albedo_color:a", 0.0, duration)
	tween.parallel().tween_property(beam.material_override, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(beam.queue_free)

	return beam


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Set up automatic cleanup for temporary particles
static func _setup_auto_cleanup(particles: GPUParticles3D, delay: float) -> void:
	# Note: This requires particles to be added to scene tree first
	# Caller should handle scene tree addition before calling this
	var cleanup_timer = Engine.get_main_loop() as SceneTree
	if cleanup_timer:
		var timer := cleanup_timer.create_timer(delay)
		timer.timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)


## Safe cleanup helper - can be called from any context
static func setup_auto_cleanup_safe(particles: GPUParticles3D, scene_tree: SceneTree, delay: float) -> void:
	if scene_tree and particles:
		var timer := scene_tree.create_timer(delay)
		timer.timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)


# ============================================================================
# DAMAGE NUMBERS
# ============================================================================

## Helper to determine damage number color based on type
static func get_damage_number_color(is_crit: bool, damage_type: String) -> Color:
	if is_crit:
		return Color(1.0, 1.0, 0.0)  # Yellow for crits

	match damage_type:
		"poison":
			return Color(0.5, 1.0, 0.3)
		"fire":
			return Color(1.0, 0.5, 0.2)
		"ice":
			return Color(0.3, 0.8, 1.0)
		"lightning":
			return Color(0.7, 0.5, 1.0)
		_:
			return Color(1.0, 0.8, 0.6)


## Scale damage number for crits
static func get_damage_number_scale(is_crit: bool) -> float:
	return 1.5 if is_crit else 1.0
