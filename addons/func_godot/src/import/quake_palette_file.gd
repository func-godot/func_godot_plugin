@icon("res://addons/func_godot/icons/icon_quake_file.svg")
class_name QuakePaletteFile
extends Resource

@export var colors: PackedColorArray

func _init(colors):
	self.colors = colors
