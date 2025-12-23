@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotMapSettings extends Resource
## Reusable map settings configuration for [FuncGodotMap] nodes.

#region BUILD
@export_group("Build Settings")

## Set automatically when [member inverse_scale_factor] is changed. Used primarily during the build process.
var scale_factor: float = 0.03125

## Ratio between map editor units and Godot units. FuncGodot will divide brush coordinates by this number and save the results to [member scale_factor].
## This does not affect entity properties unless scripted to do so.
@export var inverse_scale_factor: float = 32.0 :
	set(value):
		if value == 0.0:
			printerr("Error: Cannot set Inverse Scale Factor to Zero")
			return
		inverse_scale_factor = value
		scale_factor = 1.0 / value

## [FuncGodotFGDFile] that translates map file classnames into Godot nodes and packed scenes.
@export var entity_fgd: FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## If true, will organize [SceneTree] using TrenchBroom Layers and Groups or Hammer Visgroups. Groups will be generated as [Node3D] nodes. 
## All non-entity structural brushes will be moved out of their groups and merged into the `Worldspawn` entity.
## Any Layers toggled to be omitted from export in TrenchBroom and their child entities and groups will not be built.
@export var use_groups_hierarchy: bool = false

## Texel size for UV2 unwrapping.
## Actual texel size is uv_unwrap_texel_size / [member inverse_scale_factor]. A ratio of 1/16 is usually a good place to start with 
## (if inverse_scale_factor is 32, start with a uv_unwrap_texel_size of 2).
## Larger values will produce less detailed lightmaps. To conserve memory and filesize, use the largest value that still looks good.
@export var uv_unwrap_texel_size: float = 2.0

#endregion

#region ENTITY
@export_group("Entity Settings")

## Optional array of node groups to add all generated nodes to.
@export var entity_node_groups: Array[String] = []

@export_subgroup("Entity Property Names")
## Default class property to use in naming generated nodes. This setting is overridden by [member FuncGodotFGDEntityClass.name_property].
## Naming occurs before adding to the [SceneTree] and applying properties.
## Nodes will be named `"entity_" + name_property`. An entity's name should be unique, otherwise you may run into unexpected behavior.
@export var entity_name_property: String = ""

## Entity class property that determines whether the [FuncGodotFGDSolidClass] entity performs mesh smoothing operations.
@export var entity_smoothing_property: String = "_phong"

## Entity class property that contains the angular threshold that determines when a [FuncGodotFGDSolidClass] entity's mesh vertices are smoothed.
@export var entity_smoothing_angle_property: String = "_phong_angle"

## Entity class property that contains the snapping epsilon for generated vertices of [FuncGodotFGDSolidClass] entities. 
## Utilizing this property can help reduce instances of seams between polygons.
@export var vertex_merge_distance_property: String = "_vertex_merge_distance"

## Entity class property that tells whether interior faces should be culled for that brush entity. 
## Interior faces are faces with matching vertices or are flush within a larger face. 
## Note that this has a performance impact that scales with how many brushes are in the entity.
@export var cull_interior_faces_property: String = "_cull_interior_faces"

@export_subgroup("")
#endregion

#region TEXTURES
@export_group("Textures")

## Base directory for textures. When building materials, FuncGodot will search this directory for texture files with matching names to the textures assigned to map brush faces.
@export_dir var base_texture_dir: String = "res://textures"

## File extensions to search for texture data.
@export var texture_file_extensions: Array[String] = ["png", "jpg", "jpeg", "bmp", "tga", "webp"]

@export_subgroup("Hint Textures")
## Optional path for the clip texture, relative to [member base_texture_dir]. 
## Brush faces textured with the clip texture will have those faces removed from the generated [Mesh] but not the generated [Shape3D].
@export var clip_texture: String = "clip":
	set(tex):
		clip_texture = tex.to_lower()

## Optional path for the skip texture, relative to [member base_texture_dir]. 
## Brush faces textured with the skip texture will have those faces removed from the generated [Mesh]. 
## If [member FuncGodotFGDSolidClass.collision_shape_type] is set to concave then it will also remove collision from those faces in the generated [Shape3D].
@export var skip_texture: String = "skip":
	set(tex):
		skip_texture = tex.to_lower()

## Optional path for the origin texture, relative to [member base_texture_dir]. 
## Brush faces textured with the origin texture will have those faces removed from the generated [Mesh] and [Shape3D]. 
## The bounds of these faces will be used to calculate the origin point of the entity.
@export var origin_texture: String = "origin":
	set(tex):
		origin_texture = tex.to_lower()
@export_subgroup("")

## Optional [QuakeWadFile] resources to apply textures from. See the [Quake Wiki](https://quakewiki.org/wiki/Texture_Wad) for more information on Quake Texture WADs.
@export var texture_wads: Array[QuakeWadFile] = []

#endregion

#region MATERIALS
@export_group("Materials")

## Base directory for loading and saving materials. When building materials, FuncGodot will search this directory for material resources 
## with matching names to the textures assigned to map brush faces. If not found, will fall back to [member base_texture_dir].
@export_dir var base_material_dir: String = ""

## File extension to search for [Material] definitions
@export var material_file_extension: String = "tres"

## [Material] used as template when generating missing materials.
@export var default_material: Material = preload("res://addons/func_godot/textures/default_material.tres")

## Sampler2D uniform that supplies the Albedo in a custom shader when [member default_material] is a [ShaderMaterial].
@export var default_material_albedo_uniform: String = ""

## Automatic [ShaderMaterial] generation mapping patterns. Only used when [member default_material] is a ShaderMaterial. 
## Keys should be the names of the shader uniforms while the values should be the suffixes for the texture maps. 
## Patterns only use one replacement String: the texture name, ex: [code]"%s_normal"[/code].
@export var shader_material_uniform_map_patterns: Dictionary[String, String] = {}

@export_subgroup("BaseMaterial3D Map Patterns")
## Automatic PBR material generation albedo map pattern.
@export var albedo_map_pattern: String = "%s_albedo"
## Automatic PBR material generation normal map pattern.
@export var normal_map_pattern: String = "%s_normal"
## Automatic PBR material generation metallic map pattern
@export var metallic_map_pattern: String = "%s_metallic"
## Automatic PBR material generation roughness map pattern
@export var roughness_map_pattern: String = "%s_roughness"
## Automatic PBR material generation emission map pattern
@export var emission_map_pattern: String = "%s_emission"
## Automatic PBR material generation ambient occlusion map pattern
@export var ao_map_pattern: String = "%s_ao"
## Automatic PBR material generation height map pattern
@export var height_map_pattern: String = "%s_height"
## Automatic PBR material generation ORM map pattern
@export var orm_map_pattern: String = "%s_orm"
@export_subgroup("")

## Save automatically generated materials to disk, allowing reuse across [FuncGodotMap] nodes. 
## [i]NOTE: Materials do not use the [member default_material] settings after saving.[/i]
@export var save_generated_materials: bool = true
@export_group("")

#endregion
