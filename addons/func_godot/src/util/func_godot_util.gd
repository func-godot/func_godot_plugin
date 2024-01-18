## General-purpose utility functions namespaced to FuncGodot for compatibility
class_name FuncGodotUtil

## Print debug messages. True to print, false to ignore
const DEBUG : bool = true

## Const-predicated print function to avoid excess log spam. Print msg if [constant DEBUG] is `true`.
static func debug_print(msg) -> void:
	if(DEBUG):
		print(msg)

## Return a string that corresponds to the current OS's newline control character(s)
static func newline() -> String:
	if OS.get_name() == "Windows":
		return "\r\n"
	else:
		return "\n"

## Create a dictionary suitable for creating a category with name when overriding [method Object._get_property_list]
static func category_dict(name: String) -> Dictionary:
	return property_dict(name, TYPE_STRING, -1, "", PROPERTY_USAGE_CATEGORY)

## Creates a property with name and type from [enum @GlobalScope.Variant.Type].
## Optionally, provide hint from [enum @GlobalScope.PropertyHint] and corresponding hint_string, and usage from [enum @GlobalScope.PropertyUsageFlags].
static func property_dict(name: String, type: int, hint: int = -1, hint_string: String = "", usage: int = -1) -> Dictionary:
	var dict := {
		'name': name,
		'type': type
	}

	if hint != -1:
		dict['hint'] = hint

	if hint_string != "":
		dict['hint_string'] = hint_string

	if usage != -1:
		dict['usage'] = usage

	return dict
