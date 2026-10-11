class_name VMFParser extends RefCounted

func parse(map_data: String) -> VDFNode:
	var tokenizer = RegEx.create_from_string(r"\/\/.*|[^\s\"']+|\"([^\"]*)\"|'([^']*)'")
	
	var root = VDFNode.new()
	root.classname = "_root"
	
	var idx = 0
	var prev_token = ""
	var node: VDFNode = root
	var path: Array[VDFNode] = [root]
	
	while idx > -1:
		var matched = tokenizer.search(map_data, idx)
		if matched == null:
			break
			
		idx = matched.get_end()
		var token = matched.get_string(0).lstrip("\"").rstrip("\"")
		
		if token.begins_with("//"):
			continue
		elif token == "{":
			var leaf = VDFNode.new()
			leaf.classname = prev_token
			node.children.append(leaf)
			path.append(leaf)
			node = leaf
			prev_token = ""
		elif token == "}":
			path.pop_back()
			node = path[-1]
			assert(node != null, "invalid scope")
			prev_token = ""
		elif prev_token != "":
			node.properties[prev_token] = token
			prev_token = ""
		else:
			prev_token = token
		
	return root
