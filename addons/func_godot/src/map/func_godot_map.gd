@tool
@icon("res://addons/func_godot/icons/icon_slipgate3d.svg")
## A scene generator node that parses a Quake map file using a [FuncGodotFGDFile]. Uses a [FuncGodotMapSettings] resource to define map build settings.
## To use this node, select an instance of the node in the Godot editor and select "Quick Build", "Full Build", or "Unwrap UV2" from the toolbar. Alternatively, call [method manual_build] from code.
class_name FuncGodotMap extends Node3D

## How long to wait between child/owner batches
const YIELD_DURATION := 0.0

## Emitted when the build process successfully completes
signal build_complete()
## Emitted when the build process finishes a step. [code]progress[/code] is from 0.0-1.0
signal build_progress(step, progress)
## Emitted when the build process fails
signal build_failed()

## Emitted when UV2 unwrapping is completed
signal unwrap_uv2_complete()

@export_category("Map")

## Local path to Quake map file to build a scene from.
@export_file("*.map") var local_map_file: String = ""

## Global path to Quake map file to build a scene from. Overrides [member local_map_file].
@export_global_file("*.map") var global_map_file: String = ""

## Map path used by code. Do it this way to support both global and local paths.
var _map_file_internal: String = ""

## Map settings resource that defines map build scale, textures location, and more.
@export var map_settings: FuncGodotMapSettings = load("res://addons/func_godot/func_godot_default_map_settings.tres")

@export_category("Build")
## If true, print profiling data before and after each build step.
@export var print_profiling_data: bool = false
## If true, stop the whole editor until build is complete.
@export var block_until_complete: bool = false
## How many nodes to set the owner of, or add children of, at once. Higher values may lead to quicker build times, but a less responsive editor.
@export var set_owner_batch_size: int = 1000

# Build context variables
var func_godot: FuncGodot = null
var profile_timestamps: Dictionary = {}
var add_child_array: Array = []
var set_owner_array: Array = []
var should_add_children: bool = true
var should_set_owners: bool = true
var texture_list: Array = []
var texture_loader = null
var texture_dict: Dictionary = {}
var texture_size_dict: Dictionary = {}
var material_dict: Dictionary = {}
var entity_definitions: Dictionary = {}
var entity_dicts: Array = []
var entity_mesh_dict: Dictionary = {}
var entity_nodes: Array = []
var entity_mesh_instances: Dictionary = {}
var entity_occluder_instances: Dictionary = {}
var entity_collision_shapes: Array = []

# Utility
## Verify that FuncGodot is functioning and that [member map_file] exists. If so, build the map. If not, signal [signal build_failed]
func verify_and_build() -> void:
	if verify_parameters():
		build_map()
	else:
		emit_signal("build_failed")

## Build the map.
func manual_build() -> void:
	should_add_children = false
	should_set_owners = false
	verify_and_build()

## Return true if parameters are valid; FuncGodot should be functioning and [member map_file] should exist.
func verify_parameters() -> bool:
	# Prioritize global map file path for building at runtime
	_map_file_internal = global_map_file if global_map_file != "" else local_map_file

	if _map_file_internal == "":
		push_error("Error: Map file not set")
		return false
	
	if not FileAccess.file_exists(_map_file_internal):
		if FileAccess.file_exists(_map_file_internal + ".import"):
			_map_file_internal = _map_file_internal + ".import"
		else:
			push_error("Error: No such file %s" % _map_file_internal)
			return false
	
	if not map_settings:
		push_error("Error: Map settings not set")
		return false
	
	if not func_godot:
		func_godot = load("res://addons/func_godot/src/core/func_godot.gd").new()
	
	if not func_godot:
		push_error("Error: Failed to load func_godot.")
		return false
	
	return true

## Reset member variables that affect the current build
func reset_build_context() -> void:
	add_child_array = []
	set_owner_array = []
	texture_list = []
	texture_loader = null
	texture_dict = {}
	texture_size_dict = {}
	material_dict = {}
	entity_definitions = {}
	entity_dicts = []
	entity_mesh_dict = {}
	entity_nodes = []
	entity_mesh_instances = {}
	entity_occluder_instances = {}
	entity_collision_shapes = []
	build_step_index = 0
	build_step_count = 0
	if func_godot:
		func_godot = load("res://addons/func_godot/src/core/func_godot.gd").new()
		func_godot.map_settings = map_settings
		
## Record the start time of a build step for profiling
func start_profile(item_name: String) -> void:
	if print_profiling_data:
		print(item_name)
		profile_timestamps[item_name] = Time.get_unix_time_from_system()

## Finish profiling for a build step; print associated timing data
func stop_profile(item_name: String) -> void:
	if print_profiling_data:
		if item_name in profile_timestamps:
			var delta: float = Time.get_unix_time_from_system() - profile_timestamps[item_name]
			print("Completed in %s sec." % snapped(delta, 0.0001))
			profile_timestamps.erase(item_name)

## Run a build step. [code]step_name[/code] is the method corresponding to the step.
func run_build_step(step_name: String) -> Variant:
	start_profile(step_name)
	var result : Variant = call(step_name)
	stop_profile(step_name)
	return result

## Add [code]node[/code] as a child of parent, or as a child of [code]below[/code] if non-null. Also queue for ownership assignment.
func add_child_editor(parent: Node, node: Node, below: Node = null) -> void:
	if not node or not parent:
		return
	
	var prev_parent = node.get_parent()
	if prev_parent:
		prev_parent.remove_child(node)
	
	if below:
		below.add_sibling(node)
	else:
		parent.add_child(node)
	
	set_owner_array.append(node)

