class_name FuncGodotSurfaceGatherer extends RefCounted

var map_data: FuncGodotMapData
var split_type: SurfaceSplitType = SurfaceSplitType.NONE
var entity_filter_idx: int = -1
var texture_filter_idx: int = -1
var clip_filter_texture_idx: int
var skip_filter_texture_idx: int
var include_face_texture_info: bool = false

var out_surfaces: Array[FuncGodotMapData.FuncGodotFaceGeometry]
var out_texture_info_split_none: Array[EntityTextureIndexRanges]
# entities -> brushes -> dictionaries. Each dictionary maps normal vector -> texture idx.
var out_texture_info_split_brush: Array[Array]

func _init(in_map_data: FuncGodotMapData) -> void:
	map_data = in_map_data

func set_texture_filter(texture_name: String) -> void:
	texture_filter_idx = map_data.find_texture(texture_name)

func set_clip_filter_texture(texture_name: String) -> void:
	clip_filter_texture_idx = map_data.find_texture(texture_name)
	
func set_skip_filter_texture(texture_name: String) -> void:
	skip_filter_texture_idx = map_data.find_texture(texture_name)

func filter_entity(entity_idx: int) -> bool:
	if entity_filter_idx != -1 and entity_idx != entity_filter_idx:
		return true
	return false

func filter_face(entity_idx: int, brush_idx: int, face_idx: int) -> bool:
	var face: FuncGodotMapData.FuncGodotFace = map_data.entities[entity_idx].brushes[brush_idx].faces[face_idx]
	var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = map_data.entity_geo[entity_idx].brushes[brush_idx].faces[face_idx]
	
	if face_geo.vertices.size() < 3:
		return true
		
	if clip_filter_texture_idx != -1 and face.texture_idx == clip_filter_texture_idx:
		return true
		
	# omit faces textured with skip
	if skip_filter_texture_idx != -1 and face.texture_idx == skip_filter_texture_idx:
		return true
	
	# omit filtered texture indices
	if texture_filter_idx != -1 and face.texture_idx != texture_filter_idx:
		return true
	
	return false

func run() -> void:
	out_surfaces.clear()
	out_texture_info_split_none.clear()
	out_texture_info_split_brush.clear()
	
	var index_offset: int = 0
	var surf: FuncGodotMapData.FuncGodotFaceGeometry
	
	if split_type == SurfaceSplitType.NONE:
		surf = add_surface()
		index_offset = len(out_surfaces) - 1
		
	for e in range(map_data.entities.size()):
		var entity:= map_data.entities[e]
		var entity_geo:= map_data.entity_geo[e]
		
		if filter_entity(e):
			continue
		
		# used if tracking the ranges of mesh indices which correspond to
		# textures in a concave mesh
		var entity_index_texture_ranges := EntityTextureIndexRanges.new()
		var index_position: int = 0
		# used if tracking the normals which correspond to textures in a convex
		# brush
		var brushes_normal_to_texture_map: Array[Dictionary]
		
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
			var normal_to_texture_map := {}
			
			if split_type == SurfaceSplitType.BRUSH:
				index_offset = 0
				surf = add_surface()
				
			for f in range(brush.faces.size()):
				var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f]
				var face := brush.faces[f]
				
				if include_face_texture_info and split_type == SurfaceSplitType.BRUSH:
					# include textures in normal -> texture map even if filtered, as this
					# information corresponds with convex collision shapes whose faces are not
					# filtered
					var godot_normal := Vector3(face.plane_normal.y, face.plane_normal.z, face.plane_normal.x)
					normal_to_texture_map[godot_normal] = map_data.textures[face.texture_idx].name
				
				if filter_face(e, b, f):
					continue
				
				for v in range(face_geo.vertices.size()):
					var vert: FuncGodotMapData.FuncGodotFaceVertex = face_geo.vertices[v].duplicate()
					
					if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY:
						vert.vertex -= entity.center
					
					surf.vertices.append(vert)
				
				var num_tris: int = face_geo.vertices.size() - 2
				for i in range(num_tris * 3):
					surf.indicies.append(face_geo.indicies[i] + index_offset)
				
				if include_face_texture_info and split_type == SurfaceSplitType.NONE:
					var range := BrushTextureIndexRange.new()
					range.texture_name = map_data.textures[face.texture_idx].name
					range.start = index_position
					range.end = index_position + num_tris
					entity_index_texture_ranges.ranges.append(range)
					index_position += num_tris
				
				index_offset += face_geo.vertices.size()
			
			if include_face_texture_info:
				brushes_normal_to_texture_map.append(normal_to_texture_map)
		
		if include_face_texture_info:
			if split_type == SurfaceSplitType.NONE:
				out_texture_info_split_none.append(entity_index_texture_ranges)
			elif split_type == SurfaceSplitType.BRUSH:
				out_texture_info_split_brush.append(brushes_normal_to_texture_map)

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

class BrushTextureIndexRange:
	var texture_name: String
	var start: int
	var end: int

class EntityTextureIndexRanges:
	var ranges: Array[BrushTextureIndexRange]

# nested
enum SurfaceSplitType{
	NONE,
	ENTITY,
	BRUSH
}
