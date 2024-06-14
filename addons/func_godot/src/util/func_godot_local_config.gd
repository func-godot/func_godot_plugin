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

const CONFIG_PROPERTIES: Dictionary = {
	PROPERTY.FGD_OUTPUT_FOLDER: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"default": "",
	},
	PROPERTY.TRENCHBROOM_GAME_CONFIG_FOLDER: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"default": "",
	},
	PROPERTY.NETRADIANT_CUSTOM_GAMEPACKS_FOLDER: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"default": "",
	},
	PROPERTY.MAP_EDITOR_GAME_PATH: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"default": "",
	},
	PROPERTY.GAME_PATH_MODELS_FOLDER: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
		"default": "",
	},
	PROPERTY.DEFAULT_INVERSE_SCALE: {
		"usage": PROPERTY_USAGE_EDITOR,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "8.0,64,8.0",
		"default": 32,
	},
}

static func get_setting(property: PROPERTY) -> Variant:
	return EditorInterface.get_editor_settings().get_setting(_get_path(property))

static func set_setting(property: PROPERTY, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_setting(_get_path(property), value)

func _get(property: StringName) -> Variant:
	return get_setting(PROPERTY[property])

func _set(property: StringName, value: Variant) -> bool:
	set_setting(PROPERTY[property], value)
	return true

static func setup_editor_settings() -> void:
	var edit_setts := EditorInterface.get_editor_settings()
	
	for key in CONFIG_PROPERTIES:
		var prop = CONFIG_PROPERTIES[key]
		var path = _get_path(key)
		
		if not edit_setts.has_setting(path):
			var info = prop.duplicate()
			info["name"] = path
			
			edit_setts.set(path, prop["default"])
			edit_setts.add_property_info(info)

static func remove_editor_settings() -> void:
	for prop in CONFIG_PROPERTIES:
		EditorInterface.get_editor_settings().erase(_get_path(prop))

static func _get_path(property: PROPERTY) -> String:
	return BASE_PATH + PROPERTY.keys()[property].to_lower()

# Legacy compatibility

static func cleanup_legacy() -> void:
	var path = _get_legacy_path()
	if not FileAccess.file_exists(path):
		return
	
	# Set the EditorSettings based on the contents of the json file.
	var settings := FileAccess.get_file_as_string(path)
	if settings:
		var settings_dict = JSON.parse_string(settings)
		for key in settings_dict:
			set_setting(PROPERTY[key], settings_dict[key])
	
	DirAccess.remove_absolute(path)

static func _get_legacy_path() -> String:
	var application_name: String = ProjectSettings.get('application/config/name')
	application_name = application_name.replace(" ", "_")
	return 'user://' + application_name  + '_FuncGodotConfig.json'