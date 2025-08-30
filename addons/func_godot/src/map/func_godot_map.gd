@tool
@icon("res://addons/func_godot/icons/icon_slipgate3d.svg")
class_name FuncGodotMap extends Node3D
## Scene generator node that parses a [QuakeMapFile] according to its [FuncGodotMapSettings].
##
## A scene generator node that parses a [QuakeMapFile]. It uses a [FuncGodotMapSettings] 
## and the [FuncGodotFGDFile] contained within in order to determine what is built and how it is built.[br][br]
## If your map is not building correctly, double check your [member map_settings] to make sure you're using 
## the correct [FuncGodotMapSettings].

const _SIGNATURE: String = "[MAP]"

## Bitflag settings that control various aspects of the build process.
enum BuildFlags {
	UNWRAP_UV2 			= 1 << 0,	## Unwrap UV2s during geometry generation for lightmap baking.
	SHOW_PROFILE_INFO 	= 1 << 1,	## Print build step information during build process.
	DISABLE_SMOOTHING	= 1 << 2	## Force disable processing of vertex normal smooth shading.
}

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
var _map_file_internal: String = ""

## Map settings resource that defines map build scale, textures location, entity definitions, and more.
@export var map_settings: FuncGodotMapSettings = load(ProjectSettings.get_setting("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres"))

@export_category("Build")
## [enum BuildFlags] that can affect certain aspects of the build process.
@export_flags("Unwrap UV2:1", "Show Profiling Info:2", "Disable Smooth Shading:4") var build_flags: int = 0

## Map build failure handler. Displays error message and emits [signal build_failed] signal.
func fail_build(reason: String, notify: bool = false) -> void:
	push_error(_SIGNATURE, " ", reason)
	if notify:
		build_failed.emit()

## Frees all children of the map node.[br]
## [b][color=yellow]Warning:[/color][/b] This does not distinguish between nodes generated in the FuncGodot build process and other user created nodes.
func clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

## Checks if a [QuakeMapFile] for the build process is provided and can be found.
func verify() -> Error:
	# Prioritize global map file path for building at runtime
	_map_file_internal = global_map_file if global_map_file != "" else local_map_file
	
	if _map_file_internal.is_empty():
		fail_build("Cannot build empty map file.")
		return ERR_INVALID_PARAMETER
	
	# Retrieve real path if needed
	if _map_file_internal.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(_map_file_internal)
		if not ResourceUID.has_id(uid):
			fail_build("Error: failed to retrieve path for UID (%s)" % _map_file_internal)
			return ERR_DOES_NOT_EXIST
		_map_file_internal = ResourceUID.get_id_path(uid)
	
	if not FileAccess.file_exists(_map_file_internal):
		if not FileAccess.file_exists(_map_file_internal + ".import"):
			fail_build("Map file %s does not exist." % _map_file_internal)
			return ERR_DOES_NOT_EXIST
	
	return OK

## Builds the [member global_map_file]. If not set, builds the [member local_map_file].
## First cleans the map node of any children, then creates a [FuncGodotParser], [FuncGodotGeometryGenerator] 
## and [FuncGodotEntityAssembler] to parse and generate the map. 
func build() -> void:
	var time_elapsed: float = Time.get_ticks_msec()
	
	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		FuncGodotUtil.print_profile_info("Building...", _SIGNATURE)

	clear_children()
	
	var verify_err: Error = verify()
	if verify_err != OK:
		fail_build("Verification failed: %s. Aborting map build" % error_string(verify_err), true)
		return
	
	if not map_settings:
		push_warning("Map assembler does not have a map settings provided and will use default map settings.")
		load(ProjectSettings.get_setting("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres"))
	
	# Parse and collect map data
	var parser := FuncGodotParser.new()
	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		print("\nPARSER")
		parser.declare_step.connect(FuncGodotUtil.print_profile_info.bind(parser._SIGNATURE))
	var parse_data: FuncGodotData.ParseData = parser.parse_map_data(_map_file_internal, map_settings)
	
	if parse_data.entities.is_empty():
		return	# Already printed failure message in parser, just return here
	
	var entities: Array[FuncGodotData.EntityData] = parse_data.entities
	var groups: Array[FuncGodotData.GroupData] = parse_data.groups
	
	# Free up some memory now that we have the data
	parser = null
	
	# Retrieve geometry
	var generator := FuncGodotGeometryGenerator.new(map_settings)
	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		print("\nGEOMETRY GENERATOR")
		generator.declare_step.connect(FuncGodotUtil.print_profile_info.bind(generator._SIGNATURE))
	
	# Generate surface and shape data
	var generate_error := generator.build(build_flags, entities)
	if generate_error != OK:
		fail_build("Geometry generation failed: %s" % error_string(generate_error))
		return

	# Assemble entities and groups
	var assembler := FuncGodotEntityAssembler.new(map_settings)
	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		print("\nENTITY ASSEMBLER")
		assembler.declare_step.connect(FuncGodotUtil.print_profile_info.bind(assembler._SIGNATURE))
	assembler.build(self, entities, groups)
	
	time_elapsed = Time.get_ticks_msec() - time_elapsed

	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		print("\nCompleted in %s seconds" % (time_elapsed / 1000.0))

	if build_flags & BuildFlags.SHOW_PROFILE_INFO:
		print("")
		FuncGodotUtil.print_profile_info("Build complete", _SIGNATURE)
	build_complete.emit()
