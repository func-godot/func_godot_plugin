@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Defines a game in TrenchBroom to express a set of entity definitions and editor behaviors.
class_name TrenchBroomGameConfig
extends Resource

## Keeps track of each individual version
enum GameConfigVersion {
	Latest,
	Version4,
	Version8,
	Version9
}

## Button to export / update this game's configuration and FGD file in the TrenchBroom Games Path.
@export var export_file: bool:
	get:
		return export_file
	set(new_export_file):
		if new_export_file != export_file:
			if Engine.is_editor_hint():
				do_export_file()

## Name of the game in TrenchBroom's game list.
@export var game_name : String = "FuncGodot"

## Icon for TrenchBroom's game list.
@export var icon : Texture2D = preload("res://addons/func_godot/icon32.png")

## Available map formats when creating a new map in TrenchBroom. The order of elements in the array is the order TrenchBroom will list the available formats. The `initialmap` key value is optional.
@export var map_formats: Array[Dictionary] = [
	{ "format": "Valve", "initialmap": "initial_valve.map" },
	{ "format": "Standard", "initialmap": "initial_standard.map" },
	{ "format": "Quake2", "initialmap": "initial_quake2.map" },
	{ "format": "Quake3" }
]

@export_category("Textures")

## Path to top level textures folder relative to the game path. Also referred to as materials in the latest versions of TrenchBroom.
@export var textures_root_folder: String = "textures"

## Textures matching these patterns will be hidden from TrenchBroom.
@export var texture_exclusion_patterns: Array[String] = ["*_albedo", "*_ao", "*_emission", "*_height", "*_metallic", "*_normal", "*_orm", "*_roughness", "*_sss"]

## Palette path relative to your Game Path. Only needed for Quake WAD2 files. Half-Life WAD3 files contain the palettes within the texture information.
@export var palette_path: String = "textures/palette.lmp"

@export_category("Entities")

## FGD resource to include with this game. If using multiple FGD resources, this should be the master FGD that contains them in the `base_fgd_files` resource array.
@export var fgd_file : FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## Scale expression that modifies the default display scale of entities in TrenchBroom. See the [**TrenchBroom Documentation**](https://trenchbroom.github.io/manual/latest/#game_configuration_files_entities) for more information.
@export var entity_scale: String = "32"

## Arrays containing the TrenchBroomTag resource type.
@export_category("Tags")

## TrenchBroomTag resources that apply to brush entities.
@export var brush_tags : Array[Resource] = []

## TrenchBroomTag resources that apply to brush faces.
@export var brushface_tags : Array[Resource] = [
	preload("res://addons/func_godot/game_config/trenchbroom/tb_face_tag_clip.tres"),
	preload("res://addons/func_godot/game_config/trenchbroom/tb_face_tag_skip.tres"),
	preload("res://addons/func_godot/game_config/trenchbroom/tb_face_tag_origin.tres")
]

@export_category("Face Attributes")

## Default scale of textures on new brushes and when UV scale is reset.
@export var default_uv_scale : Vector2 = Vector2(1, 1)

@export_category("Compatibility")

## Game configuration format compatible with the version of TrenchBroom being used.
@export var game_config_version: GameConfigVersion = GameConfigVersion.Latest

## Matches tag key enum to the String name used in .cfg
static func get_match_key(tag_match_type: int) -> String:
	match tag_match_type:
		TrenchBroomTag.TagMatchType.TEXTURE:
			return "material"
		TrenchBroomTag.TagMatchType.CLASSNAME:
			return "classname"
		_:
			push_error("Tag match type %s is not valid" % [tag_match_type])
			return "ERROR"

