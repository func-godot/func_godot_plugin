@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotFGDBaseClass extends FuncGodotFGDEntityClass
## Special inheritance class for [FuncGodotFGDSolidClass] and [FuncGodotFGDPointClass] entity definitions. 
## 
## Inheritance class for [FuncGodotFGDSolidClass] and [FuncGodotFGDPointClass] entities, 
## used to shared or common properties and descriptions across different definitions.
##
## @tutorial(Quake Wiki Entity Article): https://quakewiki.org/wiki/Entity
## @tutorial(Level Design Book: Entity Types and Settings): https://book.leveldesignbook.com/appendix/resources/formats/fgd#entity-types-and-settings-basic
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties

func _init() -> void:
	prefix = "@BaseClass"
