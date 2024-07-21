class_name FuncGodotConcavePolygonShape3D
extends ConcavePolygonShape3D

# Internal data, do not set from editor or access
# Each dictionary contains:
# - texture_name: String
# - start: int (beginning of face index range, inclusive)
# - end: int (end of face index range, exclusive)
@export var _generated_texture_lookup: Array[Dictionary]

# Get the texture of a face on this shape, given the index of the face of the
# collision shape. Returns empty string if the face index is out of bounds
func get_texture_of_collision(face_index: int) -> String:
	# NOTE: face ranges are sorted, this could be binary search
	for range in _generated_texture_lookup:
		var start := range["start"] as int
		var end := range["end"] as int
		if face_index >= start and face_index < end:
			return range["texture_name"] as String

	return ""

func populate_texture_info(index_ranges: Array[Dictionary]) -> void:
	_generated_texture_lookup = index_ranges
