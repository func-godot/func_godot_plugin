class_name FuncGodotSurfaceGatherer extends RefCounted

var map_data: FuncGodotMapData
var split_type: SurfaceSplitType = SurfaceSplitType.NONE
var entity_filter_idx: int = -1
var texture_filter_idx: int = -1
var clip_filter_texture_idx: int
var skip_filter_texture_idx: int

var out_surfaces: Array[FuncGodotMapData.FuncGodotFaceGeometry]

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
	
func filter_brush(entity_idx: int, brush_idx: int) -> bool:
	var entity:= map_data.entities[entity_idx]
	var brush:= entity.brushes[brush_idx]
	
	# omit brushes that are fully-textured with clip
	if clip_filter_texture_idx != -1:
		var fully_textured: bool = true
		for face in brush.faces:
			if face.texture_idx != clip_filter_texture_idx:
				fully_textured = false
				break
		
		if fully_textured:
			return true
	
	return false

func filter_face(entity_idx: int, brush_idx: int, face_idx: int) -> bool:
	var face:= map_data.entities[entity_idx].brushes[brush_idx].faces[face_idx]
	var face_geo:= map_data.entity_geo[entity_idx].brushes[brush_idx].faces[face_idx]
	
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
			
		if split_type == SurfaceSplitType.ENTITY:
			if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.MERGE_WORLDSPAWN:
				add_surface()
				surf = out_surfaces[0]
				index_offset = surf.vertices.size()
			else:
				surf = add_surface()
				index_offset = surf.vertices.size()
				
		for b in range(entity.brushes.size()):
			if filter_brush(e, b):
				continue
			
			var brush:= entity.brushes[b]
			var brush_geo:= entity_geo.brushes[b]
			
			if split_type == SurfaceSplitType.BRUSH:
				index_offset = 0
				surf = add_surface()
				
			for f in range(brush.faces.size()):
				var face_geo:= brush_geo.faces[f]
				
				if filter_face(e, b, f):
					continue
				
				for v in range(face_geo.vertices.size()):
					var vert:= face_geo.vertices[v].duplicate()
					
					if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY:
						vert.vertex -= entity.center
					
					surf.vertices.append(vert)
					
				for i in range((face_geo.vertices.size() - 2) * 3):
					surf.indicies.append(face_geo.indicies[i] + index_offset)
				
				index_offset += face_geo.vertices.size()

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

# nested
enum SurfaceSplitType{
	NONE,
	ENTITY,
	BRUSH
}
