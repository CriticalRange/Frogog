@tool
extends EditorScript

# Run this in Godot Editor: Script > Run (Ctrl+Shift+X)
# This will print all bone names from the character model

func _run() -> void:
	print("\n=== SKELETON DEBUG ===\n")
	
	# Load the character model
	var model_scene = load("res://assets/Meshy_AI_make_a_t_pose_image_o_0103104839_texture_fbx.fbx")
	if not model_scene:
		print("ERROR: Could not load character model")
		return
	
	var model = model_scene.instantiate()
	
	# Find skeleton
	var skeleton = _find_skeleton(model)
	if skeleton:
		print("Found Skeleton: ", skeleton.name)
		print("Bone count: ", skeleton.get_bone_count())
		print("\n--- BONES ---")
		for i in range(skeleton.get_bone_count()):
			var bone_name = skeleton.get_bone_name(i)
			var parent_idx = skeleton.get_bone_parent(i)
			var parent_name = skeleton.get_bone_name(parent_idx) if parent_idx >= 0 else "ROOT"
			print("  [", i, "] ", bone_name, " (parent: ", parent_name, ")")
	else:
		print("No Skeleton3D found in model!")
		print("Node tree:")
		_print_tree(model, 0)
	
	model.queue_free()
	print("\n=== END DEBUG ===\n")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null

func _print_tree(node: Node, indent: int) -> void:
	var indent_str = "  ".repeat(indent)
	print(indent_str, node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_tree(child, indent + 1)
