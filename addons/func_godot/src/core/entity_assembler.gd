@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotEntityAssembler extends RefCounted
## Entity assembly class that is instantiated by a [FuncGodotMap] node.

const _SIGNATURE: String = "[ENT]"

# Namespacing
const _GroupData	:= FuncGodotData.GroupData
const _EntityData	:= FuncGodotData.EntityData

# Class members
## [FuncGodotMapSettings] provided by the [FuncGodotMap] during the build process.
var map_settings: FuncGodotMapSettings = null
## [enum FuncGodotMap.BuildFlags] that may affect the build process provided by the [FuncGodotMap].
var build_flags: int = 0

# Signals
## Emitted when a step in the entity assembly process is completed. 
## It is connected to [method FuncGodotUtil.print_profile_info] method if [member FuncGodotMap.build_flags] SHOW_PROFILE_INFO flag is set.
signal declare_step(step: String)

func _init(settings: FuncGodotMapSettings) -> void:
	map_settings = settings

## Attempts to retrieve a [Script] via class name, to allow for [GDScript] class instantiation.
static func get_script_by_class_name(name_of_class: String) -> Script:
	if ResourceLoader.exists(name_of_class, "Script"):
		return load(name_of_class) as Script
	for global_class in ProjectSettings.get_global_class_list():
		var found_name_of_class : String = global_class["class"]
		var found_path : String = global_class["path"]
		if found_name_of_class == name_of_class:
			return load(found_path) as Script
	return null

## Generates a [Node3D] for a group's [SceneTree] representation and links the new [Node3D] to that group.
func generate_group_node(group_data: _GroupData) -> Node3D:
	var group_node := Node3D.new()
	group_node.name = group_data.name
	group_data.node = group_node
	return group_node

