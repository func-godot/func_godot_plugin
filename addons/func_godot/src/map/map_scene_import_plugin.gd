## Scene generator node that parses a [QuakeMapFile] according to its [FuncGodotMapSettings].
##
## A scene generator node that parses a [QuakeMapFile]. It uses a [FuncGodotMapSettings] 
## and the [FuncGodotFGDFile] contained within in order to determine what is built and how it is built.[br][br]
## If your map is not building correctly, double check your [member map_settings] to make sure you're using 
## the correct [FuncGodotMapSettings].

@tool
class_name MapSceneImportPlugin
extends EditorSceneFormatImporter

const _SIGNATURE: String = "[MAP]"

## Builds the [member global_map_file]. If not set, builds the [member local_map_file].
## First cleans the map node of any children, then creates a [FuncGodotParser], [FuncGodotGeometryGenerator] 
## and [FuncGodotEntityAssembler] to parse and generate the map. 

func _get_extensions( ) -> PackedStringArray:
	return PackedStringArray(['map'])

func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var time_elapsed: float = Time.get_ticks_msec()
	
	var map_settings: FuncGodotMapSettings = options["func_godot/map_settings"]
	var build_flags:int = options["func_godot/build_flags"]
	var hyperplane_size:float = options["func_godot/hyperplane_size"]
	
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		FuncGodotUtil.print_profile_info("Building...", _SIGNATURE)
	
	# Parse and collect map data
	var parser := FuncGodotParser.new()
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nPARSER")
		parser.declare_step.connect(FuncGodotUtil.print_profile_info.bind(parser._SIGNATURE))

	var parse_data: FuncGodotData.ParseData = parser.parse_map_data(path, map_settings)
	
	if parse_data.entities.is_empty():
		return	# Already printed failure message in parser, just return here
	
	var entities: Array[FuncGodotData.EntityData] = parse_data.entities
	var groups: Array[FuncGodotData.GroupData] = parse_data.groups
	
	# Free up some memory now that we have the data
	parser = null
	
	# Retrieve geometry
	var generator := FuncGodotGeometryGenerator.new(map_settings, hyperplane_size)
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nGEOMETRY GENERATOR")
		generator.declare_step.connect(FuncGodotUtil.print_profile_info.bind(generator._SIGNATURE))
	
	# Generate surface and shape data
	var generate_error := generator.build(build_flags, entities)
	if generate_error != OK:
		push_error("Geometry generation failed: %s" % error_string(generate_error))
		return

	# Assemble entities and groups
	var assembler := FuncGodotEntityAssembler.new(map_settings, build_flags)
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nENTITY ASSEMBLER")
		assembler.declare_step.connect(FuncGodotUtil.print_profile_info.bind(assembler._SIGNATURE))
	var scene = assembler.build(entities, groups)
	
	var root_script:Script = options["nodes/root_script"]
	if not root_script:
		root_script = preload("res://addons/func_godot/src/map/func_godot_map.gd")
	scene.set_script(root_script)
	
	time_elapsed = Time.get_ticks_msec() - time_elapsed

	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nCompleted in %s seconds" % (time_elapsed / 1000.0))

	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("")
		FuncGodotUtil.print_profile_info("Build complete", _SIGNATURE)
		
	scene.name = path.get_file().get_basename().to_pascal_case()
	return scene
