@tool
@icon("res://addons/func_godot/icons/icon_godambler3d.svg")
class_name FuncGodotFGDModelPointClass extends FuncGodotFGDPointClass
## A special type of [FuncGodotFGDPointClass] entity that automatically generates a special simplified GLB model file for the map editor display. 
## Only supported in map editors that support GLTF or GLB.
##
## @tutorial(Quake Wiki Entity Article): https://quakewiki.org/wiki/Entity
## @tutorial(Level Design Book: Entity Types and Settings): https://book.leveldesignbook.com/appendix/resources/formats/fgd#entity-types-and-settings-basic
## @tutorial(Valve Developer Wiki FGD Article): https://developer.valvesoftware.com/wiki/FGD#Class_Types_and_Properties
## @tutorial(dumptruck_ds' Quake Mapping Entities Tutorial): https://www.youtube.com/watch?v=gtL9f6_N2WM
## @tutorial(Level Design Book: Display Models for Entities): https://book.leveldesignbook.com/appendix/resources/formats/fgd#display-models-for-entities
## @tutorial(Valve Developer Wiki FGD Article: Entity Description Section): https://developer.valvesoftware.com/wiki/FGD#Entity_Description
## @tutorial(TrenchBroom Manual: Display Models for Entities): https://trenchbroom.github.io/manual/latest/#display-models-for-entities

enum TargetMapEditor {
	GENERIC, ## Entity definition uses the [b]@studio[/b] key word. [member scale_expression] is ignored. Supported by all map editors.
	TRENCHBROOM ## Entity definition uses the [b]@model[/b] key word. [member scale_expression] is applied if set.
}

@export var target_map_editor: TargetMapEditor = TargetMapEditor.GENERIC
## Display model export folder relative to [member ProjectSettings.func_godot/model_point_class_save_path].
@export var models_sub_folder : String = ""
## Scale expression applied to model. Only used by TrenchBroom. If left empty, uses [member ProjectSettings.func_godot/default_inverse_scale_factor]. [br][br]Read the TrenchBroom Manual for more information on the "scale expression" feature.
@export var scale_expression : String = ""
## Model Point Class can override the 'size' meta property by auto-generating a value from the meshes' [AABB]. Proper generation requires [member scale_expression] set to a float or vector. [br][br][color=orange]WARNING:[/color] Generated size property unlikely to align cleanly to grid!
@export var generate_size_property : bool = false
## Degrees to rotate model prior to export. Different editors may handle GLTF transformations differently. If your model isn't oriented correctly, try modifying this property.
@export var rotation_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
## Creates a .gdignore file in the model export folder to prevent Godot importing the display models. Only needs to be generated once.
@export_tool_button("Generate GD Ignore File", "FileAccess") var generate_gd_ignore_file : Callable = _generate_gd_ignore_file

func _generate_gd_ignore_file() -> void:
	if Engine.is_editor_hint():
		var path: String = _get_game_path().path_join(_get_model_folder())
		var error: Error = DirAccess.make_dir_recursive_absolute(path)
		if error != Error.OK:
			printerr("Failed creating dir for GDIgnore file", error)
			return
		path = path.path_join('.gdignore')
		if FileAccess.file_exists(path):
			return
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string('')
		file.close()

## Builds and saves the display model into the specified destination, then parses the definition and outputs it into the FGD format.
func build_def_text(target_editor: FuncGodotFGDFile.FuncGodotTargetMapEditors = FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM) -> String:
	_generate_model()
	return super()

func _generate_model() -> void:
	if not scene_file:
		return 
	
	var gltf_state := GLTFState.new()
	var path: String = _get_export_dir()
	var node: Node3D = _get_node()
	if not node:
		return
	if not _create_gltf_file(gltf_state, path, node):
		printerr("could not create gltf file")
		return
	node.queue_free()
	
	if target_map_editor == TargetMapEditor.TRENCHBROOM:
		const model_key: String = "model"
		if scale_expression.is_empty():
			meta_properties[model_key] = '"%s"' % _get_local_path()
		else:
			meta_properties[model_key] = '{"path": "%s", "scale": %s }' % [
				_get_local_path(), 
				scale_expression
			]
	else:
		meta_properties["studio"] = '"%s"' % _get_local_path()
	
	if generate_size_property:
		meta_properties["size"] = _generate_size_from_aabb(gltf_state.meshes, gltf_state.get_nodes())

func _get_node() -> Node3D:
	var node := scene_file.instantiate()
	if node is Node3D: 
		return node as Node3D
	node.queue_free()
	printerr("Scene is not of type 'Node3D'")
	return null

