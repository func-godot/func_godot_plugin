@icon("res://addons/func_godot/icons/icon_slipgate.svg")
class_name FuncGodotGeometryGenerator extends RefCounted
## Geometry generation class that is instantiated by a [FuncGodotMap] node.

const _SIGNATURE: String = "[GEO]"

# Namespacing
const _VERTEX_EPSILON 	:= FuncGodotUtil._VERTEX_EPSILON
const _VERTEX_EPSILON2 	:= _VERTEX_EPSILON * _VERTEX_EPSILON

const _HYPERPLANE_SIZE	:= 65355.0

const _OriginType 	:= FuncGodotFGDSolidClass.OriginType

const _GroupData		:= FuncGodotData.GroupData
const _EntityData 		:= FuncGodotData.EntityData
const _BrushData 		:= FuncGodotData.BrushData
const _PatchData 		:= FuncGodotData.PatchData
const _FaceData 		:= FuncGodotData.FaceData
const _VertexGroupData	:= FuncGodotData.VertexGroupData

# Class members
var map_settings: FuncGodotMapSettings = null
var entity_data: Array[_EntityData]
var texture_materials: Dictionary[String, Material]
var texture_sizes: Dictionary[String, Vector2]

# Signals

## Emitted when beginning a new step of the generation process.
signal declare_step(step: String)

func _init(settings: FuncGodotMapSettings = null) -> void:
	map_settings = settings

#region TOOLS
func is_skip(face: _FaceData) -> bool:
	return FuncGodotUtil.is_skip(face.texture, map_settings)

func is_clip(face: _FaceData) -> bool:
	return FuncGodotUtil.is_clip(face.texture, map_settings)

func is_origin(face: _FaceData) -> bool:
	return FuncGodotUtil.is_origin(face.texture, map_settings)

#endregion

#region PATCHES
func sample_bezier_curve(controls: Array[Vector3], t: float) -> Vector3:
	var points: Array[Vector3] = controls.duplicate()
	for i in controls.size():
		for j in controls.size() - 1 - i:
			points[j] = points[j].lerp(points[j + 1], t)
	return points[0]

func sample_bezier_surface(controls: Array[Vector3], width: int, height: int, u: float, v: float) -> Vector3:
	var curve: Array[Vector3] = []
	for x in range(width):
		var col: Array[Vector3] = []
		for y in range(height):
			var idx := y * width + x
			col.append(controls[idx])
		curve.append(sample_bezier_curve(col, v))
	return sample_bezier_curve(curve, u)

# Generate patch triangle indices
func get_triangle_indices(width: int, height: int) -> Array[int]:
	var indices: Array[int] = []
	if width < 2 or height < 2:
		return indices
	
	for row in range(height - 1):
		for col in range(width - 1):
			## First triangle of the square; top left, top right, bottom left
			indices.append(col + row * width)             
			indices.append((col + 1) + row * width)       
			indices.append(col + (row + 1) * width)      
			 
			## Second triangle of the square; top right, bottom right, bottom left
			indices.append((col + 1) + row * width)       
			indices.append((col + 1) + (row + 1) * width) 
			indices.append(col + (row + 1) * width)      
	return indices

func create_patch_mesh(data: Array[_PatchData], mesh: Mesh):
	return

#endregion

#region BRUSHES
func generate_base_winding(plane: Plane) -> PackedVector3Array:
	var up := Vector3.UP
	if abs(plane.normal.dot(up)) > 0.9:
		up = Vector3.RIGHT

	var right: Vector3 = plane.normal.cross(up).normalized()
	var forward: Vector3 = right.cross(plane.normal).normalized()
	var centroid: Vector3 = plane.get_center()

	# construct oversized square on the plane to clip against
	var winding := PackedVector3Array()
	winding.append(centroid + (right *  _HYPERPLANE_SIZE) + (forward *  _HYPERPLANE_SIZE))
	winding.append(centroid + (right * -_HYPERPLANE_SIZE) + (forward *  _HYPERPLANE_SIZE))
	winding.append(centroid + (right * -_HYPERPLANE_SIZE) + (forward * -_HYPERPLANE_SIZE))
	winding.append(centroid + (right *  _HYPERPLANE_SIZE) + (forward * -_HYPERPLANE_SIZE))
	return winding

