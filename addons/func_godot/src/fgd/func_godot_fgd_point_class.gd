@tool
## FGD PointClass entity definition, used to define point entities.
## PointClass entities can use either the `node_class` or the `scene_file` property to tell [FuncGodotMap] what to generate on map build.
class_name FuncGodotFGDPointClass
extends FuncGodotFGDEntityClass

func _init() -> void:
	prefix = "@PointClass"

@export_group ("Scene")
## An optional scene file to instantiate on map build. Overrides `node_class` and `script_class`.
@export var scene_file: PackedScene

## An optional script file to attach to the node generated on map build. Ignored if `scene_file` is specified.
@export_group ("Scripting")
@export var script_class: Script

@export_group("Build")
## Toggles whether entity will use `angles`, `mangle`, or `angle` to determine rotations on [FuncGodotMap] build, prioritizing the key value pairs in that order. Set to `false` if you would like to define how the generated node is rotated yourself.
@export var apply_rotation_on_map_build : bool = true

## Toggles whether entity will use `scale` to determine the generated node or scene's scale. This is performed on the top level node. The property can be a [float], [Vector3], or [Vector2].
@export var apply_scale_on_map_build: bool = true
