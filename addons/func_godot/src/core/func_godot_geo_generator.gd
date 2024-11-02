extends RefCounted

# Min distance between two verts in a brush before they're merged. Higher values fix angled brushes near extents.
const CMP_EPSILON:= 0.008

const UP_VECTOR:= Vector3(0.0, 0.0, 1.0)
const RIGHT_VECTOR:= Vector3(0.0, 1.0, 0.0)
const FORWARD_VECTOR:= Vector3(1.0, 0.0, 0.0)

var map_data: FuncGodotMapData

var wind_entity_idx: int = 0
var wind_brush_idx: int = 0
var wind_face_idx: int = 0
var wind_face_center: Vector3
var wind_face_basis: Vector3
var wind_face_normal: Vector3

func _init(in_map_data: FuncGodotMapData) -> void:
	map_data = in_map_data

func sort_vertices_by_winding(a: FuncGodotMapData.FuncGodotFaceVertex, b: FuncGodotMapData.FuncGodotFaceVertex) -> bool:
	var face: FuncGodotMapData.FuncGodotFace = map_data.entities[wind_entity_idx].brushes[wind_brush_idx].faces[wind_face_idx]
	var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = map_data.entity_geo[wind_entity_idx].brushes[wind_brush_idx].faces[wind_face_idx]
	
	var u: Vector3 = wind_face_basis.normalized()
	var v: Vector3 = u.cross(wind_face_normal).normalized()
	
	var loc_a: Vector3 = a.vertex - wind_face_center
	var a_pu: float = loc_a.dot(u)
	var a_pv: float = loc_a.dot(v)
	
	var loc_b: Vector3 = b.vertex - wind_face_center
	var b_pu: float = loc_b.dot(u)
	var b_pv: float = loc_b.dot(v)
	
	var a_angle: float = atan2(a_pv, a_pu)
	var b_angle: float = atan2(b_pv, b_pu)
	
	return a_angle < b_angle

# returns null if no intersection, else intersection vertex.
func intersect_face(f0: FuncGodotMapData.FuncGodotFace, f1: FuncGodotMapData.FuncGodotFace, f2: FuncGodotMapData.FuncGodotFace) -> Variant:
	var n0:= f0.plane_normal
	var n1:= f1.plane_normal
	var n2:= f2.plane_normal
	var denom: float = n0.cross(n1).dot(n2)
	if denom < CMP_EPSILON:
		return null
	return (n1.cross(n2) * f0.plane_dist + n2.cross(n0) * f1.plane_dist + n0.cross(n1) * f2.plane_dist) / denom

func vertex_in_hull(faces: Array[FuncGodotMapData.FuncGodotFace], vertex: Vector3) -> bool:
	for face in faces:
		var proj: float = face.plane_normal.dot(vertex)
		if proj > face.plane_dist and absf(face.plane_dist - proj) > CMP_EPSILON:
			return false
	return true

func get_standard_uv(vertex: Vector3, face: FuncGodotMapData.FuncGodotFace, texture_width: int, texture_height: int) -> Vector2:
	var uv_out: Vector2
	var du:= absf(face.plane_normal.dot(UP_VECTOR))
	var dr:= absf(face.plane_normal.dot(RIGHT_VECTOR))
	var df:= absf(face.plane_normal.dot(FORWARD_VECTOR))
	
	if du >= dr and du >= df:
		uv_out = Vector2(vertex.x, -vertex.y)
	elif dr >= du and dr >= df:
		uv_out = Vector2(vertex.x, -vertex.z)
	elif df >= du and df >= dr:
		uv_out = Vector2(vertex.y, -vertex.z)
	
	var angle: float = deg_to_rad(face.uv_extra.rot)
	uv_out = Vector2(
		uv_out.x * cos(angle) - uv_out.y * sin(angle),
		uv_out.x * sin(angle) + uv_out.y * cos(angle))
	
	uv_out.x /= texture_width
	uv_out.y /= texture_height
	
	uv_out.x /= face.uv_extra.scale_x
	uv_out.y /= face.uv_extra.scale_y
	
	uv_out.x += face.uv_standard.x / texture_width
	uv_out.y += face.uv_standard.y / texture_height
	
	return uv_out

