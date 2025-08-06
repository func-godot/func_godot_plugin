@icon("res://addons/func_godot/icons/icon_slipgate.svg")
class_name FuncGodotGeometryGenerator extends RefCounted
## Geometry generation class that is instantiated by a [FuncGodotMap] node.

const _SIGNATURE: String = "[GEO]"

# Namespacing
const _VERTEX_EPSILON 	:= FuncGodotUtil._VERTEX_EPSILON
const _VERTEX_EPSILON2 	:= _VERTEX_EPSILON * _VERTEX_EPSILON

const _OriginType 	:= FuncGodotFGDSolidClass.OriginType;

const _GroupData		:= FuncGodotData.GroupData
const _EntityData 		:= FuncGodotData.EntityData
const _BrushData 		:= FuncGodotData.BrushData
const _PatchData 		:= FuncGodotData.PatchData
const _FaceData 		:= FuncGodotData.FaceData
const _VertexGroupData	:= FuncGodotData.VertexGroupData;

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

# Tools

func is_skip(face: _FaceData) -> bool:
	return FuncGodotUtil.is_skip(face.texture, map_settings)

func is_clip(face: _FaceData) -> bool:
	return FuncGodotUtil.is_clip(face.texture, map_settings)

func is_origin(face: _FaceData) -> bool:
	return FuncGodotUtil.is_origin(face.texture, map_settings)

## Patches

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

