@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
@abstract class_name FuncGodotFGDProperty extends Resource
## Entity Property definition template. WARNING! Not to be used directly! Use inheriting classes instead.
##
## Entity Property definition template. These are added to [member FuncGodotFGDEntityClass.class_properties] 
## as an alternative for setting up certain property types. 
## Currently inherited by [FuncGodotFGDPropertyChoices], [FuncGodotFGDPropertyFlags], [FuncGodotFGDPropertyTarget], and [FuncGodotFGDPropertyColor]. 
## Not to be used directly, use one of the aforementioned FGD Property class types instead.
## [br][br]
## If a property is set up incorrectly, the issue will be logged as a comment in the generated FGD file where the property would have been written to.
##
## @tutorial(Quake Wiki Entity Article): https://quakewiki.org/wiki/Entity
## @tutorial(Level Design Book: Entity Types and Settings): https://book.leveldesignbook.com/appendix/resources/formats/fgd#entity-types-and-settings-basic
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties
## @tutorial(Valve Developer Wiki Entity Descriptions): https://developer.valvesoftware.com/wiki/FGD#Entity_Description

## Default value sent to the exported FGD and retrieved by [FuncGodotParser] on map build.
## Only certain [Variant] types are allowed depending upon the property class.
@export var default_value: Variant
@export_multiline() var description: String = ""

## Builds the FGD text for [FuncGodotFGDEntityClass].
@abstract func build_fgd_text(property_name: String, target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String

## Retrieves the default value from this property resource. May retrieve it from [member default_value] or generate it based upon class specific settings.
@abstract func get_default_value() -> Variant