## Set the owner of [code]node[/code] to the current scene.
func set_owner_editor(node: Node) -> void:
	var tree : SceneTree = get_tree()
	
	if not tree:
		return
	
	var edited_scene_root : Node = tree.get_edited_scene_root()
	
	if not edited_scene_root:
		return
	
	node.set_owner(edited_scene_root)

var build_step_index : int = 0
var build_step_count : int = 0
var build_steps : Array = []
var post_attach_steps : Array = []

## Register a build step.
## [code]build_step[/code] is a string that corresponds to a method on this class, [code]arguments[/code] a list of arguments to pass to this method, and [code]target[/code] is a property on this class to save the return value of the build step in. If [code]post_attach[/code] is true, the step will be run after the scene hierarchy is completed.
func register_build_step(build_step: String, target: String = "", post_attach: bool = false) -> void:
	(post_attach_steps if post_attach else build_steps).append([build_step, target])
	build_step_count += 1

## Run all build steps. Emits [signal build_progress] after each step.
## If [code]post_attach[/code] is true, run post-attach steps instead and signal [signal build_complete] when finished.
func run_build_steps(post_attach : bool = false) -> void:
	var target_array : Array = post_attach_steps if post_attach else build_steps
	
	while target_array.size() > 0:
		var build_step : Array = target_array.pop_front()
		emit_signal("build_progress", build_step[0], float(build_step_index + 1) / float(build_step_count))
		
		var scene_tree : SceneTree = get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout
		
		var result : Variant = run_build_step(build_step[0])
		var target : String = build_step[1]
		if target != "":
			set(target, result)
			
		build_step_index += 1
		
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

	if post_attach:
		_build_complete()
	else:
		start_profile('add_children')
		add_children()

## Register all steps for the build. See [method register_build_step] and [method run_build_steps]
func register_build_steps() -> void:
	register_build_step('remove_children')
	register_build_step('load_map')
	register_build_step('fetch_texture_list', 'texture_list')
	register_build_step('init_texture_loader', 'texture_loader')
	register_build_step('load_textures', 'texture_dict')
	register_build_step('build_texture_size_dict', 'texture_size_dict')
	register_build_step('build_materials', 'material_dict')
	register_build_step('fetch_entity_definitions', 'entity_definitions')
	register_build_step('set_core_entity_definitions')
	register_build_step('generate_geometry')
	register_build_step('fetch_entity_dicts', 'entity_dicts')
	register_build_step('build_entity_nodes', 'entity_nodes')
	register_build_step('resolve_trenchbroom_group_hierarchy')
	register_build_step('build_entity_mesh_dict', 'entity_mesh_dict')
	register_build_step('build_entity_mesh_instances', 'entity_mesh_instances')
	register_build_step('build_entity_occluder_instances', 'entity_occluder_instances')
	register_build_step('build_entity_collision_shape_nodes', 'entity_collision_shapes')

## Register all post-attach steps for the build. See [method register_build_step] and [method run_build_steps]
func register_post_attach_steps() -> void:
	register_build_step('build_entity_collision_shapes', "", true)
	register_build_step('apply_entity_meshes', "", true)
	register_build_step('apply_entity_occluders', "", true)
	register_build_step('apply_properties_and_finish', "", true)

# Actions
## Build the map
func build_map() -> void:
	reset_build_context()
	if map_settings == null:
		printerr("Skipping build process: No map settings resource!")
		emit_signal("build_complete")
		return
	print('Building %s' % _map_file_internal)
	#if print_profiling_data:
		#print('\n')
	start_profile('build_map')
	register_build_steps()
	register_post_attach_steps()
	run_build_steps()

## Recursively unwrap UV2s for [code]node[/code] and its children, in preparation for baked lighting.
func unwrap_uv2(node: Node = null) -> void:
	var target_node: Node = null
	
	if node:
		target_node = node
	else:
		target_node = self
		print("Unwrapping mesh UV2s")
	
	if target_node is MeshInstance3D:
		if target_node.gi_mode == GeometryInstance3D.GI_MODE_STATIC:
			var mesh: Mesh = target_node.get_mesh()
			if mesh is ArrayMesh:
				mesh.lightmap_unwrap(Transform3D.IDENTITY, map_settings.uv_unwrap_texel_size * map_settings.scale_factor)
	
	for child in target_node.get_children():
		unwrap_uv2(child)
	
	if not node:
		print("Unwrap complete")
		emit_signal("unwrap_uv2_complete")

# Build Steps
## Recursively remove and delete all children of this node
func remove_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

## Parse and load [member map_file]
func load_map() -> void:
	func_godot.load_map(_map_file_internal, map_settings.use_trenchbroom_groups_hierarchy)

## Get textures found in [member map_file]
func fetch_texture_list() -> Array:
	return func_godot.get_texture_list() as Array

## Initialize texture loader, allowing textures in [member base_texture_dir] and [member texture_wads] to be turned into materials
func init_texture_loader() -> FuncGodotTextureLoader:
	return FuncGodotTextureLoader.new(map_settings)

## Build a dictionary from Map File texture names to their corresponding Texture2D resources in Godot
func load_textures() -> Dictionary:
	return texture_loader.load_textures(texture_list) as Dictionary

## Build a dictionary from Map File texture names to Godot materials
func build_materials() -> Dictionary:
	return texture_loader.create_materials(texture_list)

## Collect entity definitions from [member entity_fgd], as a dictionary from Map File classnames to entity definitions
func fetch_entity_definitions() -> Dictionary:
	return map_settings.entity_fgd.get_entity_definitions()

