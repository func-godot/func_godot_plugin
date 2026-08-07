## Scene generator utility that parses a [QuakeMapFile] according to its [FuncGodotMapSettings].
##
## A scene generator that parses a [QuakeMapFile]. It uses a [FuncGodotMapSettings] 
## and the [FuncGodotFGDFile] contained within in order to determine what is built and how it is built.[br][br]
## If your map is not building correctly, double check your [member map_settings] to make sure you're using 
## the correct [FuncGodotMapSettings].
@tool
class_name FuncGodotMapLoader extends RefCounted

## Frees all children of the map node.[br]
## [b][color=yellow]Warning:[/color][/b] This does not distinguish between nodes generated in the FuncGodot build process and other user created nodes.
static func clear_children(scene: Node3D) -> void:
	for child in scene.get_children():
		scene.remove_child(child)
		child.queue_free()

## Builds the Map file at [member path].
## Uses a [FuncGodotParser], [FuncGodotGeometryGenerator] and [FuncGodotEntityAssembler] to parse and generate the map. 
## 
static func load_map(path: String, options: Dictionary, scene: Node3D) -> Error:
	var time_elapsed: float = Time.get_ticks_msec()
	
	var map_settings: FuncGodotMapSettings = options["map_settings"]
	var build_flags:int = options["build_flags"]
	var hyperplane_size:float = options["hyperplane_size"]
	
	# Parse and collect map data
	var parser := FuncGodotParser.new()
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nPARSER")
		parser.declare_step.connect(FuncGodotUtil.print_profile_info.bind(parser._SIGNATURE))

	var parse_data: FuncGodotData.ParseData = parser.parse_map_data(path, map_settings)
	
	if parse_data.entities.is_empty():
		return ERR_CANT_CREATE # Already printed failure message in parser, just return here
	
	var entities: Array[FuncGodotData.EntityData] = parse_data.entities
	var groups: Array[FuncGodotData.GroupData] = parse_data.groups
	
	# Free up some memory now that we have the data
	parser = null
	
	# Retrieve geometry
	var generator := FuncGodotGeometryGenerator.new(map_settings, hyperplane_size)
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nGEOMETRY GENERATOR")
		generator.declare_step.connect(FuncGodotUtil.print_profile_info.bind(generator._SIGNATURE))
	
	# Destructive operation: clear out contents of supplied scene
	clear_children(scene)
	
	# Generate surface and shape data
	var generate_error := generator.build(build_flags, entities)
	if generate_error != OK:
		push_error("Geometry generation failed: %s" % error_string(generate_error))
		return ERR_CANT_CREATE

	# Assemble entities and groups
	var assembler := FuncGodotEntityAssembler.new(map_settings, build_flags)
	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nENTITY ASSEMBLER")
		assembler.declare_step.connect(FuncGodotUtil.print_profile_info.bind(assembler._SIGNATURE))
	scene = assembler.build(entities, groups, scene)
	
	time_elapsed = Time.get_ticks_msec() - time_elapsed

	if build_flags & FuncGodotData.BuildFlags.SHOW_PROFILE_INFO:
		print("\nCompleted in %s seconds" % (time_elapsed / 1000.0))

	return OK
