@icon("res://addons/func_godot/icons/icon_godambler.svg")
class_name FuncGodotParser extends RefCounted
## MAP and VMF parser class that is instantiated by a [FuncGodotMap] node during the build process.
##
## @tutorial(Quake Wiki Map Format Article): https://quakewiki.org/wiki/Quake_Map_Format
## @tutorial(Valve Developer Wiki VMF Article): https://developer.valvesoftware.com/wiki/VMF_(Valve_Map_Format)

const _SIGNATURE: String = "[PRS]"

const _GroupData	:= FuncGodotData.GroupData
const _EntityData	:= FuncGodotData.EntityData
const _BrushData	:= FuncGodotData.BrushData
const _PatchData	:= FuncGodotData.PatchData
const _FaceData		:= FuncGodotData.FaceData
const _ParseData	:= FuncGodotData.ParseData

## Emitted when a step in the parsing process is completed. 
## It is connected to [method FuncGodotUtil.print_profile_info] method if [member FuncGodotMap.build_flags] SHOW_PROFILE_INFO flag is set.
signal declare_step(step: String)

## Parses the map file, generating entity and group data and sub-data, then returns the generated data as an array of arrays. 
## The first array is Array[FuncGodotData.EntityData], while the second array is Array[FuncGodotData.GroupData].
func parse_map_data(map_file: String, map_settings: FuncGodotMapSettings) -> _ParseData:
	var map_data: PackedStringArray = []
	var parse_data := _ParseData.new()
	declare_step.emit("Loading map file %s" % map_file)
	
	# Retrieve real path if needed
	if map_file.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(map_file)
		if not ResourceUID.has_id(uid):
			printerr("Error: failed to retrieve path for UID (%s)" % map_file)
			return parse_data
		map_file = ResourceUID.get_id_path(uid)
	
	# Open the map file
	var file: FileAccess = FileAccess.open(map_file, FileAccess.READ)
	if not file:
		file = FileAccess.open(map_file + ".import", FileAccess.READ)
		if file:
			map_file += ".import"
		else:
			printerr("Error: Failed to open map file (" + map_file + ")")
			return parse_data
	
	# Packed map file resources need to be accessed differently in exported projects.
	if map_file.ends_with(".import"):
		while not file.eof_reached():
			var line: String = file.get_line()
			if line.begins_with("path"):
				file.close()
				line = line.replace("path=", "")
				line = line.replace('"', '')
				var data: String = (load(line) as QuakeMapFile).map_data
				if data.is_empty():
					printerr("Error: Failed to open map file (" + line + ")")
					return parse_data
				map_data = data.split("\n")
				break
	else:
		while not file.eof_reached():
			map_data.append(file.get_line())
	
	# Determine map type and parse data
	if map_file.to_lower().contains(".map"):
		declare_step.emit("Parsing as Quake MAP")
		parse_data = _parse_quake_map(map_data, map_settings, parse_data)
	elif map_file.to_lower().contains(".vmf"):
		declare_step.emit("Parsing as Source VMF")
		parse_data = _parse_vmf(map_data, map_settings, parse_data)
	
	# Determine group hierarchy
	declare_step.emit("Determining groups hierarchy")
	var groups_data: Array[_GroupData] = parse_data.groups
	for g in groups_data:
		if g.parent_id != -1:
			for p in groups_data:
				if p.id == g.parent_id:
					g.parent = p
					break
	
	var entities_data: Array[_EntityData] = parse_data.entities
	var entity_defs: Dictionary[String, FuncGodotFGDEntityClass] = map_settings.entity_fgd.get_entity_definitions()
	
	declare_step.emit("Checking entity omission and definition status")
	
	for i in range(entities_data.size() - 1, -1, -1):
		var entity: _EntityData = entities_data[i]
		
		# Delete entities from omitted groups
		if entity.group != null and entity.group.omit == true:
			entities_data.remove_at(i)
			continue
		
		# Provide entity definition to entity data. This gets used in both 
		# geo generation and entity assembly.
		if "classname" in entity.properties:
			var classname: String = entity.properties["classname"]
			if classname in entity_defs:
				entity.definition = entity_defs[classname]
	
	# Delete omitted groups
	declare_step.emit("Removing omitted layers and groups")
	for i in range(groups_data.size() - 1, -1, -1):
		if groups_data[i].omit == true:
			groups_data.remove_at(i)
	
	declare_step.emit("Map parsing complete")
	return parse_data