func get_valve_uv(vertex: Vector3, face: FuncGodotMapData.FuncGodotFace, texture_width: int, texture_height: int) -> Vector2:
	var uv_out: Vector2
	var u_axis:= face.uv_valve.u.axis
	var v_axis:= face.uv_valve.v.axis
	var u_shift:= face.uv_valve.u.offset
	var v_shift:= face.uv_valve.v.offset
	
	uv_out.x = u_axis.dot(vertex);
	uv_out.y = v_axis.dot(vertex);
	
	uv_out.x /= texture_width;
	uv_out.y /= texture_height;
	
	uv_out.x /= face.uv_extra.scale_x;
	uv_out.y /= face.uv_extra.scale_y;
	
	uv_out.x += u_shift / texture_width;
	uv_out.y += v_shift / texture_height;
	
	return uv_out

func get_standard_tangent(face: FuncGodotMapData.FuncGodotFace) -> Vector4:
	var du:= face.plane_normal.dot(UP_VECTOR)
	var dr:= face.plane_normal.dot(RIGHT_VECTOR)
	var df:= face.plane_normal.dot(FORWARD_VECTOR)
	var dua:= absf(du)
	var dra:= absf(dr)
	var dfa:= absf(df)
	
	var u_axis: Vector3
	var v_sign: float = 0.0
	
	if dua >= dra and dua >= dfa:
		u_axis = FORWARD_VECTOR
		v_sign = signf(du)
	elif dra >= dua and dra >= dfa:
		u_axis = FORWARD_VECTOR
		v_sign = -signf(dr)
	elif dfa >= dua and dfa >= dra:
		u_axis = RIGHT_VECTOR
		v_sign = signf(df)
		
	v_sign *= signf(face.uv_extra.scale_y);
	u_axis = u_axis.rotated(face.plane_normal, deg_to_rad(-face.uv_extra.rot) * v_sign)
	
	return Vector4(u_axis.x, u_axis.y, u_axis.z, v_sign)

func get_valve_tangent(face: FuncGodotMapData.FuncGodotFace) -> Vector4:
	var u_axis:= face.uv_valve.u.axis.normalized()
	var v_axis:= face.uv_valve.v.axis.normalized()
	var v_sign = -signf(face.plane_normal.cross(u_axis).dot(v_axis))
	return Vector4(u_axis.x, u_axis.y, u_axis.z, v_sign)

func generate_brush_vertices(entity_idx: int, brush_idx: int) -> void:
	var entity: FuncGodotMapData.FuncGodotEntity = map_data.entities[entity_idx]
	var brush: FuncGodotMapData.FuncGodotBrush = entity.brushes[brush_idx]
	var face_count: int = brush.faces.size()
	
	var entity_geo: FuncGodotMapData.FuncGodotEntityGeometry = map_data.entity_geo[entity_idx]
	var brush_geo: FuncGodotMapData.FuncGodotBrushGeometry = entity_geo.brushes[brush_idx]
	
	var phong: bool = entity.properties.get("_phong", "0") == "1"
	var phong_angle_str: String = entity.properties.get("_phong_angle", "89")
	var phong_angle: float = float(phong_angle_str) if phong_angle_str.is_valid_float() else 89.0
	
	for f0 in range(face_count):
		var face: FuncGodotMapData.FuncGodotFace = brush.faces[f0]
		var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f0]
		var texture: FuncGodotMapData.FuncGodotTextureData = map_data.textures[face.texture_idx]
		
		for f1 in range(face_count):
			for f2 in range(face_count):
				var vertex = intersect_face(brush.faces[f0], brush.faces[f1], brush.faces[f2])
				if not vertex is Vector3:
					continue
				if not vertex_in_hull(brush.faces, vertex):
					continue
				
				var merged: bool = false
				for f3 in range(f0):
					var other_face_geo : FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f3]
					for i in range(len(other_face_geo.vertices)):
						if other_face_geo.vertices[i].vertex.distance_to(vertex) < CMP_EPSILON:
							vertex = other_face_geo.vertices[i].vertex
							merged = true;
							break
					
					if merged:
						break
				
				var normal: Vector3 = face.plane_normal
				if phong:
					var threshold:= cos((phong_angle + 0.01) * 0.0174533)
					if face.plane_normal.dot(brush.faces[f1].plane_normal) > threshold:
						normal += brush.faces[f1].plane_normal
					if face.plane_normal.dot(brush.faces[f2].plane_normal) > threshold:
						normal += brush.faces[f2].plane_normal
					normal = normal.normalized()
				
				var uv: Vector2
				var tangent: Vector4
				if face.is_valve_uv:
					uv = get_valve_uv(vertex, face, texture.width, texture.height)
					tangent = get_valve_tangent(face)
				else:
					uv = get_standard_uv(vertex, face, texture.width, texture.height)
					tangent = get_standard_tangent(face)
					
				# Check for a duplicate vertex in the current face.
				var duplicate_idx: int = -1
				for i in range(face_geo.vertices.size()):
					if face_geo.vertices[i].vertex == vertex:
						duplicate_idx = i
						break
				
				if duplicate_idx < 0:
					var new_face_vert:= FuncGodotMapData.FuncGodotFaceVertex.new()
					new_face_vert.vertex = vertex
					new_face_vert.normal = normal
					new_face_vert.tangent = tangent
					new_face_vert.uv = uv
					face_geo.vertices.append(new_face_vert)
				elif phong:
					face_geo.vertices[duplicate_idx].normal += normal
	
	# maybe optimisable? 
	for face_geo in brush_geo.faces:
		for i in range(face_geo.vertices.size()):
			face_geo.vertices[i].normal = face_geo.vertices[i].normal.normalized()

