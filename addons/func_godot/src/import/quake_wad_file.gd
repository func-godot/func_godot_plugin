@icon("res://addons/func_godot/icons/icon_quake_file.svg")
class_name QuakeWadFile
extends Resource

@export var textures: Dictionary

func _init(textures: Dictionary = Dictionary()):
	self.textures = textures
