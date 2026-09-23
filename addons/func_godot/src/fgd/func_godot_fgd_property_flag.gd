@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDPropertyFlagDescriptor extends Resource
## Flag descriptor support resource to be used with [member FuncGodotFGDPropertyFlags.flags].

## The bit index of the flag. Ranges 0 to 23, as only 24 flags are available to bitflag properties
## across most map editors due to the way Quake handles bitwise operations.[br][br]
## [FuncGodotFGDPropertyFlags] performs a [code]1 << index[/code] bit shift to retrieve the true bitflag value.
@export_range(0, 23, 1) var index: int = 0

## This is the name that appears in the flag checkbox window when setting the property. 
## If left blank, will be given the name "Flag [member index]".
@export var display_text: String = ""
## The default state of the bitflag.
@export var enabled: bool = false
## An optional longer description for the bitflag shown in the description window.
@export var description: String = ""