## Generates and assembles a new [Node] based upon processed [FuncGodotData.EntityData]. Depending upon provided data, 
## additional [MeshInstance3D], [CollisionShape3D], and [OccluderInstance3D] nodes may also be generated.
func generate_solid_entity_node(node: Node, node_name: String, data: _EntityData, definition: FuncGodotFGDSolidClass) -> Node:
	if definition.spawn_type == FuncGodotFGDSolidClass.SpawnType.MERGE_WORLDSPAWN:
		return null
	
	if definition.node_class != "":
		if ClassDB.class_exists(definition.node_class):
				node = ClassDB.instantiate(definition.node_class)
		else:
			var script: Script = get_script_by_class_name(definition.node_class)
			if script is Script:
				node = script.new()
	else:
		node = Node3D.new()
	
	node.name = node_name
	node_name = node_name.trim_suffix(definition.classname).trim_suffix("_")
	var properties: Dictionary[String, Variant] = data.properties
	
	# Mesh Instance generation
	if data.mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = node_name + "_mesh_instance"
		mesh_instance.mesh = data.mesh
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if definition.global_illumination_mode:
			mesh_instance.gi_mode = definition.global_illumination_mode
		mesh_instance.cast_shadow = definition.shadow_casting_setting
		mesh_instance.layers = definition.render_layers
		node.add_child(mesh_instance)
		data.mesh_instance = mesh_instance
		
		# Occluder generation
		if definition.build_occlusion and data.mesh:
			var verts: PackedVector3Array = []
			var indices: PackedInt32Array = []
			var index: int = 0
			for surf_idx in range(data.mesh.get_surface_count()):
				var vert_count: int = verts.size()
				var surf_array: Array = data.mesh.surface_get_arrays(surf_idx)
				verts.append_array(surf_array[Mesh.ARRAY_VERTEX])
				indices.resize(indices.size() + surf_array[Mesh.ARRAY_INDEX].size())
				for new_index in surf_array[Mesh.ARRAY_INDEX]:
					indices[index] = (new_index + vert_count)
					index += 1
			
			var occluder := ArrayOccluder3D.new()
			occluder.set_arrays(verts, indices)
			var occluder_instance := OccluderInstance3D.new()
			occluder_instance.name = node_name + "_occluder_instance"
			occluder_instance.occluder = occluder
			node.add_child(occluder_instance)
			data.occluder_instance = occluder_instance
		
		# NOTE: Currently occuring in EntityAssembler until the appropriate method in GeometryGenerator is resolved
		# For now, smooth entire mesh, then unwrap for lightmap if needed
		if not (build_flags & FuncGodotMap.BuildFlags.DISABLE_SMOOTHING) and data.is_smooth_shaded(map_settings.entity_smoothing_property):
			mesh_instance.mesh = FuncGodotUtil.smooth_mesh_by_angle(data.mesh, data.get_smoothing_angle(map_settings.entity_smoothing_angle_property))

			if data.is_gi_enabled() and (build_flags & FuncGodotMap.BuildFlags.UNWRAP_UV2):
				mesh_instance.mesh.lightmap_unwrap(
					Transform3D.IDENTITY,
					map_settings.uv_unwrap_texel_size * map_settings.scale_factor
				)

	# Collision generation
	if data.shapes.size() and node is CollisionObject3D:
		node.collision_layer = definition.collision_layer
		node.collision_mask = definition.collision_mask
		node.collision_priority = definition.collision_priority
		
		var shape_to_face_array : Array[PackedInt32Array] = []
		if data.mesh_metadata.has('shape_to_face_array'):
			shape_to_face_array = data.mesh_metadata['shape_to_face_array']
			data.mesh_metadata.erase('shape_to_face_array')
		
		# Generate CollisionShape3D nodes and apply shapes
		var face_index_metadata : Dictionary[String, PackedInt32Array] = {}
		for i in data.shapes.size():
			var shape := data.shapes[i]
			var collision_shape := CollisionShape3D.new()
			if definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.CONCAVE:
				collision_shape.name = node_name + "_collision_shape"
			else:
				collision_shape.name = node_name + "_brush_%s_collision_shape" % i
			collision_shape.shape = shape
			collision_shape.shape.margin = definition.collision_shape_margin
			collision_shape.owner = node.owner
			node.add_child(collision_shape)
			data.collision_shapes.append(collision_shape)
			if shape_to_face_array.size() > i:
				face_index_metadata[collision_shape.name] = shape_to_face_array[i]
		
		if definition.add_collision_shape_to_face_indices_metadata:
			data.mesh_metadata['collision_shape_to_face_indices_map'] = face_index_metadata

	if "position" in node:
		if node.position is Vector3:
			node.position = FuncGodotUtil.id_to_opengl(data.origin)
		elif node.position is Vector2:
			node.position = Vector2(data.origin.z, -data.origin.y) * map_settings.inverse_scale_factor
	
	if not data.mesh_metadata.is_empty():
		node.set_meta("func_godot_mesh_data", data.mesh_metadata)
	
	return node

