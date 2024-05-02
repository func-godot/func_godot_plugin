@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Local machine project wide settings. Can define global defaults for some FuncGodot properties.
## DO NOT CREATE A NEW RESOURCE! This resource works by saving a configuration file to your game's *user://* folder and pulling the properties from that config file rather than this resource.
## Use the premade `addons/func_godot/func_godot_local_config.tres` instead.
class_name FuncGodotLocalConfig
extends Resource

enum PROPERTY {
	FGD_OUTPUT_FOLDER,
	TRENCHBROOM_GAME_CONFIG_FOLDER,
	NETRADIANT_CUSTOM_GAMEPACKS_FOLDER,
	MAP_EDITOR_GAME_PATH,
	GAME_PATH_MODELS_FOLDER,
	DEFAULT_INVERSE_SCALE
}

@export var export_func_godot_settings: bool: set = _save_settings
@export var reload_func_godot_settings: bool = false :
	set(value):
		_load_settings()

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

var settings_dict: Dictionary
var loaded := false

static func get_setting(name: PROPERTY) -> Variant:
	var settings = load("res://addons/func_godot/func_godot_local_config.tres")
	if not settings.loaded: 
		settings._load_settings()
	return settings.settings_dict.get(PROPERTY.keys()[name], '') as Variant

func _get_property_list() -> Array:
	return CONFIG_PROPERTIES.duplicate()

func _get(property: StringName) -> Variant:
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: 
		return null
	_try_loading()
	return settings_dict.get(PROPERTY.keys()[config['func_godot_type']], _get_default_value(config['type']))

func _set(property: StringName, value: Variant) -> bool:
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: 
		return false
	settings_dict[PROPERTY.keys()[config['func_godot_type']]] = value
	return true
	
func _get_default_value(type) -> Variant:
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

func _get_config_property(name: StringName) -> Variant:
	for config in CONFIG_PROPERTIES:
		if config['name'] == name: 
			return config
	return null

func _load_settings() -> void:
	loaded = true
	var path = _get_path()
	if not FileAccess.file_exists(path):
		return
	var settings = FileAccess.get_file_as_string(path)
	settings_dict = {}
	if not settings or settings.is_empty():
		return
	settings = JSON.parse_string(settings)
	for key in settings.keys():
		settings_dict[key] = settings[key]
	notify_property_list_changed()

func _try_loading() -> void:
	if not loaded: 
		_load_settings()

func _save_settings(_s = null) -> void:
	if settings_dict.size() == 0: 
		return
	var path = _get_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	var json = JSON.stringify(settings_dict)
	file.store_line(json)
	loaded = false
	print("Saved settings to ", path)

func _get_path() -> String:
	var application_name: String = ProjectSettings.get('application/config/name')
	application_name = application_name.replace(" ", "_")
	return 'user://' + application_name  + '_FuncGodotConfig.json'
