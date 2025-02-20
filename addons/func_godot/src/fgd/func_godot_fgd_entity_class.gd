@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Base entity definition class. Not to be used directly, use [FuncGodotFGDBaseClass], [FuncGodotFGDSolidClass], or [FuncGodotFGDPointClass] instead.
class_name FuncGodotFGDEntityClass
extends Resource

var prefix: String = ""

@export_group("Entity Definition")

## Entity classname. This is a required field in all entity types as it is parsed by both the map editor and by FuncGodot on map build.
@export var classname : String = ""

## Entity description that appears in the map editor. Not required.
@export_multiline var description : String = ""

## Entity does not get written to the exported FGD. Entity is only used for [FuncGodotMap] build process.
@export var func_godot_internal : bool = false

## FuncGodotFGDBaseClass resources to inherit [member class_properties] and [member class_descriptions] from.
@export var base_classes: Array[Resource] = []

## Key value pair properties that will appear in the map editor. After building the FuncGodotMap in Godot, these properties will be added to a Dictionary that gets applied to the generated Node, as long as that Node is a tool script with an exported `func_godot_properties` Dictionary.
@export var class_properties : Dictionary = {}

## Descriptions for previously defined key value pair properties.
@export var class_property_descriptions : Dictionary = {}

## Automatically applies entity class properties to matching properties in the generated node. When using this feature, class properties need to be the correct type or you may run into errors on map build.
@export var auto_apply_to_matching_node_properties : bool = false

## Appearance properties for the map editor. See the [**Valve FGD**](https://developer.valvesoftware.com/wiki/FGD#Entity_Description) and [**TrenchBroom**](https://trenchbroom.github.io/manual/latest/#display-models-for-entities) documentation for more information.
@export var meta_properties : Dictionary = {
	"size": AABB(Vector3(-8, -8, -8), Vector3(8, 8, 8)),
	"color": Color(0.8, 0.8, 0.8)
}

@export_group("Node Generation")

## Node to generate on map build. This can be a built-in Godot class or a GDExtension class. For Point Class entities that use Scene File instantiation leave this blank.
@export var node_class := ""

## Class property to use in naming the generated node. Overrides `name_property` in [FuncGodotMapSettings].
## Naming occurs before adding to the [SceneTree] and applying properties.
## Nodes will be named `"entity_" + name_property`. An entity's name should be unique, otherwise you may run into unexpected behavior.
@export var name_property := ""