## Generates completed text for a .cfg file.
func build_class_text() -> String:
	var map_formats_str : String = ""
	for map_format in map_formats:
		map_formats_str += "{ \"format\": \"" + map_format.format + "\""
		if map_format.has("initialmap"):
			map_formats_str += ", \"initialmap\": \"" + map_format.initialmap + "\""
		if map_format != map_formats[-1]:
			map_formats_str += " },\n\t\t"
		else:
			map_formats_str += " }"
	
	var texture_exclusion_patterns_str := ""
	for tex_pattern in texture_exclusion_patterns:
		texture_exclusion_patterns_str += "\"" + tex_pattern + "\""
		if tex_pattern != texture_exclusion_patterns[-1]:
			texture_exclusion_patterns_str += ", "
	
	var fgd_filename_str : String = "\"" + fgd_file.fgd_name + ".fgd\""

	var brush_tags_str = parse_tags(brush_tags)
	var brushface_tags_str = parse_tags(brushface_tags)
	var uv_scale_str = parse_default_uv_scale(default_uv_scale)
	
	var config_text : String = ""
	match game_config_version:
		GameConfigVersion.Latest, GameConfigVersion.Version8, GameConfigVersion.Version9:
			config_text = get_game_config_v9v8_text() % [
				game_name,
				map_formats_str,
				textures_root_folder,
				texture_exclusion_patterns_str,
				palette_path,
				fgd_filename_str,
				entity_scale,
				brush_tags_str,
				brushface_tags_str,
				uv_scale_str
			]

		GameConfigVersion.Version4:
			config_text = get_game_config_v4_text() % [
				game_name,
				map_formats_str,
				textures_root_folder,
				texture_exclusion_patterns_str,
				palette_path,
				fgd_filename_str,
				entity_scale,
				brush_tags_str,
				brushface_tags_str,
				uv_scale_str
			]

		_:
			push_error("Unsupported Game Config Version!")
	
	return config_text

## Converts brush, FuncGodotFace, and attribute tags into a .cfg-usable String.
func parse_tags(tags: Array) -> String:
	var tags_str := ""
	for brush_tag in tags:
		if brush_tag.tag_match_type >= TrenchBroomTag.TagMatchType.size():
			continue
		tags_str += "{\n"
		tags_str += "\t\t\t\t\"name\": \"%s\",\n" % brush_tag.tag_name
		var attribs_str := ""
		for brush_tag_attrib in brush_tag.tag_attributes:
			attribs_str += "\"%s\"" % brush_tag_attrib
			if brush_tag_attrib != brush_tag.tag_attributes[-1]:
				attribs_str += ", "
		tags_str += "\t\t\t\t\"attribs\": [ %s ],\n" % attribs_str
		tags_str += "\t\t\t\t\"match\": \"%s\",\n" % get_match_key(brush_tag.tag_match_type)
		tags_str += "\t\t\t\t\"pattern\": \"%s\"" % brush_tag.tag_pattern
		if brush_tag.texture_name != "":
			tags_str += ",\n"
			tags_str += "\t\t\t\t\"material\": \"%s\"" % brush_tag.texture_name
		tags_str += "\n"
		tags_str += "\t\t\t}"
		if brush_tag != tags[-1]:
			tags_str += ","
	if game_config_version < GameConfigVersion.Version9:
		tags_str = tags_str.replace("material", "texture")
	return tags_str

## Converts array of flags to .cfg String.
func parse_flags(flags: Array) -> String:
	var flags_str := ""
	for attrib_flag in flags:
		flags_str += "{\n"
		flags_str += "\t\t\t\t\"name\": \"%s\",\n" % attrib_flag.attrib_name
		flags_str += "\t\t\t\t\"description\": \"%s\"\n" % attrib_flag.attrib_description
		flags_str += "\t\t\t}"
		if attrib_flag != flags[-1]:
			flags_str += ","
	return flags_str

## Converts default uv scale vector to .cfg String.
func parse_default_uv_scale(texture_scale : Vector2) -> String:
	var entry_str = "\"scale\": [{x}, {y}]"
	return entry_str.format({
		"x": texture_scale.x,
		"y": texture_scale.y
	})

