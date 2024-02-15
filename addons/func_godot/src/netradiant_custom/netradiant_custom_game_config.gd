@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Builds a new gamepack for NetRadiant Custom
class_name NetRadiantCustomGameConfig
extends Resource

## Button to export/update this gamepack's folder
@export var export_file: bool:
	get:
		return export_file
	set(new_export_file):
		if new_export_file != export_file:
			if Engine.is_editor_hint():
				do_export_file()

## Name of the gamepack in NetRadiant Custom's gamepack list.
@export var game_name : String = "funcgodot"

## FGD resource to include with this gamepack. If using multiple FGD resources, this should be the master FGD that contains them in the `base_fgd_files` resource array.
@export var fgd_file : FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## Scale of entities in NetRadiant Custom
@export var entity_scale: String = "32"

## Generates completed text for a .gamepack file.
func build_class_text() -> String:
	return ""

## Exports or updates a folder in the /games directory, with an icon, .cfg, and all accompanying FGDs.
func do_export_file() -> void:
	var gamepack_folder: String = FuncGodotProjectConfig.get_setting(FuncGodotProjectConfig.PROPERTY.MAP_EDITOR_GAME_CONFIG_FOLDER) as String
	if gamepack_folder.is_empty():
		print("Skipping export: No NetRadiant Custom gamepack folder")
		return
	
	# Make sure FGD file is set
	if !fgd_file:
		print("Skipping export: No FGD file")
		return
	
	var gamepack_dir := DirAccess.open(gamepack_folder)
	# Create config folder in case it does not exist
	if gamepack_dir == null:
		print("Couldn't open directory, creating...")
		var err := DirAccess.make_dir_recursive_absolute(gamepack_folder)
		if err != OK:
			print("Skipping export: Failed to create directory")
			return
		gamepack_dir = DirAccess.open(gamepack_folder)
	
	# .gamepack
	var export_gamepack_file: Dictionary = {}
	export_gamepack_file.game_name = game_name
	export_gamepack_file.target_file = gamepack_folder + "/" + game_name + ".gamepack"
	print("Exporting NetRadiant Custom Gamepack File to ", export_gamepack_file.target_file)
	var file = FileAccess.open(export_gamepack_file.target_file, FileAccess.WRITE)
	file.store_string(build_class_text())
	file = null # Official way to close files in GDscript 2
	
	# FGD
	var export_fgd : FuncGodotFGDFile = fgd_file.duplicate()
	export_fgd.do_export_file(true)
	print("Export complete\n")
