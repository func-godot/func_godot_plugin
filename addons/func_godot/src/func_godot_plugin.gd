@tool
class_name FuncGodotPlugin
extends EditorPlugin

var map_import_plugin : QuakeMapImportPlugin = null
var palette_import_plugin : QuakePaletteImportPlugin = null
var wad_import_plugin: QuakeWadImportPlugin = null

var func_godot_map_control: Control = null
var func_godot_map_progress_bar: Control = null
var edited_object_ref: WeakRef = weakref(null)

func _get_plugin_name() -> String:
	return "FuncGodot"

func _handles(object: Object) -> bool:
	return object is FuncGodotMap
	
func _edit(object: Object) -> void:
	edited_object_ref = weakref(object)

func _make_visible(visible: bool) -> void:
	if func_godot_map_control:
		func_godot_map_control.set_visible(visible)

	if func_godot_map_progress_bar:
		func_godot_map_progress_bar.set_visible(visible)

func _enter_tree() -> void:
	# Import plugins
	map_import_plugin = QuakeMapImportPlugin.new()
	palette_import_plugin = QuakePaletteImportPlugin.new()
	wad_import_plugin = QuakeWadImportPlugin.new()
	
	add_import_plugin(map_import_plugin)
	add_import_plugin(palette_import_plugin)
	add_import_plugin(wad_import_plugin)
	
	# FuncGodotMap button
	func_godot_map_control = create_func_godot_map_control()
	func_godot_map_control.set_visible(false)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, func_godot_map_control)
	
	func_godot_map_progress_bar = create_func_godot_map_progress_bar()
	func_godot_map_progress_bar.set_visible(false)
	add_control_to_container(EditorPlugin.CONTAINER_INSPECTOR_BOTTOM, func_godot_map_progress_bar)
	
	add_custom_type("FuncGodotMap", "Node3D", preload("res://addons/func_godot/src/map/func_godot_map.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("FuncGodotMap")
	remove_import_plugin(map_import_plugin)
	remove_import_plugin(palette_import_plugin)
	if wad_import_plugin:
		remove_import_plugin(wad_import_plugin)
		
	map_import_plugin = null
	palette_import_plugin = null
	wad_import_plugin = null

	if func_godot_map_control:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, func_godot_map_control)
		func_godot_map_control.queue_free()
		func_godot_map_control = null

	if func_godot_map_progress_bar:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, func_godot_map_progress_bar)
		func_godot_map_progress_bar.queue_free()
		func_godot_map_progress_bar = null

## Create the toolbar controls for [FuncGodotMap] instances in the editor
func create_func_godot_map_control() -> Control:
	var separator = VSeparator.new()
	
	var icon = TextureRect.new()
	icon.texture = preload("res://addons/func_godot/icons/icon_slipgate3d.svg")
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var build_button = Button.new()
	build_button.text = "Build"
	build_button.connect("pressed",Callable(self,"func_godot_map_build"))
	
	var unwrap_uv2_button = Button.new()
	unwrap_uv2_button.text = "Unwrap UV2"
	unwrap_uv2_button.connect("pressed",Callable(self,"func_godot_map_unwrap_uv2"))
	
	var control = HBoxContainer.new()
	control.add_child(separator)
	control.add_child(icon)
	control.add_child(build_button)
	control.add_child(unwrap_uv2_button)
	
	return control

## Create a progress bar for building a [FuncGodotMap]
func create_func_godot_map_progress_bar() -> Control:
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var progress_bar := ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.show_percentage = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.custom_minimum_size.y = 30
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	progress_bar.add_child(progress_label)
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	progress_label.offset_top = -9
	progress_label.offset_left = 3

	return progress_bar

## Create the "Build" button for [FuncGodotMap]s in the editor
func func_godot_map_build() -> void:
	var edited_object : FuncGodotMap = edited_object_ref.get_ref()
	if not edited_object:
		return

	edited_object.should_add_children = true
	edited_object.should_set_owners = true

	set_func_godot_map_control_disabled(true)
	edited_object.build_progress.connect(func_godot_map_build_progress)
	edited_object.build_complete.connect(func_godot_map_build_complete.bind(edited_object))
	edited_object.build_failed.connect(func_godot_map_build_complete.bind(edited_object))

	edited_object.verify_and_build()

## Create the "Unwrap UV2" button for [FuncGodotMap]s in the editor
func func_godot_map_unwrap_uv2() -> void:
	var edited_object = edited_object_ref.get_ref()
	if not edited_object:
		return

	if not edited_object is FuncGodotMap:
		return

	set_func_godot_map_control_disabled(true)
	if not edited_object.is_connected("unwrap_uv2_complete", func_godot_map_build_complete):
		edited_object.connect("unwrap_uv2_complete", func_godot_map_build_complete.bind(edited_object))

	edited_object.unwrap_uv2()

## Enable or disable the control for [FuncGodotMap]s in the editor
func set_func_godot_map_control_disabled(disabled: bool) -> void:
	if not func_godot_map_control:
		return

	for child in func_godot_map_control.get_children():
		if child is Button:
			child.set_disabled(disabled)

## Update the build progress bar (see: [method create_func_godot_map_progress_bar]) to display the current step and progress (0-1)
func func_godot_map_build_progress(step: String, progress: float) -> void:
	var progress_label = func_godot_map_progress_bar.get_node("ProgressLabel")
	func_godot_map_progress_bar.value = progress
	progress_label.text = step.capitalize()

## Callback for when the build process for a [FuncGodotMap] is finished.
func func_godot_map_build_complete(func_godot_map: FuncGodotMap) -> void:
	var progress_label = func_godot_map_progress_bar.get_node("ProgressLabel")
	progress_label.text = "Build Complete"

	set_func_godot_map_control_disabled(false)

	if func_godot_map.is_connected("build_progress",Callable(self,"func_godot_map_build_progress")):
		func_godot_map.disconnect("build_progress",Callable(self,"func_godot_map_build_progress"))

	if func_godot_map.is_connected("build_complete",Callable(self,"func_godot_map_build_complete")):
		func_godot_map.disconnect("build_complete",Callable(self,"func_godot_map_build_complete"))

	if func_godot_map.is_connected("build_failed",Callable(self,"func_godot_map_build_complete")):
		func_godot_map.disconnect("build_failed",Callable(self,"func_godot_map_build_complete"))
