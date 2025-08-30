@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name NetRadiantCustomGamePackConfig extends Resource
## Builds a gamepack for NetRadiant Custom.
##
## Resource that builds a gamepack configuration for NetRadiant Custom.

enum NetRadiantCustomMapType {
	QUAKE_1, ## Removes PatchDef entries from the map file.
	QUAKE_3 ## Allows the saving of PatchDef entries in the map file.
}

@export_tool_button("Export Gamepack") var _export_file: Callable = export_file 

## Gamepack folder and file name. Must be lower case and must not contain special characters.
@export var gamepack_name : String = "func_godot":
	set(new_name):
		gamepack_name = new_name.to_lower()

## Name of the game in NetRadiant Custom's gamepack list.
@export var game_name : String = "FuncGodot"

## Directory path containing your maps, textures, shaders, etc... relative to your project directory.
@export var base_game_path : String = ""

## [FuncGodotFGDFile] to include with this gamepack. If using multiple FGD file resources, 
## this should be the master FGD that contains them in [member FuncGodotFGDFile.base_fgd_files].
@export var fgd_file : FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## Collection of [NetRadiantCustomShader] resources for shader file generation.
@export var netradiant_custom_shaders : Array[Resource] = [
	preload("res://addons/func_godot/game_config/netradiant_custom/netradiant_custom_shader_clip.tres"),
	preload("res://addons/func_godot/game_config/netradiant_custom/netradiant_custom_shader_skip.tres"),
	preload("res://addons/func_godot/game_config/netradiant_custom/netradiant_custom_shader_origin.tres")
]

## Supported texture file types.
@export var texture_types : PackedStringArray = ["png", "jpg", "jpeg", "bmp", "tga"]

## Supported model file types.
@export var model_types : PackedStringArray = ["glb", "gltf", "obj"]

## Supported audio file types.
@export var sound_types : PackedStringArray = ["wav", "ogg"]

## Default scale of textures in NetRadiant Custom.
@export var default_scale : String = "1.0"

## Clip texture path that gets applied to [i]weapclip[/i] and [i]nodraw[/i] shaders.
@export var clip_texture: String = "textures/special/clip"

## Skip texture path that gets applied to [i]caulk[/i] and [i]nodrawnonsolid[/i] shaders.
@export var skip_texture: String = "textures/special/skip"

## Quake map type NetRadiant will filter the map for, determining whether PatchDef entries are saved. 
## [color=red][b]WARNING![/b][/color] Toggling this option may be destructive!
@export var map_type: NetRadiantCustomMapType = NetRadiantCustomMapType.QUAKE_1

## Variables to include in the exported gamepack's [code]default_build_menu.xml[/code].[br][br]
## Each [String] key defines a variable name, and its corresponding [String] value as the literal command-line string 
## to execute in place of this variable identifier[br][br]
## Entries may be referred to by key in [member default_build_menu_commands] values.
@export var default_build_menu_variables: Dictionary

## Commands to include in the exported gamepack's [code]default_build_menu.xml[/code].[br][br]
## Keys, specified as a [String], define the build option name as you want it to appear in NetRadiant Custom.[br][br]
## Values represent commands taken within each option.[br][br]They may be either a [String] or an [Array] of [String] elements 
## that will be used as the full command-line text issued by each command [i]within[/i] its associated build option key.[br][br]
## They may reference entries in [member default_build_menu_variables] by using brackets: [code][variable key name][/code]
@export var default_build_menu_commands: Dictionary

# Generates completed text for a .shader file.
func _build_shader_text() -> String:
	var shader_text: String = ""
	for shader_res in netradiant_custom_shaders:
		shader_text += (shader_res as NetRadiantCustomShader).texture_path + "\n{\n"
		for shader_attrib in (shader_res as NetRadiantCustomShader).shader_attributes:
			shader_text += "\t" + shader_attrib + "\n"
		shader_text += "}\n"
	return shader_text

# Generates completed text for a .gamepack file.
func _build_gamepack_text() -> String:
	var texturetypes_str: String = ""
	for texture_type in texture_types:
		texturetypes_str += texture_type
		if texture_type != texture_types[-1]:
			texturetypes_str += " "
	
	var modeltypes_str: String = ""
	for model_type in model_types:
		modeltypes_str += model_type
		if model_type != model_types[-1]:
			modeltypes_str += " "
	
	var soundtypes_str: String = ""
	for sound_type in sound_types:
		soundtypes_str += sound_type
		if sound_type != sound_types[-1]:
			soundtypes_str += " "

	var maptype_str: String

	if map_type == NetRadiantCustomMapType.QUAKE_3:
		maptype_str = "mapq3"
	else:
		maptype_str = "mapq1"
	
	var gamepack_text: String = """<?xml version="1.0"?>
<game
  type="q3"
  index="1" 
  name="%s"
  enginepath_win32="C:/%s/"
  engine_win32="%s.exe"
  enginepath_linux="/usr/local/games/%s/"
  engine_linux="%s"
  basegame="%s"
  basegamename="%s"
  unknowngamename="Custom %s modification"
  shaderpath="scripts"
  archivetypes="pk3"
  texturetypes="%s"
  modeltypes="%s"
  soundtypes="%s"
  maptypes="%s"
  shaders="quake3"
  entityclass="quake3"
  entityclasstype="fgd"
  entities="quake"
  brushtypes="quake"
  patchtypes="quake3"
  q3map2_type="quake3"
  default_scale="%s"
  shader_weapclip="%s"
  shader_caulk="%s"
  shader_nodraw="%s"
  shader_nodrawnonsolid="%s"
  common_shaders_name="Common"
  common_shaders_dir="common/"
/>
"""
	
	return gamepack_text % [
		game_name,
		game_name,
		gamepack_name,
		game_name,
		gamepack_name,
		base_game_path,
		game_name,
		game_name,
		texturetypes_str,
		modeltypes_str,
		soundtypes_str,
		maptype_str,
		default_scale,
		clip_texture,
		skip_texture,
		clip_texture,
		skip_texture
	]

