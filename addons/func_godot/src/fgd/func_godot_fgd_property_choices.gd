@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDPropertyChoices extends FuncGodotFGDProperty
## FGD Entity class property definition for Choices property types.
##
## FGD Entity class property definition used to generate a choices property 
## for FGD export and [FuncGodotParser] retrieval.[br][br]
## Choices are created through the [member choices] [Dictionary] entries. 
## Each entry corresponds to a single choice option, where the dictionary key corresponds to 
## the choice option value while the dictionary value corresponds to the choice option description.
##
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties

## [Dictionary] of choices to be exported to the FGD. The dictionary key is the choice option's value, 
## while the dictionary value is the choice option's description.[br][br]
## The choice option value may be an [int], [String], [StringName], or [NodePath],
## but the choice option description must be a [String].
@export var choices: Dictionary[Variant, String]

func build_fgd_text(property_name: String, target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	var s: String = "\t" + property_name + "(choices)"
	if description:
		s += " : \"" + description + "\""
	if default_value:
		if description.is_empty():
			s += "\"\" : "
		match typeof(default_value):
			TYPE_INT: s += " : " + String.num(default_value, 0)
			TYPE_STRING: s += " : \"" + default_value + "\""
			TYPE_STRING_NAME, TYPE_NODE_PATH: s += " : \"" + String(default_value) + "\""
			_:
				push_error("ERROR: Invalid Choice default value type! Should be Integer, String, StringName, or NodePath.")
				return "\t// " + property_name + "(choices) was incorrectly set up: invalid default value type. Should be Integer, String, StringName, or NodePath."
			_: s += " : 0"
	s += " =\n\t[\n"
	for prop in choices.keys():
		s += "\t\t"
		match typeof(prop):
			TYPE_INT: s += String.num(prop, 0)
			TYPE_STRING: s += "\"" + prop + "\""
			TYPE_STRING_NAME, TYPE_NODE_PATH: s += "\"" + String(prop) + "\""
			_:
				push_error("ERROR: Invalid Choice option value type! Should be Integer, String, StringName, or NodePath.")
				return "\t// " + property_name + "(choices) was incorrectly set up: invalid option value type. Should be Integer, String, StringName, or NodePath."
		s += " : \"" + choices[prop] + "\"\n"
	s += "\t]"
	return s

func get_default_value() -> Variant:
	return default_value
