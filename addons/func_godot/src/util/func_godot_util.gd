class_name FuncGodotUtil
## Static class with a number of reuseable utility methods that can be called at Editor or Run Time.

const _VERTEX_EPSILON: float = 0.008

const _VEC3_UP_ID		:= Vector3(0.0, 0.0, 1.0)
const _VEC3_RIGHT_ID		:= Vector3(0.0, 1.0, 0.0)
const _VEC3_FORWARD_ID 	:= Vector3(1.0, 0.0, 0.0)

## Connected by the [FuncGodotMap] node to the build process' sub-components if the 
## [member FuncGodotMap.build_flags]'s SHOW_PROFILE_INFO flag is set.
static func print_profile_info(message: String, signature: String) -> void:
	prints(signature, message)

## Return a [String] that corresponds to the current [OS]'s newline control characters.
static func newline() -> String:
	if OS.get_name() == "Windows":
		return "\r\n"
	else:
		return "\n"

#region MATH

static func op_vec3_sum(lhs: Vector3, rhs: Vector3) -> Vector3: 
	return lhs + rhs

static func op_vec3_avg(array: Array[Vector3]) -> Vector3:
	if array.is_empty():
		push_error("Cannot average empty Vector3 array!")
		return Vector3()
	return array.reduce(op_vec3_sum, Vector3()) / array.size()

## Conversion from id tech coordinate system to Godot, from a top-down perspective.
static func id_to_opengl(vec: Vector3) -> Vector3: 
	return Vector3(vec.y, vec.z, vec.x)

## Check if a point is inside a convex hull defined by a series of planes by an epsilon constant.
static func is_point_in_convex_hull(planes: Array[Plane], vertex: Vector3) -> bool:
	for plane in planes:
		var distance: float = plane.normal.dot(vertex) - plane.d
		if distance > _VERTEX_EPSILON:
			return false
	return true

#endregion

#region PATCH DEF

## Returns the control points that defines a cubic curve for a equivalent input quadratic curve.
static func elevate_quadratic(p0: Vector3, p1: Vector3, p2: Vector3) -> Array[Vector3]:
	return [p0, p0 + (2.0/3.0) * (p1 - p0), p2 + (2.0/3.0) * (p1 - p2), p2 ]

## Create a Curve3D and bake points.
static func create_curve(start: Vector3, control: Vector3, end: Vector3, bake_interval: float = 0.05) -> Curve3D:
	var ret := Curve3D.new()
	ret.bake_interval = bake_interval
	update_ref_curve(ret, start, control, end, bake_interval)
	return ret

## Update a Curve3D given quadratic inputs.
static func update_ref_curve(curve: Curve3D, p0: Vector3, p1: Vector3, p2: Vector3, bake_interval: float = 0.05) -> void:
	curve.clear_points()
	curve.bake_interval = bake_interval
	curve.add_point(p0, (p1 - p0) * (2.0 / 3.0))
	curve.add_point(p1, (p1 - p0) * (1.0 / 3.0), (p2 - p1) * (1.0 / 3.0))
	curve.add_point(p2, (p2 - p1 * (2.0 / 3.0)))

#endregion

#region TEXTURES

## Fallback texture if the one defined in the [QuakeMapFile] cannot be found.
const default_texture_path: String = "res://addons/func_godot/textures/default_texture.png"

const _pbr_textures: PackedInt32Array = [
	StandardMaterial3D.TEXTURE_ALBEDO,
	StandardMaterial3D.TEXTURE_NORMAL,
	StandardMaterial3D.TEXTURE_METALLIC,
	StandardMaterial3D.TEXTURE_ROUGHNESS,
	StandardMaterial3D.TEXTURE_EMISSION,
	StandardMaterial3D.TEXTURE_AMBIENT_OCCLUSION,
	StandardMaterial3D.TEXTURE_HEIGHTMAP,
	ORMMaterial3D.TEXTURE_ORM
	]

## Searches for a Texture2D within the base texture directory or the WAD files added to map settings. 
## If not found, a default texture is returned.
static func load_texture(texture_name: String, wad_resources: Array[QuakeWadFile], map_settings: FuncGodotMapSettings) -> Texture2D:
	for texture_file_extension in map_settings.texture_file_extensions:
		var texture_path: String = map_settings.base_texture_dir.path_join(texture_name + "." + texture_file_extension)
		if ResourceLoader.exists(texture_path):
			return load(texture_path)
	
	var texture_name_lower: String = texture_name.to_lower()
	for wad in wad_resources:
		if texture_name_lower in wad.textures:
			return wad.textures[texture_name_lower]
	
	return load(default_texture_path)