func run() -> void:
	map_data.entity_geo.resize(map_data.entities.size())
	for i in range(map_data.entity_geo.size()):
		map_data.entity_geo[i] = FuncGodotMapData.FuncGodotEntityGeometry.new()
	
	for e in range(map_data.entities.size()):
		var entity: FuncGodotMapData.FuncGodotEntity = map_data.entities[e]
		var entity_geo: FuncGodotMapData.FuncGodotEntityGeometry = map_data.entity_geo[e]
		entity_geo.brushes.resize(entity.brushes.size())
		for i in range(entity_geo.brushes.size()):
			entity_geo.brushes[i] = FuncGodotMapData.FuncGodotBrushGeometry.new()
		
		for b in range(entity.brushes.size()):
			var brush: FuncGodotMapData.FuncGodotBrush = entity.brushes[b]
			var brush_geo: FuncGodotMapData.FuncGodotBrushGeometry = entity_geo.brushes[b]
			brush_geo.faces.resize(brush.faces.size())
			for i in range(brush_geo.faces.size()):
				brush_geo.faces[i] = FuncGodotMapData.FuncGodotFaceGeometry.new()
	
	var generate_vertices_task = func(e):
		var entity: FuncGodotMapData.FuncGodotEntity = map_data.entities[e]
		var entity_geo: FuncGodotMapData.FuncGodotEntityGeometry = map_data.entity_geo[e]
		var entity_mins: Vector3 = Vector3.ZERO
		var entity_maxs: Vector3 = Vector3.ZERO
		var origin_mins: Vector3 = Vector3.INF
		var origin_maxs: Vector3 = -Vector3.INF
		
		entity.center = Vector3.ZERO
		
		for b in range(entity.brushes.size()):
			var brush: FuncGodotMapData.FuncGodotBrush = entity.brushes[b]
			brush.center = Vector3.ZERO
			var vert_count: int = 0
			
			# Check if this is a special brush (eg: origin)
			var brush_texture_type: FuncGodotMapData.FuncGodotTextureType = FuncGodotMapData.FuncGodotTextureType.NORMAL
			if brush.faces.size() > 0:
				brush_texture_type = map_data.textures[brush.faces[0].texture_idx].type
				
				# Check that all the faces match the same type
				for face_idx in range(1,brush.faces.size()):
					if map_data.textures[brush.faces[face_idx].texture_idx].type != brush_texture_type:
						brush_texture_type = FuncGodotMapData.FuncGodotTextureType.NORMAL # Reset face type if it doesn't match
						break
			
			generate_brush_vertices(e, b)
			
			var brush_geo: FuncGodotMapData.FuncGodotBrushGeometry = map_data.entity_geo[e].brushes[b]
			for face in brush_geo.faces:
				for vert in face.vertices:
					entity_mins = entity_mins.min(vert.vertex)
					entity_maxs = entity_maxs.max(vert.vertex)
					
					if brush_texture_type == FuncGodotMapData.FuncGodotTextureType.ORIGIN:
						origin_mins = origin_mins.min(vert.vertex)
						origin_maxs = origin_maxs.max(vert.vertex)
					
					brush.center += vert.vertex
					vert_count += 1
			
			if vert_count > 0:
				brush.center /= float(vert_count)
		
		# Default origin type is BOUNDS_CENTER
		entity.center = entity_maxs - ((entity_maxs - entity_mins) * 0.5)
		
		if entity.origin_type != FuncGodotMapData.FuncGodotEntityOriginType.BOUNDS_CENTER and entity.brushes.size() > 0:
			match entity.origin_type:
				FuncGodotMapData.FuncGodotEntityOriginType.ABSOLUTE, FuncGodotMapData.FuncGodotEntityOriginType.RELATIVE:
					if 'origin' in entity.properties:
						var origin_comps: PackedFloat64Array = entity.properties['origin'].split_floats(' ')
						if origin_comps.size() > 2:
							if entity.origin_type == FuncGodotMapData.FuncGodotEntityOriginType.ABSOLUTE:
								entity.center = Vector3(origin_comps[0], origin_comps[1], origin_comps[2])
							else: # OriginType.RELATIVE
								entity.center += Vector3(origin_comps[0], origin_comps[1], origin_comps[2])
				
				FuncGodotMapData.FuncGodotEntityOriginType.BRUSH:
					if origin_mins != Vector3.INF:
						entity.center = origin_maxs - ((origin_maxs - origin_mins) * 0.5)
				
				FuncGodotMapData.FuncGodotEntityOriginType.BOUNDS_MINS:
					entity.center = entity_mins
				
				FuncGodotMapData.FuncGodotEntityOriginType.BOUNDS_MAXS:
					entity.center = entity_maxs
				
				FuncGodotMapData.FuncGodotEntityOriginType.AVERAGED:
					entity.center = Vector3.ZERO
					for b in range(entity.brushes.size()):
						entity.center += entity.brushes[b].center
					entity.center /= float(entity.brushes.size())
	
	var generate_vertices_task_id:= WorkerThreadPool.add_group_task(generate_vertices_task, map_data.entities.size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(generate_vertices_task_id)
	
	# wind face vertices
	for e in range(map_data.entities.size()):
		var entity: FuncGodotMapData.FuncGodotEntity = map_data.entities[e]
		var entity_geo: FuncGodotMapData.FuncGodotEntityGeometry = map_data.entity_geo[e]
		
		for b in range(entity.brushes.size()):
			var brush: FuncGodotMapData.FuncGodotBrush = entity.brushes[b]
			var brush_geo: FuncGodotMapData.FuncGodotBrushGeometry = entity_geo.brushes[b]
			
			for f in range(brush.faces.size()):
				var face: FuncGodotMapData.FuncGodotFace = brush.faces[f]
				var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f]
				
				if face_geo.vertices.size() < 3:
					continue
				
				wind_entity_idx = e
				wind_brush_idx = b
				wind_face_idx = f
				
				wind_face_basis = face_geo.vertices[1].vertex - face_geo.vertices[0].vertex
				wind_face_center = Vector3.ZERO
				wind_face_normal = face.plane_normal
				
				for v in face_geo.vertices:
					wind_face_center += v.vertex
				
				wind_face_center /= face_geo.vertices.size()
				
				face_geo.vertices.sort_custom(sort_vertices_by_winding)
				wind_entity_idx = 0
	
	# index face vertices
	var index_faces_task:= func(e):
		var entity_geo: FuncGodotMapData.FuncGodotEntityGeometry = map_data.entity_geo[e]
		
		for b in range(entity_geo.brushes.size()):
			var brush_geo: FuncGodotMapData.FuncGodotBrushGeometry = entity_geo.brushes[b]
			
			for f in range(brush_geo.faces.size()):
				var face_geo: FuncGodotMapData.FuncGodotFaceGeometry = brush_geo.faces[f]
				
				if face_geo.vertices.size() < 3:
					continue
					
				var i_count: int = 0
				face_geo.indicies.resize((face_geo.vertices.size() - 2) * 3)
				for i in range(face_geo.vertices.size() - 2):
					face_geo.indicies[i_count] = 0
					face_geo.indicies[i_count + 1] = i + 1
					face_geo.indicies[i_count + 2] = i + 2
					i_count += 3
					
	var index_faces_task_id:= WorkerThreadPool.add_group_task(index_faces_task, map_data.entities.size(), 4, true)
	WorkerThreadPool.wait_for_group_task_completion(index_faces_task_id)
