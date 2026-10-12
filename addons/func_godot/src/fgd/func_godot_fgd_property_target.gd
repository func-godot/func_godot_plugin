@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDPropertyTarget extends FuncGodotFGDProperty
## FGD Entity class property definition for target_source and target_destination property types.
##
## FGD Entity class property definition used to generate a target_source or target_destination property for FGD export.

enum FGDTargetType {
	TARGET_SOURCE,
	TARGET_DESTINATION,
}
## The property type exported to the FGD.
@export var fgd_target_type: FGDTargetType = FGDTargetType.TARGET_SOURCE

func build_fgd_text(property_name: String, target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	var s: String = "\t" + property_name + "("
	match fgd_target_type:
		FGDTargetType.TARGET_SOURCE: s += "target_source"
		FGDTargetType.TARGET_DESTINATION: s += "target_destination"
		_: s += "string"
	s += ")"
	if description:
		s += " : \"" + description + "\""
	if default_value:
		if description.is_empty():
			s += "\"\" : "
		match typeof(default_value):
			TYPE_STRING: s += " : \"" + default_value + "\""
			TYPE_STRING_NAME, TYPE_NODE_PATH: s += " : \"" + String(default_value) + "\""
			_:
				push_error("ERROR: FGD Target Property given incorrect default value type! Should be String, StringName, or NodePath.")
				return "\t// " + property_name + "(target) was incorrectly set up: invalid default value type. Should be String, StringName, or NodePath."
	return s

func get_default_value() -> Variant:
	match typeof(default_value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH: return default_value
	return ""
