## Scene generator node that parses a [QuakeMapFile] according to its [FuncGodotMapSettings].
##
## A scene generator node that parses a [QuakeMapFile]. It uses a [FuncGodotMapSettings] 
## and the [FuncGodotFGDFile] contained within in order to determine what is built and how it is built.[br][br]
## If your map is not building correctly, double check your [member map_settings] to make sure you're using 
## the correct [FuncGodotMapSettings].
## [br][br]
## @deprecated: In Editor usage of Map generation using this Node results in destructive operations and is discouraged. Recommended is to import map files as Scenes.  To load maps at runtime, prefer using [FuncGodotMapLoader].
@tool
@icon("res://addons/func_godot/icons/icon_slipgate3d.svg")
class_name FuncGodotMap extends Node3D

const _SIGNATURE: String = "[MAP]"

## Bitflag settings that control various aspects of the build process.
const BuildFlags = FuncGodotData.BuildFlags

## Emitted when the build process fails.
signal build_failed

## Emitted when the build process succesfully completes.
signal build_complete

@export_tool_button("Build Map","CollisionShape3D") var _build_func: Callable = build
@export_tool_button("Clear Map","Skeleton3D") var _clear_func: Callable = clear_children

@export_category("Map")
## Local path to MAP or VMF file to build a scene from.
@export_file("*.map","*.vmf") var local_map_file: String = ""

## Global path to MAP or VMF file to build a scene from. Overrides [member FuncGodotMap.local_map_file].
@export_global_file("*.map","*.vmf") var global_map_file: String = ""

# Map path used by code. Do it this way to support both global and local paths.
var _map_file_internal: String :
	get():
		return global_map_file if not global_map_file.is_empty() else local_map_file

## Map settings resource that defines map build scale, textures location, entity definitions, and more.
@export var map_settings: FuncGodotMapSettings = load(ProjectSettings.get_setting("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres"))

@export_category("Build")
## [enum BuildFlags] that can affect certain aspects of the build process.
@export_flags("Unwrap UV2:1", "Show Profiling Info:2", "Disable Smooth Shading:4") var build_flags: int = 0

## The hyperplane is an initial plane that all geometry faces are cut from, like a large sheet of marble before a sculptor begins chiseling. 
## The hyperplane size would need to be able to cover your map's potential total area.
## Smaller values can minimize floating point errors, reducing the effect of gaps between polygon seams.
## Measured in Godot units, not Quake units.
@export_range(256.0, 2048.0, 128.0) var hyperplane_size: float = 512.0

## Frees all children of the map node.[br]
## [b][color=yellow]Warning:[/color][/b] This does not distinguish between nodes generated in the FuncGodot build process and other user created nodes.
func clear_children() -> void:
	FuncGodotMapLoader.clear_children(self)
	if Engine.is_editor_hint():
		Engine.get_singleton(&"EditorInterface").mark_scene_as_unsaved()
		
## Builds the [member global_map_file]. If not set, builds the [member local_map_file].
## First cleans the map node of any children, then creates a [FuncGodotParser], [FuncGodotGeometryGenerator] 
## and [FuncGodotEntityAssembler] to parse and generate the map. 
func build() -> void:
	var success = FuncGodotMapLoader.load_map(
		self._map_file_internal,
		{
			"map_settings": self.map_settings,
			"build_flags": self.build_flags,
			"hyperplane_size": self.hyperplane_size
		},
		self
	)
	if Engine.is_editor_hint():
		Engine.get_singleton(&"EditorInterface").mark_scene_as_unsaved()

	if success == OK:
		build_complete.emit()
	else:
		build_failed.emit()
