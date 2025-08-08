<p align="center"><img src="https://github.com/func-godot/.github/assets/44485952/53bdc589-33e8-4a39-8707-01a5f850d155" alt="FuncGodotRanger" width="15%" /> 
<img src="https://github.com/func-godot/.github/assets/44485952/b7c19218-2089-4319-a2bd-6ce4b354c1ce" alt="FuncGodot" width="80%"/></p>

***FuncGodot*** is a plugin for [Godot 4](https://godotengine.org/) that allows users to generate Godot scenes using the [Quake MAP file format](https://quakewiki.org/wiki/Quake_Map_Format) and [Valve Map Format](https://developer.valvesoftware.com/wiki/VMF_(Valve_Map_Format)). Map files can be made in a variety of editors, the most commonly recommended one being [TrenchBroom](https://trenchbroom.github.io/). It is a reworking and rewrite of the [Qodot](https://github.com/QodotPlugin/Qodot) plugin for Godot 3 and 4.

## [Download FuncGodot!](https://github.com/func-godot/func_godot_plugin)

[Full documentation is available online](https://func-godot.github.io/func_godot_docs/) as well as off. [Download a standalone copy of the manual here](https://github.com/func-godot/func_godot_docs/releases/).

For more help or to contribute to the community, join us on the [**Official FuncGodot Discord**](https://discord.gg/eBQ7EfNZSZ)!

<p align="center"><img src="https://github.com/func-godot/.github/assets/44485952/0a4d2436-884e-4cee-94a8-220df3813627" alt="TrenchBroom" width="45%" /> 
<img src="https://github.com/func-godot/.github/assets/44485952/25e96e49-3482-40cf-ade9-99e83c3eca7d" alt="Godot FuncGodotMap Built" width="45%"/></p>


## Features

- Godot Scene Generation
  - Supports Quake `map` and Hammer `vmf`
  - Supports Quake WAD2, Half-Life WAD3, and `lmp` palette formats
  - Meshes from `map` brush geometry
  - Materials and UVs from map texture definitions
  - Convex and concave collision shapes
- Entity Definition Support
  - Fully customizable entities that can be defined for map editors and generated in Godot
  - Leverage the map format's classname and key value pair systems
  - Define the visual and collision properties of brush entities on a per-classname basis
  - Retrieve easy to access mesh metadata for per face material information
  - Define point entities that can be generated from node class name and script or from packed scenes
  - Generate GLB display models with correct orientation and scale for point entities in map editors with GLTF support
  - FGD (Forge Game Data) export
- TrenchBroom Integration
  - GameConfig export
  - Brush and Face Tags
  - `model` keyword and scale expression
- NetRadiant Custom Integration
  - Gamepack Export
  - Shader definitions
  - Customizable build options

## Confirmed Compatible Map Editors
  - TrenchBroom
  - Hammer
  - J.A.C.K.
  - NetRadiant Custom

Help us add to this list by testing out your preferred map editor and helping us come up with compatibility solutions!

## Credits

FuncGodot was created by [Hannah "EMBYR" Crawford](https://embyr.sh/), [Emberlynn Bland](https://github.com/deertears/), [Tim "RhapsodyInGeek" Maccabe](https://github.com/RhapsodyInGeek), and [Vera "sinewavey" Lux](https://github.com/sinewavey), reworked from the [Godot 4 port of Qodot](https://github.com/QodotPlugin/Qodot/tree/main) by Embyr, with contributions from members of the FuncGodot, Qodot, Godot, and Quake Mapping Communities.

Both plugins are based on the original [Qodot for Godot 3.5](https://github.com/QodotPlugin/qodot-plugin/) created by [Josh "Shifty" Palmer](https://twitter.com/ShiftyAxel).

<p align="center"><img src="https://github.com/func-godot/.github/assets/44485952/9ff9cd96-024b-4202-b4a2-611741b81609" alt="Godambler" /></p>