## Filters faces textured with Skip during the geometry generation step of the build process.
static func is_skip(texture: String, map_settings: FuncGodotMapSettings) -> bool:
	if map_settings:
		return texture.to_lower() == map_settings.skip_texture
	return false

## Filters faces textured with Clip during the geometry generation step of the build process.
static func is_clip(texture: String, map_settings: FuncGodotMapSettings) -> bool:
	if map_settings:
		return texture.to_lower() == map_settings.clip_texture
	return false

## Filters faces textured with Origin during the parsing and geometry generation steps of the build process.
static func is_origin(texture: String, map_settings: FuncGodotMapSettings) -> bool:
	if map_settings:
		return texture.to_lower() == map_settings.origin_texture
	return false

## Filters faces textured with any of the tool textures during the geometry generation step of the build process.
static func filter_face(texture: String, map_settings: FuncGodotMapSettings) -> bool:
	if map_settings:
		texture = texture.to_lower()
		if (texture == map_settings.skip_texture
			or texture == map_settings.clip_texture
		 	or texture == map_settings.origin_texture
			):
			return true
	return false

## Adds PBR textures to an existing [BaseMaterial3D].
static func build_base_material(map_settings: FuncGodotMapSettings, material: BaseMaterial3D, texture: String) -> void:
	var path: String = map_settings.base_texture_dir.path_join(texture)
	# Check if there is a subfolder with our PBR textures
	if DirAccess.open(path.path_join(path)):
		path = path.path_join(path)
	
	var pbr_suffixes: PackedStringArray = [
		map_settings.albedo_map_pattern,
		map_settings.normal_map_pattern,
		map_settings.metallic_map_pattern,
		map_settings.roughness_map_pattern,
		map_settings.emission_map_pattern,
		map_settings.ao_map_pattern,
		map_settings.height_map_pattern,
		map_settings.orm_map_pattern,
	]
	
	for texture_file_extension in map_settings.texture_file_extensions:
		for i in pbr_suffixes.size():
			if not pbr_suffixes[i].is_empty():
				var pbr: String = pbr_suffixes[i] % [path, texture_file_extension]
				if ResourceLoader.exists(pbr):
					material.set_texture(_pbr_textures[i], load(pbr))

## Builds both materials and sizes dictionaries for use in the geometry generation step of the build process. 
## Both dictionaries use texture names as keys. The materials dictionary uses [Material] as values, 
## while the sizes dictionary saves the albedo texture sizes to aid in UV mapping.
static func build_texture_map(entity_data: Array[FuncGodotData.EntityData], map_settings: FuncGodotMapSettings) -> Array[Dictionary]:
	var texture_materials: Dictionary[String, Material] = {}
	var texture_sizes: Dictionary[String, Vector2] = {}
	
	# Prepare WAD files
	var wad_resources: Array[QuakeWadFile] = []
	for wad in map_settings.texture_wads:
		if wad and not wad in wad_resources:
			wad_resources.append(wad)
	
	for entity in entity_data:
		if not entity.is_visual():
			continue

		for brush in entity.brushes:
			for face in brush.faces:
				var texture_name: String = face.texture
				
				if filter_face(texture_name, map_settings):
					continue
				if texture_materials.has(texture_name):
					continue
				
				var material_path: String = map_settings.base_material_dir if not map_settings.base_material_dir.is_empty() else map_settings.base_texture_dir
				material_path = material_path.path_join(texture_name) + "." + map_settings.material_file_extension
				material_path = material_path.replace("*", "")
				
				if ResourceLoader.exists(material_path):
					var material: Material = load(material_path)
					texture_materials[texture_name] = material
					if material is BaseMaterial3D:
						var albedo = material.albedo_texture
						if albedo is Texture2D:
							texture_sizes[texture_name] = material.albedo_texture.get_size()
					elif material is ShaderMaterial:
						var albedo = material.get_shader_parameter(map_settings.default_material_albedo_uniform)
						if albedo is Texture2D:
							texture_sizes[texture_name] = albedo.get_size()
					if not texture_sizes.has(texture_name):
						var texture: Texture2D = load_texture(texture_name, wad_resources, map_settings)
						if texture:
							texture_sizes[texture_name] = texture.get_size()
					if not texture_sizes.has(texture_name):
						texture_sizes[texture_name] = Vector2.ONE * map_settings.inverse_scale_factor
				
				# Material generation
				elif map_settings.default_material:
					var material = map_settings.default_material.duplicate(true)
					var texture: Texture2D = load_texture(texture_name, wad_resources, map_settings)
					texture_sizes[texture_name] = texture.get_size()
					
					if material is BaseMaterial3D:
						material.albedo_texture = texture
						build_base_material(map_settings, material, texture_name)
					elif material is ShaderMaterial:
						material.set_shader_parameter(map_settings.default_material_albedo_uniform, texture)
					
					if (map_settings.save_generated_materials and material 
						and texture_name != map_settings.clip_texture 
						and texture_name != map_settings.skip_texture 
						and texture_name != map_settings.origin_texture 
						and texture.resource_path != default_texture_path):
						ResourceSaver.save(material, material_path)
					
					texture_materials[texture_name] = material
				else: # No default material exists
					printerr("Error: No default material found in map settings")
	
	return [texture_materials, texture_sizes]

