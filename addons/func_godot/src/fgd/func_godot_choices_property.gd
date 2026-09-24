class_name FuncGodotChoicesProperty
extends Resource
## Special resource used to indicate that an FGD entity property is of type "choices".

## The default value for this property.
@export var default_value: Variant

## The available choices for this property.
@export var choices: Dictionary[Variant, String]