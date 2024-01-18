@tool
class_name QuakeWadImportPlugin extends EditorImportPlugin

enum WadEntryType {
	Palette = 0x40,
	SBarPic = 0x42,
	MipsTexture = 0x44,
	ConsolePic = 0x45
}

const TEXTURE_NAME_LENGTH := 16
const MAX_MIP_LEVELS := 4

func _get_importer_name() -> String:
	return 'func_godot.wad'

func _get_visible_name() -> String:
	return 'Quake Texture2D WAD'

func _get_resource_type() -> String:
	return 'Resource'

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(['wad'])

func _get_save_extension() -> String:
	return 'res'

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_import_options(path, preset) -> Array[Dictionary]:
	return [
		{
			'name': 'palette_file',
			'default_value': 'res://addons/func_godot/palette.lmp',
			'property_hint': PROPERTY_HINT_FILE,
			'hint_string': '*.lmp'
		},
		{
			'name': 'generate_mipmaps',
			'default_value': true,
			'property_hint': PROPERTY_HINT_NONE
		}
	]

func _get_preset_count() -> int:
	return 0
	
func _get_import_order() -> int:
	return 0
	
func _get_priority() -> float:
	return 1.0
	
func _import(source_file, save_path, options, r_platform_variants, r_gen_files) -> Error:
	var save_path_str : String = '%s.%s' % [save_path, _get_save_extension()]

	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		print(['Error opening super.wad file: ', err])
		return err

	var palette_path : String = options['palette_file']
	var palette_file : QuakePaletteFile = load(palette_path) as QuakePaletteFile
	if not palette_file:
		print('Error: Invalid palette file')
		return ERR_CANT_ACQUIRE_RESOURCE

	# Read WAD header
	var magic : PackedByteArray = file.get_buffer(4)
	var magic_string : String = magic.get_string_from_ascii()

	if(magic_string != 'WAD2'):
		print('Error: Invalid WAD magic')
		return ERR_INVALID_DATA

	var num_entries : int = file.get_32()
	var dir_offset : int = file.get_32()

	# Read entry list
	file.seek(0)
	file.seek(dir_offset)

	var entries : Array = []

	for entry_idx in range(0, num_entries):
		var offset : int = file.get_32()
		var in_wad_size : int = file.get_32()
		var size : int = file.get_32()
		var type : int = file.get_8()
		var compression : int = file.get_8()
		var unknown : int = file.get_16()
		var name : PackedByteArray = file.get_buffer(TEXTURE_NAME_LENGTH)
		var name_string : String = name.get_string_from_ascii()

		if type == int(WadEntryType.MipsTexture):
			entries.append([
				offset,
				in_wad_size,
				size,
				type,
				compression,
				name_string
			])

	# Read mip textures
	var texture_data_array: Array = []
	for entry in entries:
		var offset : int = entry[0]
		file.seek(0)
		file.seek(offset)

		var name : PackedByteArray = file.get_buffer(TEXTURE_NAME_LENGTH)
		var name_string : String = name.get_string_from_ascii()

		var width : int = file.get_32()
		var height : int = file.get_32()

		var mip_offsets : Array = []
		for idx in range(0, MAX_MIP_LEVELS):
			mip_offsets.append(file.get_32())

		var num_pixels : int = width * height
		texture_data_array.append([name_string, width, height, file.get_buffer(num_pixels)])

	# Create texture resources
	var textures : Dictionary = {}

	for texture_data in texture_data_array:
		var name : String = texture_data[0]
		var width : int = texture_data[1]
		var height : int = texture_data[2]
		var pixels : PackedByteArray = texture_data[3]

		var pixels_rgb := PackedByteArray()
		for palette_color in pixels:
			var rgb_color := palette_file.colors[palette_color] as Color
			pixels_rgb.append(rgb_color.r8)
			pixels_rgb.append(rgb_color.g8)
			pixels_rgb.append(rgb_color.b8)

		var texture_image := Image.create_from_data(width, height, false, Image.FORMAT_RGB8, pixels_rgb)
		if options["generate_mipmaps"] == true:
			texture_image.generate_mipmaps()
		
		var texture := ImageTexture.create_from_image(texture_image) #,Texture2D.FLAG_MIPMAPS | Texture2D.FLAG_REPEAT | Texture2D.FLAG_ANISOTROPIC_FILTER

		textures[name] = texture

	# Save WAD resource
	var wad_resource := QuakeWadFile.new(textures)
	return ResourceSaver.save(wad_resource, save_path_str)