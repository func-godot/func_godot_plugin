@tool
class_name MapSceneImportPlugin
extends EditorSceneFormatImporter

const _SIGNATURE: String = "[MAP]"

func _get_extensions( ) -> PackedStringArray:
	return PackedStringArray(['map'])

func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var root_type: StringName = options.get("nodes/root_node", "Node3D")
	if not root_type:
		root_type = "Node3D"
	var scene = ClassDB.instantiate(root_type)
	var root_script:Script = options.get("nodes/root_script")
	if root_script:
		scene.set_script(root_script)
	
	FuncGodotMapLoader.load_map(path, {
		"map_settings": options["func_godot/map_settings"],
		"build_flags": options["func_godot/build_flags"],
		"hyperplane_size": options["func_godot/hyperplane_size"]
	}, scene)
	
	scene.name = path.get_file().get_basename().to_pascal_case()
	
	return scene
