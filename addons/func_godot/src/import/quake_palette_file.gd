@icon("res://addons/func_godot/icons/icon_quake_file.svg")
class_name QuakePaletteFile extends Resource
## Quake LMP palette format file used with [QuakeWadFile].
##
## Quake LMP palette format file used in conjunction with a Quake WAD2 format [QuakeWadFile]. 
## Not required for the Valve WAD3 format.
##
## @tutorial(Quake Wiki Palette Article): https://quakewiki.org/wiki/Quake_palette#palette.lmp

## Collection of [Color]s retrieved from the LMP palette file.
@export var colors: PackedColorArray

func _init(colors):
	self.colors = colors
