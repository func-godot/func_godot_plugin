@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
class_name FuncGodotPlugin extends EditorPlugin

var map_import_plugin : QuakeMapImportPlugin = null
var palette_import_plugin : QuakePaletteImportPlugin = null
var wad_import_plugin: QuakeWadImportPlugin = null

#var func_godot_map_progress_bar: Control = null
var edited_object_ref: WeakRef = weakref(null)

func _get_plugin_name() -> String:
	return "FuncGodot"

func _handles(object: Object) -> bool:
	return object is FuncGodotMap

func _edit(object: Object) -> void:
	edited_object_ref = weakref(object)

#func _make_visible(visible: bool) -> void:
	#if func_godot_map_progress_bar:
		#func_godot_map_progress_bar.set_visible(visible)

func _enter_tree() -> void:
	# Import plugins
	map_import_plugin = QuakeMapImportPlugin.new()
	palette_import_plugin = QuakePaletteImportPlugin.new()
	wad_import_plugin = QuakeWadImportPlugin.new()
	
	add_import_plugin(map_import_plugin)
	add_import_plugin(palette_import_plugin)
	add_import_plugin(wad_import_plugin)
	
	#func_godot_map_progress_bar = create_func_godot_map_progress_bar()
	#func_godot_map_progress_bar.set_visible(false)
	#add_control_to_container(EditorPlugin.CONTAINER_INSPECTOR_BOTTOM, func_godot_map_progress_bar)
	
	add_custom_type("FuncGodotMap", "Node3D", preload("res://addons/func_godot/src/map/func_godot_map.gd"), null)
	
	# Default Map Settings
	if not ProjectSettings.has_setting("func_godot/default_map_settings"):
		ProjectSettings.set_setting("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres")
		var property_info = {
			"name": "func_godot/default_map_settings",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tres"
		}
		ProjectSettings.add_property_info(property_info)
		ProjectSettings.set_as_basic("func_godot/default_map_settings", true)
		ProjectSettings.set_initial_value("func_godot/default_map_settings", "res://addons/func_godot/func_godot_default_map_settings.tres")
	
	# Default Inverse Scale Factor
	if not ProjectSettings.has_setting("func_godot/default_inverse_scale_factor"):
		ProjectSettings.set_setting("func_godot/default_inverse_scale_factor", 32.0)
		var property_info = {
			"name": "func_godot/default_inverse_scale_factor",
			"type": TYPE_FLOAT
		}
		ProjectSettings.add_property_info(property_info)
		ProjectSettings.set_as_basic("func_godot/default_inverse_scale_factor", true)
		ProjectSettings.set_initial_value("func_godot/default_inverse_scale_factor", 32.0)
	
	# Model Point Class Default Path
	if not ProjectSettings.has_setting("func_godot/model_point_class_save_path"):
		ProjectSettings.set_setting("func_godot/model_point_class_save_path", "")
		var property_info = {
			"name": "func_godot/model_point_class_save_path",
			"type": TYPE_STRING
		}
		ProjectSettings.add_property_info(property_info)
		ProjectSettings.set_as_basic("func_godot/model_point_class_save_path", true)
		ProjectSettings.set_initial_value("func_godot/model_point_class_save_path", "")

func _exit_tree() -> void:
	remove_custom_type("FuncGodotMap")
	remove_import_plugin(map_import_plugin)
	remove_import_plugin(palette_import_plugin)
	if wad_import_plugin:
		remove_import_plugin(wad_import_plugin)
		
	map_import_plugin = null
	palette_import_plugin = null
	wad_import_plugin = null
	
	#if func_godot_map_progress_bar:
		#remove_control_from_container(EditorPlugin.CONTAINER_INSPECTOR_BOTTOM, func_godot_map_progress_bar)
		#func_godot_map_progress_bar.queue_free()
		#func_godot_map_progress_bar = null

# Create a progress bar for building a [FuncGodotMap]
#func create_func_godot_map_progress_bar() -> Control:
	#var progress_label = Label.new()
	#progress_label.name = "ProgressLabel"
	#progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	#
	#var progress_bar := ProgressBar.new()
	#progress_bar.name = "ProgressBar"
	#progress_bar.show_percentage = false
	#progress_bar.min_value = 0.0
	#progress_bar.max_value = 1.0
	#progress_bar.custom_minimum_size.y = 30
	#progress_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	#progress_bar.add_child(progress_label)
	#progress_label.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	#progress_label.offset_top = -9
	#progress_label.offset_left = 3
	#
	#return progress_bar

# Update the build progress bar (see: [method create_func_godot_map_progress_bar]) to display the current step and progress (0-1)
#func func_godot_map_build_progress(step: String, progress: float) -> void:
	#var progress_label = func_godot_map_progress_bar.get_node("ProgressLabel")
	#func_godot_map_progress_bar.value = progress
	#progress_label.text = step.capitalize()

## Callback for when the build process for a [FuncGodotMap] is finished.
func func_godot_map_build_complete(func_godot_map: FuncGodotMap) -> void:
	#var progress_label = func_godot_map_progress_bar.get_node("ProgressLabel")
	#progress_label.text = "Build Complete"
	
	#if func_godot_map.is_connected("build_progress",Callable(self,"func_godot_map_build_progress")):
		#func_godot_map.disconnect("build_progress",Callable(self,"func_godot_map_build_progress"))
	
	if func_godot_map.is_connected("build_complete",Callable(self,"func_godot_map_build_complete")):
		func_godot_map.disconnect("build_complete",Callable(self,"func_godot_map_build_complete"))
	
	if func_godot_map.is_connected("build_failed",Callable(self,"func_godot_map_build_complete")):
		func_godot_map.disconnect("build_failed",Callable(self,"func_godot_map_build_complete"))
