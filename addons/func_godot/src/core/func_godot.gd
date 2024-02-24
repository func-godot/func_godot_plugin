class_name FuncGodot extends RefCounted

var map_data:= FuncGodotMapData.new()
var map_parser:= FuncGodotMapParser.new(map_data)
var geo_generator = preload("res://addons/func_godot/src/core/func_godot_geo_generator.gd").new(map_data)
var surface_gatherer:= FuncGodotSurfaceGatherer.new(map_data)

func load_map(filename: String, keep_tb_groups: bool) -> void:
	map_parser.load(filename, keep_tb_groups)

func get_texture_list() -> PackedStringArray:
	var g_textures: PackedStringArray
	var tex_count: int = map_data.textures.size()
	
	g_textures.resize(tex_count)
	for i in range(tex_count):
		g_textures.set(i, map_data.textures[i].name)
	
	return g_textures

func set_entity_definitions(entity_defs: Dictionary) -> void:
	for i in range(entity_defs.size()):
		var classname: String = entity_defs.keys()[i]
		var spawn_type: int = entity_defs.values()[i].get("spawn_type", FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY)
		var origin_type: int = entity_defs.values()[i].get("origin_type", FuncGodotMapData.FuncGodotEntityOriginType.IGNORE)
		map_data.set_entity_types_by_classname(classname, spawn_type, origin_type)

func generate_geometry(texture_dict: Dictionary) -> void:
	var keys: Array = texture_dict.keys()
	for key in keys:
		var val: Vector2 = texture_dict[key]
		map_data.set_texture_size(key, val.x, val.y)
	geo_generator.run()

func get_entity_dicts() -> Array:
	var ent_dicts: Array
	for entity in map_data.entities:
		var dict: Dictionary
		dict["brush_count"] = entity.brushes.size()
		
		# TODO: This is a horrible remnant of the worldspawn layer system, remove it.
		var brush_indices: PackedInt64Array
		brush_indices.resize(entity.brushes.size())
		for b in range(entity.brushes.size()):
			brush_indices[b] = b
		
		dict["brush_indices"] = brush_indices
		dict["center"] = Vector3(entity.center.y, entity.center.z, entity.center.x)
		dict["properties"] = entity.properties
		
		ent_dicts.append(dict)
	
	return ent_dicts

func gather_texture_surfaces_mt(texture_name: String, clip_filter_texture: String, skip_filter_texture: String, inverse_scale_factor: float) -> Array:
	var sg: FuncGodotSurfaceGatherer = FuncGodotSurfaceGatherer.new(map_data)
	sg.reset_params()
	sg.split_type = FuncGodotSurfaceGatherer.SurfaceSplitType.ENTITY
	sg.set_texture_filter(texture_name)
	sg.set_clip_filter_texture(clip_filter_texture)
	sg.set_skip_filter_texture(skip_filter_texture)
	sg.run()
	return _fetch_surfaces_internal(sg, inverse_scale_factor)

func gather_worldspawn_layer_surfaces(texture_name: String, clip_filter_texture: String, skip_filter_texture: String) -> void:
	_gather_texture_surfaces_internal(texture_name, clip_filter_texture, skip_filter_texture)

func gather_entity_convex_collision_surfaces(entity_idx: int) -> void:
	_gather_convex_collision_surfaces(entity_idx)
	
func gather_entity_concave_collision_surfaces(entity_idx: int, skip_filter_texture: String) -> void:
	_gather_concave_collision_surfaces(entity_idx, skip_filter_texture)
	
func gather_worldspawn_layer_collision_surfaces(entity_idx: int) -> void:
	_gather_convex_collision_surfaces(entity_idx)

func fetch_surfaces(inverse_scale_factor: float) -> Array:	
	return _fetch_surfaces_internal(surface_gatherer, inverse_scale_factor)

func _fetch_surfaces_internal(surf_gatherer: FuncGodotSurfaceGatherer, inverse_scale_factor: float) -> Array:	
	var surfs: Array[FuncGodotMapData.FuncGodotFaceGeometry] = surf_gatherer.out_surfaces
	var surf_array: Array
	
	for surf in surfs:
		if surf == null or surf.vertices.size() == 0:
			surf_array.append(null)
			continue
			
		var vertices: PackedVector3Array
		var normals: PackedVector3Array
		var tangents: PackedFloat64Array
		var uvs: PackedVector2Array
		for v in surf.vertices:
			vertices.append(Vector3(v.vertex.y, v.vertex.z, v.vertex.x) / inverse_scale_factor)
			normals.append(Vector3(v.normal.y, v.normal.z, v.normal.x))
			tangents.append(v.tangent.y)
			tangents.append(v.tangent.z)
			tangents.append(v.tangent.x)
			tangents.append(v.tangent.w)
			uvs.append(Vector2(v.uv.x, v.uv.y))
			
		var indices: PackedInt32Array
		if surf.indicies.size() > 0:
			indices.append_array(surf.indicies)
		
		var brush_array: Array
		brush_array.resize(Mesh.ARRAY_MAX)
		
		brush_array[Mesh.ARRAY_VERTEX] = vertices
		brush_array[Mesh.ARRAY_NORMAL] = normals
		brush_array[Mesh.ARRAY_TANGENT] = tangents
		brush_array[Mesh.ARRAY_TEX_UV] = uvs
		brush_array[Mesh.ARRAY_INDEX] = indices
		
		surf_array.append(brush_array)
		
	return surf_array

# internal
func _gather_texture_surfaces_internal(texture_name: String, clip_filter_texture: String, skip_filter_texture: String) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = FuncGodotSurfaceGatherer.SurfaceSplitType.ENTITY
	surface_gatherer.set_texture_filter(texture_name)
	surface_gatherer.set_clip_filter_texture(clip_filter_texture)
	surface_gatherer.set_skip_filter_texture(skip_filter_texture)	
	surface_gatherer.run()

func _gather_convex_collision_surfaces(entity_idx: int) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = FuncGodotSurfaceGatherer.SurfaceSplitType.BRUSH
	surface_gatherer.entity_filter_idx = entity_idx	
	surface_gatherer.run()
	
func _gather_concave_collision_surfaces(entity_idx: int, skip_filter_texture: String) -> void:
	surface_gatherer.reset_params()
	surface_gatherer.split_type = FuncGodotSurfaceGatherer.SurfaceSplitType.NONE
	surface_gatherer.entity_filter_idx = entity_idx
	surface_gatherer.set_skip_filter_texture(skip_filter_texture)	
	surface_gatherer.run()
