@tool
class_name Quake2WalImportPlugin extends EditorImportPlugin

const TEXTURE_NAME_LENGTH := 32
const MAX_MIP_LEVELS := 4
const DEFAULT_PALETTE_PATH := "res://addons/func_godot/quake2_palette.lmp"

func _get_importer_name() -> String:
	return "func_godot.wal"

func _get_visible_name() -> String:
	return "Quake 2 WAL"

func _get_resource_type() -> String:
	return "Texture2D"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["wal"])

func _get_save_extension() -> String:
	return "res"

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_import_options(path, preset) -> Array[Dictionary]:
	return [
		{
			"name": "palette_file",
			"default_value": DEFAULT_PALETTE_PATH,
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.lmp,*.pcx,*.tres,*.res"
		},
		{
			"name": "generate_mipmaps",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE
		}
	]

func _get_preset_count() -> int:
	return 0

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 1.0

func _build_fallback_palette() -> PackedColorArray:
	var colors := PackedColorArray()
	for i in 256:
		var t: float = float(i) / 255.0
		colors.append(Color(t, t, t, 1.0))
	return colors

func _load_pcx_palette(palette_path: String) -> PackedColorArray:
	var file := FileAccess.open(palette_path, FileAccess.READ)
	if file == null:
		return PackedColorArray()

	var length: int = file.get_length()
	# PCX palette footer is 0x0C + 768 RGB bytes.
	if length < 769:
		file.close()
		return PackedColorArray()

	file.seek(length - 769)
	var marker: int = file.get_8()
	if marker != 0x0C:
		file.close()
		return PackedColorArray()

	var bytes: PackedByteArray = file.get_buffer(768)
	file.close()
	if bytes.size() != 768:
		return PackedColorArray()

	var colors := PackedColorArray()
	colors.resize(256)
	for i in 256:
		var idx: int = i * 3
		colors[i] = Color8(bytes[idx], bytes[idx + 1], bytes[idx + 2], 255)
	return colors

func _import(source_file, save_path, options, r_platform_variants, r_gen_files) -> Error:
	var save_path_str: String = "%s.%s" % [save_path, _get_save_extension()]
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		printerr(["Error opening .wal file: ", err])
		return err

	# WAL header
	file.get_buffer(TEXTURE_NAME_LENGTH) # name
	var width: int = file.get_32()
	var height: int = file.get_32()
	var mip_offsets: PackedInt32Array = PackedInt32Array()
	mip_offsets.resize(MAX_MIP_LEVELS)
	for i in MAX_MIP_LEVELS:
		mip_offsets[i] = file.get_32()
	file.get_buffer(TEXTURE_NAME_LENGTH) # animname
	file.get_32() # flags
	file.get_32() # contents
	file.get_32() # value

	if width <= 0 or height <= 0:
		printerr("Error: Invalid .wal dimensions")
		file.close()
		return ERR_INVALID_DATA

	if mip_offsets[0] <= 0:
		printerr("Error: Invalid .wal mip offset")
		file.close()
		return ERR_INVALID_DATA

	file.seek(mip_offsets[0])
	var num_pixels: int = width * height
	var pixels: PackedByteArray = file.get_buffer(num_pixels)
	file.close()

	if pixels.size() != num_pixels:
		printerr("Error: Unexpected .wal pixel data size")
		return ERR_INVALID_DATA

	var colors: PackedColorArray = PackedColorArray()
	var palette_path: String = options.get("palette_file", DEFAULT_PALETTE_PATH)
	if not palette_path.is_empty():
		if palette_path.to_lower().ends_with(".pcx"):
			colors = _load_pcx_palette(palette_path)
		else:
			var palette_resource: QuakePaletteFile = load(palette_path) as QuakePaletteFile
			if palette_resource and palette_resource.colors.size() >= 256:
				colors = palette_resource.colors
		if colors.size() < 256:
			push_warning("Invalid palette file for .wal import (%s). Using fallback grayscale palette." % palette_path)

	if colors.size() < 256:
		colors = _build_fallback_palette()

	var pixels_rgba := PackedByteArray()
	pixels_rgba.resize(num_pixels * 4)
	for i in num_pixels:
		var palette_index: int = pixels[i]
		var color: Color = colors[palette_index]
		var offset: int = i * 4
		pixels_rgba[offset] = color.r8
		pixels_rgba[offset + 1] = color.g8
		pixels_rgba[offset + 2] = color.b8
		# Quake-era masked pixels are commonly palette index 255 (often magenta in palettes).
		if palette_index == 255 or (color.r8 == 255 and color.g8 == 0 and color.b8 == 255):
			pixels_rgba[offset + 3] = 0
		else:
			pixels_rgba[offset + 3] = 255

	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels_rgba)
	if options.get("generate_mipmaps", true):
		image.generate_mipmaps()

	var texture := ImageTexture.create_from_image(image)
	return ResourceSaver.save(texture, save_path_str)
