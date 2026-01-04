extends Node
class_name ObjectPool

var objects = []
var scene = null
var script_class = null
var pool_size = 0
var parent_node = null

func _ready():
	_init_pool()

func _init_pool():
	for i in range(pool_size):
		var obj = null
		if scene != null:
			obj = scene.instantiate()
		elif script_class != null:
			obj = script_class.new()
		else:
			return
		obj.set_physics_process(false)
		obj.set_process(false)
		obj.visible = false
		parent_node.add_child(obj)
		objects.append(obj)

func get_object():
	# Clean up freed objects from the pool
	var i = 0
	while i < objects.size():
		if not is_instance_valid(objects[i]):
			objects.remove_at(i)
		else:
			i += 1

	# Find an inactive object
	for obj in objects:
		if is_instance_valid(obj) and not obj.visible:
			obj.visible = true
			obj.set_physics_process(true)
			obj.set_process(true)
			return obj

	# Pool exhausted, create new
	var obj = null
	if scene != null:
		obj = scene.instantiate()
	elif script_class != null:
		obj = script_class.new()
	else:
		return null
	parent_node.add_child(obj)
	objects.append(obj)
	return obj

func return_object(obj):
	obj.visible = false
	obj.set_physics_process(false)
	obj.set_process(false)

static var pool_dict = {}

static func get_pool(p_scene, p_size, p_parent):
	var path = p_scene.resource_path
	if not pool_dict.has(path):
		var p = ObjectPool.new()
		p.scene = p_scene
		p.pool_size = p_size
		p.parent_node = p_parent
		pool_dict[path] = p
		p_parent.add_child(p)
	return pool_dict[path]

static func get_pool_for_script(p_class, p_size, p_parent):
	var name = p_class.get_global_name()
	if name == "":
		name = str(p_class.get_instance_id())
	if not pool_dict.has(name):
		var p = ObjectPool.new()
		p.script_class = p_class
		p.pool_size = p_size
		p.parent_node = p_parent
		pool_dict[name] = p
		p_parent.add_child(p)
	return pool_dict[name]
