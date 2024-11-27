class_name FuncGodotSurfaceGatherer extends RefCounted

var map_data: FuncGodotMapData
var map_settings: FuncGodotMapSettings
var split_type: SurfaceSplitType = SurfaceSplitType.NONE
var entity_filter_idx: int = -1
var texture_filter_idx: int = -1
var clip_filter_texture_idx: int
var skip_filter_texture_idx: int
var origin_filter_texture_idx: int
var metadata_skip_flags: int

var out_surfaces: Array[FuncGodotMapData.FuncGodotFaceGeometry]
var out_metadata: Dictionary

func _init(in_map_data: FuncGodotMapData, in_map_settings: FuncGodotMapSettings) -> void:
	map_data = in_map_data
	map_settings = in_map_settings

func set_texture_filter(texture_name: String) -> void:
	texture_filter_idx = map_data.find_texture(texture_name)

func set_clip_filter_texture(texture_name: String) -> void:
	clip_filter_texture_idx = map_data.find_texture(texture_name)
	
func set_skip_filter_texture(texture_name: String) -> void:
	skip_filter_texture_idx = map_data.find_texture(texture_name)

func set_origin_filter_texture(texture_name: String) -> void:
	origin_filter_texture_idx = map_data.find_texture(texture_name)

func filter_entity(entity_idx: int) -> bool:
	if entity_filter_idx != -1 and entity_idx != entity_filter_idx:
		return true
	return false

func filter_face(entity_idx: int, brush_idx: int, face_idx: int) -> bool:
	var face: FuncGodotMapData.FuncGodotFace = map_data.entities[entity_idx].brushes[brush_idx].faces[face_idx]
	var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = map_data.entity_geo[entity_idx].brushes[brush_idx].faces[face_idx]
	
	if face_geo.vertices.size() < 3:
		return true

	# Omit faces textured with Clip
	if clip_filter_texture_idx != -1 and face.texture_idx == clip_filter_texture_idx:
		return true
		
	# Omit faces textured with Skip
	if skip_filter_texture_idx != -1 and face.texture_idx == skip_filter_texture_idx:
		return true

	# Omit faces textured with Origin
	if origin_filter_texture_idx != -1 and face.texture_idx == origin_filter_texture_idx:
		return true
	
	# Omit filtered texture indices
	if texture_filter_idx != -1 and face.texture_idx != texture_filter_idx:
		return true
	
	return false

