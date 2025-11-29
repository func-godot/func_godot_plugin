@tool
@icon("res://addons/func_godot/icons/icon_godambler3d.svg")
class_name FuncGodotFGDPointClass extends FuncGodotFGDEntityClass
## FGD PointClass entity definition.
##
## A resource used to define an FGD Point Class entity. PointClass entities can use either the [member FuncGodotFGDEntityClass.node_class] 
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

## An optional [Array] of [FuncGodotFGDPointClassDisplayDescriptor] that describes how this Point Entity should appear in the map editor. 
## When using multiple display descriptors, only the first element found without [member FuncGodotFGDPointClassDisplayDescriptor.conditional] 
## will be used as the default display asset. If no descriptor is found without a condition, the last descriptor will become the default.[br][br] 
## Conditional display descriptors will be written to the FGD in the order set in the array.[br][br] 
## [color=orange]WARNING:[/color] Multiple descriptors are only supported by TrenchBroom! They will be omitted on export when 
## [member FuncGodotFGDFile.target_map_editor] is not set to [enum FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM].
@export var display_descriptors: Array[FuncGodotFGDPointClassDisplayDescriptor] = []

func _build_model_branch_text(descriptor: FuncGodotFGDPointClassDisplayDescriptor) -> String:
	if not descriptor:
		return ''
	
	var model_string: String = ''
	var uses_options: bool = false
	
	if not descriptor.scale.is_empty() or not descriptor.skin.is_empty() or not descriptor.frame.is_empty():
		uses_options = true
	
	if not uses_options:
		return descriptor.display_asset_path
	
	model_string = '{ \"path\": %s' % descriptor.display_asset_path
	
	if not descriptor.skin.is_empty():
		model_string += ', \"skin\": %s' % descriptor.skin
	if not descriptor.frame.is_empty():
		model_string += ', \"frame\": %s' % descriptor.frame
	if not descriptor.scale.is_empty():
		model_string += ', \"scale\": %s' % descriptor.scale
	
	model_string += " }"
	
	return model_string

func _build_model_text() -> String:
	var model_string: String = ''
	
	if display_descriptors.is_empty():
		return model_string
	
	if display_descriptors.size() == 1:
		return _build_model_branch_text(display_descriptors[0])
	
	model_string = '{{'
	var default_display: FuncGodotFGDPointClassDisplayDescriptor
	for i in display_descriptors.size():
		var d: FuncGodotFGDPointClassDisplayDescriptor = display_descriptors[i]
		
		# Only set the first discovered descriptor without a condition to the default, which must be the last option in a list. 
		# If a conditional is not set, skip it.
		if d.conditional.is_empty():
			if not default_display:
				default_display = d
			else:
				printerr(classname + " has a Point Class Display Descriptor without required conditionals set. Must have only 1 conditionless Display Descriptor!")
			continue
		
		model_string += '%s -> %s, ' % [d.conditional, _build_model_branch_text(d)]
	
	if default_display:
		model_string += '%s }}' % _build_model_branch_text(default_display)
	else:
		model_string = model_string.trim_suffix(', ')
		model_string += ' }}'
	
	return model_string

func _build_studio_text() -> String:
	var display_string = ""
	for d in display_descriptors:
		if d.display_asset_path.find('\"') != -1:
			display_string = d.display_asset_path
		else:
			printerr(classname + " attempting to set an invalid value to @studio format during FGD export. Only relative file paths encapsulated by quotations are valid.")
	return display_string

func build_def_text(target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	if not display_descriptors.is_empty():
		if target_editor == FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM:
			var display_string: String = _build_model_text()
			if not display_string.is_empty():
				meta_properties["model"] = display_string
		else:
			var display_string: String = _build_studio_text()
			if not display_string.is_empty():
				meta_properties["studio"] = display_string
	return super(target_editor)