func _get_export_dir() -> String:
	var work_dir: String = _get_game_path()
	var model_dir: String = _get_model_folder()
	return work_dir.path_join(model_dir).path_join('%s.glb' % classname)

func _get_local_path() -> String:
	return _get_model_folder().path_join('%s.glb' % classname)

func _get_model_folder() -> String:
	var model_dir: String = ProjectSettings.get_setting("func_godot/model_point_class_save_path", "") as String
	if not models_sub_folder.is_empty():
		model_dir = model_dir.path_join(models_sub_folder)
	return model_dir

func _get_game_path() -> String:
	return FuncGodotLocalConfig.get_setting(FuncGodotLocalConfig.PROPERTY.MAP_EDITOR_GAME_PATH) as String

func _create_gltf_file(gltf_state: GLTFState, path: String, node: Node3D) -> bool:
	var global_export_path = path
	var gltf_document := GLTFDocument.new()
	gltf_state.create_animations = false
	
	node.rotate_x(deg_to_rad(rotation_offset.x))
	node.rotate_y(deg_to_rad(rotation_offset.y))
	node.rotate_z(deg_to_rad(rotation_offset.z))
	
	# With TrenchBroom we can specify a scale expression, but for other editors we need to scale our models manually.
	if target_map_editor != TargetMapEditor.TRENCHBROOM:
		var scale_factor: Vector3 = Vector3.ONE
		if scale_expression.is_empty():
			scale_factor *= ProjectSettings.get_setting("func_godot/default_inverse_scale_factor", 32.0) as float
		else:
			if scale_expression.begins_with('\''):
				var scale_arr := scale_expression.split_floats(' ', false)
				if scale_arr.size() == 3:
					scale_factor *= Vector3(scale_arr[0], scale_arr[1], scale_arr[2])
			elif scale_expression.to_float() > 0:
				scale_factor *= scale_expression.to_float()
		if scale_factor.length() == 0:
			scale_factor = Vector3.ONE # Don't let the node scale into oblivion!
		node.scale *= scale_factor
	
	var error: Error = gltf_document.append_from_scene(node, gltf_state)
	if error != Error.OK:
		printerr("Failed appending to gltf document", error)
		return false
	
	call_deferred("_save_to_file_system", gltf_document, gltf_state, global_export_path)
	return true

func _save_to_file_system(gltf_document: GLTFDocument, gltf_state: GLTFState, path: String) -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != Error.OK:
		printerr("Failed creating dir", error)
		return 
	
	error = gltf_document.write_to_filesystem(gltf_state, path)
	if error != Error.OK:
		printerr("Failed writing to file system", error)
		return 
	print('Exported model to ', path)

func _generate_size_from_aabb(meshes: Array[GLTFMesh], nodes: Array[GLTFNode]) -> AABB:
	var aabb := AABB()
	for mesh in meshes:
		aabb = aabb.merge(mesh.mesh.get_mesh().get_aabb())
	var pos_ofs := Vector3.ZERO
	if not nodes.is_empty():
		var ct: int = 0
		for node in nodes:
			if node.parent == 0:
				pos_ofs += node.position
				ct += 1
		pos_ofs /= maxi(ct, 1)
	aabb.position += pos_ofs
	
	# Reorient the AABB so it matches TrenchBroom's coordinate system
	var size_prop := AABB()
	size_prop.position = Vector3(aabb.position.z, aabb.position.x, aabb.position.y)
	size_prop.size = Vector3(aabb.size.z, aabb.size.x, aabb.size.y)
	
	# Scale the size bounds to our scale factor
	# Scale factor will need to be set if we decide to auto-generate our bounds
	var scale_factor: Vector3 = Vector3.ONE
	if target_map_editor == TargetMapEditor.TRENCHBROOM:
		if scale_expression.is_empty():
			scale_factor *= ProjectSettings.get_setting("func_godot/default_inverse_scale_factor", 32.0) as float
		else:
			if scale_expression.begins_with('\''):
				var scale_arr := scale_expression.split_floats(' ', false)
				if scale_arr.size() == 3:
					scale_factor *= Vector3(scale_arr[0], scale_arr[1], scale_arr[2])
			elif scale_expression.to_float() > 0:
				scale_factor *= scale_expression.to_float()
	
	size_prop.position *= scale_factor
	size_prop.size *= scale_factor
	size_prop.size += size_prop.position
	# Round the size so it can stay on grid level 1 at least
	for i in 3:
		size_prop.position[i] = round(size_prop.position[i])
		size_prop.size[i] = round(size_prop.size[i])
	return size_prop
