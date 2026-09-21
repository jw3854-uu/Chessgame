class_name StatusInstance
extends RefCounted

## Minimal reusable status payload. One entry per status id per unit.
var id: String = ""
var duration: int = -1
var stacks: int = 0
var source_id: String = ""
var meta: Dictionary = {}


func _init(
	p_id: String = "",
	p_duration: int = -1,
	p_stacks: int = 0,
	p_source_id: String = "",
	p_meta: Dictionary = {}
) -> void:
	id = p_id
	duration = p_duration
	stacks = p_stacks
	source_id = p_source_id
	meta = p_meta.duplicate(true)