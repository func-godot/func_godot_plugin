@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
@tool
## Reusable map settings configuration for [FuncGodotMap] nodes.
class_name FuncGodotMapSettings
extends Resource

## Ratio between map editor units and Godot units. FuncGodot will divide brush coordinates by this number when building. This does not affect entity properties unless scripted to do so.
var scale_factor: float = 0.03125
@export var inverse_scale_factor: float = 32.0 :
	set(value):
		inverse_scale_factor = value
		scale_factor = 1.0 / value

## [FuncGodotFGDFile] that translates map file classnames into Godot nodes and packed scenes.
@export var entity_fgd: FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## Default class property to use in naming generated nodes. This setting is overridden by `name_property` in [FuncGodotFGDEntityClass].
## Naming occurs before adding to the [SceneTree] and applying properties.
## Nodes will be named `"entity_" + name_property`. An entity's name should be unique, otherwise you may run into unexpected behavior.
@export var entity_name_property: String = ""

@export_category("Textures")

## Base directory for textures. When building materials, FuncGodot will search this directory for texture files with matching names to the textures assigned to map brush faces.
@export_dir var base_texture_dir: String = "res://textures"

## File extensions to search for texture data.
@export var texture_file_extensions: Array[String] = ["png", "jpg", "jpeg", "bmp", "tga", "webp"]

## Optional path for the clip texture, relative to [member base_texture_dir]. Brush faces textured with the clip texture will have those faces removed from the generated [MeshInstance3D] but not the generated [CollisionShape3D].
@export var clip_texture: String = "special/clip"

## Optional path for the skip texture, relative to [member base_texture_dir]. Brush faces textured with the skip texture will have those faces removed from the generated [MeshInstance3D]. If the [FuncGodotFGDSolidClass] `collision_shape_type` is set to concave then it will also remove collision from those faces in the generated [CollisionShape3D].
@export var skip_texture: String = "special/skip"

## Optional path for the origin texture, relative to [member base_texture_dir]. Brush faces textured with the origin texture will have those faces removed from the generated [MeshInstance3D]. The bounds of these faces will be used to calculate the origin point of the entity.
@export var origin_texture: String = "special/origin"

## Optional [QuakeWADFile] resources to apply textures from. See the [Quake Wiki](https://quakewiki.org/wiki/Texture_Wad) for more information on Quake Texture WADs.
@export var texture_wads: Array[Resource] = []

@export_category("Materials")

## File extension to search for [Material] definitions
@export var material_file_extension: String = "tres"

## [Material] used as template when generating missing materials.
@export var default_material: Material = preload("res://addons/func_godot/textures/default_material.tres")

## Sampler2D uniform that supplies the Albedo in a custom shader when [member default_material] is a [ShaderMaterial].
@export var default_material_albedo_uniform: String = ""

## Automatic PBR material generation albedo map pattern.
@export var albedo_map_pattern: String = "%s_albedo.%s"
## Automatic PBR material generation normal map pattern.
@export var normal_map_pattern: String = "%s_normal.%s"
## Automatic PBR material generation metallic map pattern
@export var metallic_map_pattern: String = "%s_metallic.%s"
## Automatic PBR material generation roughness map pattern
@export var roughness_map_pattern: String = "%s_roughness.%s"
## Automatic PBR material generation emission map pattern
@export var emission_map_pattern: String = "%s_emission.%s"
## Automatic PBR material generation ambient occlusion map pattern
@export var ao_map_pattern: String = "%s_ao.%s"
## Automatic PBR material generation height map pattern
@export var height_map_pattern: String = "%s_height.%s"
## Automatic PBR material generation ORM map pattern
@export var orm_map_pattern: String = "%s_orm.%s"

## Save automatically generated materials to disk, allowing reuse across [FuncGodotMap] nodes. [i]NOTE: Materials do not use the Default Material settings after saving.[/i]
@export var save_generated_materials: bool = true

@export_category("UV Unwrap")

## Texel size for UV2 unwrapping.
## Actual texel size is uv_unwrap_texel_size / inverse_scale_factor. A ratio of 1/16 is usually a good place to start with (if inverse_scale_factor is 32, start with a uv_unwrap_texel_size of 2).
## Larger values will produce less detailed lightmaps. To conserve memory and filesize, use the largest value that still looks good.
@export var uv_unwrap_texel_size: float = 2.0

@export_category("TrenchBroom")

## If true, will organize Scene Tree using Trenchbroom Layers and Groups. Layers and Groups will be generated as [Node3D] nodes. 
## All structural brushes will be moved out of the Layers and Groups and merged into the Worldspawn entity.
## Any Layers toggled to be omitted from export in TrenchBroom will not be built.
@export var use_trenchbroom_groups_hierarchy: bool = false