#endregion

#region UV MAPPING

## Returns UV coordinate calculated from the Valve 220 UV format.
static func get_valve_uv(vertex: Vector3, u_axis: Vector3, v_axis: Vector3, uv_basis := Transform2D.IDENTITY, texture_size := Vector2.ONE) -> Vector2:
	var uv := Vector2(u_axis.dot(vertex), v_axis.dot(vertex))
	uv += (uv_basis.origin * uv_basis.get_scale())
	uv.x /= uv_basis.x.x
	uv.y /= uv_basis.y.y
	uv.x /= texture_size.x
	uv.y /= texture_size.y
	return uv

## Returns UV coordinate calculated from the original id Standard UV format.
static func get_quake_uv(vertex: Vector3, normal: Vector3, uv_basis := Transform2D.IDENTITY, texture_size := Vector2.ONE) -> Vector2: 
	var nx := absf(normal.dot(Vector3.RIGHT))
	var ny := absf(normal.dot(Vector3.UP))
	var nz := absf(normal.dot(Vector3.FORWARD))
	var uv: Vector2
	
	if ny >= nx and ny >= nz:
		uv = Vector2(vertex.x, -vertex.z)
	elif nx >= ny and nx >= nz:
		uv = Vector2(vertex.y, -vertex.z)
	else:
		uv = Vector2(vertex.x, vertex.y)
	
	var uv_out := uv.rotated(uv_basis.get_rotation())
	uv_out /= uv_basis.get_scale()
	uv_out += uv_basis.origin
	uv_out /= texture_size
	return uv_out

## Determines which UV format is being used and returns the UV coordinate.
static func get_face_vertex_uv(vertex: Vector3, face: FuncGodotData.FaceData, texture_size: Vector2) -> Vector2:
	if face.uv_axes.size() >= 2:
		return get_valve_uv(vertex, face.uv_axes[0], face.uv_axes[1], face.uv, texture_size)
	else:
		return get_quake_uv(vertex, face.plane.normal, face.uv, texture_size)

## Returns the tangent calculated from the Valve 220 UV format.
static func get_valve_tangent(u: Vector3, v: Vector3, normal: Vector3) -> PackedFloat32Array:
	var u_axis: Vector3 = u.normalized()
	var v_axis: Vector3 = v.normalized()
	var v_sign: float = -signf(normal.cross(u_axis).dot(v_axis))
	return [u_axis.x, u_axis.y, u_axis.z, v_sign]

	# NOTE: we may still need to orthonormalize tangents. Just in case, here's a rough outline.
	#var tangent: Vector3 = u.normalized() 
	#tangent = (tangent - normal * normal.dot(tangent)).normalized()
	#
	## in the case of parallel U or V axes to planar normal, reconstruct the tangent
	#if tangent.length_squared() < 0.01:
	#	if absf(normal.y) < 0.9:
	#		tangent = Vector3.UP.cross(normal)
	#	else:
	#		tangent = Vector3.RIGHT.cross(normal)
	#
	#tangent = tangent.normalized()
	#return [tangent.x, tangent.y, tangent.z, -signf(normal.cross(tangent).dot(v.normalized))]