## Generates and assembles a new [Node] or [PackedScene] based upon processed [FuncGodotData.EntityData].
func generate_point_entity_node(node: Node, node_name: String, properties: Dictionary, definition: FuncGodotFGDPointClass) -> Node:
	var classname: String = properties["classname"]
	
	if definition.scene_file:
		var flag: PackedScene.GenEditState = PackedScene.GEN_EDIT_STATE_DISABLED
		if Engine.is_editor_hint():
			flag = PackedScene.GEN_EDIT_STATE_INSTANCE
		node = definition.scene_file.instantiate(flag)
	elif definition.node_class != "":
		if ClassDB.class_exists(definition.node_class):
				node = ClassDB.instantiate(definition.node_class)
		else:
			var script: Script = get_script_by_class_name(definition.node_class)
			if script is Script:
				node = script.new()
	if not node:
		node = Node3D.new()
	
	node.name = node_name
	
	if "rotation_degrees" in node and definition.apply_rotation_on_map_build:
		var angles := Vector3.ZERO
		if "angles" in properties or "mangle" in properties:
			var key := "angles" if "angles" in properties else "mangle"
			var angles_raw = properties[key]
			if angles_raw is String:
				angles_raw = angles_raw.split_floats(' ')
				if angles_raw.size() < 3:
					push_error("Invalid vector format for \"" + key + "\" in entity \"" + classname + "\"")
					angles_raw = null
			if angles_raw:
				angles = Vector3(-angles_raw[0], angles_raw[1], -angles_raw[2])
				if key == "mangle":
					if definition.classname.begins_with("light"):
						angles = Vector3(angles_raw[1], angles_raw[0], -angles_raw[2])
					elif definition.classname == "info_intermission":
						angles = Vector3(angles_raw[0], angles_raw[1], -angles_raw[2])
		elif "angle" in properties:
			var angle = properties["angle"]
			if not angle is float:
				angle = float(angle)
			if is_equal_approx(angle, -1):
				angles.x = 90
			elif is_equal_approx(angle, -2):
				angles.x = -90
			else:
				angles.y += angle
		angles.y += 180
		node.rotation_degrees = angles
	
	if "scale" in node and definition.apply_scale_on_map_build:
		if "scale" in properties:
			var scale_prop: Variant = properties["scale"]
			if typeof(scale_prop) == TYPE_STRING:
				var scale_arr: PackedStringArray = (scale_prop as String).split(" ")
				match scale_arr.size():
					1: scale_prop = scale_arr[0].to_float()
					3: scale_prop = Vector3(scale_arr[1].to_float(), scale_arr[2].to_float(), scale_arr[0].to_float())
					2: scale_prop = Vector2(scale_arr[0].to_float(), scale_arr[0].to_float())
			if typeof(scale_prop) == TYPE_FLOAT or typeof(scale_prop) == TYPE_INT:
				node.scale *= scale_prop as float
			elif node.scale is Vector3:
				if typeof(scale_prop) == TYPE_VECTOR3 or typeof(scale_prop) == TYPE_VECTOR3I:
					node.scale *= scale_prop as Vector3
			elif node.scale is Vector2:
				if typeof(scale_prop) == TYPE_VECTOR2 or typeof(scale_prop) == TYPE_VECTOR2I:
					node.scale *= scale_prop as Vector2
	
	if "origin" in properties:
		var origin_vec: Vector3 = Vector3.ZERO
		var origin_prop = properties['origin']
		if origin_prop is Vector3:
			origin_vec = Vector3(origin_prop.y, origin_prop.z, origin_prop.x)
		elif origin_prop is String:
			var origin_comps: PackedFloat64Array = properties['origin'].split_floats(' ')
			if origin_comps.size() > 2:
				origin_vec = Vector3(origin_comps[1], origin_comps[2], origin_comps[0])
			else:
				push_error("Invalid vector format for \"origin\" in " + node_name)
		else:
			push_error("Invalid vector format for \"origin\" in " + node_name)
		
		if "position" in node:
			if node.position is Vector3:
				node.position = origin_vec * map_settings.scale_factor
			elif node.position is Vector2:
				node.position = Vector2(origin_vec.z, -origin_vec.y)
	
	return node

## Converts the [String] values of the entity data's [code]properties[/code] [Dictionary] to various [Variant] formats 
## based upon the [FuncGodotFGDEntity]'s class properties, then attempts to send those properties to a [code]func_godot_properties[/code] [Dictionary] 
## and an [code]_func_godot_apply_properties(properties: Dictionary)[/code] method on the node. A deferred call to [code]_func_godot_build_complete()[/code] is also made.
func apply_entity_properties(node: Node, data: _EntityData) -> void:
	var properties: Dictionary[String, Variant] = data.properties
	
	if data.definition:
		var def := data.definition
		if def.auto_apply_to_matching_node_properties:
			for property in properties:
				if property == 'scale' and def is FuncGodotFGDPointClass and def.apply_scale_on_map_build:
					# scale has already been applied
					continue
				if property in node:
					if typeof(node.get(property)) == typeof(properties[property]):
						node.set(property, properties[property])
					else:
						push_error("Entity %s property \'%s\' type mismatch with matching generated node property." % [node.name, property])
	
	if "func_godot_properties" in node:
		node.func_godot_properties = properties
	
	if node.has_method("_func_godot_apply_properties"):
		node.call("_func_godot_apply_properties", properties)
	
	if node.has_method("_func_godot_build_complete"):
		node.call_deferred("_func_godot_build_complete")

