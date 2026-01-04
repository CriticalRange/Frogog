extends Node3D

## Smooth terrain generator with slopes using a single mesh

const TERRAIN_SIZE = 650  # Total size in units
const PLAYABLE_AREA = 600  # Playable area size (guardrails at this boundary)
const FAKE_AREA_OFFSET = 25  # Fake area beyond playable area
const SEGMENTS = 250  # Number of segments for smoothness (increased for larger map)

# Boundary system
var _boundary_walls: Array[StaticBody3D] = []

# Terrain type colors (for vertex coloring)
enum Biome {
	GRASS,
	DIRT,
	STONE,
	SAND,
	SNOW,
	DARK_GRASS,
	MOSS
}

const BIOME_COLORS = {
	Biome.GRASS: Color(0.2, 0.8, 0.15),       # Super vibrant green
	Biome.DIRT: Color(0.3, 0.5, 0.2),         # Greenish dirt
	Biome.STONE: Color(0.25, 0.4, 0.25),      # Dark green stone
	Biome.SAND: Color(0.5, 0.65, 0.25),       # Green-ish sand
	Biome.SNOW: Color(0.6, 0.85, 0.7),        # Minty snow
	Biome.DARK_GRASS: Color(0.1, 0.5, 0.05),  # Deep jungle green
	Biome.MOSS: Color(0.3, 0.7, 0.2)          # Bright moss
}

# Noise for terrain generation
var noise_continental: FastNoiseLite
var noise_terrain: FastNoiseLite
var noise_detail: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_temperature: FastNoiseLite

var terrain_mesh: MeshInstance3D
var collision_shape: CollisionShape3D

var player_spawn_height = 0.0

# Batch spawning for vegetation
var _vegetation_batch_data: Array = []  # Pre-calculated vegetation data
var _vegetation_batch_index: int = 0
const VEGETATION_PER_FRAME: int = 20  # Spawn this many per frame

func _ready():
	add_to_group("terrain")
	randomize()
	setup_noise()
	generate_terrain_mesh()
	_create_boundary_walls()  # Add guardrails
	add_vegetation()
	spawn_interactables()

func setup_noise():
	# Continental noise - large scale landmasses
	noise_continental = FastNoiseLite.new()
	noise_continental.seed = randi()
	noise_continental.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_continental.frequency = 0.008
	noise_continental.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_continental.fractal_octaves = 3
	noise_continental.fractal_gain = 0.5
	noise_continental.fractal_lacunarity = 2.0

	# Main terrain noise
	noise_terrain = FastNoiseLite.new()
	noise_terrain.seed = randi() + 1
	noise_terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_terrain.frequency = 0.02
	noise_terrain.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_terrain.fractal_octaves = 3
	noise_terrain.fractal_gain = 0.5
	noise_terrain.fractal_lacunarity = 2.0

	# Detail noise
	noise_detail = FastNoiseLite.new()
	noise_detail.seed = randi() + 2
	noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_detail.frequency = 0.06
	noise_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_detail.fractal_octaves = 2
	noise_detail.fractal_gain = 0.4
	noise_detail.fractal_lacunarity = 2.0

	# Moisture noise
	noise_moisture = FastNoiseLite.new()
	noise_moisture.seed = randi() + 4
	noise_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_moisture.frequency = 0.012
	noise_moisture.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_moisture.fractal_octaves = 2
	noise_moisture.fractal_gain = 0.5
	noise_moisture.fractal_lacunarity = 2.0

	# Temperature noise
	noise_temperature = FastNoiseLite.new()
	noise_temperature.seed = randi() + 5
	noise_temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_temperature.frequency = 0.01
	noise_temperature.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_temperature.fractal_octaves = 2
	noise_temperature.fractal_gain = 0.5
	noise_temperature.fractal_lacunarity = 2.0
	noise_temperature.offset = Vector3(1000, 1000, 1000)

func get_terrain_height(x: float, z: float) -> float:
	# Flat terrain - no slopes
	return 0.0

func get_biome(x: float, z: float, height: float, moisture: float, temperature: float) -> Biome:
	if height > 6:
		return Biome.SNOW
	elif height > 4:
		if temperature < -0.2:
			return Biome.SNOW
		return Biome.STONE
	elif height < -1:
		return Biome.SAND

	if moisture > 0.5:
		if temperature > 0.3:
			return Biome.DARK_GRASS
		return Biome.MOSS
	elif moisture < -0.3:
		return Biome.DIRT
	else:
		if temperature < -0.4:
			return Biome.DIRT
		return Biome.GRASS