## Hand the FuncGodot core the entity definitions
func set_core_entity_definitions() -> void:
	var core_ent_defs: Dictionary = {}
	for classname in entity_definitions:
		core_ent_defs[classname] = {}
		var entity_definition: FuncGodotFGDEntityClass = entity_definitions[classname]
		if entity_definition is FuncGodotFGDSolidClass:
			core_ent_defs[classname]['spawn_type'] = entity_definition.spawn_type
			core_ent_defs[classname]['origin_type'] = entity_definition.origin_type
			
			const MFlags = FuncGodotMapData.FuncGodotEntityMetadataInclusionFlags
			var flags := MFlags.NONE
			if entity_definition.add_textures_metadata: flags |= MFlags.TEXTURES
			if entity_definition.add_vertex_metadata: flags |= MFlags.VERTEX
			if entity_definition.add_face_normal_metadata: flags |= MFlags.FACE_NORMAL
			if entity_definition.add_face_position_metadata: flags |= MFlags.FACE_POSITION
			if entity_definition.add_collision_shape_face_range_metadata: flags |= MFlags.COLLISION_SHAPE_TO_FACE_RANGE_MAP
			core_ent_defs[classname]['metadata_inclusion_flags'] = flags
	func_godot.set_entity_definitions(core_ent_defs)

## Generate geometry from map file
func generate_geometry() -> void:
	func_godot.generate_geometry(texture_size_dict);

## Get a list of dictionaries representing each entity from the FuncGodot core
func fetch_entity_dicts() -> Array:
	return func_godot.get_entity_dicts()

## Build a dictionary from Map File textures to the sizes of their corresponding Godot textures
func build_texture_size_dict() -> Dictionary:
	var texture_size_dict: Dictionary = {}
	
	for tex_key in texture_dict:
		var texture: Texture2D = texture_dict[tex_key] as Texture2D
		if texture:
			texture_size_dict[tex_key] = texture.get_size()
		else:
			texture_size_dict[tex_key] = Vector2.ONE
	
	return texture_size_dict

## Build nodes from the entities in [member entity_dicts]
func build_entity_nodes() -> Array:
	var entity_nodes : Array = []
	entity_nodes.resize(entity_dicts.size())
	
	# TrenchBroom: Prevent generation of omitted layers
	var omitted_entities : Array[int] = []
	var omitted_groups: Array[String] = []
	
	if map_settings.use_trenchbroom_groups_hierarchy:
		# Omit layers
		for entity_idx in range(0, entity_dicts.size()):
			var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
			var properties: Dictionary = entity_dict['properties'] as Dictionary
			
			if '_tb_type' in properties and properties['_tb_type'] == '_tb_layer':
				if '_tb_layer_omit_from_export' in properties and properties['_tb_layer_omit_from_export'] == "1":
					omitted_entities.append(entity_idx)
					omitted_groups.append("layer_" + str(properties.get('_tb_id', "-1")))
		
		# Omit groups and top-level entities
		for entity_idx in range(0, entity_dicts.size()):
			if omitted_entities.find(entity_idx) != -1:
				continue
			
			var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
			var properties: Dictionary = entity_dict['properties'] as Dictionary
			
			if '_tb_layer' in properties:
				if omitted_groups.find("layer_" + str(properties['_tb_layer'])) != -1:
					omitted_entities.append(entity_idx)
					if '_tb_id' in properties and properties['_tb_type'] == '_tb_group':
						omitted_groups.append("group_" + str(properties.get('_tb_id', "-1")))

	for entity_idx in range(0, entity_dicts.size()):
		var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
		var properties: Dictionary = entity_dict['properties'] as Dictionary

		if map_settings.use_trenchbroom_groups_hierarchy:
			if omitted_entities.find(entity_idx) != -1:
				entity_nodes[entity_idx] = null
				continue
			if '_tb_group' in properties and omitted_groups.find("group_" + str(properties['_tb_group'])) != -1:
				entity_nodes[entity_idx] = null
				continue

		var node: Node = null
		var node_name: String = "entity_%s" % entity_idx
		
		var should_add_child: bool = should_add_children
		
		if 'classname' in properties:
			var classname: String = properties['classname']
			node_name += "_" + classname
			if classname in entity_definitions:
				var entity_definition: FuncGodotFGDEntityClass = entity_definitions[classname] as FuncGodotFGDEntityClass
				
				var name_prop: String
				if entity_definition.name_property in properties:
					name_prop = str(properties[entity_definition.name_property])
				elif map_settings.entity_name_property in properties:
					name_prop = str(properties[map_settings.entity_name_property])
				if not name_prop.is_empty():
					node_name = "entity_" + name_prop
				
				if entity_definition is FuncGodotFGDSolidClass:
					if entity_definition.spawn_type == FuncGodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
						entity_nodes[entity_idx] = null
						continue
					if entity_definition.node_class != "":
						node = ClassDB.instantiate(entity_definition.node_class)
				elif entity_definition is FuncGodotFGDPointClass:
					if entity_definition.scene_file:
						var flag: PackedScene.GenEditState = PackedScene.GEN_EDIT_STATE_DISABLED
						if Engine.is_editor_hint():
							flag = PackedScene.GEN_EDIT_STATE_INSTANCE
						node = entity_definition.scene_file.instantiate(flag)
					elif entity_definition.node_class != "":
						node = ClassDB.instantiate(entity_definition.node_class)
					if 'rotation_degrees' in node and entity_definition.apply_rotation_on_map_build:
						var angles := Vector3.ZERO
						if 'angles' in properties or 'mangle' in properties:
							var key := 'angles' if 'angles' in properties else 'mangle'
							var angles_raw = properties[key]
							if not angles_raw is Vector3:
								angles_raw = angles_raw.split_floats(' ')
							if angles_raw.size() > 2:
								angles = Vector3(-angles_raw[0], angles_raw[1], -angles_raw[2])
								if key == 'mangle':
									if entity_definition.classname.begins_with('light'):
										angles = Vector3(angles_raw[1], angles_raw[0], -angles_raw[2])
									elif entity_definition.classname == 'info_intermission':
										angles = Vector3(angles_raw[0], angles_raw[1], -angles_raw[2])
							else:
								push_error("Invalid vector format for \'" + key + "\' in entity \'" + classname + "\'")
						elif 'angle' in properties:
							var angle = properties['angle']
							if not angle is float:
								angle = float(angle)
							angles.y += angle
						angles.y += 180
						node.rotation_degrees = angles
				else:
					node = Node3D.new()
				if entity_definition.script_class:
					node.set_script(entity_definition.script_class)
		if not node:
			node = Node3D.new()
		
		node.name = node_name
		
		if 'origin' in properties and entity_dict.brush_count < 1:
			var origin_vec: Vector3 = Vector3.ZERO
			var origin_comps: PackedFloat64Array = properties['origin'].split_floats(' ')
			if origin_comps.size() > 2:
				origin_vec = Vector3(origin_comps[1], origin_comps[2], origin_comps[0])
			else:
				push_error("Invalid vector format for \'origin\' in " + node.name)
			if 'position' in node:
				if node.position is Vector3:
					node.position = origin_vec * map_settings.scale_factor
				elif node.position is Vector2:
					node.position = Vector2(origin_vec.z, -origin_vec.y)
		else:
			if entity_idx != 0 and 'position' in node:
				if node.position is Vector3:
					node.position = entity_dict['center'] * map_settings.scale_factor
		
		entity_nodes[entity_idx] = node
		
		if should_add_child:
			queue_add_child(self, node)
	
	return entity_nodes