func build_def_text(target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	# Class prefix
	var res : String = prefix
	
	# Meta properties
	var base_str = ""
	var meta_props = meta_properties.duplicate()
	
	for base_class in base_classes:
		if not 'classname' in base_class:
			continue
			
		base_str += base_class.classname
		
		if base_class != base_classes.back():
			base_str += ", "
			
	if base_str != "":
		meta_props['base'] = base_str
		
	for prop in meta_props:
		if prefix == '@SolidClass':
			if prop == "size" or prop == "model":
				continue
		
		if prop == 'model' and target_editor != FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM:
			continue
		
		var value = meta_props[prop]
		res += " " + prop + "("
		
		if value is AABB:
			res += "%s %s %s, %s %s %s" % [
				value.position.x,
				value.position.y,
				value.position.z,
				value.size.x,
				value.size.y,
				value.size.z
			]
		elif value is Color:
			res += "%s %s %s" % [
				value.r8,
				value.g8,
				value.b8
			]
		elif value is String:
			res += value
		
		res += ")"
	
	res += " = " + classname
	
	if prefix != "@BaseClass": # having a description in BaseClasses crashes some editors
		var normalized_description = description.replace("\"", "\'")
		if normalized_description != "":
			res += " : \"%s\" " % [normalized_description]
		else: # Having no description crashes some editors
			res += " : \"" + classname + "\" "
	
	if class_properties.size() > 0:
		res += FuncGodotUtil.newline() + "[" + FuncGodotUtil.newline()
	else:
		res += "["
	
	# Class properties
	for prop in class_properties:
		var value = class_properties[prop]
		var prop_val = null
		var prop_type := ""
		var prop_description: String
		if prop in class_property_descriptions:
			# Optional default value for Choices can be set up as [String, int]
			if value is Dictionary and class_property_descriptions[prop] is Array:
				var prop_arr: Array = class_property_descriptions[prop]
				if prop_arr.size() > 1 and (prop_arr[1] is int or prop_arr[1] is String):
					prop_description = "\"" + prop_arr[0] + "\" : " + str(prop_arr[1])
				else:
					prop_description = "\"\" : 0"
					printerr(str(prop) + " has incorrect description format. Should be [String description, int / String default value].")
			else:
				prop_description = "\"" + class_property_descriptions[prop] + "\""
		else:
			prop_description = "\"\""
		
		match typeof(value):
			TYPE_INT:
				prop_type = "integer"
				prop_val = str(value)
			TYPE_FLOAT:
				prop_type = "float"
				prop_val = "\"" + str(value) + "\""
			TYPE_STRING:
				prop_type = "string"
				prop_val = "\"" + value + "\""
			TYPE_BOOL:
				prop_type = "choices"
				prop_val = FuncGodotUtil.newline() + "\t[" + FuncGodotUtil.newline()
				prop_val += "\t\t" + str(0) + " : \"No\"" + FuncGodotUtil.newline()
				prop_val += "\t\t" + str(1) + " : \"Yes\"" + FuncGodotUtil.newline()
				prop_val += "\t]"
			TYPE_VECTOR2, TYPE_VECTOR2I:
				prop_type = "string"
				prop_val = "\"%s %s\"" % [value.x, value.y]
			TYPE_VECTOR3, TYPE_VECTOR3I:
				prop_type = "string"
				prop_val = "\"%s %s %s\"" % [value.x, value.y, value.z]
			TYPE_VECTOR4, TYPE_VECTOR4I:
				prop_type = "string"
				prop_val = "\"%s %s %s %s\"" % [value[0], value[1], value[2], value[3]]
			TYPE_COLOR:
				prop_type = "color255"
				prop_val = "\"%s %s %s\"" % [value.r8, value.g8, value.b8]
			TYPE_DICTIONARY:
				prop_type = "choices"
				prop_val = FuncGodotUtil.newline() + "\t[" + FuncGodotUtil.newline()
				for choice in value:
					var choice_val = value[choice]
					if typeof(choice_val) == TYPE_STRING:
						if not (choice_val as String).begins_with("\""):
							choice_val = "\"" + choice_val + "\""
					prop_val += "\t\t" + str(choice_val) + " : \"" + choice + "\"" + FuncGodotUtil.newline()
				prop_val += "\t]"
			TYPE_ARRAY:
				prop_type = "flags"
				prop_val = FuncGodotUtil.newline() + "\t[" + FuncGodotUtil.newline()
				for arr_val in value:
					prop_val += "\t\t" + str(arr_val[1]) + " : \"" + str(arr_val[0]) + "\" : " + ("1" if arr_val[2] else "0") + FuncGodotUtil.newline()
				prop_val += "\t]"
			TYPE_NODE_PATH:
				prop_type = "target_destination"
				prop_val = "\"\""
			TYPE_OBJECT:
				if value is Resource:
					prop_val = value.resource_path
					if value is Material:
						if target_editor != FuncGodotFGDFile.FuncGodotTargetMapEditors.JACK:
							prop_type = "material"
						else:
							prop_type = "shader"
					elif value is Texture2D:
						prop_type = "decal"
					elif value is AudioStream:
						prop_type = "sound"
				else:
					prop_type = "target_source"
					prop_val = "\"\""
		
		if prop_val:
			res += "\t"
			res += prop
			res += "("
			res += prop_type
			res += ")"
			
			if not value is Array:
				if not value is Dictionary or prop_description != "":
					res += " : "
					res += prop_description
			
			if value is bool or value is Dictionary or value is Array:
				res += " = "
			else:
				res += " : "
			
			res += prop_val
			res += FuncGodotUtil.newline()
	
	res += "]" + FuncGodotUtil.newline()
	
	return res
