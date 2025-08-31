@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotData
## Container that holds various data structs to be used in the [FuncGodotMap] build process.
##
## FuncGodot utilizes multiple custom data structs to hold information parsed from the map file 
## and read and modified by the other core build classes. 
## All data structs extend from [RefCounted], therefore all data is passed by reference.
## [br][br]
## [FuncGodotData.FaceData][br]
## [FuncGodotData.BrushData][br]
## [FuncGodotData.PatchData][br]
## [FuncGodotData.GroupData][br]
## [FuncGodotData.EntityData][br]

## Data struct representing both a single map plane and a mesh face. Generated during parsing by plane definitions in the map file, 
## it is further modified and utilized during the geo generation stage to create the final entity meshes.
class FaceData extends RefCounted:
	## Vertex array for the face. Only populated in combination with other faces, as a result of planar intersections.
	var vertices: PackedVector3Array = []
	## Index array for the face. Used in ArrayMesh creation.
	var indices: PackedInt32Array = []
	## Vertex normal array for the face. 
	## By default, set to the planar normal, which results in flat shading. May be modified to adjust shading.
	var normals: PackedVector3Array = []
	## Tangent data for the face.
	var tangents: PackedFloat32Array = []
	## Local path to the texture without the extension, relative to the FuncGodotMap node's settings' base texture directory.
	var texture: String
	## UV transform data generated during the parsing stage. Used for both Standard and Valve 220 UV formats, 
	## though rotation is not applied to the transform when using Valve 220.
	var uv: Transform2D
	## Raw vector data provided by the Valve 220 format during parsing. It is used to calculate rotations. 
	## The presence of this data determines how face UVs and tangents are calculated.
	var uv_axes: PackedVector3Array = []
	## Raw plane data parsed from the map file using the id Tech coordinate system.
	var plane: Plane
	
	## Returns the average position of all vertices in the face. Only valid when the face has at least one vertex.
	func get_centroid() -> Vector3:
		return FuncGodotUtil.op_vec3_avg(vertices)
	
	## Returns an arbitrary coplanar direction to use for winding the face.
	## Only valid when the face has at least two vertices.
	func get_basis() -> Vector3:
		if vertices.size() < 2:
			push_error("Cannot get winding basis without at least 2 vertices!")
			return Vector3.ZERO
		return (vertices[1] - vertices[0]).normalized()
	
	## Prepares the face for OpenGL triangle winding order. 
	## Sorts the vertex array in-place by angle from the centroid.
	func wind() -> void:
		var centroid: Vector3 = get_centroid()
		var u_axis: Vector3 = get_basis()
		var v_axis: Vector3 = u_axis.cross(plane.normal).normalized()
		var cmp_winding_angle: Callable = (
			func(a: Vector3, b: Vector3) -> bool:
				var dir_a: Vector3 = a - centroid
				var dir_b: Vector3 = b - centroid
				var angle_a: float = atan2(dir_a.dot(v_axis), dir_a.dot(u_axis))
				var angle_b: float = atan2(dir_b.dot(v_axis), dir_b.dot(u_axis))
				return angle_a < angle_b
		)

		var _vertices: Array[Vector3]
		_vertices.assign(vertices)
		_vertices.sort_custom(cmp_winding_angle)
		vertices = _vertices
	
	## Repopulate the [member indices] array to create a triangle fan. 
	## The face must be properly wound for the resulting indices to be valid.
	func index_vertices() -> void:
		var tri_count: int = vertices.size() - 2
		indices.resize(tri_count * 3)
		var index: int = 0
		for i in tri_count:
			indices[index] = 0
			indices[index + 1] = i + 1
			indices[index + 2] = i + 2
			index += 3

## Data struct representing a single map format brush. It is largely meant as a container for [FuncGodotData.FaceData] data.
class BrushData extends RefCounted:
	## Raw plane data parsed from the map file using the id Tech coordinate system.
	var planes: Array[Plane]
	## Collection of [FuncGodotData.FaceData].
	var faces: Array[FaceData]
	## [code]true[/code] if this brush is completely covered in the [i]Origin[/i] texture defined in [FuncGodotMapSettings].
	## Determined during [FuncGodotParser] and utilized during [FuncGodotGeometryGenerator].
	var origin: bool = false

## Data struct representing a patch def entity.
class PatchData extends RefCounted:
	## Local path to the texture without the extension, relative to the FuncGodotMap node's settings' base texture directory.
	var texture: String
	var size: PackedInt32Array
	var points: PackedVector3Array
	var uvs: PackedVector2Array