## Returns the tangent calculated from the original id Standard UV format.
static func get_quake_tangent(normal: Vector3, uv_y_scale: float, uv_rotation: float) -> PackedFloat32Array:
	var dx := normal.dot(_VEC3_RIGHT_ID)
	var dy := normal.dot(_VEC3_UP_ID)
	var dz := normal.dot(_VEC3_FORWARD_ID)
	var dxa := absf(dx)
	var dya := absf(dy)
	var dza := absf(dz)
	var u_axis: Vector3
	var v_sign: float = 0.0
	
	if dya >= dxa and dya >= dza:
		u_axis = _VEC3_FORWARD_ID
		v_sign = signf(dy)
	elif dxa >= dya and dxa >= dza:
		u_axis = _VEC3_FORWARD_ID
		v_sign = -signf(dx)
	elif dza >= dya and dza >= dxa:
		u_axis = _VEC3_RIGHT_ID
		v_sign = signf(dz)
		
	v_sign *= signf(uv_y_scale)
	u_axis = u_axis.rotated(normal, deg_to_rad(-uv_rotation) * v_sign)
	return [u_axis.x, u_axis.y, u_axis.z, v_sign]

static func get_face_tangent(face: FuncGodotData.FaceData) -> PackedFloat32Array:
	if face.uv_axes.size() >= 2:
		return get_valve_tangent(face.uv_axes[0], face.uv_axes[1], face.plane.normal)
	else:
		return get_quake_tangent(face.plane.normal, face.uv.get_scale().y, face.uv.get_rotation())

#endregion

#region MESH

static func smooth_mesh_by_angle(mesh: ArrayMesh, angle_deg: float = 89.0) -> Mesh:
	if not mesh:
		push_error("Need a source mesh to smooth")
		return
	
	var angle: float = deg_to_rad(clampf(angle_deg, 0.0, 360.0))
	
	var mesh_vertices: 	Array[Vector3] = []
	var mesh_normals: 	Array[Vector3] = []
	var surface_data: 	Array[Dictionary] = []
	var mdt: MeshDataTool
	var st := SurfaceTool.new()
	
	# Collect surface information
	for surface_index in mesh.get_surface_count():
		mdt = MeshDataTool.new()
		
		if mdt.create_from_surface(mesh, surface_index) != OK:
			continue
		
		var info: Dictionary = {
			"mdt": mdt,
			"ofs": mesh_vertices.size(),
			"mat": mesh.surface_get_material(surface_index)
		}
		
		surface_data.append(info)
		
		for i in mdt.get_vertex_count():
			mesh_vertices.append(mdt.get_vertex(i))
			mesh_normals.append(mdt.get_vertex_normal(i))
	
	var groups: Dictionary = {}
	
	# Group vertices by position
	for i in mesh_vertices.size():
		var pos := mesh_vertices[i]
		
		# this is likely already snapped from the map building process
		var key := pos.snappedf(_VERTEX_EPSILON)
		
		if not groups.has(key):
			groups[key] = [i]
		else:
			groups[key].append(i)
	
	# Collect normals. Likely optimizable.
	for group in groups.values():
		for i in group:
			var this := mesh_normals[i]
			var normal_out := Vector3()
			for j in group:
				var other := mesh_normals[j]
				if this.angle_to(other) <= angle:
					normal_out += other
			
			mesh_normals[i] = normal_out.normalized()
	
	var smoothed_mesh := ArrayMesh.new()
	
	# Construct smoothed output mesh
	for dict in surface_data:
		mdt = dict["mdt"]
		var offset: int = dict["ofs"]
		for i in mdt.get_vertex_count():
			mdt.set_vertex_normal(i, mesh_normals[offset + i])
		
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(dict["mat"])
		
		for i in mdt.get_face_count():
			for j in 3:
				var index := mdt.get_face_vertex(i, j)
				st.set_normal(mdt.get_vertex_normal(index))
				st.set_uv(mdt.get_vertex_uv(index))
				st.set_tangent(mdt.get_vertex_tangent(index))
				st.add_vertex(mdt.get_vertex(index))
		
		smoothed_mesh = st.commit(smoothed_mesh)
	
	return smoothed_mesh

#endregion