## Build [CollisionShape3D] nodes for brush entities
func build_entity_collision_shape_nodes() -> Array:
	var entity_collision_shapes_arr: Array = []
	
	for entity_idx in range(0, entity_nodes.size()):
		var entity_collision_shapes: Array = []
		
		var entity_dict: Dictionary = entity_dicts[entity_idx]
		var properties: Dictionary = entity_dict['properties']
		
		var node: Node = entity_nodes[entity_idx] as Node
		var concave: bool = false
		
		if 'classname' in properties:
			var classname: String = properties['classname']
			if classname in entity_definitions:
				var entity_definition: FuncGodotFGDSolidClass = entity_definitions[classname] as FuncGodotFGDSolidClass
				if entity_definition:
					if entity_definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.NONE:
						entity_collision_shapes_arr.append(null)
						continue
					elif entity_definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.CONCAVE:
						concave = true
					
					if entity_definition.spawn_type == FuncGodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
						# TODO: Find the worldspawn object instead of assuming index 0
						node = entity_nodes[0] as Node
					
					if node and node is CollisionObject3D:
						(node as CollisionObject3D).collision_layer = entity_definition.collision_layer
						(node as CollisionObject3D).collision_mask = entity_definition.collision_mask
						(node as CollisionObject3D).collision_priority = entity_definition.collision_priority
		
		# don't create collision shapes that wont be attached to a CollisionObject3D as they are a waste
		if not node or (not node is CollisionObject3D):
			entity_collision_shapes_arr.append(null)
			continue
		
		if concave:
			var collision_shape: CollisionShape3D = CollisionShape3D.new()
			collision_shape.name = "entity_%s_collision_shape" % entity_idx
			entity_collision_shapes.append(collision_shape)
			queue_add_child(node, collision_shape)
		else:
			for brush_idx in entity_dict['brush_indices']:
				var collision_shape: CollisionShape3D = CollisionShape3D.new()
				collision_shape.name = "entity_%s_brush_%s_collision_shape" % [entity_idx, brush_idx]
				entity_collision_shapes.append(collision_shape)
				queue_add_child(node, collision_shape)
		entity_collision_shapes_arr.append(entity_collision_shapes)
	
	return entity_collision_shapes_arr