## Data struct representing a TrenchBroom Group, TrenchBroom Layer, or Valve VisGroup. 
## Generated during the parsing stage and utilized during both parsing and entity assembly stages.
class GroupData extends RefCounted:
	enum GroupType { GROUP, LAYER, }
	## Defines whether the group is a Group or a Layer. Currently only determines the name of the group.
	var type: GroupType = GroupType.GROUP
	## Group ID retrieved from the map file. Utilized during the parsing and entity assembly stages to determine 
	## which entities belong to which groups as well as which groups are children of other groups.
	var id: int
	## Generated during the parsing stage using the format of type_id_name, eg: group_2_Arkham.
	var name: String
	## ID of the parent group data, used to determine which group data is this group's parent.
	var parent_id: int = -1
	## Pointer to another group data that this group is a child of.
	var parent: GroupData = null
	## Pointer to generated Node3D representing this group in the SceneTree.
	var node: Node3D = null
	## If true, erases all entities assigned to this group and then the group itself at the end of the parsing stage, preventing those entities from being generated into nodes. 
	## Can be set in TrenchBroom on layers using the "omit layer" option.
	var omit: bool = false

## Data struct representing a map format entity.
class EntityData extends RefCounted:
	## All of the entity's key value pairs from the map file, retrieved during parsing. 
	## The func_godot_properties dictionary generated at the end of entity assembly is derived from this.
	var properties: Dictionary = {}
	## The entity's brush data collected during the parsing stage. If the entity's FGD resource cannot be found, 
	## the presence of a single brush determines this entity to be a Solid Entity.
	var brushes: Array[BrushData] = []
	## The entity's patch def data collected during the parsing stage. If the entity's FGD resource cannot be found, 
	## the presence of a single patch def determines this entity to be a Solid Entity.
	var patches: Array[PatchData] = []
	## Pointer to the group data this entity belongs to.
	var group: GroupData = null
	## The entity's FGD resource, determined by matching the classname properties of each. 
	## This can only be a [FuncGodotFGDSolidClass], [FuncGodotFGDPointClass], or [FuncGodotFGDModelPointClass].
	var definition: FuncGodotFGDEntityClass = null
	## Mesh resource generated during the geometry generation stage and applied during the entity assembly stage.
	var mesh: ArrayMesh = null
	## MeshInstance3D node generated during the entity assembly stage.
	var mesh_instance: MeshInstance3D = null
	## Optional mesh metadata compiled during the geometry generation stage, used to determine face information from collision.
	var mesh_metadata: Dictionary = {}
	## A collection of collision shape resources generated during the geometry generation stage and applied during the entity assembly stage.
	var shapes: Array[Shape3D] = []
	## A collection of [CollisionShape3D] nodes generated during the entity assembly stage. Each node corresponds to a shape in the [member shapes] array.
	var collision_shapes: Array[CollisionShape3D] = []
	## [OccluderInstance3D] node generated during the entity assembly stage using the [member mesh] resource.
	var occluder_instance: OccluderInstance3D = null
	## True global position of the entity's generated node that the mesh's vertices are offset by during the geometry generation stage.
	var origin: Vector3 = Vector3.ZERO

	## Checks the entity's FGD resource definition, returning whether the Solid Class has a [MeshInstance3D] built for it.
	func is_visual() -> bool:
		return (definition
				and definition is FuncGodotFGDSolidClass
				and definition.build_visuals)
	
	## Checks the entity's FGD resource definition, returning whether the Solid Class CollisionShapeType is set to Convex.
	func is_collision_convex() -> bool:
		return (definition 
				and definition is FuncGodotFGDSolidClass 
				and definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.CONVEX
		)
	
	## Checks the entity's FGD resource definition, returning whether the Solid Class CollisionShapeType is set to Concave.
	func is_collision_concave() -> bool:
		return (definition 
				and definition is FuncGodotFGDSolidClass 
				and definition.collision_shape_type == FuncGodotFGDSolidClass.CollisionShapeType.CONCAVE
		)
	
	## Determines if the entity's mesh should be processed for normal smoothing. 
	## The smoothing property can be retrieved from [member FuncGodotMapSettings.entity_smoothing_property].
	func is_smooth_shaded(smoothing_property: String = "_phong") -> bool: 
		return properties.get(smoothing_property, "0").to_int()
  	
	## Retrieves the entity's smoothing angle to determine if the face should be smoothed. 
	## The smoothing angle property can be retrieved from [member FuncGodotMapSettings.entity_smoothing_angle_property].
	func get_smoothing_angle(smoothing_angle_property: String = "_phong_angle") -> float:
		return properties.get(smoothing_angle_property, "89.0").to_float()

class VertexGroupData:
	## Faces this vertex appears in.
	var faces: Array[FaceData]
	## Index within the associated face for this vertex.
	var face_indices: PackedInt32Array

class ParseData:
	var entities: Array[EntityData] = []
	var groups: Array[GroupData] = []