func generate_terrain_mesh():
	print("Generating smooth terrain...")

	# Grid settings
	var grid_size := SEGMENTS + 1
	var step := TERRAIN_SIZE / float(SEGMENTS)
	var half_size := TERRAIN_SIZE / 2.0

	# Use SurfaceTool for proper vertex color support
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Create a material with vertex colors enabled
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	st.set_material(material)

	# Build vertex grid with triangles
	for z in range(SEGMENTS):
		for x in range(SEGMENTS):
			var i = z * grid_size + x

			# Get positions and heights for the quad
			var vx1 := x * step - half_size
			var vz1 := z * step - half_size
			var h1 := get_terrain_height(vx1, vz1)

			var vx2 := (x + 1) * step - half_size
			var vz2 := z * step - half_size
			var h2 := get_terrain_height(vx2, vz2)

			var vx3 := x * step - half_size
			var vz3 := (z + 1) * step - half_size
			var h3 := get_terrain_height(vx3, vz3)

			var vx4 := (x + 1) * step - half_size
			var vz4 := (z + 1) * step - half_size
			var h4 := get_terrain_height(vx4, vz4)

			# Get colors for each vertex
			var c1 := _get_biome_color(get_biome(vx1, vz1, h1, noise_moisture.get_noise_2d(vx1, vz1), noise_temperature.get_noise_2d(vx1, vz1)))
			var c2 := _get_biome_color(get_biome(vx2, vz2, h2, noise_moisture.get_noise_2d(vx2, vz2), noise_temperature.get_noise_2d(vx2, vz2)))
			var c3 := _get_biome_color(get_biome(vx3, vz3, h3, noise_moisture.get_noise_2d(vx3, vz3), noise_temperature.get_noise_2d(vx3, vz3)))
			var c4 := _get_biome_color(get_biome(vx4, vz4, h4, noise_moisture.get_noise_2d(vx4, vz4), noise_temperature.get_noise_2d(vx4, vz4)))

			# First triangle (v1, v2, v3)
			_add_vertex(st, vx1, h1, vz1, c1)
			_add_vertex(st, vx2, h2, vz2, c2)
			_add_vertex(st, vx3, h3, vz3, c3)

			# Second triangle (v2, v4, v3)
			_add_vertex(st, vx2, h2, vz2, c2)
			_add_vertex(st, vx4, h4, vz4, c4)
			_add_vertex(st, vx3, h3, vz3, c3)

	# Generate normals
	st.generate_normals()

	# Create the mesh
	var final_mesh := st.commit()

	# Ensure material is applied
	final_mesh.surface_set_material(0, material)

	# Create mesh instance
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = final_mesh
	add_child(terrain_mesh)

	# Create collision shape
	create_terrain_collision()

	# Set player spawn height (flat terrain)
	player_spawn_height = 0.0

	print("Terrain generated!")

