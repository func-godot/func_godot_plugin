@icon("res://addons/func_godot/icons/icon_quake_file.svg")
class_name QuakeWadFile extends Resource
## Texture container in the WAD2 or WAD3 format.
##
## Texture container in the Quake WAD2 or Valve WAD3 format. 
##
## @tutorial(Quake Wiki WAD Article): https://quakewiki.org/wiki/Texture_Wad
## @tutorial(Valve Developer Wiki WAD3 Article): https://developer.valvesoftware.com/wiki/WAD

## Collection of [ImageTexture] imported from the WAD file.
@export var textures: Dictionary[String, ImageTexture]

func _init(textures: Dictionary = Dictionary()):
	self.textures = textures