## Build the concrete [Shape3D] resources for each brush
func build_entity_collision_shapes() -> void:
	for entity_idx in range(0, entity_dicts.size()):
		var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
		var properties: Dictionary = entity_dict['properties']
		var entity_position: Vector3 = Vector3.ZERO
		if entity_nodes[entity_idx] != null and entity_nodes[entity_idx].get("position"):
			if entity_nodes[entity_idx].position is Vector3:
				entity_position = entity_nodes[entity_idx].position
		
		if entity_collision_shapes.size() < entity_idx:
			continue
		if entity_collision_shapes[entity_idx] == null:
			continue
		
		var entity_collision_shape: Array = entity_collision_shapes[entity_idx]
		var concave: bool = false
		var shape_margin: float = 0.04
		var entity_definition: FuncGodotFGDSolidClass
		
		if 'classname' in properties:
			var classname: String = properties['classname']
			if classname in entity_definitions:
				entity_definition = entity_definitions[classname] as FuncGodotFGDSolidClass
				if entity_definition:
					match(entity_definition.collision_shape_type):
						FuncGodotFGDSolidClass.CollisionShapeType.NONE:
							continue
						FuncGodotFGDSolidClass.CollisionShapeType.CONVEX:
							concave = false
						FuncGodotFGDSolidClass.CollisionShapeType.CONCAVE:
							concave = true
					shape_margin = entity_definition.collision_shape_margin
		
		if entity_collision_shapes[entity_idx] == null:
			continue
		
		if concave:
			func_godot.gather_entity_concave_collision_surfaces(entity_idx)
		else:
			func_godot.gather_entity_convex_collision_surfaces(entity_idx)
		var entity_surfaces: Array = func_godot.fetch_surfaces(func_godot.surface_gatherer)
		var metadata: Dictionary = func_godot.surface_gatherer.out_metadata
		var collision_shape_to_face_range_map: Dictionary = {}
		var face_shape_indices: Array[Vector2i] = metadata["shape_index_ranges"]
		
		var entity_verts: PackedVector3Array = PackedVector3Array()
		
		for surface_idx in range(0, entity_surfaces.size()):
			if entity_surfaces[surface_idx] == null:
				continue

			var surface_verts: Array = entity_surfaces[surface_idx]
			
			if concave:
				var vertices: PackedVector3Array = surface_verts[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var indices: PackedInt32Array = surface_verts[Mesh.ARRAY_INDEX] as PackedInt32Array
				for vert_idx in indices:
					entity_verts.append(vertices[vert_idx])
			else:
				var shape_points = PackedVector3Array()
				for vertex in surface_verts[Mesh.ARRAY_VERTEX]:
					if not vertex in shape_points:
						shape_points.append(vertex)
				
				var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
				shape.set_points(shape_points)
				shape.margin = shape_margin
				
				var collision_shape: CollisionShape3D = entity_collision_shape[surface_idx]
				collision_shape.set_shape(shape)
				
				# For face shape range metadata, we need to add info about child node names
				if entity_definition and entity_definition.add_collision_shape_face_range_metadata:
					collision_shape_to_face_range_map[collision_shape.name] = face_shape_indices[surface_idx]
				
		if concave:
			if entity_verts.size() == 0:
				continue
			
			var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
			shape.set_faces(entity_verts)
			shape.margin = shape_margin
			
			var collision_shape: CollisionShape3D = entity_collision_shapes[entity_idx][0]
			collision_shape.set_shape(shape)
			
			if entity_definition and entity_definition.add_collision_shape_face_range_metadata:
				collision_shape_to_face_range_map[collision_shape.name] = Vector2i(0, entity_verts.size() / 3)

		if entity_definition:
			if not entity_definition.add_face_normal_metadata:
				metadata.erase("normals")
			if not entity_definition.add_face_position_metadata:
				metadata.erase("positions")
			if not entity_definition.add_textures_metadata:
				metadata.erase("textures")
				metadata.erase("texture_names")
			if not entity_definition.add_vertex_metadata:
				metadata.erase("vertices")

			metadata.erase("shape_index_ranges") # cleanup intermediate / buffer
			if entity_definition.add_collision_shape_face_range_metadata:
				metadata["collision_shape_to_face_range_map"] = collision_shape_to_face_range_map

			if not metadata.is_empty():
				entity_nodes[entity_idx].set_meta("func_godot_mesh_data", metadata)

## Build Dictionary from entity indices to [ArrayMesh] instances
func build_entity_mesh_dict() -> Dictionary:
	var meshes: Dictionary = {}
	
	var texture_surf_map: Dictionary
	var texture_to_metadata_map: Dictionary
	for texture in texture_dict:
		texture_surf_map[texture] = Array()
		texture_to_metadata_map[texture] = {}
	
	var gather_task = func(i):
		var texture: String = texture_dict.keys()[i]
		var fetch_result = func_godot.gather_texture_surfaces(texture)
		texture_surf_map[texture] = fetch_result["surfaces"]
		texture_to_metadata_map[texture] = fetch_result["metadata"]
	
	var task_id: int = WorkerThreadPool.add_group_task(gather_task, texture_dict.keys().size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	for texture in texture_dict:
		var texture_surfaces: Array = texture_surf_map[texture] as Array
		
		for entity_idx in range(0, texture_surfaces.size()):
			var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
			var properties: Dictionary = entity_dict['properties']
			
			var entity_surface = texture_surfaces[entity_idx]
			var entity_definition: FuncGodotFGDSolidClass
			
			if 'classname' in properties:
				var classname: String = properties['classname']
				if classname in entity_definitions:
					entity_definition = entity_definitions[classname] as FuncGodotFGDSolidClass
					if entity_definition:
						if entity_definition.spawn_type == FuncGodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
							entity_surface = null
							
						if not entity_definition.build_visuals and not entity_definition.build_occlusion:
							entity_surface = null
						
			if entity_surface == null:
				continue
			
			if not entity_idx in meshes:
				meshes[entity_idx] = ArrayMesh.new()
			
			var mesh: ArrayMesh = meshes[entity_idx]
			mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, entity_surface)
			mesh.surface_set_name(mesh.get_surface_count() - 1, texture)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material_dict[texture])

			# Build metadata only if the node is set to not build collision. Otherwise we are already building it in build_entity_collision_shapes.
			if entity_definition and entity_definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.NONE:
				if not mesh.has_meta("func_godot_mesh_data"):
					mesh.set_meta("func_godot_mesh_data", Dictionary())
				var this_textures_metadata: Dictionary = texture_to_metadata_map[texture]
				var entity_metadata: Dictionary = mesh.get_meta("func_godot_mesh_data")
				var entity_index_ranges: Array[Vector2i] = this_textures_metadata["entity_index_ranges"]
				var range: Vector2i = entity_index_ranges[entity_idx]

				if entity_definition.add_vertex_metadata:
					var vertices: PackedVector3Array = entity_metadata.get("vertices", PackedVector3Array())
					vertices.append_array((this_textures_metadata["vertices"] as PackedVector3Array).slice(range.x * 3, range.y * 3))
					entity_metadata["vertices"] = vertices

				if entity_definition.add_face_normal_metadata:
					var normals: PackedVector3Array = entity_metadata.get("normals", PackedVector3Array())
					normals.append_array((this_textures_metadata["normals"] as PackedVector3Array).slice(range.x, range.y))
					entity_metadata["normals"] = normals

				if entity_definition.add_face_position_metadata:
					var positions: PackedVector3Array = entity_metadata.get("positions", PackedVector3Array())
					positions.append_array((this_textures_metadata["positions"] as PackedVector3Array).slice(range.x, range.y))
					entity_metadata["positions"] = positions

				if entity_definition.add_textures_metadata:
					# different (if null: add empty) logic for texture_names due to not being able make a static typed
					# Array[StringName] inline in the get() function
					if not entity_metadata.has("texture_names"):
						var new: Array[StringName] = []
						entity_metadata["texture_names"] = new
					var texture_names: Array[StringName] = entity_metadata["texture_names"]
					var textures: PackedInt32Array = entity_metadata.get("textures", PackedInt32Array())
					var texture_block: PackedInt32Array = []
					texture_block.resize(range.y - range.x)
					texture_block.fill(texture_names.size())
					texture_names.append(StringName(texture))
					textures.append_array(texture_block)
					entity_metadata["textures"] = textures

	return meshes

