@tool
@icon("res://addons/func_godot/icons/icon_godambler3d.svg")
class_name FuncGodotFGDPointClassDisplayDescriptor extends Resource
## Resource that describes how to display an FGD Point Class entity.
##
## A resource for [FuncGodotFGDPointClass] that describes how to display a point entity in a map editor. 
## Values entered into the different options are taken literally: paths should be enclosed within quotation marks, 
## while class property keys and integer values should omit them.[br][br]
##
## Most editors only support the [member display_asset] option. Exporting an FGD compatible with these editors will 
## automatically omit the unsupported options introduced by TrenchBroom when exporting from their respective game configuration resources 
## or setting [member FuncGodotFGDFile.target_map_editor] away from [enum FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM].
##
## The extra options are considered advanced features and are unable to be evaluated by FuncGodot to ensure they were input correctly. 
## Exercise caution, care, and patience when attempting to use these, especially the [member conditional] option. 
## 
## @tutorial(Level Design Book: Display Models for Entities): https://book.leveldesignbook.com/appendix/resources/formats/fgd#display-models-for-entities
## @tutorial(Valve Developer Wiki FGD Article: Entity Description Section): https://developer.valvesoftware.com/wiki/FGD#Entity_Description
## @tutorial(TrenchBroom Manual: Display Models for Entities): https://trenchbroom.github.io/manual/latest/#display-models-for-entities
## @tutorial(TrenchBroom Manual: Expression Language): https://trenchbroom.github.io/manual/latest/#expression_language

## Either a file path to the asset that will be displayed for this point entity, relative to the map editor's game path, 
## or a class property key that can contain the path.[br][br] 
## For paths, you must surround the path with quotes, e.g: [code]"models/marsfrog.glb"[/code]. 
## For properties, you must omit the quotes, e.g: [code]display_model_path[/code].[br][br] 
## Different editors support different file types: common ones include MDL, GLB, SPR, and PNG. 
@export var display_asset_path: String = ""

@export_group("TrenchBroom Options")
## Optional string that determines the scale of the display asset. This can be a number, a class property key, or 
## a scale expression in accordance with TrenchBroom's Expression Language. Leave blank to use the game configuration's default scale expression.[br][br]
## [color=orange]WARNING:[/color] Only utilized by TrenchBroom!
@export var scale: String = ""

## Optional string that determines which skin the display asset should use. This can be either a number or a class property key.[br][br] 
## [color=orange]WARNING:[/color] Only utilized by TrenchBroom!
@export var skin: String = ""

## Optional string that determines the appearance of a display asset based on its file type. This can be either a number or a class property key.[br][br] 
## Traditional Quake MDL files will set the display to that frame of its animations (all animations in a Quake MDL are compiled into a single animation). 
## GLBs meanwhile seem to set themselves to the animation assigned to an index that matches the [code]frame[/code] value.[br][br] 
## [color=orange]WARNING:[/color] Only utilized by TrenchBroom!
@export var frame: String = ""

## Optional evaluation string that, when true, will force the Point Class to display the asset defined by [member display_asset_path].
## Format should be [code]property == value[/code] or some other valid expression in accordance with TrenchBroom's Expression Language.[br][br] 
## [color=orange]WARNING:[/color] Only utilized by TrenchBroom!
@export var conditional: String = ""
