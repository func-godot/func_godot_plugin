@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name NetRadiantCustomShader
extends Resource

## Path to texture without extension, eg: `textures/special/clip`.
@export var texture_path: String

## Shader property to apply to faces using [member texture_path].
@export var shader_attributes : Array[String] = ["qer_trans 0.4"]
