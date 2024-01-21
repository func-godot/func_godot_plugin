class_name FuncGodotMapData extends RefCounted

var entities: Array[FuncGodotMapData.Entity]
var entity_geo: Array[FuncGodotMapData.EntityGeometry]
var textures: Array[FuncGodotMapData.TextureData]

func register_texture(name: String) -> int:
	for i in range(textures.size()):
		if textures[i].name == name:
			return i
	
	textures.append(TextureData.new(name))
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

func set_spawn_type_by_classname(key: String, spawn_type: EntitySpawnType) -> void:
	for entity in entities:
		if entity.properties.has("classname") and entity.properties["classname"] == key:
			entity.spawn_type = spawn_type

func clear() -> void:
	entities.clear()
	entity_geo.clear()
	textures.clear()

# --------------------------------------------------------------------------------------------------
# Nested Types
# --------------------------------------------------------------------------------------------------
enum EntitySpawnType{
	WORLDSPAWN = 0,
	MERGE_WORLDSPAWN = 1,
	ENTITY = 2
}

class FacePoints:
	var v0: Vector3
	var v1: Vector3
	var v2: Vector3

class ValveTextureAxis:
	var axis: Vector3
	var offset: float
	
class ValveUV:
	var u: ValveTextureAxis
	var v: ValveTextureAxis
	
	func _init() -> void:
		u = ValveTextureAxis.new()
		v = ValveTextureAxis.new()
	
class FaceUVExtra:
	var rot: float
	var scale_x: float
	var scale_y: float
	
class Face:
	var plane_points: FacePoints
	var plane_normal: Vector3
	var plane_dist: float
	var texture_idx: int
	var is_valve_uv: bool
	var uv_standard: Vector2
	var uv_valve: ValveUV
	var uv_extra: FaceUVExtra
	
	func _init() -> void:
		plane_points = FacePoints.new()
		uv_valve = ValveUV.new()
		uv_extra = FaceUVExtra.new()

class Brush:
	var faces: Array[Face]
	var center: Vector3

class Entity:
	var properties: Dictionary
	var brushes: Array[Brush]
	var center: Vector3
	var spawn_type: EntitySpawnType
	
class FaceVertex:
	var vertex: Vector3
	var normal: Vector3
	var uv: Vector2
	var tangent: Vector4
	
	func duplicate() -> FaceVertex:
		var new_vert := FaceVertex.new()
		new_vert.vertex = vertex
		new_vert.normal = normal
		new_vert.uv = uv
		new_vert.tangent = tangent
		return new_vert
	
class FaceGeometry:
	var vertices: Array[FaceVertex]
	var indicies: Array[int]

class BrushGeometry:
	var faces: Array[FaceGeometry]
	
class EntityGeometry:
	var brushes: Array[BrushGeometry]

class TextureData:
	var name: String
	var width: int
	var height: int
	
	func _init(in_name: String):
		name = in_name