## Brushes
func generate_brush_vertices_old(entity_index: int, brush_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	var brush: _BrushData = entity.brushes[brush_index]
	var face_count: int = brush.planes.size()
	
	#var do_phong: bool = entity.properties.get("_phong", 0) != 0;
	#var phong_angle_str: String = entity.properties.get("_phong_angle", "89")
	#var phong_angle: float = float(phong_angle_str) if phong_angle_str.is_valid_float() else 89.0

	# Check for valid planar intersections and clean up duplicates to prepare face geometry
	for f0 in face_count:
		var face: _FaceData = brush.faces[f0]
		var plane: Plane = brush.planes[f0]

		for f1 in face_count:
			for f2 in face_count:
				var value: Variant = plane.intersect_3(brush.planes[f1], brush.planes[f2])
				if value == null: 
					continue

				var vertex: Vector3 = value
				if not FuncGodotUtil.is_point_in_convex_hull(brush.planes, vertex): 
					continue
				
				var merged: bool = false
				for f3 in range(f0):
					var other_face: _FaceData = brush.faces[f3]
					for i in other_face.vertices.size():
						if other_face.vertices[i].distance_squared_to(vertex) < _VERTEX_EPSILON2:
							vertex = other_face.vertices[i]
							merged = true
							break
					if merged: 
						break
				var normal: Vector3 = plane.normal
				var tangent: PackedFloat32Array = FuncGodotUtil.get_face_tangent(face)
				var duplicate_index: int = -1
				for i in face.vertices.size():
					if face.vertices[i] == vertex:
						duplicate_index = i
						break
				
				if duplicate_index < 0:
					face.vertices.append(vertex)
					face.normals.append(normal)
					face.tangents.append_array(tangent)
				else:
					face.normals[duplicate_index] += normal
	
	for face in brush.faces:
		for i in face.vertices.size():
			face.normals[i] = face.normals[i].normalized()

func generate_brush_vertices(entity_index: int, brush_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	var brush: _BrushData = entity.brushes[brush_index]
	var face_count: int = brush.faces.size()
	
	var f0: _FaceData
	var f1: _FaceData
	var f2: _FaceData
	
	var spatial_hash: Dictionary[Vector3i, Vector3] = {}; 

	# Check for planar intersections in the face by unique triplets of planes.
	for i in face_count:
		f0 = brush.faces[i]

		for j in range(i + 1, face_count):
			f1 = brush.faces[j]

			for k in range(j + 1, face_count):
				f2 = brush.faces[k]

				var intersection := f0.plane.intersect_3(f1.plane, f2.plane)
				if intersection == null:
					continue
				
				var vertex: Vector3 = intersection;
				if not FuncGodotUtil.is_point_in_convex_hull(brush.planes, vertex):
					continue	

				# Each face contains the vertex 
				f0.vertices.append(vertex)
				f1.vertices.append(vertex)
				f2.vertices.append(vertex)
	
	# By default, brushes are flat shaded. Thus, the normal for each vertex is simply the face normal.
	# Winding and indexing faces processes don't have to reorder these as smoothing would then take place after.
	for face in brush.faces:
		face.normals.resize(face.vertices.size())
		face.normals.fill(face.plane.normal)

		var tangent := FuncGodotUtil.get_face_tangent(face)
		for i in face.vertices.size():
			face.tangents.append_array(tangent)


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
				
				var vertices: PackedVector3Array;
				for brush in entity.brushes:
					for face in brush.faces:
						vertices.append_array(face.vertices);
				
				entity.origin = FuncGodotUtil.op_vec3_avg(vertices);

func wind_entity_faces(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]
	for brush in entity.brushes:
		for face in brush.faces:
			face.wind()
			face.index_vertices()

func smooth_entity_vertices(entity_index: int) -> void:
	var entity: _EntityData = entity_data[entity_index]	
	if !entity.is_smooth_shaded(map_settings.entity_smoothing_property):
		return
	
	var smoothing_angle: float = deg_to_rad(entity.get_smoothing_angle(map_settings.entity_smoothing_angle_property))
	var vertex_map: Dictionary[Vector3, _VertexGroupData] = {}
	
	# Group vertices by position and build map. NOTE: Vector3 keys can suffer from floating point precision.
	# However, the vertex position should have already been snapped to _VERTEX_EPSILON. 
	for brush in entity.brushes:
		for face in brush.faces:
			for i in face.vertices.size():
				var pos := face.vertices[i].snappedf(_VERTEX_EPSILON)

				if !vertex_map.has(pos):
					vertex_map[pos] = _VertexGroupData.new()

				var data := vertex_map[pos]
				data.faces.append(face)
				data.face_indices.append(i)
	
	var smoothed_normals: PackedVector3Array;

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
	return;

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
	var texture_names_metadata: Array[StringName] = []
	var textures_metadata: PackedInt32Array = []
	var vertices_metadata: PackedVector3Array = []
	var normals_metadata: PackedVector3Array = []
	var positions_metadata: PackedVector3Array = []
	
	# Arrange faces by surface texture
	for brush in entity.brushes:
		for face in brush.faces:
			if is_skip(face) or is_origin(face):
				continue
			
			if not surfaces.has(face.texture):
				surfaces[face.texture] = []
			surfaces[face.texture].append(face)
			
			if def.add_textures_metadata:
				var tex_index: int = texture_names_metadata.find(face.texture)
				if tex_index < 0:
					tex_index = texture_names_metadata.size()
					texture_names_metadata.append(face.texture)
				textures_metadata.append(tex_index)
	
	# Cache order for consistency when rebuilding 
	var textures: Array[String] = surfaces.keys();
	
	# Output mesh data
	var mesh := ArrayMesh.new()
	var mesh_arrays: Array[Array] = []
	var build_concave: bool = entity.is_concave()
	var concave_vertices: PackedVector3Array

	# Iteration variables
	var arrays: Array
	var faces: Array
	
	# MULTISURFACE SCOPE BEGIN
	for texture_name in textures:
		# SURFACE SCOPE BEGIN
		faces = surfaces[texture_name]

		# Prepare new array
		arrays = Array()
		arrays.resize(ArrayMesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] 	= PackedVector3Array()
		arrays[Mesh.ARRAY_NORMAL] 	= PackedVector3Array()
		arrays[Mesh.ARRAY_TANGENT] 	= PackedFloat32Array()
		arrays[Mesh.ARRAY_TEX_UV] 	= PackedVector2Array()
		arrays[Mesh.ARRAY_INDEX] 	= PackedInt32Array()
		
		# Begin fresh index offset for this subarray
		var index_offset: int = 0; 
		
		for face in faces:
			# FACE SCOPE BEGIN
			
			# Reject invalid faces
			if face.vertices.size() < 3 || is_skip(face) || is_origin(face):
				continue
			
			# Create trimesh points regardless of texture
			if build_concave:	
				var tris: PackedVector3Array;
				tris.resize(face.indices.size())
				
				# Add triangles from face indices directly
				# TODO: This can possibly be merged with the below loop in a clever way
				for i in face.indices.size():
					tris[i] = op_entity_ogl_xf.call(face.vertices[face.indices[i]])
				
				concave_vertices.append_array(tris)
				
			# Do not generate visuals for clip textures
			if is_clip(face):
				continue
			
			# Append face data to surface array
			for i in face.vertices.size():
				# TODO: Mesh metadata may be generated here.
				var v: Vector3 = face.vertices[i]
				arrays[ArrayMesh.ARRAY_VERTEX].append(op_entity_ogl_xf.call(v))
				arrays[ArrayMesh.ARRAY_NORMAL].append(FuncGodotUtil.id_to_opengl(face.normals[i]))
				var tx_sz: Vector2 = texture_sizes.get(face.texture, Vector2.ONE * map_settings.inverse_scale_factor)
				arrays[ArrayMesh.ARRAY_TEX_UV].append(FuncGodotUtil.get_face_vertex_uv(v, face, tx_sz))
				
				for j in 4:
					arrays[ArrayMesh.ARRAY_TANGENT].append(face.tangents[i + j])
			
			# Create offset indices for the visual mesh
			var op_shift_index: Callable = (func(a: int) -> int: return a + index_offset)
			arrays[ArrayMesh.ARRAY_INDEX].append_array(Array(face.indices).map(op_shift_index))
			
			index_offset += face.vertices.size()
			
			# FACE SCOPE END
		
		if FuncGodotUtil.filter_face(texture_name, map_settings):
			continue
		
		mesh_arrays.append(arrays);
		
		if def.add_vertex_metadata:
			vertices_metadata.append_array(arrays[Mesh.ARRAY_VERTEX])
		if def.add_face_normal_metadata:
			normals_metadata.append_array(arrays[Mesh.ARRAY_NORMAL])
		if def.add_face_position_metadata:
			var vertices: PackedVector3Array = arrays[ArrayMesh.ARRAY_VERTEX]
			var positions: PackedVector3Array = []
			positions.resize(vertices.size() / 3)
			for i in positions.size():
				var v: int = i * 3
				if vertices.size() > v + 2:
					positions[i] = (vertices[v] + vertices[v + 1] + vertices[v + 2]) / 3
			positions_metadata.append_array(positions)

		# SURFACE SCOPE END

	# MULTISURFACE SCOPE END

	# Clear up unusued memory
	arrays = [];
	surfaces = {};
	
	# Build mesh
	for array_index in mesh_arrays.size():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays[array_index]);
		mesh.surface_set_name(array_index, textures[array_index]);
		mesh.surface_set_material(array_index, texture_materials[textures[array_index]]);
	
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
	
	if entity.is_convex():
		var sh: ConvexPolygonShape3D;
		for b in entity.brushes:
			if b.planes.is_empty() or b.origin:
				continue
			
			var points := Array(Geometry3D.compute_convex_mesh_points(b.planes)).map(op_entity_ogl_xf)
			if points.is_empty():
				continue
			
			sh = ConvexPolygonShape3D.new()
			sh.points = points
			entity.shapes.append(sh)
	
	elif build_concave && concave_vertices.size():
		var sh := ConcavePolygonShape3D.new()
		sh.set_faces(concave_vertices)
		entity.shapes.append(sh)

func unwrap_uv2s(entity_index: int, texel_size: float) -> void:
	var entity: _EntityData = entity_data[entity_index]
	if entity.mesh:
		if (entity.definition as FuncGodotFGDSolidClass).use_in_baked_light:
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