## Exports or updates a folder in the /games directory, with an icon, .cfg, and all accompanying FGDs.
func do_export_file() -> void:
	var config_folder: String = FuncGodotLocalConfig.get_setting(FuncGodotLocalConfig.PROPERTY.TRENCHBROOM_GAME_CONFIG_FOLDER) as String
	if config_folder.is_empty():
		printerr("Skipping export: No TrenchBroom Game folder")
		return
	
	# Make sure FGD file is set
	if !fgd_file:
		printerr("Skipping export: No FGD file")
		return
	
	var config_dir := DirAccess.open(config_folder)
	# Create config folder in case it does not exist
	if config_dir == null:
		print("Couldn't open directory, creating...")
		var err := DirAccess.make_dir_recursive_absolute(config_folder)
		if err != OK:
			printerr("Skipping export: Failed to create directory")
			return
	
	# Icon
	var icon_path : String = config_folder + "/icon.png"
	print("Exporting icon to ", icon_path)
	var export_icon : Image = icon.get_image()
	export_icon.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	export_icon.save_png(icon_path)
	
	# .cfg
	var target_file_path: String = config_folder + "/GameConfig.cfg"
	print("Exporting TrenchBroom Game Config to ", target_file_path)
	var file = FileAccess.open(target_file_path, FileAccess.WRITE)
	file.store_string(build_class_text())
	file.close()
	
	# FGD
	var export_fgd : FuncGodotFGDFile = fgd_file.duplicate()
	export_fgd.do_export_file(FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM, config_folder)
	print("TrenchBroom Game Config export complete\n")

#region GameConfigDeclarations
func get_game_config_v4_text() -> String:
	return """\
{
	"version": 4,
	"name": "%s",
	"icon": "icon.png",
	"fileformats": [
		%s
	],
	"filesystem": {
		"searchpath": ".",
		"packageformat": { "extension": ".zip", "format": "zip" }
	},
	"textures": {
		"package": { "type": "directory", "root": "%s" },
		"format": { "extensions": ["jpg", "jpeg", "tga", "png", "D", "C"], "format": "image" },
		"excludes": [ %s ],
		"palette": "%s",
		"attribute": ["_tb_textures", "wad"]
	},
	"entities": {
		"definitions": [ %s ],
		"defaultcolor": "0.6 0.6 0.6 1.0",
		"modelformats": [ "bsp, mdl, md2" ],
		"scale": %s
	},
	"tags": {
		"brush": [
			%s
		],
		"brushface": [
			%s
		]
	},
	"faceattribs": { 
		"defaults": {
			%s
		},
		"contentflags": [],
		"surfaceflags": []
	}
}
	"""

func get_game_config_v9v8_text() -> String:
	var config_text: String = """\
{
	"version": 9,
	"name": "%s",
	"icon": "icon.png",
	"fileformats": [
		%s
	],
	"filesystem": {
		"searchpath": ".",
		"packageformat": { "extension": ".zip", "format": "zip" }
	},
	"materials": {
		"root": "%s",
		"extensions": [".bmp", ".exr", ".hdr", ".jpeg", ".jpg", ".png", ".tga", ".webp", ".D", ".C"],
		"excludes": [ %s ],
		"palette": "%s",
		"attribute": "wad"
	},
	"entities": {
		"definitions": [ %s ],
		"defaultcolor": "0.6 0.6 0.6 1.0",
		"scale": %s
	},
	"tags": {
		"brush": [
			%s
		],
		"brushface": [
			%s
		]
	},
	"faceattribs": { 
		"defaults": {
			%s
		},
		"contentflags": [],
		"surfaceflags": []
	}
}
	"""
	
	if game_config_version != GameConfigVersion.Version9: # Change this to check if == Version8 when TB 2024.2 hits Stable
		config_text = config_text.replace(": 9,", ": 8,")
		config_text = config_text.replace("material", "texture")
	
	return config_text

#endregion
