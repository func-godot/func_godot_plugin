@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDPropertyFlags extends FuncGodotFGDProperty
## FGD Entity class property definition for Bitflag property types.
##
## FGD Entity class property definition used to generate a set of bitflag properties 
## for FGD export and [FuncGodotParser] retrieval.[br][br]
## Bitflags are set up through the use of [FuncGodotFGDPropertyFlagDescriptor] resources placed within 
## the [member flags] [Array].[br][br]
## These resources can be saved to disk for reuse like other resources.
##
## @tutorial(Valve Developer Wiki Flags Article) : https://developer.valvesoftware.com/wiki/Flag
## @tutorial(Valve Developer Wiki FGD Article Flags Section) : https://developer.valvesoftware.com/wiki/FGD#Flags
## @tutorial(Wikipedia Bitwise Operation Article) : https://en.wikipedia.org/wiki/Bitwise_operation

## Array of [FuncGodotFGDPropertyFlagDescriptor] resources. This property's default value is generated using the sum of the enabled flags' values.
@export var flags: Array[FuncGodotFGDPropertyFlagDescriptor] = []

func build_fgd_text(property_name: String, target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	var s: String = "\t" + property_name + "(flags) =\n\t[\n"
	for flag in flags:
		s += "\t\t"
		s += String.num(1 << flag.index, 0)
		s += " : \""
		if flag.name:
			s += flag.name
		else:
			s += "Flag " + String.num(flag.index, 0)
		s += "\" : "
		if !flag.enabled:
			s += "0"
		else:
			s += "1"
		if flag.description:
			s += " : \"" + flag.description + "\""
		s += "\n"
	s += "\t]"
	return s

func get_default_value() -> Variant:
	var sum: int = 0
	for flag in flags:
		if flag.enabled:
			sum += 1 << flag.index
	return sum
