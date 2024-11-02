class_name FuncGodotTextureLoader

enum PBRSuffix {
	ALBEDO,
	NORMAL,
	METALLIC,
	ROUGHNESS,
	EMISSION,
	AO,
	HEIGHT,
	ORM
}

# Suffix string / Godot enum / StandardMaterial3D property
const PBR_SUFFIX_NAMES: Dictionary = {
	PBRSuffix.ALBEDO: 'albedo',
	PBRSuffix.NORMAL: 'normal',
	PBRSuffix.METALLIC: 'metallic',
	PBRSuffix.ROUGHNESS: 'roughness',
	PBRSuffix.EMISSION: 'emission',
	PBRSuffix.AO: 'ao',
	PBRSuffix.HEIGHT: 'height',
	PBRSuffix.ORM: 'orm'
}

const PBR_SUFFIX_PATTERNS: Dictionary = {
	PBRSuffix.ALBEDO: '%s_albedo.%s',
	PBRSuffix.NORMAL: '%s_normal.%s',
	PBRSuffix.METALLIC: '%s_metallic.%s',
	PBRSuffix.ROUGHNESS: '%s_roughness.%s',
	PBRSuffix.EMISSION: '%s_emission.%s',
	PBRSuffix.AO: '%s_ao.%s',
	PBRSuffix.HEIGHT: '%s_height.%s',
	PBRSuffix.ORM: '%s_orm.%s'
}

var PBR_SUFFIX_TEXTURES: Dictionary = {
	PBRSuffix.ALBEDO: StandardMaterial3D.TEXTURE_ALBEDO,
	PBRSuffix.NORMAL: StandardMaterial3D.TEXTURE_NORMAL,
	PBRSuffix.METALLIC: StandardMaterial3D.TEXTURE_METALLIC,
	PBRSuffix.ROUGHNESS: StandardMaterial3D.TEXTURE_ROUGHNESS,
	PBRSuffix.EMISSION: StandardMaterial3D.TEXTURE_EMISSION,
	PBRSuffix.AO: StandardMaterial3D.TEXTURE_AMBIENT_OCCLUSION,
	PBRSuffix.HEIGHT: StandardMaterial3D.TEXTURE_HEIGHTMAP,
	PBRSuffix.ORM: ORMMaterial3D.TEXTURE_ORM
}

const PBR_SUFFIX_PROPERTIES: Dictionary = {
	PBRSuffix.NORMAL: 'normal_enabled',
	PBRSuffix.EMISSION: 'emission_enabled',
	PBRSuffix.AO: 'ao_enabled',
	PBRSuffix.HEIGHT: 'heightmap_enabled',
}

var map_settings: FuncGodotMapSettings = FuncGodotMapSettings.new()
var texture_wad_resources: Array = []

# Overrides
func _init(new_map_settings: FuncGodotMapSettings) -> void:
	map_settings = new_map_settings
	load_texture_wad_resources()

# Business Logic
func load_texture_wad_resources() -> void:
	texture_wad_resources.clear()
	for texture_wad in map_settings.texture_wads:
		if texture_wad and not texture_wad in texture_wad_resources:
			texture_wad_resources.append(texture_wad)

func load_textures(texture_list: Array) -> Dictionary:
	var texture_dict: Dictionary = {}
	for texture_name in texture_list:
		texture_dict[texture_name] = load_texture(texture_name)
	return texture_dict

func load_texture(texture_name: String) -> Texture2D:
	# Load albedo texture if it exists
	for texture_extension in map_settings.texture_file_extensions:
		var texture_path: String = "%s/%s.%s" % [map_settings.base_texture_dir, texture_name, texture_extension]
		if ResourceLoader.exists(texture_path, "Texture2D") or ResourceLoader.exists(texture_path + ".import", "Texture2D"):
			return load(texture_path) as Texture2D
	
	var texture_name_lower: String = texture_name.to_lower()
	for texture_wad in texture_wad_resources:
		if texture_name_lower in texture_wad.textures:
			return texture_wad.textures[texture_name_lower]
	
	return load("res://addons/func_godot/textures/default_texture.png") as Texture2D

