@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Local machine map editor settings. Can define global defaults for some FuncGodot properties.
class_name FuncGodotProjectConfig

const DEFAULT_SETTINGS_PATH := "res://addons/func_godot/func_godot_default_map_settings.tres"

enum PROPERTY {
	DEFAULT_MAP_CONFIG,
}

const BASE_PATH := "func_godot/maps/"

static var CONFIG_PROPERTIES := {
	PROPERTY.DEFAULT_MAP_CONFIG: {
		"usage": PROPERTY_USAGE_EDITOR,
		"default": load(DEFAULT_SETTINGS_PATH).duplicate(),
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "FuncGodotMapSettings",
		"basic": true,
	},
}

static func get_setting(property: PROPERTY):
	return ProjectSettings.get_setting_with_override(_get_path(property))

static func set_setting(property: PROPERTY, value):
	ProjectSettings.set_setting(BASE_PATH + str(property).to_lower(), value)

static func setup_project_settings():
	for property in CONFIG_PROPERTIES.keys():
		var name := _get_path(property)
		
		if ProjectSettings.has_setting(name):
			continue
		
		var config: Dictionary = CONFIG_PROPERTIES[property]
		
		ProjectSettings.set_setting(name, config["default"])
		ProjectSettings.set_initial_value(name, config["default"])
		
		var hint := config.duplicate()
		hint["name"] = name
		ProjectSettings.add_property_info(hint)
		
		ProjectSettings.set_as_basic(name, config["basic"])

static func remove_project_settings():
	for property in CONFIG_PROPERTIES.keys():
		print("REMOVING: " + _get_path(property))
		ProjectSettings.set_setting(_get_path(property), null)

static func _get_path(property: PROPERTY) -> String:
	print("GETTING PATH: " + BASE_PATH + PROPERTY.keys()[property].to_lower())
	return BASE_PATH + PROPERTY.keys()[property].to_lower()