## Parser subroutine called by [method parse_map_data], specializing in the Quake MAP format.
func _parse_quake_map(map_data: PackedStringArray, map_settings: FuncGodotMapSettings, parse_data: _ParseData) -> _ParseData:
	var entities_data: Array[_EntityData] = parse_data.entities
	var groups_data: Array[_GroupData] = parse_data.groups
	var ent: _EntityData = null
	var brush: _BrushData = null
	var patch: _PatchData = null
	var scope: int = 0 # Scope level, to keep track of where we are in PatchDef parsing
	
	for line in map_data:
		line = line.replace("\t", "")
		
		#region START DATA
		# Start entity, brush, or patchdef
		if line.begins_with("{"):
			if not ent:
				ent = _EntityData.new()
			else:
				if not patch:
					brush = _BrushData.new()
				else:
					scope += 1
			continue
		#endregion
		
		#region COMMIT DATA
		# Commit entity or brush
		if line.begins_with("}"):
			if brush:
				ent.brushes.append(brush)
				brush = null
			elif patch:
				if scope:
					scope -= 1
				else:
					ent.patches.append(patch)
					patch = null
			else:
				# TrenchBroom layers and groups
				if ent.properties["classname"] == "func_group" and ent.properties.has("_tb_type"):
					# Merge TB Group / Layer structural brushes with worldspawn
					if entities_data.size():
						entities_data[0].brushes.append_array(ent.brushes)
					
					# Create group data
					var group: _GroupData = _GroupData.new()
					var props: Dictionary = ent.properties
					group.id = props["_tb_id"] as int
					if props["_tb_type"] == "_tb_layer":
						group.type = _GroupData.GroupType.GROUP
						group.name = "layer_"
					else:
						group.name = "group_"
					group.name = group.name + str(group.id)
					if props["_tb_name"] != "Unnamed":
						group.name = group.name + "_" + (props["_tb_name"] as String).replace(" ", "_")
					if props.has("_tb_layer"):
						group.parent_id = props["_tb_layer"] as int
					if props.has("_tb_group"):
						group.parent_id = props["_tb_group"] as int
					if props.has("_tb_layer_omit_from_export"):
						group.omit = true
					
					# Commit group
					groups_data.append(group)
					
				# Commit entity
				else:
					entities_data.append(ent)
				ent = null
			continue
		#endregion
		
		#region PROPERTY DATA
		# Retrieve key value pairs
		if line.begins_with("\""):
			var tokens: PackedStringArray = line.split("\" \"")
			if tokens.size() < 2:
				tokens = line.split("\"\"")
			var key: String = tokens[0].trim_prefix("\"")
			var value: String = tokens[1].trim_suffix("\"")
			ent.properties[key] = value
		#endregion
		
		#region BRUSH DATA
		if brush and line.begins_with("("):
			line = line.replace("(","")
			var tokens: PackedStringArray = line.split(" ) ")
			
			# Retrieve plane data
			var points: PackedVector3Array
			points.resize(3) 
			for i in 3:
				tokens[i] = tokens[i].trim_prefix("(")
				var pts: PackedFloat64Array = tokens[i].split_floats(" ", false)
				var point := Vector3(pts[0], pts[1], pts[2])
				points[i] = point
			
			var plane := Plane(points[0], points[1], points[2])
			brush.planes.append(plane)
			
			var face: _FaceData = _FaceData.new()
			face.plane = plane
			
			# Retrieve texture data
			var tex: String = String()
			if tokens[3].begins_with("\""): # textures with spaces get surrounded by double quotes
				var last_quote := tokens[3].rfind("\"")
				tex = tokens[3].substr(1, last_quote - 1)
				tokens = tokens[3].substr(last_quote + 2).split(" ] ")
			else:
				tex = tokens[3].get_slice(" ", 0)
				tokens = tokens[3].trim_prefix(tex + " ").split(" ] ")
			face.texture = tex
			
			# Check for origin brushes. Brushes must be completely textured with origin to be valid.
			if brush.faces.is_empty():
				if tex == map_settings.origin_texture:
					brush.origin = true
			elif brush.origin == true:
				if tex != map_settings.origin_texture:
					brush.origin = false
			
			# Retrieve UV data
			var uv: Transform2D = Transform2D.IDENTITY
			
			# Valve 220: texname [ ux uy ux offsetX ] [vx vy vz offsetY] rotation scaleX scaleY
			if tokens.size() > 1:
				var coords: PackedFloat64Array
				for i in 2: 
					coords = tokens[i].trim_prefix("[ ").split_floats(" ", false)
					face.uv_axes.append(Vector3(coords[0], coords[1], coords[2])) # Save axis vectors separately
					face.uv.origin[i] = coords[3] # UV offset stored as transform origin
				
				coords = tokens[2].split_floats(" ", false)
				# UV scale factor stored in basis
				face.uv.x = Vector2(coords[1], 0.0)
				face.uv.y = Vector2(0.0, coords[2])
			
			# Quake Standard: texname offsetX offsetY rotation scaleX scaleY
			else:
				var coords: PackedFloat64Array = tokens[0].split_floats(" ", false)
				face.uv.origin = Vector2(coords[0], coords[1])
				
				var r: float = deg_to_rad(coords[2])
				face.uv.x = Vector2(cos(r), -sin(r)) * coords[3]
				face.uv.y = Vector2(sin(r), cos(r)) * coords[4]
			
			brush.faces.append(face)
			continue
		#endregion
		
		#region PATCH DATA
		if patch:
			if line.begins_with("("):
				line = line.replace("( ","")
				# Retrieve patch control points
				if patch.size:
					var tokens: PackedStringArray = line.replace("(", "").split(" )", false)
					for i in tokens.size():
						var subtokens: PackedFloat64Array = tokens[i].split_floats(" ", false)
						patch.points.append(Vector3(subtokens[0], subtokens[1], subtokens[2]))
						patch.uvs.append(Vector2(subtokens[3], subtokens[4]))
				# Retrieve patch size
				else:
					var tokens: PackedStringArray = line.replace(")","").split(" ", false)
					patch.size.resize(tokens.size())
					for i in tokens.size():
						patch.size[i] = tokens[i].to_int()
			# Retrieve patch texture
			elif not line.begins_with(")"):
				patch.texture = line.replace("\"","")
		
		if line.begins_with("patchDef"):
			brush = null
			patch = _PatchData.new()
			continue
		#endregion
	
	#region ASSIGN GROUPS
	for e in entities_data:
		var group_id: int = -1
		if e.properties.has("_tb_layer"):
			group_id = e.properties["_tb_layer"] as int
		elif e.properties.has("_tb_group"):
			group_id = e.properties["_tb_group"] as int
		if group_id != -1:
			for g in groups_data:
				if g.id == group_id:
					e.group = g
					break
	#endregion
	
	return parse_data

