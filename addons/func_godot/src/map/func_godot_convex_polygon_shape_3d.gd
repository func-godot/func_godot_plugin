class_name FuncGodotConvexPolygonShape3D
extends ConvexPolygonShape3D

const FLOATING_POINT_ERROR_EPSILON := 0.0001

# Internal data, do not set from editor or access
# maps normal Vector3 -> texture name String
@export var _generated_texture_lookup := {}

# Get the texture of a face on this shape, given the normal of collisions
# with this shape. Accounts for floating point innaccuracies
func get_texture_of_collision(normal: Vector3) -> String:
	if _generated_texture_lookup.has(normal):
		return _generated_texture_lookup[normal]

	# maybe we have it but floating point madness happened in physics,
	# given normal is just slightly different than actual
	for tex_normal in _generated_texture_lookup.keys():
		if tex_normal.dot(normal) > 1 - FLOATING_POINT_ERROR_EPSILON:
			return _generated_texture_lookup[tex_normal]

	# TODO: return another texture in the brush a best match?
	return ""

func populate_texture_info(brush: FuncGodotMapData.FuncGodotBrush, map_data: FuncGodotMapData) -> void:
	_generated_texture_lookup.clear()
	for face in brush.faces:
		var normal := face.plane_normal
		normal = Vector3(normal.y, normal.z, normal.x)
		_generated_texture_lookup[normal] = map_data.textures[face.texture_idx].name