func _add_vertex(st: SurfaceTool, x: float, y: float, z: float, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(Vector3(x, y, z))

func _get_biome_color(biome: Biome) -> Color:
	var base_color = BIOME_COLORS.get(biome, BIOME_COLORS[Biome.GRASS])
	var variation = randf() * 0.08 - 0.04
	return Color(
		clampf(base_color.r + variation, 0, 1),
		clampf(base_color.g + variation, 0, 1),
		clampf(base_color.b + variation, 0, 1)
	)

func create_terrain_collision():
	# Create a static body for collision
	var static_body = StaticBody3D.new()
	static_body.name = "TerrainCollision"
	add_child(static_body)

	# Create collision shape
	collision_shape = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()

	# Get mesh data for collision
	var mesh = terrain_mesh.mesh
	if mesh is ArrayMesh and mesh.get_surface_count() > 0:
		# Extract faces from the mesh for collision
		var surface_arrays = mesh.surface_get_arrays(0)
		var vertices = surface_arrays[Mesh.ARRAY_VERTEX]

		# Build faces array (triangles as vertex triplets)
		var faces = PackedVector3Array()

		# Check if we have indices
		if Mesh.ARRAY_INDEX < surface_arrays.size():
			var indices = surface_arrays[Mesh.ARRAY_INDEX]
			if indices and indices.size() > 0:
				# Indexed mesh - use indices to build faces
				for i in range(0, indices.size(), 3):
					faces.append(vertices[indices[i]])
					faces.append(vertices[indices[i + 1]])
					faces.append(vertices[indices[i + 2]])
			else:
				# Non-indexed mesh - vertices are already in triangle order
				faces = vertices
		else:
			# Non-indexed mesh - vertices are already in triangle order
			faces = vertices

		shape.set_faces(faces)

	collision_shape.shape = shape
	static_body.add_child(collision_shape)

func get_height_at(world_x: float, world_z: float) -> float:
	# Flat terrain - always return 0
	return 0.0

func add_vegetation():
	print("Generating vegetation data...")

	# Pre-generate all vegetation data (fast - just math)
	_vegetation_batch_data.clear()

	# Simple grass patches
	for i in range(150):
		var x = randf_range(-TERRAIN_SIZE / 2.0 + 5, TERRAIN_SIZE / 2.0 - 5)
		var z = randf_range(-TERRAIN_SIZE / 2.0 + 5, TERRAIN_SIZE / 2.0 - 5)

		var height = get_terrain_height(x, z)
		var moisture = noise_moisture.get_noise_2d(x, z)
		var temperature = noise_temperature.get_noise_2d(x, z)
		var biome = get_biome(x, z, height, moisture, temperature)

		if (biome == Biome.GRASS or biome == Biome.DARK_GRASS) and height > -0.5:
			_vegetation_batch_data.append({
				type = "grass",
				x = x,
				z = z,
				height = height,
				rot_x = randf() * 0.3,
				rot_z = randf() * 0.3,
				blade_height = 0.25 + randf() * 0.15,
				green = 0.4 + randf() * 0.15 - (0.1 if biome == Biome.DARK_GRASS else 0.0)
			})

	# Trees - lots of them for lush forest feel
	var tree_count = 400
	for i in range(tree_count):
		var x = randf_range(-TERRAIN_SIZE / 2.0 + 10, TERRAIN_SIZE / 2.0 - 10)
		var z = randf_range(-TERRAIN_SIZE / 2.0 + 10, TERRAIN_SIZE / 2.0 - 10)

		var height = get_terrain_height(x, z)
		var dist = sqrt(x*x + z*z)

		# Keep trees away from spawn area
		if dist > 15:
			var moisture = noise_moisture.get_noise_2d(x, z)
			var biome = get_biome(x, z, height, moisture, 0)
			# Trees grow on grass and dark grass
			if biome == Biome.GRASS or biome == Biome.DARK_GRASS or biome == Biome.MOSS:
				var rng = randf()
				_vegetation_batch_data.append({
					type = "tree",
					x = x,
					z = z,
					height = height,
					rng = rng,
					trunk_height = 2.5 + rng * 2.0,
					trunk_radius = 0.15 + rng * 0.15,
					canopy_size = 1.5 + rng * 1.5
				})

	# Rocks
	for i in range(40):
		var x = randf_range(-TERRAIN_SIZE / 2.0 + 5, TERRAIN_SIZE / 2.0 - 5)
		var z = randf_range(-TERRAIN_SIZE / 2.0 + 5, TERRAIN_SIZE / 2.0 - 5)

		var height = get_terrain_height(x, z)
		var dist = sqrt(x*x + z*z)

		if dist > 10 and height > 0:
			var size = 0.25 + randf() * 0.3
			_vegetation_batch_data.append({
				type = "rock",
				x = x,
				z = z,
				height = height,
				size = size,
				rot_x = randf() * 0.5,
				rot_y = randf() * TAU,
				rot_z = randf() * 0.5,
				color = Color(0.45 + randf() * 0.1, 0.45 + randf() * 0.1, 0.5 + randf() * 0.05)
			})

	print("Vegetation data generated: ", _vegetation_batch_data.size(), " items to spawn")

	# Start batch spawning
	_vegetation_batch_index = 0
	_spawn_vegetation_batch()

# Spawn a batch of vegetation per frame
func _spawn_vegetation_batch() -> void:
	var end_index = mini(_vegetation_batch_index + VEGETATION_PER_FRAME, _vegetation_batch_data.size())

	while _vegetation_batch_index < end_index:
		var data = _vegetation_batch_data[_vegetation_batch_index]

		match data.type:
			"grass":
				var grass = MeshInstance3D.new()
				var blade = BoxMesh.new()
				blade.size = Vector3(0.08, data.blade_height, 0.08)
				grass.mesh = blade

				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.1, data.green, 0.1)
				grass.set_surface_override_material(0, mat)

				grass.position = Vector3(data.x, data.height + 0.125, data.z)
				grass.rotation.x = data.rot_x
				grass.rotation.z = data.rot_z
				add_child(grass)

			"tree":
				_spawn_tree_from_data(data)

			"rock":
				var rock = MeshInstance3D.new()
				var rock_mesh = SphereMesh.new()
				rock_mesh.radius = data.size
				rock_mesh.height = data.size * 0.7
				rock.mesh = rock_mesh

				var mat = StandardMaterial3D.new()
				mat.albedo_color = data.color
				mat.roughness = 0.85
				rock.set_surface_override_material(0, mat)

				rock.position = Vector3(data.x, data.height + data.size * 0.3, data.z)
				rock.scale = Vector3(1, 0.6, 1)
				rock.rotation = Vector3(data.rot_x, data.rot_y, data.rot_z)
				add_child(rock)

		_vegetation_batch_index += 1

	# Continue spawning if there's more
	if _vegetation_batch_index < _vegetation_batch_data.size():
		call_deferred("_spawn_vegetation_batch")
	else:
		print("Vegetation spawning complete!")

