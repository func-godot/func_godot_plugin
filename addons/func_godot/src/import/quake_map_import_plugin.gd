@tool
class_name QuakeMapImportPlugin extends EditorImportPlugin

func _get_importer_name() -> String:
	return 'func_godot.map'

func _get_visible_name() -> String:
	return 'Quake Map'

func _get_resource_type() -> String:
	return 'Resource'

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(['map','vmf'])
	
func _get_priority():
	return 1.0

func _get_save_extension() -> String:
	return 'tres'

func _get_import_options(path, preset):
	return []

func _get_preset_count() -> int:
	return 0
	
func _get_import_order():
	return 0

func _import(source_file, save_path, options, r_platform_variants, r_gen_files) -> Error:
	var save_path_str = '%s.%s' % [save_path, _get_save_extension()]

	var map_resource : QuakeMapFile = null

	if ResourceLoader.exists(save_path_str):
		map_resource = load(save_path_str) as QuakeMapFile
		map_resource.revision += 1
	else:
		map_resource = QuakeMapFile.new()
	map_resource.map_data = FileAccess.open(source_file, FileAccess.READ).get_as_text()

	return ResourceSaver.save(map_resource, save_path_str)
