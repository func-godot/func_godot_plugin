@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Reusable map settings configuration for [FuncGodotMap] nodes.
class_name FuncGodotMapSettings
extends Resource

@export_category("Build")

## Ratio between map editor units and Godot units. FuncGodot will divide brush coordinates by this number when building. This does not affect entity properties unless scripted to do so.
@export var inverse_scale_factor: float = 32.0

@export_category("Entities")

## [FuncGodotFGDFile] that translates map file classnames into Godot nodes and packed scenes.
@export var entity_fgd: FuncGodotFGDFile = load("res://addons/func_godot/fgd/func_godot_fgd.tres")

@export_category("Textures")

## Base directory for textures. When building materials, FuncGodot will search this directory for texture files with matching names to the textures assigned to map brush faces.
@export_dir var base_texture_dir: String = "res://textures"

## File extensions to search for texture data.
@export var texture_file_extensions: PackedStringArray = ["png", "jpg", "jpeg", "bmp", "tga", "webp"]

## Optional path for the clip texture, relative to [member base_texture_dir]. Brush faces textured with the clip texture will have those faces removed from the generated [MeshInstance3D] but not the generated [CollisionShape3D].
@export var clip_texture: String = "special/clip"

## Optional path for the skip texture, relative to [member base_texture_dir]. Brush faces textured with the skip texture will have those faces removed from the generated [MeshInstance3D]. If the [FuncGodotFGDSolidClass] `collision_shape_type` is set to concave then it will also remove collision from those faces in the generated [CollisionShape3D].
@export var skip_texture: String = "special/skip"

## Optional [QuakeWADFile] resources to apply textures from. See the [Quake Wiki](https://quakewiki.org/wiki/Texture_Wad) for more information on Quake Texture WADs.
@export var texture_wads: Array[QuakeWadFile] = []

@export_category("Materials")

## File extensions to search for [Material] definitions
@export var material_file_extension: String = "tres"

## If true, all materials will be unshaded, i.e. will ignore light. Also known as "fullbright".
@export var unshaded: bool = false

## [Material] used as template when generating missing materials.
@export var default_material: Material = StandardMaterial3D.new()

## Sampler2D uniform that supplies the Albedo in a custom shader when [member default_material] is a [ShaderMaterial].
@export var default_material_albedo_uniform: String = ""

@export_category("UV Unwrap")

## Texel size for UV2 unwrapping.
## A texel size of 1 will lead to a 1:1 correspondence between texture texels and lightmap texels. Larger values will produce less detailed lightmaps. To conserve memory and filesize, use the largest value that still looks good.
@export var uv_unwrap_texel_size: float = 1.0

@export_category("TrenchBroom")

## Organize Scene Tree using Trenchbroom Layers and Groups.
@export var use_trenchbroom_groups_hierarchy: bool = false
