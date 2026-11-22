## Abstract base for all save backends.
## Extend this; never instantiate directly.
class_name SaveBackend
extends Node

signal save_completed(success: bool)
signal load_completed(success: bool, data: Dictionary)

func save(_data: Dictionary) -> void:
	push_error("%s: save() not implemented" % get_script().resource_path)

func load_data() -> void:
	push_error("%s: load_data() not implemented" % get_script().resource_path)

func is_available() -> bool:
	return false