## Exports this game's configuration with an icon, .cfg, and all accompanying FGD files in the [FuncGodotLocalConfig] [b]NetRadiant Custom Gamepacks Folder[/b].
func export_file() -> void:
	var game_path: String = FuncGodotLocalConfig.get_setting(FuncGodotLocalConfig.PROPERTY.MAP_EDITOR_GAME_PATH) as String
	if game_path.is_empty():
		printerr("Skipping export: Map Editor Game Path not set in Project Configuration")
		return
	
	var gamepacks_folder: String = FuncGodotLocalConfig.get_setting(FuncGodotLocalConfig.PROPERTY.NETRADIANT_CUSTOM_GAMEPACKS_FOLDER) as String
	if gamepacks_folder.is_empty():
		printerr("Skipping export: No NetRadiant Custom gamepacks folder")
		return
	
	# Make sure FGD file is set
	if !fgd_file:
		printerr("Skipping export: No FGD file")
		return
	
	# Make sure we're actually in the NetRadiant Custom gamepacks folder
	if DirAccess.open(gamepacks_folder + "/games") == null:
		printerr("Skipping export: No \'games\' folder. Is this the NetRadiant Custom gamepacks folder?")
		return
	
	# Create gamepack folders in case they do not exist
	var gamepack_dir_paths: Array = [
		gamepacks_folder + "/" + gamepack_name + ".game",
		gamepacks_folder + "/" + gamepack_name + ".game/" + base_game_path,
		gamepacks_folder + "/" + gamepack_name + ".game/scripts",
		game_path + "/scripts"
	]
	var err: Error
	
	for path in gamepack_dir_paths:
		if DirAccess.open(path) == null:
			print("Couldn't open " + path + ", creating...")
			err = DirAccess.make_dir_recursive_absolute(path)
			if err != OK:
				printerr("Skipping export: Failed to create directory")
				return
	
	var target_file_path: String
	var file: FileAccess
	
	# .gamepack
	target_file_path = gamepacks_folder + "/games/" + gamepack_name + ".game"
	print("Exporting NetRadiant Custom Gamepack to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(_build_gamepack_text())
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# .shader
	# NOTE: To work properly, this should go in the game path. For now, I'm leaving the export to NRC as well, so it can easily
	# be repackaged for distribution. However, I believe in the end, it shouldn't exist there. 
	# We'll need to make a decision for this. - Vera
	var shader_text: String = _build_shader_text()
	
	# build to <gamepack path>/scripts/
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/scripts/" + gamepack_name + ".shader"
	print("Exporting NetRadiant Custom shader definitions to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(shader_text)
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)

	# build to <game path>/scripts/	
	target_file_path = game_path.path_join("scripts/%s.shader" % gamepack_name) 
	print("Exporting NetRadiant Custom shader definitions to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(shader_text)
		file.close()
	else:
		printerr("Error: could not modify " + target_file_path)
	
	# shaderlist.txt - see above NOTE regarding duplication 
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/scripts/shaderlist.txt"
	print("Exporting NetRadiant Custom shader list to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(gamepack_name)
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# game path/scripts/shaderlist.txt
	target_file_path = game_path.path_join("scripts/shaderlist.txt")
	print("Exporting NetRadiant Custom shader list to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(gamepack_name)
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# default_build_menu.xml
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/default_build_menu.xml"
	print("Exporting NetRadiant Custom default build menu to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	
	if file != null:
		file.store_string("<?xml version=\"1.0\"?>\n<project version=\"2.0\">\n")
		
		for key in default_build_menu_variables.keys():
			if key is String:
				if default_build_menu_variables[key] is String:
					file.store_string('\t<var name="%s">%s</var>\n' % [key, default_build_menu_variables[key]])
				
				else:
					push_error(
						"Variable key '%s' value '%s' is invalid type: %s; should be: String" % [
						key, default_build_menu_variables[key], 
						type_string(typeof(default_build_menu_variables[key]))
						])
			else:
				push_error(
					"Variable '%s' is an invalid key type: %s; should be: String" % [
						key, type_string(typeof(key))
						])
			
			
		for key in default_build_menu_commands.keys():
			if key is String:
				file.store_string('\t<build name="%s">\n' % key)
				
				if default_build_menu_commands[key] is String:
					file.store_string('\t\t<command>%s</command>\n\t</build>\n' % default_build_menu_commands[key])
				
				elif default_build_menu_commands[key] is Array:
					for command in default_build_menu_commands[key]:
						if command is String:
							file.store_string('\t\t<command>%s</command>\n' % command)
						else:
							push_error("Build option '%s' has invalid command: %s with type: %s; should be: String" % [
								key, command, type_string(typeof(command))
								])	
						
					file.store_string('\t</build>\n')
			
			else:
				push_error("Build option '%s' is an invalid type: %s; should be: String" % [
					key, type_string(typeof(key))
					])
		
		file.store_string("</project>")
	
	# FGD
	var export_fgd : FuncGodotFGDFile = fgd_file.duplicate()
	export_fgd.do_export_file(FuncGodotFGDFile.FuncGodotTargetMapEditors.NET_RADIANT_CUSTOM, gamepacks_folder + "/" + gamepack_name + ".game/" + base_game_path)
	print("NetRadiant Custom Gamepack export complete\n")