func run() -> void:
	out_surfaces.clear()
	var texture_names: Array[StringName] = []
	var textures: PackedInt32Array = []
	var vertices: PackedVector3Array = []
	var positions: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var shape_index_ranges: Array[Vector2i] = []
	var entity_index_ranges: Array[Vector2i] = []
	
	var index_offset: int = 0
	var entity_face_range: Vector2i = Vector2i.ZERO
	const MFlags = FuncGodotMapData.FuncGodotEntityMetadataInclusionFlags
	var build_entity_index_ranges: bool = not metadata_skip_flags & MFlags.ENTITY_INDEX_RANGES
	var surf: FuncGodotMapData.FuncGodotFaceGeometry
	
	if split_type == SurfaceSplitType.NONE:
		surf = add_surface()
		index_offset = len(out_surfaces) - 1
		
	for e in range(map_data.entities.size()):
		var entity:= map_data.entities[e]
		var entity_geo:= map_data.entity_geo[e]
		var shape_face_range := Vector2i.ZERO
		var total_entity_tris := 0
		var include_normals_metadata: bool = not metadata_skip_flags & MFlags.FACE_NORMAL and entity.metadata_inclusion_flags & MFlags.FACE_NORMAL
		var include_vertices_metadata: bool = not metadata_skip_flags & MFlags.VERTEX and entity.metadata_inclusion_flags & MFlags.VERTEX
		var include_textures_metadata: bool = not metadata_skip_flags & MFlags.TEXTURES and entity.metadata_inclusion_flags & MFlags.TEXTURES
		var include_positions_metadata: bool = not metadata_skip_flags & MFlags.FACE_POSITION and entity.metadata_inclusion_flags & MFlags.FACE_POSITION
		var include_shape_range_metadata: bool = not metadata_skip_flags & MFlags.COLLISION_SHAPE_TO_FACE_RANGE_MAP and entity.metadata_inclusion_flags &  MFlags.COLLISION_SHAPE_TO_FACE_RANGE_MAP
		
		if filter_entity(e):
			continue
			
		if split_type == SurfaceSplitType.ENTITY:
			if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.MERGE_WORLDSPAWN:
				add_surface()
				surf = out_surfaces[0]
				index_offset = surf.vertices.size()
			else:
				surf = add_surface()
				index_offset = surf.vertices.size()
				
		for b in range(entity.brushes.size()):
			var brush:= entity.brushes[b]
			var brush_geo:= entity_geo.brushes[b]
			var total_brush_tris:= 0
			
			if split_type == SurfaceSplitType.BRUSH:
				index_offset = 0
				surf = add_surface()
				
			for f in range(brush.faces.size()):
				var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f]
				var face: FuncGodotMapData.FuncGodotFace = brush.faces[f]
				var num_tris = face_geo.vertices.size() - 2
				
				if filter_face(e, b, f):
					continue
				
				for v in range(face_geo.vertices.size()):
					var vert: FuncGodotMapData.FuncGodotFaceVertex = face_geo.vertices[v].duplicate()
					
					if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY:
						vert.vertex -= entity.center
					
					surf.vertices.append(vert)
				
				if include_normals_metadata:
					var normal := Vector3(face.plane_normal.y, face.plane_normal.z, face.plane_normal.x)
					for i in num_tris:
						normals.append(normal)
				if include_shape_range_metadata or build_entity_index_ranges:
					total_brush_tris += num_tris
				if include_textures_metadata:
					var texname := StringName(map_data.textures[face.texture_idx].name)
					var index: int
					if texture_names.is_empty():
						texture_names.append(texname)
						index = 0
					elif texture_names.back() == texname:
						# Common case, faces with textures are next to each other
						index = texture_names.size() - 1
					else:
						var texture_name_index: int = texture_names.find(texname)
						if texture_name_index == -1:
							index = texture_names.size()
							texture_names.append(texname)
						else:
							index = texture_name_index
					# Metadata addresses triangles, so we have to duplicate the info for each tri
					for i in num_tris:
						textures.append(index)
				
				var avg_vertex_pos := Vector3.ZERO
				var avg_vertex_pos_ct: int = 0
				for i in range(num_tris * 3):
					surf.indicies.append(face_geo.indicies[i] + index_offset)
					var vertex: Vector3 = surf.vertices[surf.indicies.back()].vertex
					vertex = Vector3(vertex.y, vertex.z, vertex.x) * map_settings.scale_factor
					if include_vertices_metadata:
						vertices.append(vertex)
					if include_positions_metadata:
						avg_vertex_pos_ct += 1
						avg_vertex_pos += vertex
						if avg_vertex_pos_ct == 3:
							avg_vertex_pos /= 3
							positions.append(avg_vertex_pos)
							avg_vertex_pos = Vector3.ZERO
							avg_vertex_pos_ct = 0
				
				index_offset += face_geo.vertices.size()
			
			if include_shape_range_metadata:
				shape_face_range.x = shape_face_range.y
				shape_face_range.y = shape_face_range.x + total_brush_tris
				shape_index_ranges.append(shape_face_range)

			if build_entity_index_ranges:
				total_entity_tris += total_brush_tris

		if build_entity_index_ranges:
			entity_face_range.x = entity_face_range.y
			entity_face_range.y = entity_face_range.x + total_entity_tris
			entity_index_ranges.append(entity_face_range)

	out_metadata = {
		textures = textures,
		texture_names = texture_names,
		normals = normals,
		vertices = vertices,
		positions = positions,
		shape_index_ranges = shape_index_ranges,
	}	
	if build_entity_index_ranges:
		out_metadata["entity_index_ranges"] = entity_index_ranges

func add_surface() -> FuncGodotMapData.FuncGodotFaceGeometry:
	var surf:= FuncGodotMapData.FuncGodotFaceGeometry.new()
	out_surfaces.append(surf)
	return surf

func reset_params() -> void:
	split_type = SurfaceSplitType.NONE
	entity_filter_idx = -1
	texture_filter_idx = -1
	clip_filter_texture_idx = -1
	skip_filter_texture_idx = -1
	metadata_skip_flags = FuncGodotMapData.FuncGodotEntityMetadataInclusionFlags.ENTITY_INDEX_RANGES

# nested
enum SurfaceSplitType{
	NONE,
	ENTITY,
	BRUSH
}