# Spawn tree from pre-calculated data
func _spawn_tree_from_data(data: Dictionary) -> void:
	# Create tree as StaticBody3D for collision
	var tree = StaticBody3D.new()
	tree.position = Vector3(data.x, data.height, data.z)
	tree.collision_layer = 2  # Environment layer
	tree.collision_mask = 0

	# Trunk
	var trunk_mesh_instance = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = data.trunk_radius
	trunk_mesh.bottom_radius = data.trunk_radius * 1.2
	trunk_mesh.height = data.trunk_height
	trunk_mesh_instance.mesh = trunk_mesh

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.15)  # Brown trunk
	trunk_mesh_instance.set_surface_override_material(0, trunk_mat)
	tree.add_child(trunk_mesh_instance)

	# Position trunk at half height
	trunk_mesh_instance.position = Vector3(0, data.trunk_height / 2.0, 0)

	# Foliage layers (cone shapes for pine tree look)
	var foliage_count = 4
	var foliage_spacing = data.trunk_height / foliage_count

	for i in range(foliage_count):
		var foliage = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		var layer_size = data.canopy_size * (1.0 - float(i) * 0.15)
		cone.top_radius = 0
		cone.bottom_radius = layer_size
		cone.height = layer_size * 1.5
		foliage.mesh = cone

		var foliage_mat = StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(0.1, 0.5 + randf() * 0.1, 0.15)
		foliage.set_surface_override_material(0, foliage_mat)

		var foliage_y = (i + 1) * foliage_spacing
		foliage.position = Vector3(0, foliage_y, 0)
		tree.add_child(foliage)

	# SINGLE collision shape for the whole tree (huge optimization!)
	var tree_col = CollisionShape3D.new()
	var tree_shape = CylinderShape3D.new()
	tree_shape.radius = data.canopy_size * 0.4
	tree_shape.height = data.trunk_height + data.canopy_size
	tree_col.shape = tree_shape
	tree_col.position = Vector3(0, (data.trunk_height + data.canopy_size) / 2.0 - data.canopy_size * 0.3, 0)
	tree.add_child(tree_col)

	add_child(tree)