func generate_face_vertices(brush: _BrushData, face_index: int, vertex_merge_distance: float = 0.0) -> PackedVector3Array:
	var plane: Plane = brush.faces[face_index].plane
	
	# Generate initial square polygon to clip other planes against
	var winding: PackedVector3Array = generate_base_winding(plane)

	for other_face_index in brush.faces.size():
		if other_face_index == face_index:
			continue
		
		# NOTE: This may need to be recentered to the origin, then moved back to the correct face position
		# This problem may arise from floating point inaccuracy, given a large enough initial brush
		winding = Geometry3D.clip_polygon(winding, brush.faces[other_face_index].plane)
		if winding.is_empty():
			break
	
	# Reduce seams between vertices
	for i in winding.size():
		winding.set(i, winding.get(i).snappedf(vertex_merge_distance))

	return winding

func generate_brush_vertices(entity_index: int, brush_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	var brush: _BrushData = entity.brushes[brush_index]
	var vertex_merge_distance: float = entity.properties.get(map_settings.vertex_merge_distance_property, 0.0) as float
	
	for face_index in brush.faces.size():
		var face: _FaceData = brush.faces[face_index]
		face.vertices = generate_face_vertices(brush, face_index, vertex_merge_distance)
		
		face.normals.resize(face.vertices.size())
		face.normals.fill(face.plane.normal)
		
		var tangent: PackedFloat32Array = FuncGodotUtil.get_face_tangent(face)
		
		# convert into OpenGL coordinates
		for i in face.vertices.size():
			face.tangents.append(tangent[1]) # Y
			face.tangents.append(tangent[2]) # Z
			face.tangents.append(tangent[0]) # X
			face.tangents.append(tangent[3]) # W
	return

func generate_entity_vertices(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	for brush_index in entity.brushes.size():
		generate_brush_vertices(entity_index, brush_index)

func determine_entity_origins(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	var origin_type := _OriginType.BRUSH
		
	if entity.definition is not FuncGodotFGDSolidClass:
		if entity.brushes.is_empty():
			return
	else:
		origin_type = entity.definition.origin_type
	
	if entity_index == 0:
		entity.origin = Vector3.ZERO
		return
	
	var entity_mins: Vector3 = Vector3.INF
	var entity_maxs: Vector3 = Vector3.INF
	var origin_mins: Vector3 = Vector3.INF
	var origin_maxs: Vector3 = -Vector3.INF
	
	for brush in entity.brushes:
		for face in brush.faces:
			for vertex in face.vertices:
				if entity_mins != Vector3.INF:
					entity_mins = entity_mins.min(vertex)
				else:
					entity_mins = vertex
				if entity_maxs != Vector3.INF:
					entity_maxs = entity_maxs.max(vertex)
				else:
					entity_maxs = vertex
				
				if brush.origin:
					if origin_mins != Vector3.INF:
						origin_mins = origin_mins.min(vertex)
					else:
						origin_mins = vertex
					if origin_maxs != Vector3.INF:
						origin_maxs = origin_maxs.max(vertex)
					else:
						origin_maxs = vertex
	
	# Default origin type is BOUNDS_CENTER
	if entity_maxs != Vector3.INF and entity_mins != Vector3.INF:
		entity.origin = entity_maxs - ((entity_maxs - entity_mins) * 0.5)
	
	if origin_type != _OriginType.BOUNDS_CENTER and entity.brushes.size() > 0:
		match origin_type:
			_OriginType.ABSOLUTE, _OriginType.RELATIVE:
				if "origin" in entity.properties:
					var origin_comps: PackedFloat64Array = entity.properties["origin"].split_floats(" ")
					if origin_comps.size() > 2:
						if entity.origin_type == _OriginType.ABSOLUTE:
							entity.origin = Vector3(origin_comps[0], origin_comps[1], origin_comps[2])
						else: # _OriginType.RELATIVE
							entity.origin += Vector3(origin_comps[0], origin_comps[1], origin_comps[2])
				
			_OriginType.BRUSH:
				if origin_mins != Vector3.INF:
					entity.origin = origin_maxs - ((origin_maxs - origin_mins) * 0.5)
			
			_OriginType.BOUNDS_MINS:
				entity.origin = entity_mins
			
			_OriginType.BOUNDS_MAXS:
				entity.origin = entity_maxs
			
			_OriginType.AVERAGED:
				entity.origin = Vector3.ZERO
				var vertices: PackedVector3Array
				for brush in entity.brushes:
					for face in brush.faces:
						vertices.append_array(face.vertices)
				entity.origin = FuncGodotUtil.op_vec3_avg(vertices)

func wind_entity_faces(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	for brush in entity.brushes:
		for face in brush.faces:
			# Faces should already be wound from the new generation process, but this should be tested further first.
			face.wind()
			face.index_vertices()

func smooth_entity_vertices(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	if not entity.is_smooth_shaded(map_settings.entity_smoothing_property):
		return
	
	var smoothing_angle: float = deg_to_rad(entity.get_smoothing_angle(map_settings.entity_smoothing_angle_property))
	var vertex_map: Dictionary[Vector3, _VertexGroupData] = {}
	
	# Group vertices by position and build map. NOTE: Vector3 keys can suffer from floating point precision.
	# However, the vertex position should have already been snapped to _VERTEX_EPSILON. 
	for brush in entity.brushes:
		for face in brush.faces:
			for i in face.vertices.size():
				var pos := face.vertices[i].snappedf(_VERTEX_EPSILON)
				
				if not vertex_map.has(pos):
					vertex_map[pos] = _VertexGroupData.new()
				
				var data := vertex_map[pos]
				data.faces.append(face)
				data.face_indices.append(i)
	
	var smoothed_normals: PackedVector3Array
	
	for vertex_group in vertex_map.values():
		if vertex_group.faces.size() <= 1:
			continue
		
		# Collect final normals in a temporary arrays
		# These cannot be applied until all original normals have been checked.
		smoothed_normals = []
		
		for i in vertex_group.faces.size():
			var this_face: _FaceData = vertex_group.faces[i]
			var this_index: int = vertex_group.face_indices[i]
			var this_normal: Vector3 = this_face.normals[this_index] 
			var average_normal: Vector3 = this_normal
			
			for j in vertex_group.faces.size():
				# Skip this face
				if i == j:
					continue
				
				var other_face: _FaceData = vertex_group.faces[j]
				var other_index: int = vertex_group.face_indices[j]
				var other_normal: Vector3 = other_face.normals[other_index]
				
				if this_normal.angle_to(other_normal) <= smoothing_angle:
					average_normal += other_normal
			
			# Store the averaged normal
			smoothed_normals.append(average_normal.normalized())
			
		# Apply smoothed normals back to face data
		for i in vertex_group.faces.size():
			var face: _FaceData = vertex_group.faces[i]
			var index: int = vertex_group.face_indices[i]
			face.normals[index] = smoothed_normals[i]
	return

#endregion

func generate_entity_surfaces(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	
	# Don't build for non-solid classes or solids without any brushes.
	if not entity or entity.brushes.is_empty():
		return
	
	var def: FuncGodotFGDSolidClass
	if entity.definition is not FuncGodotFGDSolidClass:
		def = FuncGodotFGDSolidClass.new()
	else:
		def = entity.definition
	
	var op_entity_ogl_xf: Callable = func(v: Vector3) -> Vector3:
		return (FuncGodotUtil.id_to_opengl(v - entity.origin) * map_settings.scale_factor)
	
	# Surface groupings <texture_name, Array[Face]>
	var surfaces: Dictionary[String, Array] = {}

	# Metadata
	var current_metadata_index: int = 0
	var texture_names_metadata: Array[StringName] = []
	var textures_metadata: PackedInt32Array = []
	var vertices_metadata: PackedVector3Array = []
	var normals_metadata: PackedVector3Array = []
	var positions_metadata: PackedVector3Array = []
	var shape_to_face_metadata: Array[PackedInt32Array] = []
	var face_index_metadata_map: Dictionary[_FaceData, PackedInt32Array] = {}
	
	# Arrange faces by surface texture
	for brush in entity.brushes:
		for face in brush.faces:
			if is_skip(face) or is_origin(face):
				continue
			
			if not surfaces.has(face.texture):
				surfaces[face.texture] = []
			surfaces[face.texture].append(face)
	
	# Cache order for consistency when rebuilding 
	var textures: Array[String] = surfaces.keys()
	
	# Output mesh data
	var mesh := ArrayMesh.new()
	var mesh_arrays: Array[Array] = []
	var build_concave: bool = entity.is_collision_concave()
	var concave_vertices: PackedVector3Array

	# Iteration variables
	var arrays: Array
	var faces: Array
	
	# MULTISURFACE SCOPE BEGIN
	for texture_name in textures:
		# SURFACE SCOPE BEGIN
		faces = surfaces[texture_name]
		
		# Get texture index for metadata
		var tex_index: int = texture_names_metadata.size()
		if def.add_textures_metadata:
			texture_names_metadata.append(texture_name)

		# Prepare new array
		arrays = Array()
		arrays.resize(ArrayMesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] 	= PackedVector3Array()
		arrays[Mesh.ARRAY_NORMAL] 	= PackedVector3Array()
		arrays[Mesh.ARRAY_TANGENT] 	= PackedFloat32Array()
		arrays[Mesh.ARRAY_TEX_UV] 	= PackedVector2Array()
		arrays[Mesh.ARRAY_INDEX] 	= PackedInt32Array()
		
		# Begin fresh index offset for this subarray
		var index_offset: int = 0
		
		for face in faces:
			# FACE SCOPE BEGIN
			
			# Reject invalid faces
			if face.vertices.size() < 3 or is_skip(face) or is_origin(face):
				continue
			
			# Create trimesh points regardless of texture
			if build_concave:
				var tris: PackedVector3Array
				tris.resize(face.indices.size())
				
				# Add triangles from face indices directly
				# TODO: This can possibly be merged with the below loop in a clever way
				for i in face.indices.size():
					tris[i] = op_entity_ogl_xf.call(face.vertices[face.indices[i]])
				
				concave_vertices.append_array(tris)
				
			# Do not generate visuals for clip textures
			if is_clip(face):
				continue
			
			# Handle metadata for this face
			# Add metadata per triangle rather than per face to keep consistent metadata
			var num_tris = face.indices.size() / 3
			if def.add_textures_metadata:
				var tex_array: Array[int] = []
				tex_array.resize(num_tris)
				tex_array.fill(tex_index)
				textures_metadata.append_array(tex_array)
			if def.add_face_normal_metadata:
				var normal_array: Array[Vector3] = []
				normal_array.resize(num_tris)
				normal_array.fill(FuncGodotUtil.id_to_opengl(face.plane.normal))
				normals_metadata.append_array(normal_array)
			if def.add_face_position_metadata:
				for i in num_tris:
					var triangle_indices: Array[int] = []
					var triangle_vertices: Array[Vector3] = []
					triangle_indices.assign(face.indices.slice(i * 3, i * 3 + 3))
					triangle_vertices.assign(triangle_indices.map(func(idx : int) -> Vector3: return face.vertices[idx]))
					var position := FuncGodotUtil.op_vec3_avg(triangle_vertices)
					positions_metadata.append(op_entity_ogl_xf.call(position))
			if def.add_vertex_metadata:
				for i in face.indices:
					vertices_metadata.append(op_entity_ogl_xf.call(face.vertices[i]))
			if def.add_collision_shape_to_face_indices_metadata:
				face_index_metadata_map[face] = PackedInt32Array(range(current_metadata_index, current_metadata_index + num_tris))
			current_metadata_index += num_tris
			
			# Append face data to surface array
			for i in face.vertices.size():
				# TODO: Mesh metadata may be generated here.
				var v: Vector3 = face.vertices[i]
				arrays[ArrayMesh.ARRAY_VERTEX].append(op_entity_ogl_xf.call(v))
				arrays[ArrayMesh.ARRAY_NORMAL].append(FuncGodotUtil.id_to_opengl(face.normals[i]))
				var tx_sz: Vector2 = texture_sizes.get(face.texture, Vector2.ONE * map_settings.inverse_scale_factor)
				arrays[ArrayMesh.ARRAY_TEX_UV].append(FuncGodotUtil.get_face_vertex_uv(v, face, tx_sz))
				
				for j in 4:
					arrays[ArrayMesh.ARRAY_TANGENT].append(face.tangents[(i * 4) + j])
			
			# Create offset indices for the visual mesh
			var op_shift_index: Callable = (func(a: int) -> int: return a + index_offset)
			arrays[ArrayMesh.ARRAY_INDEX].append_array(Array(face.indices).map(op_shift_index))
			
			index_offset += face.vertices.size()
			
			# FACE SCOPE END
		
		if FuncGodotUtil.filter_face(texture_name, map_settings):
			continue
		
		mesh_arrays.append(arrays)
		
		# SURFACE SCOPE END
	
	# MULTISURFACE SCOPE END
	textures.erase(map_settings.clip_texture)
	
	if def.build_visuals:
		# Build mesh
		for array_index in mesh_arrays.size():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays[array_index])
			mesh.surface_set_name(array_index, textures[array_index])
			mesh.surface_set_material(array_index, texture_materials[textures[array_index]])
		
		# Apply mesh metadata	
		if def.add_textures_metadata:
			entity.mesh_metadata["texture_names"] = texture_names_metadata
			entity.mesh_metadata["textures"] = textures_metadata
		if def.add_vertex_metadata:
			entity.mesh_metadata["vertices"] = vertices_metadata
		if def.add_face_normal_metadata:
			entity.mesh_metadata["normals"] = normals_metadata
		if def.add_face_position_metadata:
			entity.mesh_metadata["positions"] = positions_metadata
		
		entity.mesh = mesh
	
	# Clear up unusued memory
	arrays = []
	surfaces = {}
	
	if entity.is_collision_convex():
		var sh: ConvexPolygonShape3D
		for b in entity.brushes:
			if b.planes.is_empty() or b.origin:
				continue
			
			var points := Array(Geometry3D.compute_convex_mesh_points(b.planes)).map(op_entity_ogl_xf)
			if points.is_empty():
				continue
			
			sh = ConvexPolygonShape3D.new()
			sh.points = points
			entity.shapes.append(sh)
	
			if def.add_collision_shape_to_face_indices_metadata:
				# convex collision has one shape per brush, so collect the
				# indices for this brush's faces
				var face_indices_array : PackedInt32Array = []
				for face in b.faces:
					if face_index_metadata_map.has(face):
						face_indices_array.append_array(face_index_metadata_map[face])
				shape_to_face_metadata.append(face_indices_array)

	elif build_concave and concave_vertices.size():
		var sh := ConcavePolygonShape3D.new()
		sh.set_faces(concave_vertices)
		entity.shapes.append(sh)
		
		if def.add_collision_shape_to_face_indices_metadata:
			# for concave collision the shape will always represent every face
			# in the entity, so just add every face here
			var face_indices_array : PackedInt32Array = []
			for fm in face_index_metadata_map.values():
				face_indices_array.append_array(fm)
			shape_to_face_metadata.append(face_indices_array)
			
	if def.add_collision_shape_to_face_indices_metadata:
		# this metadata will be mapped to the actual shape node names during entity assembly
		entity.mesh_metadata["shape_to_face_array"] = shape_to_face_metadata

func unwrap_uv2s(entity_index: int, texel_size: float) -> void:
	var entity: _EntityData = entity_data[entity_index]
	if entity.mesh:
		if (entity.definition as FuncGodotFGDSolidClass).global_illumination_mode:
			entity.mesh.lightmap_unwrap(Transform3D.IDENTITY, texel_size)

# Main build process
func build(build_flags: int, entities: Array[_EntityData]) -> Error:
	var entity_count: int = entities.size()
	declare_step.emit("Preparing %s %s" % [entity_count, "entity" if entity_count == 1 else "entities"])
	entity_data = entities
	
	declare_step.emit("Gathering materials")
	var texture_map: Array[Dictionary] = FuncGodotUtil.build_texture_map(entity_data, map_settings)
	texture_materials = texture_map[0]
	texture_sizes = texture_map[1]
	
	var task_id: int
	declare_step.emit("Generating brush vertices")
	task_id = WorkerThreadPool.add_group_task(generate_entity_vertices, entity_count, -1, false, "Generate Brush Vertices")
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	declare_step.emit("Determining solid entity origins")
	task_id = WorkerThreadPool.add_group_task(determine_entity_origins, entity_count, -1, false, "Determine Entity Origins")
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	declare_step.emit("Winding faces")
	task_id = WorkerThreadPool.add_group_task(wind_entity_faces, entity_count, -1, false, "Wind Brush Faces")
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	# TODO: Reimplement after solving issues
	#if not (build_flags & FuncGodotMap.BuildFlags.DISABLE_SMOOTHING):
	#	declare_step.emit("Smoothing entity faces")
	#	task_id = WorkerThreadPool.add_group_task(smooth_entity_vertices, entity_count, -1, false, "Smooth Entities")
	#	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	declare_step.emit("Generating surfaces")
	task_id = WorkerThreadPool.add_group_task(generate_entity_surfaces, entity_count, -1, false, "Generate Surfaces")
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	if build_flags & FuncGodotMap.BuildFlags.UNWRAP_UV2:
		declare_step.emit("Unwrapping UV2s")
		var texel_size: float = map_settings.uv_unwrap_texel_size * map_settings.scale_factor
		for entity_index in entity_count:
			unwrap_uv2s(entity_index, texel_size)
	
	declare_step.emit("Geometry generation complete")
	return OK
