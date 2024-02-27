class_name FuncGodotMapData extends RefCounted

var entities: Array[FuncGodotMapData.FuncGodotEntity]
var entity_geo: Array[FuncGodotMapData.FuncGodotEntityGeometry]
var textures: Array[FuncGodotMapData.FuncGodotTextureData]

func register_texture(name: String) -> int:
	for i in range(textures.size()):
		if textures[i].name == name:
			return i
	
	textures.append(FuncGodotTextureData.new(name))
	return textures.size() - 1

func set_texture_size(name: String, width: int, height: int) -> void:
	for i in range(textures.size()):
		if textures[i].name == name:
			textures[i].width = width
			textures[i].height = height
			return

func find_texture(texture_name: String) -> int:
	for i in range(textures.size()):
		if textures[i].name == texture_name:
			return i
	return -1

func set_entity_types_by_classname(classname: String, spawn_type: int, origin_type: int) -> void:
	for entity in entities:
		if entity.properties.has("classname") and entity.properties["classname"] == classname:
			entity.spawn_type = spawn_type as FuncGodotMapData.FuncGodotEntitySpawnType
			if entity.spawn_type == FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY:
				entity.origin_type = origin_type as FuncGodotMapData.FuncGodotEntityOriginType
			else:
				entity.origin_type = FuncGodotMapData.FuncGodotEntityOriginType.IGNORE

func clear() -> void:
	entities.clear()
	entity_geo.clear()
	textures.clear()

# --------------------------------------------------------------------------------------------------
# Nested Types
# --------------------------------------------------------------------------------------------------
enum FuncGodotEntitySpawnType {
	WORLDSPAWN = 0,
	MERGE_WORLDSPAWN = 1,
	ENTITY = 2
}

enum FuncGodotEntityOriginType {
	IGNORE = 0,
	ABSOLUTE = 1,
	RELATIVE = 2
}

class FuncGodotFacePoints:
	var v0: Vector3
	var v1: Vector3
	var v2: Vector3

class FuncGodotValveTextureAxis:
	var axis: Vector3
	var offset: float
	
class FuncGodotValveUV:
	var u: FuncGodotValveTextureAxis
	var v: FuncGodotValveTextureAxis
	
	func _init() -> void:
		u = FuncGodotValveTextureAxis.new()
		v = FuncGodotValveTextureAxis.new()
	
class FuncGodotFaceUVExtra:
	var rot: float
	var scale_x: float
	var scale_y: float
	
class FuncGodotFace:
	var plane_points: FuncGodotFacePoints
	var plane_normal: Vector3
	var plane_dist: float
	var texture_idx: int
	var is_valve_uv: bool
	var uv_standard: Vector2
	var uv_valve: FuncGodotValveUV
	var uv_extra: FuncGodotFaceUVExtra
	
	func _init() -> void:
		plane_points = FuncGodotFacePoints.new()
		uv_valve = FuncGodotValveUV.new()
		uv_extra = FuncGodotFaceUVExtra.new()

class FuncGodotBrush:
	var faces: Array[FuncGodotFace]
	var center: Vector3

class FuncGodotEntity:
	var properties: Dictionary
	var brushes: Array[FuncGodotBrush]
	var center: Vector3
	var spawn_type: FuncGodotEntitySpawnType
	var origin_type: FuncGodotEntityOriginType
	
class FuncGodotFaceVertex:
	var vertex: Vector3
	var normal: Vector3
	var uv: Vector2
	var tangent: Vector4
	
	func duplicate() -> FuncGodotFaceVertex:
		var new_vert := FuncGodotFaceVertex.new()
		new_vert.vertex = vertex
		new_vert.normal = normal
		new_vert.uv = uv
		new_vert.tangent = tangent
		return new_vert
	
class FuncGodotFaceGeometry:
	var vertices: Array[FuncGodotFaceVertex]
	var indicies: Array[int]

class FuncGodotBrushGeometry:
	var faces: Array[FuncGodotFaceGeometry]
	
class FuncGodotEntityGeometry:
	var brushes: Array[FuncGodotBrushGeometry]

class FuncGodotTextureData:
	var name: String
	var width: int
	var height: int
	
	func _init(in_name: String):
		name = in_name