func spawn_interactables():
	print("Spawning interactables...")

	# Preload interactable scenes
	var reward_statue_scene = preload("res://scenes/reward_statue.tscn")
	var difficulty_tomb_scene = preload("res://scenes/difficulty_tomb.tscn")
	var smuggler_scene = preload("res://scenes/smuggler.tscn")
	var time_freeze_obelisk_scene = preload("res://scenes/time_freeze_obelisk.tscn")
	var ancient_armory_scene = preload("res://scenes/ancient_armory.tscn")

	# Spawn 2-5 reward statues
	var statue_count = randi_range(2, 6)
	for i in range(statue_count):
		var x = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var z = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var dist_from_center = sqrt(x*x + z*z)

		# Keep away from spawn area
		if dist_from_center > 15:
			var height = get_terrain_height(x, z)
			var statue = reward_statue_scene.instantiate()
			statue.position = Vector3(x, height + 0.3, z)
			_spawn_interactableDeferred(statue)

	# Spawn 2-3 difficulty tombs
	var tomb_count = randi_range(2, 4)
	for i in range(tomb_count):
		var tomb_x = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var tomb_z = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var tomb_dist = sqrt(tomb_x*tomb_x + tomb_z*tomb_z)

		if tomb_dist > 20:
			var tomb_height = get_terrain_height(tomb_x, tomb_z)
			var tomb = difficulty_tomb_scene.instantiate()
			tomb.position = Vector3(tomb_x, tomb_height + 0.3, tomb_z)
			_spawn_interactableDeferred(tomb)

	# Spawn 3-6 smugglers
	var smuggler_count = randi_range(3, 7)
	for i in range(smuggler_count):
		var sx = randf_range(-PLAYABLE_AREA / 2.5, PLAYABLE_AREA / 2.5)
		var sz = randf_range(-PLAYABLE_AREA / 2.5, PLAYABLE_AREA / 2.5)
		var sdist = sqrt(sx*sx + sz*sz)

		if sdist > 18:
			var sheight = get_terrain_height(sx, sz)
			var smuggler = smuggler_scene.instantiate()
			smuggler.position = Vector3(sx, sheight + 0.3, sz)
			# Random rotation for variety
			smuggler.rotation.y = randf() * TAU
			_spawn_interactableDeferred(smuggler)

	# Spawn 2 Time Freeze Obelisks
	for i in range(2):
		var obelisk_x = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var obelisk_z = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var obelisk_dist = sqrt(obelisk_x*obelisk_x + obelisk_z*obelisk_z)

		if obelisk_dist > 25:
			var obelisk_height = get_terrain_height(obelisk_x, obelisk_z)
			var obelisk = time_freeze_obelisk_scene.instantiate()
			obelisk.position = Vector3(obelisk_x, obelisk_height + 0.3, obelisk_z)
			_spawn_interactableDeferred(obelisk)

	# Spawn 1-2 Ancient Armories (always at least 1)
	var armory_count = randi_range(1, 3)
	for i in range(armory_count):
		var armory_x = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var armory_z = randf_range(-TERRAIN_SIZE / 2.5, TERRAIN_SIZE / 2.5)
		var armory_dist = sqrt(armory_x*armory_x + armory_z*armory_z)

		if armory_dist > 30:
			var armory_height = get_terrain_height(armory_x, armory_z)
			var armory = ancient_armory_scene.instantiate()
			armory.position = Vector3(armory_x, armory_height + 0.3, armory_z)
			_spawn_interactableDeferred(armory)

	print("Interactables spawned!")

func _spawn_interactableDeferred(interactable: Node3D) -> void:
	get_tree().current_scene.call_deferred("add_child", interactable)

# ============ BOUNDARY SYSTEM ============

func _create_boundary_walls() -> void:
	# Create invisible guardrails at the playable area boundary
	# These prevent player from leaving the playable area
	# The fake area (between PLAYABLE_AREA and TERRAIN_SIZE) creates the illusion
	# of a larger world while actually bounding the player

	var half_playable := PLAYABLE_AREA / 2.0
	var wall_height := 20.0  # Tall enough to prevent jumping over
	var wall_thickness := 5.0

	# Create 4 walls: North, South, East, West
	var walls_data := [
		# Position (x, y, z), Size (x, z)
		[Vector3(0, 0, -half_playable - wall_thickness/2), Vector2(PLAYABLE_AREA + wall_thickness * 2, wall_thickness)],      # North
		[Vector3(0, 0, half_playable + wall_thickness/2), Vector2(PLAYABLE_AREA + wall_thickness * 2, wall_thickness)],       # South
		[Vector3(-half_playable - wall_thickness/2, 0, 0), Vector2(wall_thickness, PLAYABLE_AREA + wall_thickness * 2)],     # West
		[Vector3(half_playable + wall_thickness/2, 0, 0), Vector2(wall_thickness, PLAYABLE_AREA + wall_thickness * 2)],      # East
	]

	for wall_data in walls_data:
		var wall := _create_guardrail_wall(wall_data[0], wall_data[1], wall_height)
		add_child(wall)
		_boundary_walls.append(wall)

	# Create fake exterior visual barrier
	# This is a visual barrier at the terrain edge that looks like
	# impassable terrain (cliffs, dense fog, etc.)
	_create_fake_exterior_barrier()

