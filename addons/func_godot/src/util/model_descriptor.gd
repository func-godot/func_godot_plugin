class_name ModelDescriptor
extends Resource

@export var path: String = ""
# Optional but defaults to 0. Not harmful to use defaults
@export_range(0, 10000,1) var skin: int = 0
@export_range(0, 10000,1) var frame: int = 0