## Build [MeshInstance3D]s from brush entities and add them to the add child queue
func build_entity_mesh_instances() -> Dictionary:
	var entity_mesh_instances: Dictionary = {}
	for entity_idx in entity_mesh_dict:
		var use_in_baked_light: bool = false
		var shadow_casting_setting: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		var render_layers: int = 1
		
		var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
		var properties: Dictionary = entity_dict['properties']
		var classname: String = properties['classname']
		if classname in entity_definitions:
			var entity_definition: FuncGodotFGDSolidClass = entity_definitions[classname] as FuncGodotFGDSolidClass
			if entity_definition:
				if not entity_definition.build_visuals:
					continue
				
				if entity_definition.use_in_baked_light:
					use_in_baked_light = true
				elif '_shadow' in properties:
					if properties['_shadow'] == "1":
						use_in_baked_light = true
				shadow_casting_setting = entity_definition.shadow_casting_setting
				render_layers = entity_definition.render_layers
		
		if not entity_mesh_dict[entity_idx]:
			continue
		
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.name = 'entity_%s_mesh_instance' % entity_idx
		mesh_instance.gi_mode = MeshInstance3D.GI_MODE_STATIC if use_in_baked_light else GeometryInstance3D.GI_MODE_DISABLED
		mesh_instance.cast_shadow = shadow_casting_setting
		mesh_instance.layers = render_layers
		
		queue_add_child(entity_nodes[entity_idx], mesh_instance)
		
		entity_mesh_instances[entity_idx] = mesh_instance
	
	return entity_mesh_instances

func build_entity_occluder_instances() -> Dictionary:
	var entity_occluder_instances: Dictionary = {}
	for entity_idx in entity_mesh_dict:
		var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
		var properties: Dictionary = entity_dict['properties']
		var classname: String = properties['classname']
		if classname in entity_definitions:
			var entity_definition: FuncGodotFGDSolidClass = entity_definitions[classname] as FuncGodotFGDSolidClass
			if entity_definition:
				if entity_definition.build_occlusion:
					if not entity_mesh_dict[entity_idx]:
						continue
					
					var occluder_instance: OccluderInstance3D = OccluderInstance3D.new()
					occluder_instance.name = 'entity_%s_occluder_instance' % entity_idx
					
					queue_add_child(entity_nodes[entity_idx], occluder_instance)
					entity_occluder_instances[entity_idx] = occluder_instance
	
	return entity_occluder_instances

## Assign [ArrayMesh]es to their [MeshInstance3D] counterparts
func apply_entity_meshes() -> void:
	for entity_idx in entity_mesh_instances:
		var mesh: Mesh = entity_mesh_dict[entity_idx] as Mesh
		var mesh_instance: MeshInstance3D = entity_mesh_instances[entity_idx] as MeshInstance3D
		if not mesh or not mesh_instance:
			if mesh.has_meta("func_godot_mesh_data"):
				mesh.remove_meta("func_godot_mesh_data")
			continue
		
		mesh_instance.set_mesh(mesh)
		queue_add_child(entity_nodes[entity_idx], mesh_instance)
		if mesh.has_meta("func_godot_mesh_data"):
			entity_nodes[entity_idx].set_meta("func_godot_mesh_data", mesh.get_meta("func_godot_mesh_data"))
			mesh.remove_meta("func_godot_mesh_data")

