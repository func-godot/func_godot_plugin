@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Local machine map editor settings. Can define global defaults for some FuncGodot properties.
class_name FuncGodotLocalConfig

enum PROPERTY {
	FGD_OUTPUT_FOLDER,
	TRENCHBROOM_GAME_CONFIG_FOLDER,
	NETRADIANT_CUSTOM_GAMEPACKS_FOLDER,
	MAP_EDITOR_GAME_PATH,
	GAME_PATH_MODELS_FOLDER,
	DEFAULT_INVERSE_SCALE
}

const BASE_PATH: String = "func_godot/local_config/"

const CONFIG_PROPERTIES: Array[Dictionary] = [
	{
		"name": "fgd_output_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"func_godot_type": PROPERTY.FGD_OUTPUT_FOLDER
	},
	{
		"name": "trenchbroom_game_config_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"func_godot_type": PROPERTY.TRENCHBROOM_GAME_CONFIG_FOLDER
	},
	{
		"name": "netradiant_custom_gamepacks_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"func_godot_type": PROPERTY.NETRADIANT_CUSTOM_GAMEPACKS_FOLDER
	},
	{
		"name": "map_editor_game_path",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"func_godot_type": PROPERTY.MAP_EDITOR_GAME_PATH
	},
	{
		"name": "game_path_models_folder",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"func_godot_type": PROPERTY.GAME_PATH_MODELS_FOLDER
	},
	{
		"name": "default_inverse_scale_factor",
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_FLOAT,
		"func_godot_type": PROPERTY.DEFAULT_INVERSE_SCALE
	}
]

static func get_setting(name: PROPERTY) -> Variant:
	return EditorInterface.get_editor_settings().get_setting(BASE_PATH + str(name))

static func set_setting(name: PROPERTY, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_setting(BASE_PATH + str(name), value)

func _get(property: StringName) -> Variant:
	return get_setting(PROPERTY[property])

func _set(property: StringName, value: Variant) -> bool:
	set_setting(PROPERTY[property], value)
	return true

static func _get_default_value(type) -> Variant:
	match type:
		TYPE_STRING: return ''
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_BOOL: return false
		TYPE_VECTOR2: return Vector2.ZERO
		TYPE_VECTOR3: return Vector3.ZERO
		TYPE_ARRAY: return []
		TYPE_DICTIONARY: return {}
	push_error("Invalid setting type. Returning null")
	return null

static func setup_editor_settings() -> void:
	var edit_setts := EditorInterface.get_editor_settings()
	
	for prop in CONFIG_PROPERTIES:
		var path = BASE_PATH + prop["name"]
		
		if not edit_setts.has_setting(path):
			var info := {
				"name": path,
				"type": prop["type"],
				"hint": prop["hint"] if "hint" in prop else PROPERTY_HINT_NONE,
				"usage": prop["usage"],
			}
			
			edit_setts.set(path, _get_default_value(prop["type"]))
			edit_setts.add_property_info(info)

static func remove_editor_settings() -> void:
	for prop in CONFIG_PROPERTIES:
		EditorInterface.get_editor_settings().erase(BASE_PATH + prop["name"])

# Legacy compatibility

static func cleanup_legacy() -> void:
	var path = _get_path()
	if not FileAccess.file_exists(path):
		return
	
	# Set the EditorSettings based on the contents of the json file.
	var settings := FileAccess.get_file_as_string(path)
	if settings:
		var settings_dict = JSON.parse_string(settings)
		for key in settings_dict:
			set_setting(PROPERTY[key], settings_dict[key])
	
	DirAccess.remove_absolute(path)

static func _get_path() -> String:
	var application_name: String = ProjectSettings.get('application/config/name')
	application_name = application_name.replace(" ", "_")
	return 'user://' + application_name  + '_FuncGodotConfig.json'