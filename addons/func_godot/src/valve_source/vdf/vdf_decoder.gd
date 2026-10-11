class_name VDFDecoder extends RefCounted

@abstract class IDecoder:
	@abstract func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant

var _registry: Dictionary[String, IDecoder]

func decode(node: VDFNode, map_settings: FuncGodotMapSettings) -> Variant:
	if node.classname not in _registry:
		return null
		
	var decoded_children = node.children.map(decode.bind(map_settings))
	
	var decoder = _registry.get(node.classname)
	return decoder.decode(node.properties, decoded_children, map_settings, node)

func _init(recognized_types: Dictionary[String, IDecoder]):
	_registry = recognized_types
