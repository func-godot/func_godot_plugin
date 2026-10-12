@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDPropertyColor extends FuncGodotFGDProperty
## FGD Entity class property definition for color property types.
##
## FGD Entity class property definition used to generate a color property for FGD export. 
## Color properties can be two different types:[br]
## - [b]color255[/b] : 8 bit RGB values ranging between 0-255.[br]
## - [b]color1[/b] : Float RGB values ranging between 0.0-1.0.[br]

enum FGDColorType {
	COLOR255,
	COLOR1
}
@export var fgd_color_type: FGDColorType = FGDColorType.COLOR255

func build_fgd_text(property_name: String, target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	var s: String = "\t" + property_name + "("
	if fgd_color_type == FGDColorType.COLOR255:
		s += "color255"
	else:
		s += "color1"
	s += ")"
	if description:
		s += " : \"" + description + "\""
	if default_value:
		if typeof(default_value) != TYPE_COLOR:
			push_error("ERROR: Invalid FGD Property Color default value type! Should be Color")
			return "\t// " + property_name + "(color) was incorrectly set up: invalid default value type. Should be Color."
		if description.is_empty():
			s += "\"\" : "
		if fgd_color_type == FGDColorType.COLOR255:
			s += " : \"%s %s %s\"" % [default_value.r8, default_value.g8, default_value.b8]
		else:
			s += " : \"%s %s %s\"" % [default_value.r, default_value.g, default_value.b]
	return s

func get_default_value() -> Variant:
	if typeof(default_value) != TYPE_COLOR:
		return Color()
	return default_value

## Convert the raw property [String] to [Color] based on [member fgd_color_type] for [FuncGodotParser].
func get_color_from_property_string(classname: String, property_name: String, property_string: String) -> Color:
	var prop_color: Color = get_default_value()
	var prop_comps: PackedStringArray = property_string.split(" ")
	if prop_comps.size() > 2:
		if fgd_color_type == FGDColorType.COLOR255:
			prop_color.r8 = prop_comps[0].to_int()
			prop_color.g8 = prop_comps[1].to_int()
			prop_color.b8 = prop_comps[2].to_int()
		else:
			prop_color.r = prop_comps[0].to_float()
			prop_color.g = prop_comps[1].to_float()
			prop_color.b = prop_comps[2].to_float()
		prop_color.a = 1.0
	else:
		push_error("Invalid Color format for \'" + property_name + "\' in entity \'" + classname + "\': " + property_string)
	return prop_color
