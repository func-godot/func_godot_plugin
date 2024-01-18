@tool
@icon("res://addons/func_godot/icons/icon_slipgate3d.svg")
## A scene generator node that parses a Quake map file using a [FuncGodotFGDFile]. Uses a [FuncGodotMapSettings] resource to define map build settings.
## To use this node, select an instance of the node in the Godot editor and select "Quick Build", "Full Build", or "Unwrap UV2" from the toolbar. Alternatively, call [method manual_build] from code.
class_name FuncGodotMap extends Node3D

@export_category("Map")

## Local path to Quake map file to build a scene from.
@export_file("*.map") var local_map_file : String = ""

## Global path to Quake map file to build a scene from. Overrides [member local_map_file].
@export_global_file("*.map") var global_map_file : String = ""

## Map settings resource that defines map build scale, textures location, and more
@export var map_settings : FuncGodotMapSettings = null