## Parser subroutine called by [method parse_map_data], specializing in the Valve Map Format used by Hammer based editors.
func _parse_vmf(map_data: PackedStringArray, map_settings: FuncGodotMapSettings, parse_data: _ParseData) -> _ParseData:
	var entities_data: Array[_EntityData] = parse_data.entities
	var groups_data: Array[_GroupData] = parse_data.groups
	var ent: _EntityData = null
	var brush: _BrushData = null
	var group: _GroupData = null
	var group_parent_hierarchy: Array[_GroupData] = []
	var scope: int = 0
	
	for line in map_data:
		line = line.replace("\t", "")
		
		#region START DATA
		if line.begins_with("entity") or line.begins_with("world"):
			ent = _EntityData.new()
			continue
		if line.begins_with("solid"):
			brush = _BrushData.new()
			continue
		if brush and line.begins_with("{"):
			scope += 1
			continue
		if line == "visgroup":
			if group != null:
				groups_data.append(group)
				group_parent_hierarchy.append(group)
			group = _GroupData.new()
			if group_parent_hierarchy.size():
				group.parent = group_parent_hierarchy.back()
				group.parent_id = group.parent.id
			continue
		#endregion
		
		#region COMMIT DATA
		if line.begins_with("}"):
			if scope > 0:
				scope -= 1
			if not scope:
				if brush:
					if brush.faces.size():
						ent.brushes.append(brush)
					brush = null
				elif ent:
					entities_data.append(ent)
					ent = null
				elif group:
					groups_data.append(group)
					group = null
				elif group_parent_hierarchy.size():
					group_parent_hierarchy.pop_back()
			continue
		#endregion
		
		# Retrieve key value pairs
		if (ent or group) and line.begins_with("\""):
			var tokens: PackedStringArray = line.split("\" \"")
			var key: String = tokens[0].trim_prefix("\"")
			var value: String = tokens[1].trim_suffix("\"")
			
			#region BRUSH DATA
			if brush:
				if scope > 1:
					match key:
						"plane":
							tokens = value.replace("(", "").split(")", false)
							var points: PackedVector3Array
							points.resize(3) 
							for i in 3:
								tokens[i] = tokens[i].trim_prefix("(")
								var pts: PackedFloat64Array = tokens[i].split_floats(" ", false)
								var point: Vector3 = Vector3(pts[0], pts[1], pts[2])
								points[i] = point
							brush.planes.append(Plane(points[0], points[1], points[2]))
							brush.faces.append(_FaceData.new())
							brush.faces[-1].plane = brush.planes[-1]
							continue
						"material":
							if brush.faces.size():
								brush.faces[-1].texture = value
								# Origin brush needs to be completely set to origin, otherwise it's invalid
								if brush.faces.size() < 2:
									if value == map_settings.origin_texture:
										brush.origin = true
								elif brush.origin == true:
									if value != map_settings.origin_texture:
										brush.origin = false
							continue
						"uaxis", "vaxis":
							if brush.faces.size():
								value = value.replace("[", "")
								var vals: PackedFloat64Array = value.replace("]", "").split_floats(" ", false)
								var face: _FaceData = brush.faces[-1]
								face.uv_axes.append(Vector3(vals[0], vals[1], vals[2]))
								if key.begins_with("u"):
									face.uv.origin.x = vals[3] # Offset
									face.uv.x *= vals[4] # Scale
								else:
									face.uv.origin.y = vals[3] # Offset
									face.uv.y *= vals[4] # Scale
							continue
						"rotation":
							# Rotation isn't used in Valve 220 mapping and VMFs are 220 exclusive
							continue
						"visgroupid":
							# Don't put worldspawn into a group
							if entities_data.size():
								# Only nodes can be organized into groups in the SceneTree, so only use the first brush's group
								if not ent.properties.has(key):
									ent.properties[key] = value
			#endregion
			elif ent:
				ent.properties[key] = value
				continue
			elif group:
				if key == "name":
					group.name = "group_%s_" + value
				elif key == "visgroupid":
					group.id = value.to_int()
					group.name = group.name % value
					group.name = group.name.replace(" ", "_")
				continue
	
	#region ASSIGN GROUPS
	for e in entities_data:
		if e.properties.has("visgroupid"):
			var group_id: int = e.properties["visgroupid"] as int
			for g in groups_data:
				if g.id == group_id:
					e.group = g
					break
	#endregion
	
	return parse_data
