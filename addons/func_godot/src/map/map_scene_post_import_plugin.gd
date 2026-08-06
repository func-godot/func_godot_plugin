@tool
class_name MapScenePostImportPlugin
extends EditorScenePostImportPlugin

func _get_import_options(path: String) -> void:
	if !path.ends_with(".map"):
		return
		
	var default_map_settings = load(ProjectSettings.get_setting("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres"))

	add_import_option_advanced(TYPE_OBJECT, "func_godot/map_settings", default_map_settings, PROPERTY_HINT_RESOURCE_TYPE, "FuncGodotMapSettings")
	#@export_flags("Unwrap UV2:1", "Show Profiling Info:2", "Disable Smooth Shading:4") var build_flags: int = 0
	add_import_option_advanced(TYPE_INT, "func_godot/build_flags", 0, PROPERTY_HINT_FLAGS, "Unwrap UV2,Show Profiling Info,Disable Smooth Shading");
	## The hyperplane is an initial plane that all geometry faces are cut from, like a large sheet of marble before a sculptor begins chiseling. 
	## The hyperplane size would need to be able to cover your map's potential total area.
	## Smaller values can minimize floating point errors, reducing the effect of gaps between polygon seams.
	## Measured in Godot units, not Quake units.
	add_import_option_advanced(TYPE_FLOAT, "func_godot/hyperplane_size", 512.0, PROPERTY_HINT_RANGE, "256.0,2048.0")
	
