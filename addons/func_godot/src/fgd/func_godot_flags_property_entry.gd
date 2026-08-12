@tool
class_name FuncGodotFlagsPropertyEntry
extends Resource
## Special resource used to make setting flags as a property type on an entity easier.

## The name of the flag
@export var name: String
@export var value := 0

## The "index" of the bitflag. For example: index 0 is equal to a raw value of 1, index 2 is equal to a raw value of 2, index 3 is equal to a raw value of 4, index 4 is equal to a raw value of 8, etc.
@export_range(0, 23, 1) var index := 0

var bitflag_value: int:
	get: return 1 << index

## Whether this flag is enabled by default
@export var enabled_by_default := false