func apply_entity_occluders() -> void:
	for entity_idx in entity_mesh_dict:
		var mesh: Mesh = entity_mesh_dict[entity_idx] as Mesh
		var occluder_instance: OccluderInstance3D
		
		if entity_idx in entity_occluder_instances:
			occluder_instance = entity_occluder_instances[entity_idx]
		
		if not mesh or not occluder_instance:
			continue
		
		var verts: PackedVector3Array
		var indices: PackedInt32Array
		var index: int = 0
		for surf_idx in range(mesh.get_surface_count()):
			var vert_count: int = verts.size()
			var surf_array: Array = mesh.surface_get_arrays(surf_idx)
			verts.append_array(surf_array[Mesh.ARRAY_VERTEX])
			indices.resize(indices.size() + surf_array[Mesh.ARRAY_INDEX].size())
			for new_index in surf_array[Mesh.ARRAY_INDEX]:
				indices[index] = (new_index + vert_count)
				index += 1
		
		var occluder: ArrayOccluder3D = ArrayOccluder3D.new()
		occluder.set_arrays(verts, indices)
		
		occluder_instance.occluder = occluder

## Resolve entity group hierarchy, turning Trenchbroom groups into nodes and queueing their contents to be added to said nodes as children
func resolve_trenchbroom_group_hierarchy() -> void:
	if not map_settings.use_trenchbroom_groups_hierarchy:
		return
	
	var parent_entities: Dictionary = {}
	var child_entities: Dictionary = {}
	
	# Gather all entities which are children in some group or parents in some group
	for node_idx in range(0, entity_nodes.size()):
		var node: Node = entity_nodes[node_idx]
		var properties: Dictionary = entity_dicts[node_idx]['properties']
		
		if not properties: 
			continue
		
		if not ('_tb_id' in properties or '_tb_group' in properties or '_tb_layer' in properties):
			continue
		
		# identify children
		if '_tb_group' in properties or '_tb_layer' in properties: 
			child_entities[node_idx] = node
		
		# identify parents
		if '_tb_id' in properties:
			node.set_meta("_tb_type", properties['_tb_type'])
			if properties['_tb_type'] == "_tb_group":
				node.name = "group_" + str(properties['_tb_id'])
			elif properties['_tb_type'] == "_tb_layer":
				node.name = "layer_" + str(properties['_tb_layer_sort_index'])
			if properties['_tb_name'] != "Unnamed":
				node.name = node.name + "_" + properties['_tb_name']
			parent_entities[node_idx] = node
	
	var child_to_parent_map: Dictionary = {}
	
	#For each child,...
	for node_idx in child_entities:
		var node: Node = child_entities[node_idx]
		var properties: Dictionary = entity_dicts[node_idx]['properties']
		var tb_group: Variant = null
		if '_tb_group' in properties:
			tb_group = properties['_tb_group']
		elif '_tb_layer' in properties:
			tb_group = properties['_tb_layer']
		if tb_group == null: 
			continue

		var parent: Node = null
		var parent_properties: Dictionary = {}
		var parent_entity = null
		var parent_idx = null
		
		# ...identify its direct parent out of the parent_entities array
		for possible_parent in parent_entities:
			parent_entity = parent_entities[possible_parent]
			parent_properties = entity_dicts[possible_parent]['properties']			
			if parent_properties['_tb_id'] == tb_group:
				parent = parent_entity
				parent_idx = possible_parent
				break
		# If there's a match, pass it on to the child-parent relationship map
		if parent:
			child_to_parent_map[node_idx] = parent_idx 
	
	for child_idx in child_to_parent_map:
		var child = entity_nodes[child_idx]
		var parent_idx = child_to_parent_map[child_idx]
		var parent = entity_nodes[parent_idx]
		queue_add_child(parent, child, null, true)

## Add a child and its new parent to the add child queue. If [code]below[/code] is a node, add it as a child to that instead. If [code]relative[/code] is true, set the location of node relative to parent.
func queue_add_child(parent, node, below = null, relative = false) -> void:
	add_child_array.append({"parent": parent, "node": node, "below": below, "relative": relative})

## Assign children to parents based on the contents of the add child queue (see [method queue_add_child])
func add_children() -> void:
	while true:
		for i in range(0, set_owner_batch_size):
			if add_child_array.size() > 0:
				var data: Dictionary = add_child_array.pop_front()
				if data:
					add_child_editor(data['parent'], data['node'], data['below'])
					if data['relative']:
						if (data['node'] is Node3D and data['parent'] is Node3D) or (data['node'] is Node2D and data['parent'] is Node2D):
							data['node'].position -= data['parent'].position
				continue
			add_children_complete()
			return
		
		var scene_tree: SceneTree = get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

## Set owners and start post-attach build steps
func add_children_complete() -> void:
	stop_profile('add_children')
	
	if should_set_owners:
		start_profile('set_owners')
		set_owners()
	else:
		run_build_steps(true)

## Set owner of nodes generated by FuncGodot to scene root based on [member set_owner_array]
func set_owners() -> void:
	while true:
		for i in range(0, set_owner_batch_size):
			var node: Node = set_owner_array.pop_front()
			if node:
				set_owner_editor(node)
			else:
				set_owners_complete()
				return
				
		var scene_tree: SceneTree = get_tree()
		if scene_tree and not block_until_complete:
			await get_tree().create_timer(YIELD_DURATION).timeout

## Finish profiling for set_owners and start post-attach build steps
func set_owners_complete() -> void:
	stop_profile('set_owners')
	run_build_steps(true)