func create_materials(texture_list: Array) -> Dictionary:
	var texture_materials: Dictionary = {}
	#prints("TEXLI", texture_list)
	for texture in texture_list:
		texture_materials[texture] = create_material(texture)
	return texture_materials

func create_material(texture_name: String) -> Material:
	# Autoload material if it exists
	var material_dict: Dictionary = {}
	
	var material_path: String = "%s/%s.%s" % [map_settings.base_texture_dir, texture_name, map_settings.material_file_extension]
	if not material_path in material_dict and (FileAccess.file_exists(material_path) or FileAccess.file_exists(material_path + ".remap")):
		var loaded_material: Material = load(material_path)
		if loaded_material:
			material_dict[material_path] = loaded_material
	
	# If material already exists, use it
	if material_path in material_dict:
		return material_dict[material_path]
	
	var material: Material = null
	
	if map_settings.default_material:
		material = map_settings.default_material.duplicate()
	else:
		material = StandardMaterial3D.new()
	var texture: Texture2D = load_texture(texture_name)
	if not texture:
		return material
	
	if material is StandardMaterial3D:
		material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, texture)
	elif material is ShaderMaterial && map_settings.default_material_albedo_uniform != "":
		material.set_shader_parameter(map_settings.default_material_albedo_uniform, texture)
	elif material is ORMMaterial3D:
		material.set_texture(ORMMaterial3D.TEXTURE_ALBEDO, texture)
	
	var pbr_textures : Dictionary = get_pbr_textures(texture_name)
	
	for pbr_suffix in PBRSuffix.values():
		var suffix: int = pbr_suffix
		var tex: Texture2D = pbr_textures[suffix]
		if tex:
			if material is ShaderMaterial:
				material = StandardMaterial3D.new()
				material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, texture)
			var enable_prop: String = PBR_SUFFIX_PROPERTIES[suffix] if suffix in PBR_SUFFIX_PROPERTIES else ""
			if(enable_prop != ""):
				material.set(enable_prop, true)
			material.set_texture(PBR_SUFFIX_TEXTURES[suffix], tex)
		
	material_dict[material_path] = material
	
	if (map_settings.save_generated_materials and material 
		and texture_name != map_settings.clip_texture 
		and texture_name != map_settings.skip_texture 
		and texture.resource_path != "res://addons/func_godot/textures/default_texture.png"):
		ResourceSaver.save(material, material_path)
	
	return material

# PBR texture fetching
func get_pbr_suffix_pattern(suffix: int) -> String:
	if not suffix in PBR_SUFFIX_NAMES:
		return ''
	
	var pattern_setting: String = "%s_map_pattern" % [PBR_SUFFIX_NAMES[suffix]]
	if pattern_setting in map_settings:
		return map_settings.get(pattern_setting)
	
	return PBR_SUFFIX_PATTERNS[suffix]

func get_pbr_texture(texture: String, suffix: PBRSuffix) -> Texture2D:
	var texture_comps: PackedStringArray = texture.split('/')
	if texture_comps.size() == 0:
		return null
	
	for texture_extension in map_settings.texture_file_extensions:
		var path: String = "%s/%s/%s" % [
			map_settings.base_texture_dir,
			'/'.join(texture_comps),
			get_pbr_suffix_pattern(suffix) % [
				texture_comps[-1],
				texture_extension
			]
		]

		if(FileAccess.file_exists(path)):
			return load(path) as Texture2D

	return null

func get_pbr_textures(texture_name: String) -> Dictionary:
	var pbr_textures: Dictionary = {}
	for pbr_suffix in PBRSuffix.values():
		pbr_textures[pbr_suffix] = get_pbr_texture(texture_name, pbr_suffix)
	return pbr_textures
