@tool
@icon("res://addons/func_godot/icons/icon_godambler3d.svg")
class_name FuncGodotFGDPointClass extends FuncGodotFGDEntityClass
## FGD PointClass entity definition.
##
## A resource used to define an FGD PointClass entity. PointClass entities can use either the [member FuncGodotFGDEntityClass.node_class] 
## or the [member scene_file] property to tell [FuncGodotMap] what to generate on map build.
##
## @tutorial(Quake Wiki Entity Article): https://quakewiki.org/wiki/Entity
## @tutorial(Level Design Book: Entity Types and Settings): https://book.leveldesignbook.com/appendix/resources/formats/fgd#entity-types-and-settings-basic
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties
## @tutorial(dumptruck_ds' Quake Mapping Entities Tutorial): https://www.youtube.com/watch?v=gtL9f6_N2WM
## @tutorial(Level Design Book: Display Models for Entities): https://book.leveldesignbook.com/appendix/resources/formats/fgd#display-models-for-entities
## @tutorial(Valve Developer Wiki FGD Article: Entity Description Section): https://developer.valvesoftware.com/wiki/FGD#Entity_Description
## @tutorial(TrenchBroom Manual: Display Models for Entities): https://trenchbroom.github.io/manual/latest/#display-models-for-entities

func _init() -> void:
	prefix = "@PointClass"

@export_group ("Scene")
## An optional [PackedScene] file to instantiate on map build. Overrides [member FuncGodotFGDEntityClass.node_class] and [member script_class].
@export var scene_file: PackedScene

@export_group ("Scripting")
## An optional [Script] resource to attach to the node generated on map build. Ignored if [member scene_file] is specified.
@export var script_class: Script

@export_group("Build")
## Toggles whether entity will use `angles`, `mangle`, or `angle` to determine rotations on [FuncGodotMap] build, prioritizing the key value pairs in that order. 
## Set to [code]false[/code] if you would like to define how the generated node is rotated yourself.
@export var apply_rotation_on_map_build : bool = true

## Toggles whether entity will use `scale` to determine the generated node or scene's scale. This is performed on the top level node. 
## The property can be a [float], [Vector3], or [Vector2]. Set to [code]false[/code] if you would like to define how the generated node is scaled yourself.
@export var apply_scale_on_map_build: bool = true