## Apply Map File properties to [Node3D] instances, transferring Map File dictionaries to [Node3D.func_godot_properties]
## and then calling the appropriate callbacks.
func apply_properties_and_finish() -> void:
	for entity_idx in range(0, entity_nodes.size()):
		var entity_node: Node = entity_nodes[entity_idx] as Node
		if not entity_node:
			continue
		
		var entity_dict: Dictionary = entity_dicts[entity_idx] as Dictionary
		var properties: Dictionary = entity_dict['properties'] as Dictionary
		
		if 'classname' in properties:
			var classname: String = properties['classname']
			if classname in entity_definitions:
				var entity_definition: FuncGodotFGDEntityClass = entity_definitions[classname] as FuncGodotFGDEntityClass
				
				for property in properties:
					var prop_string = properties[property]
					if property in entity_definition.class_properties:
						var prop_default: Variant = entity_definition.class_properties[property]
						
						match typeof(prop_default):
							TYPE_INT:
								properties[property] = prop_string.to_int()
							TYPE_FLOAT:
								properties[property] = prop_string.to_float()
							TYPE_BOOL:
								properties[property] = bool(prop_string.to_int())
							TYPE_VECTOR3:
								var prop_comps: PackedFloat64Array = prop_string.split_floats(" ")
								if prop_comps.size() > 2:
									properties[property] = Vector3(prop_comps[0], prop_comps[1], prop_comps[2])
								else:
									push_error("Invalid Vector3 format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
									properties[property] = prop_default
							TYPE_VECTOR3I:
								var prop_vec: Vector3i = prop_default
								var prop_comps: PackedStringArray = prop_string.split(" ")
								if prop_comps.size() > 2:
									for i in 3:
										prop_vec[i] = prop_comps[i].to_int()
								else:
									push_error("Invalid Vector3i format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
								properties[property] = prop_vec
							TYPE_COLOR:
								var prop_color: Color = prop_default
								var prop_comps: PackedStringArray = prop_string.split(" ")
								if prop_comps.size() > 2:
									prop_color.r8 = prop_comps[0].to_int()
									prop_color.g8 = prop_comps[1].to_int()
									prop_color.b8 = prop_comps[2].to_int()
									prop_color.a = 1.0
								else:
									push_error("Invalid Color format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
								properties[property] = prop_color
							TYPE_DICTIONARY:
								var prop_desc = entity_definition.class_property_descriptions[property]
								if prop_desc is Array and prop_desc.size() > 1 and prop_desc[1] is int:
									properties[property] = prop_string.to_int()
							TYPE_ARRAY:
								properties[property] = prop_string.to_int()
							TYPE_VECTOR2:
								var prop_comps: PackedFloat64Array = prop_string.split_floats(" ")
								if prop_comps.size() > 1:
									properties[property] = Vector2(prop_comps[0], prop_comps[1])
								else:
									push_error("Invalid Vector2 format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
									properties[property] = prop_default
							TYPE_VECTOR2I:
								var prop_vec: Vector2i = prop_default
								var prop_comps: PackedStringArray = prop_string.split(" ")
								if prop_comps.size() > 1:
									for i in 2:
										prop_vec[i] = prop_comps[i].to_int()
								else:
									push_error("Invalid Vector2i format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
									properties[property] = prop_vec
							TYPE_VECTOR4:
								var prop_comps: PackedFloat64Array = prop_string.split_floats(" ")
								if prop_comps.size() > 3:
									properties[property] = Vector4(prop_comps[0], prop_comps[1], prop_comps[2], prop_comps[3])
								else:
									push_error("Invalid Vector4 format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
									properties[property] = prop_default
							TYPE_VECTOR4I:
								var prop_vec: Vector4i = prop_default
								var prop_comps: PackedStringArray = prop_string.split(" ")
								if prop_comps.size() > 3:
									for i in 4:
										prop_vec[i] = prop_comps[i].to_int()
								else:
									push_error("Invalid Vector4i format for \'" + property + "\' in entity \'" + classname + "\': " + prop_string)
								properties[property] = prop_vec
							TYPE_NODE_PATH:
								properties[property] = prop_string
							TYPE_OBJECT:
								properties[property] = prop_string
				
				# Assign properties not defined with defaults from the entity definition
				for property in entity_definitions[classname].class_properties:
					if not property in properties:
						var prop_default: Variant = entity_definition.class_properties[property]
						# Flags
						if prop_default is Array:
							var prop_flags_sum := 0
							for prop_flag in prop_default:
								if prop_flag is Array and prop_flag.size() > 2:
									if prop_flag[2] and prop_flag[1] is int:
										prop_flags_sum += prop_flag[1]
							properties[property] = prop_flags_sum
						# Choices
						elif prop_default is Dictionary:
							var prop_desc = entity_definition.class_property_descriptions[property]
							if prop_desc is Array and prop_desc.size() > 1 and (prop_desc[1] is int or prop_desc[1] is String):
								properties[property] = prop_desc[1]
							else:
								properties[property] = 0
						elif prop_default is Resource:
							properties[property] = prop_default.resource_path
						# Everything else
						else:
							properties[property] = prop_default
						
				if entity_definition.auto_apply_to_matching_node_properties:
					for property in properties:
						if property in entity_node:
							if typeof(entity_node.get(property)) == typeof(properties[property]):
								entity_node.set(property, properties[property])
							else:
								push_error("Entity %s property \'%s\' type mismatch with matching generated node property." % [entity_node.name, property])
		
		if 'func_godot_properties' in entity_node:
			entity_node.func_godot_properties = properties
		
		if entity_node.has_method("_func_godot_apply_properties"):
			entity_node.call("_func_godot_apply_properties", properties)
		
		if entity_node.has_method("_func_godot_build_complete"):
			entity_node.call_deferred("_func_godot_build_complete")

# Cleanup after build is finished (internal)
func _build_complete():
	reset_build_context()
	stop_profile('build_map')
	print('Build complete\n')
	emit_signal("build_complete")
