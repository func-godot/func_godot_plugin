@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotLocalConfig extends Resource
## Local machine project wide settings. [color=red]WARNING![/color] Do not create your own! Use the resource in [i]addons/func_godot[/i].
## 
## Local machine project wide settings. Can define global defaults for some FuncGodot properties.
## [color=red][b]DO NOT CREATE A NEW RESOURCE![/b][/color] This resource works by saving a configuration file to your game's [b][i]user://[/i][/b] folder 
## and pulling the properties from that config file rather than this resource. Use the premade [b][i]addons/func_godot/func_godot_local_config.tres[/i][/b] instead.
## [br][br]
## [b]Fgd Output Folder :[/b] Global directory path that [FuncGodotFGDFile] saves to when exported. Overridden when exported from a game configuration resource like [TrenchBroomGameConfig].[br][br]
## [b]Trenchbroom Game Config Folder :[/b] Global directory path where your TrenchBroom game configuration should be saved to. Consult the [url="https://trenchbroom.github.io/manual/latest/#game_configuration_files"]TrenchBroom Manual's Game Configuration documentation[/url] for more information.[br][br]
## [b]Netradiant Custom Gamepacks Folder :[/b] Global directory path where your NetRadiant Custom gamepacks are saved. On Windows this is the [i]gamepacks[/i] folder in your NetRadiant Custom installation.[br][br]
## [b]Map Editor Game Path :[/b] Global directory path to your mapping folder where all of your mapping assets exist. This is usually either your project folder or a subfolder within it.[br][br]
## [b]Game Path Models Folder :[/b] Relative directory path from your Map Editor Game Path to a subfolder containing any display models you might use for your map editor. Currently only used by [FuncGodotFGDModelPointClass].[br][br]
## [b]Default Inverse Scale Factor :[/b] Scale factor that affects how [FuncGodotFGDModelPointClass] entities scale their map editor display models. Not used with TrenchBroom, use [member TrenchBroomGameConfig.entity_scale] expression instead.[br][br]

enum PROPERTY {
	FGD_OUTPUT_FOLDER,
	TRENCHBROOM_GAME_CONFIG_FOLDER,
	NETRADIANT_CUSTOM_GAMEPACKS_FOLDER,
	MAP_EDITOR_GAME_PATH,
	#GAME_PATH_MODELS_FOLDER,
	#DEFAULT_INVERSE_SCALE
}

@export_tool_button("Export func_godot settings", "Save") var _save_settings = export_func_godot_settings
@export_tool_button("Reload func_godot settings", "Reload") var _load_settings = reload_func_godot_settings

const _CONFIG_PROPERTIES: Array[Dictionary] = [
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
	#{
		#"name": "game_path_models_folder",
		#"usage": PROPERTY_USAGE_EDITOR,
		#"type": TYPE_STRING,
		#"func_godot_type": PROPERTY.GAME_PATH_MODELS_FOLDER
	#},
	#{
		#"name": "default_inverse_scale_factor",
		#"usage": PROPERTY_USAGE_EDITOR,
		#"type": TYPE_FLOAT,
		#"func_godot_type": PROPERTY.DEFAULT_INVERSE_SCALE
	#}
]

var _settings_dict: Dictionary
var _loaded := false

## Retrieve a setting from the local configuration.
static func get_setting(name: PROPERTY) -> Variant:
	var settings: FuncGodotLocalConfig = load("res://addons/func_godot/func_godot_local_config.tres")
	settings.reload_func_godot_settings()
	return settings._settings_dict.get(PROPERTY.keys()[name], '') as Variant

func _get_property_list() -> Array:
	return _CONFIG_PROPERTIES.duplicate()

func _get(property: StringName) -> Variant:
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: 
		return null
	_try_loading()
	return _settings_dict.get(PROPERTY.keys()[config['func_godot_type']], _get_default_value(config['type']))

func _set(property: StringName, value: Variant) -> bool:
	var config = _get_config_property(property)
	if config == null and not config is Dictionary: 
		return false
	_settings_dict[PROPERTY.keys()[config['func_godot_type']]] = value
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
	for config in _CONFIG_PROPERTIES:
		if config['name'] == name: 
			return config
	return null

## Reload this system's configuration settings into the Local Config resource.
func reload_func_godot_settings() -> void:
	_loaded = true
	var path = _get_path()
	if not FileAccess.file_exists(path):
		return
	var settings = FileAccess.get_file_as_string(path)
	_settings_dict = {}
	if not settings or settings.is_empty():
		return
	settings = JSON.parse_string(settings)
	for key in settings.keys():
		_settings_dict[key] = settings[key]
	notify_property_list_changed()

func _try_loading() -> void:
	if not _loaded:
		reload_func_godot_settings()

## Export the current resource settings to a configuration file in this game's [i]user://[/i] folder.
func export_func_godot_settings() -> void:
	if _settings_dict.size() == 0: 
		return
	var path = _get_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	var json = JSON.stringify(_settings_dict)
	file.store_line(json)
	_loaded = false
	print("Saved settings to ", path)

func _get_path() -> String:
	var application_name: String = ProjectSettings.get('application/config/name')
	application_name = application_name.replace(" ", "_")
	return 'user://' + application_name  + '_FuncGodotConfig.json'