## Generate a [Node] from [FuncGodotData.EntityData]. The returned node value can be [code]null[/code], 
## in the case of [FuncGodotFGDSolidClass] entities with no [FuncGodotData.BrushData] entries.
func generate_entity_node(entity_data: _EntityData, entity_index: int) -> Node:
	var node: Node = null
	var node_name: String = "entity_%s" % entity_index
	var properties: Dictionary[String, Variant] = entity_data.properties
	var entity_def: FuncGodotFGDEntityClass = entity_data.definition
	
	if "classname" in entity_data.properties:
		var classname: String = properties["classname"]
	
	node_name += "_" + properties["classname"]
	
	var name_prop: String
	if entity_def.name_property in properties:
		name_prop = str(properties[entity_def.name_property])
	elif map_settings.entity_name_property in properties:
		name_prop = str(properties[map_settings.entity_name_property])
	if not name_prop.is_empty():
		node_name = "entity_" + name_prop
	
	if entity_def is FuncGodotFGDSolidClass:
		node = generate_solid_entity_node(node, node_name, entity_data, entity_def)
	elif entity_def is FuncGodotFGDPointClass:
		node = generate_point_entity_node(node, node_name, properties, entity_def)
	
	if node:
		if entity_def.script_class:
			node.set_script(entity_def.script_class)
		
		var node_groups: Array[String] = map_settings.entity_node_groups.duplicate()
		node_groups.append_array(entity_def.node_groups)
		for node_group in node_groups:
			if node_group.is_empty():
				continue
			node.add_to_group(node_group, true)
	
	return node

## Main entity assembly process called by [FuncGodotMap]. Generates and sorts group nodes in the [SceneTree] first, 
## then generates and assembles [Node]s based upon the provided [FuncGodotData.EntityData] and adds them to the [SceneTree].
func build(map_node: FuncGodotMap, entities: Array[_EntityData], groups: Array[_GroupData]) -> void:
	var scene_root := map_node.get_tree().edited_scene_root if map_node.is_inside_tree() else map_node
	build_flags = map_node.build_flags
	
	if map_settings.use_groups_hierarchy:
		declare_step.emit("Generating %s groups" % groups.size())
		# Generate group nodes
		for group in groups:
			group.node = generate_group_node(group)
		# Sort hierarchy and add them to the map
		for group in groups:
			if group.parent_id < 0:
				map_node.add_child(group.node)
				group.node.owner = scene_root
			else:
				for parent in groups:
					if group.parent_id == parent.id:
						parent.node.add_child(group.node)
						group.node.owner = scene_root
		declare_step.emit("Groups generation and sorting complete")
	
	declare_step.emit("Assembling %s entities" % entities.size())
	var entity_node: Node = null
	for entity_index in entities.size():
		var entity_data : _EntityData = entities[entity_index]
		entity_node = generate_entity_node(entity_data, entity_index)
		if entity_node:
			if not map_settings.use_groups_hierarchy or not entity_data.group:
				map_node.add_child(entity_node)
				if entity_index == 0:
					map_node.move_child(entity_node, 0)
			elif map_settings.use_groups_hierarchy:
				for group in groups:
					if entity_data.group.id == group.id:
						group.node.add_child(entity_node)
			
			entity_node.owner = scene_root
			if entity_data.mesh_instance:
				entity_data.mesh_instance.owner = scene_root
			for shape in entity_data.collision_shapes:
				if shape:
					shape.owner = scene_root
			if entity_data.occluder_instance:
				entity_data.occluder_instance.owner = scene_root
			
			apply_entity_properties(entity_node, entity_data)
	declare_step.emit("Entity assembly and property application complete")
