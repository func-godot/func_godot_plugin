@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Pattern matching tags to enable a number of features in TrenchBroom, including display appearance and menu filtering options. This resource gets added to the [TrenchBroomGameConfig] resource. Does not affect appearance or functionality in Godot.
## See the TrenchBroom Documentation on [**Tags under the Game Configuration section**](https://trenchbroom.github.io/manual/latest/#game_configuration_files) and [**Special Bruch FuncGodotFace Types**](https://trenchbroom.github.io/manual/latest/#special_brush_face_types) for more information.
class_name TrenchBroomTag
extends Resource

enum TagMatchType {
	TEXTURE, ## Tag applies to any brush face with a texture matching the texture name.
	CLASSNAME ## Tag applies to any brush entity with a class name matching the tag pattern.
}

## Name to define this tag. Not used as the matching pattern.
@export var tag_name: String

## The attributes applied to matching faces or brush entities. Only "_transparent" is supported in TrenchBroom, which makes matching faces or brush entities transparent.
@export var tag_attributes : Array[String] = ["transparent"]

## Determines how the tag is matched. See [constant TagMatchType].
@export var tag_match_type: TagMatchType

## A string that filters which flag, param, or classname to use. [code]*[/code] can be used as a wildcard to include multiple options.
## [b]Example:[/b] [code]trigger_*[/code] with [constant TagMatchType] [i]Classname[/i] will apply this tag to all brush entities with the [code]trigger_[/code] prefix.
@export var tag_pattern: String

## A string that filters which textures recieve these attributes. Only used with a [constant TagMatchType] of [i]Texture[/i].
@export var texture_name: String
