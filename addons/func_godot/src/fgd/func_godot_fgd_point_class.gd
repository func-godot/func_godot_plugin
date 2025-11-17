@tool
@icon("res://addons/func_godot/icons/icon_godambler3d.svg")
class_name FuncGodotFGDPointClass extends FuncGodotFGDEntityClass
## FGD PointClass entity definition.
##
## A resource used to define an FGD PointClass entity. PointClass entities can use either the [member FuncGodotFGDEntityClass.node_class] 
## or the [member scene_file] property to tell [FuncGodotMap] what to generate on map build.
##
## @tutorial(Quake Wiki Entity Article): https://quakewiki.org/wiki/Entity
## @tutorial(Level Design Book: Entity Types and Settings): https://book.leveldesignbook.com/appendix/resources/formats/fgd#entity-types-and-settings-basic
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties
## @tutorial(dumptruck_ds' Quake Mapping Entities Tutorial): https://www.youtube.com/watch?v=gtL9f6_N2WM
## @tutorial(Level Design Book: Display Models for Entities): https://book.leveldesignbook.com/appendix/resources/formats/fgd#display-models-for-entities
## @tutorial(Valve Developer Wiki FGD Article: Entity Description Section): https://developer.valvesoftware.com/wiki/FGD#Entity_Description
## @tutorial(TrenchBroom Manual: Display Models for Entities): https://trenchbroom.github.io/manual/latest/#display-models-for-entities

func _init() -> void:
	prefix = "@PointClass"

## An optional [PackedScene] file to instantiate on map build. Overrides [member FuncGodotFGDEntityClass.node_class] and [member script_class].
@export var scene_file: PackedScene

## An optional [Script] resource to attach to the node generated on map build. Ignored if [member scene_file] is specified.
@export var script_class: Script

## Toggles whether entity will use `angles`, `mangle`, or `angle` to determine rotations on [FuncGodotMap] build, prioritizing the key value pairs in that order. 
## Set to [code]false[/code] if you would like to define how the generated node is rotated yourself.
@export var apply_rotation_on_map_build : bool = true

## Toggles whether entity will use `scale` to determine the generated node or scene's scale. This is performed on the top level node. 
## The property can be a [float], [Vector3], or [Vector2]. Set to [code]false[/code] if you would like to define how the generated node is scaled yourself.
@export var apply_scale_on_map_build: bool = true

@export_subgroup("Models")
## The array of models to use. The order of this array is the order the conditions will be checked.
@export var models: Array[FuncGodotFGDPointClassModelDescriptor]
## The default model scale multiplier. Only relevant for Trenchbroom's model syntax.
@export var model_scale_multiplier: int = 32;
## Whether to multiply by the scale key on your entity. If true, this model won't render in Trenchbroom until a scale key is set.
## If false, the scale will be the Model Scale Multiplier
@export var multiply_by_scale_key: bool = true

func model_wrangle() -> String:
	var scale_expr := '"scale": '+str(model_scale_multiplier)
	if multiply_by_scale_key:
		scale_expr+="*scale"
	var model_switcher := "";
	if models.size() > 0:
		model_switcher = "{{ "
	var default_model: FuncGodotFGDPointClassModelDescriptor = null
	var conditions_checked: Dictionary[String, bool] = {}
	
	if models.size() > 0:
		model_switcher += ""
		for model:FuncGodotFGDPointClassModelDescriptor in models:
			if !model:
				continue
			if conditions_checked.get(model.condition, false):
				printerr("Model Descriptor with condition is duplicate: " + model.condition)
				continue;
			conditions_checked[model.condition] = true
			if model.condition == "":
				default_model = model;
				continue
			model_switcher += model.condition + ' -> { "path": "'+model.path+'", "frame":'+str(model.frame)+', "skin":'+str(model.skin)+', '+scale_expr+' }, '
		if !default_model:
			model_switcher = model_switcher.trim_suffix(", ")
			
	if default_model:
		model_switcher += '{ "path": "'+default_model.path+'", "frame":'+str(default_model.frame)+', "skin":'+str(default_model.skin)+', '+scale_expr+' }'
		
	if models.size() > 0:
		model_switcher += " }}"
	return model_switcher

func studio_wrangle() -> String:
	if models.size() > 1:
		push_warning("When using a non-Trenchbroom editor, only the first Model provided is used");
	var model := models[0]
	return '"'+model.path+'"'


func build_def_text(target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	if models.size() > 0:
		if target_editor == FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM:
			self.meta_properties["model"] = self.model_wrangle();
		else:
			self.meta_properties["studio"] = self.studio_wrangle();
	return super(target_editor);
