extends Object

const IDecoder = preload("./vdf/vdf_decoder.gd").IDecoder

class VmfParsedDataDecoder extends IDecoder:
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var parsed_data = FuncGodotData.ParseData.new()
		
		for child in children:
			if child is FuncGodotData.EntityData:
				parsed_data.entities.append(child)
			if child is FuncGodotData.GroupData:
				parsed_data.groups.append(child)
				
		#ASSIGN GROUPS
		for e in parsed_data.entities:
			if "visgroupid" in e.properties:
				var group_id: int = e.properties["visgroupid"] as int
				for g in parsed_data.groups:
					if g.id == group_id:
						e.group = g
						break

		return parsed_data
		
class VmfEntityDecoder extends IDecoder:
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var ent = FuncGodotData.EntityData.new()
		ent.properties = properties
		
		for child in children:
			if child is FuncGodotData.BrushData:
				ent.brushes.append(child)
		
		if not ent.brushes.is_empty():
			var brush: VDFNode
			var editor: VDFNode
			for brush_meta in raw_data.children:
				if brush_meta.classname != "solid":
					continue
				brush = brush_meta
				break
			
			if brush:
				for editor_meta in brush.children:
					if editor_meta.classname == "editor":
						editor = editor_meta
			
			if editor and "visgroupid" in editor.properties:
				ent.properties["visgroupid"] = editor.properties.visgroupid
		
		return ent
		
class VmfBrushDecoder extends IDecoder:
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var brush = FuncGodotData.BrushData.new()
		
		for child in children:
			if child is FuncGodotData.FaceData:
				brush.faces.append(child)
				brush.planes.append(child.plane)
				
		brush.origin = brush.faces.all(
			func (f):
				return f.texture == map_settings.origin_texture
		)
		
		return brush
		
class VmfFaceDecoder extends IDecoder:
	func _read_vec3_array(value: String):
		var tokens = value.replace("(", "").replace(")", "").split_floats(" ", false)
		assert(tokens.size() == 9, "invalid number of points to construct plane")
		var points: PackedVector3Array
		for i in range(0, len(tokens), 3):
			points.append(
				Vector3(tokens[i], tokens[i+1], tokens[i+2])
			)
		return points
		
	func _read_uv(value: String):
		var vals: PackedFloat64Array = value.replace("[", "").replace("]", "").split_floats(" ", false)
		return {
			"axis": Vector3(vals[0], vals[1], vals[2]),
			"offset": vals[3],
			"scale": vals[4]
		}
	
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var face = FuncGodotData.FaceData.new()
		
		face.texture = properties.material
		
		var points = _read_vec3_array(properties.plane)
		face.plane = Plane(
			points[0] * map_settings.scale_factor,
			points[1] * map_settings.scale_factor,
			points[2] * map_settings.scale_factor
		)
		
		var uaxis = _read_uv(properties.uaxis)
		var vaxis = _read_uv(properties.vaxis)
		face.uv_axes = [uaxis.axis, vaxis.axis]
		face.uv.origin = Vector2(uaxis.offset, vaxis.offset)
		face.uv.x *= uaxis.scale * map_settings.scale_factor
		face.uv.y *= vaxis.scale * map_settings.scale_factor 
		
		return face
		
class VmfVisgroupDecoder extends IDecoder:
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var group = FuncGodotData.GroupData.new()
		if "name" in properties:
			group.name = "group_%s_" + properties.name
			
		if "visgroupid" in properties:
			var value = properties.visgroupid
			group.id = value.to_int()
			group.name = group.name % value
			group.name = group.name.replace(" ", "_")
					
		for subgroup in children:
			if subgroup is FuncGodotData.GroupData:
				subgroup.parent = group
				subgroup.parent_id = group.id

		return group
		
class VmfVisgroupsDecoder extends IDecoder:
	func flatten(acc: Array[FuncGodotData.GroupData], group: FuncGodotData.GroupData):
		acc.append(group)
		for g in group.children:
			flatten(acc, g)
	
	func decode(properties: Dictionary[String, Variant], children: Array[Variant], map_settings: FuncGodotMapSettings, raw_data: VDFNode) -> Variant:
		var acc: Array[FuncGodotData.GroupData] = []
		for child in children:
			if child is FuncGodotData.GroupData:
				flatten(acc, child)
		return acc
	
static var VMFDecoder: VDFDecoder = VDFDecoder.new({
	"_root": VmfParsedDataDecoder.new(),
	"world": VmfEntityDecoder.new(),
	"entity": VmfEntityDecoder.new(),
	"solid": VmfBrushDecoder.new(),
	"side": VmfFaceDecoder.new(),
	"visgroup": VmfVisgroupDecoder.new(),
	"visgroups": VmfVisgroupsDecoder.new()
})