func _create_guardrail_wall(position: Vector3, size: Vector2, height: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = position

	# Create collision shape
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size.x, height, size.y)
	collision.shape = box_shape
	# Lower the collision so its top is at ground level
	collision.position.y = height / 2.0
	wall.add_child(collision)

	# Create visual barrier (semi-transparent, darker to indicate impassable)
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(size.x, height, size.y)
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = height / 2.0

	# Dark, ominous material to indicate boundary
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.1, 0.15, 0.7)  # Dark blue-black, semi-transparent
	material.emission_enabled = true
	material.emission = Color(0.2, 0.3, 0.5, 0.3)  # Slight blue glow
	material.emission_energy_multiplier = 0.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	material.no_depth_test = true  # Always visible
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.add_child(mesh_instance)

	# Add to collision layer for detection
	wall.collision_layer = 16  # Boundary layer
	wall.collision_mask = 0

	return wall

func _create_fake_exterior_barrier() -> void:
	# Create a visual ring at the terrain edge
	# This gives the impression of a cliff edge or impassable barrier

	var half_terrain := TERRAIN_SIZE / 2.0
	var half_playable := PLAYABLE_AREA / 2.0
	var barrier_width := (TERRAIN_SIZE - PLAYABLE_AREA) / 2.0

	# Create barrier meshes along the edges
	var barrier_positions := []
	var markers_per_edge := 40  # Increased for larger map

	# North edge
	for i in range(markers_per_edge):
		var t := i / float(markers_per_edge - 1)
		var x := lerpf(-half_terrain, half_terrain, t)
		var z := -half_playable - barrier_width / 2
		barrier_positions.append(Vector3(x, 0, z))

	# South edge
	for i in range(markers_per_edge):
		var t := i / float(markers_per_edge - 1)
		var x := lerpf(-half_terrain, half_terrain, t)
		var z := half_playable + barrier_width / 2
		barrier_positions.append(Vector3(x, 0, z))

	# West edge
	for i in range(markers_per_edge):
		var t := i / float(markers_per_edge - 1)
		var x := -half_playable - barrier_width / 2
		var z := lerpf(-half_terrain, half_terrain, t)
		barrier_positions.append(Vector3(x, 0, z))

	# East edge
	for i in range(markers_per_edge):
		var t := i / float(markers_per_edge - 1)
		var x := half_playable + barrier_width / 2
		var z := lerpf(-half_terrain, half_terrain, t)
		barrier_positions.append(Vector3(x, 0, z))

	# Create visual markers at each position
	for pos in barrier_positions:
		_create_boundary_marker(pos)

func _create_boundary_marker(position: Vector3) -> void:
	# Create a tall, ominous pillar/obelisk at the boundary
	var marker := MeshInstance3D.new()

	# Pillar shape
	var pillar := CylinderMesh.new()
	pillar.top_radius = 1.5
	pillar.bottom_radius = 2.0
	pillar.height = 15.0
	pillar.radial_segments = 6  # Hexagonal for ancient look
	marker.mesh = pillar
	marker.position = Vector3(position.x, 7.5, position.z)  # Half height

	# Ancient stone material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.35, 0.8)
	material.roughness = 0.9
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color(0.1, 0.15, 0.2, 0.3)
	material.emission_energy_multiplier = 0.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Add subtle glow
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 5, 0)
	glow.light_color = Color(0.3, 0.4, 0.6, 1.0)
	glow.light_energy = 2.0
	glow.omni_range = 15.0
	glow.shadow_enabled = false
	marker.add_child(glow)

	add_child(marker)

# Get the playable area bounds (for other systems to query)
static func get_playable_area_bounds() -> Dictionary:
	return {
		"size": 600,  # PLAYABLE_AREA
		"half_size": 300.0,
		"min_x": -300.0,
		"max_x": 300.0,
		"min_z": -300.0,
		"max_z": 300.0
	}
