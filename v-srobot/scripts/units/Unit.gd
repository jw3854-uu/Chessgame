class_name Unit
extends Node2D

signal statuses_changed

@onready var body: ColorRect = $Body
@onready var select_ring: ColorRect = $SelectRing
@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HpLabel

var unit_id: String = ""
var display_name: String = "Unit"
var grid_pos: Vector2i = Vector2i.ZERO
var move_range: int = BalanceConfig.PLAYER_MOVE_RANGE
var has_moved_this_round: bool = false
var has_attacked_this_round: bool = false
var is_player: bool = true
var is_boss: bool = false

var max_hp: int = BalanceConfig.PLAYER_MAX_HP
var hp: int = BalanceConfig.PLAYER_MAX_HP
var shield: int = 0
var attack_damage: int = BalanceConfig.PLAYER_ATTACK_DAMAGE
var attack_range: int = BalanceConfig.PLAYER_ATTACK_RANGE
var attack_damage_type: int = 0 ## CombatResolver.DamageType.PHYSICAL

## Authoritative status storage for this unit: status_id -> StatusInstance
var statuses: Dictionary = {}


func setup(id: String, label: String, color: Color) -> void:
	unit_id = id
	display_name = label
	name = id
	_ensure_nodes()
	body.color = color
	name_label.text = label
	refresh_hp_label()
	set_selected(false)


func setup_combat_stats(p_max_hp: int, p_attack_damage: int, p_attack_range: int, p_damage_type: int) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	attack_damage = p_attack_damage
	attack_range = p_attack_range
	attack_damage_type = p_damage_type
	refresh_hp_label()


func _ensure_nodes() -> void:
	if body == null:
		body = $Body
	if select_ring == null:
		select_ring = $SelectRing
	if name_label == null:
		name_label = $NameLabel
	if hp_label == null:
		hp_label = $HpLabel


func set_grid_pos(cell: Vector2i) -> void:
	grid_pos = cell
	position = BalanceConfig.grid_to_world_center(cell)


func set_selected(selected: bool) -> void:
	_ensure_nodes()
	select_ring.visible = selected


func reset_round_actions() -> void:
	has_moved_this_round = false
	has_attacked_this_round = false


func mark_moved() -> void:
	has_moved_this_round = true


func mark_attacked() -> void:
	has_attacked_this_round = true


func is_dead() -> bool:
	return hp <= 0


func is_immune_to_damage_type(_damage_type: int) -> bool:
	return false


func get_occupied_cells() -> Array[Vector2i]:
	return [grid_pos]


func add_shield(amount: int) -> int:
	if amount <= 0:
		return shield
	shield += amount
	statuses_changed.emit()
	return shield


func has_holy_shield() -> bool:
	return get_status(StatusIds.HOLY_SHIELD) != null


func grant_holy_shield() -> void:
	if has_holy_shield():
		statuses_changed.emit()
		return
	statuses[StatusIds.HOLY_SHIELD] = StatusInstance.new(StatusIds.HOLY_SHIELD, -1, 1)
	statuses_changed.emit()


func consume_holy_shield() -> void:
	if statuses.has(StatusIds.HOLY_SHIELD):
		statuses.erase(StatusIds.HOLY_SHIELD)
		statuses_changed.emit()


func get_status(status_id: String) -> StatusInstance:
	return statuses.get(status_id, null) as StatusInstance


func get_burning_stacks() -> int:
	var s: StatusInstance = get_status(StatusIds.BURNING)
	if s == null:
		return 0
	return s.stacks


func add_burning_stacks(amount: int) -> int:
	if amount <= 0:
		return get_burning_stacks()
	var s: StatusInstance = get_status(StatusIds.BURNING)
	if s == null:
		s = StatusInstance.new(StatusIds.BURNING, -1, 0)
		statuses[StatusIds.BURNING] = s
	s.stacks += amount
	statuses_changed.emit()
	return s.stacks


func set_burning_stacks(amount: int) -> void:
	if amount <= 0:
		clear_burning()
		return
	var s: StatusInstance = get_status(StatusIds.BURNING)
	if s == null:
		s = StatusInstance.new(StatusIds.BURNING, -1, amount)
		statuses[StatusIds.BURNING] = s
	else:
		s.stacks = amount
	statuses_changed.emit()


func clear_burning() -> void:
	if statuses.has(StatusIds.BURNING):
		statuses.erase(StatusIds.BURNING)
		statuses_changed.emit()


func burning_ui_text() -> String:
	var stacks: int = get_burning_stacks()
	if stacks <= 0:
		return ""
	var dmg: int = stacks * BalanceConfig.BURNING_DAMAGE_PER_STACK
	return "Burning: %d stacks (%d damage)" % [stacks, dmg]


func refresh_hp_label() -> void:
	_ensure_nodes()
	if hp_label != null:
		hp_label.text = "%d/%d" % [hp, max_hp]


func show_damage_popup(amount: int, immune: bool = false, holy_blocked: bool = false) -> void:
	var popup := Label.new()
	if holy_blocked:
		popup.text = "BLOCKED"
		popup.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	elif immune:
		popup.text = "IMMUNE"
		popup.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	else:
		popup.text = "-%d" % amount
		popup.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	popup.position = Vector2(-28, -70)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 10
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	popup.add_theme_constant_override("outline_size", 4)
	popup.add_theme_font_size_override("font_size", 16)
	add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "position", popup.position + Vector2(0, -24), 0.55)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.55)
	tween.tween_callback(popup.queue_free)

func can_use_skills() -> bool:
	return not has_imprisoned()


func has_imprisoned() -> bool:
	return get_status(StatusIds.IMPRISONED) != null


func apply_imprisoned() -> void:
	## Resets duration tracking so the next applicable PLAYER_PHASE is blocked.
	var inst := StatusInstance.new(StatusIds.IMPRISONED, -1, 1, "", {"seen_player_phase": false})
	statuses[StatusIds.IMPRISONED] = inst
	statuses_changed.emit()


func mark_imprisoned_seen_player_phase() -> void:
	var s: StatusInstance = get_status(StatusIds.IMPRISONED)
	if s == null:
		return
	s.meta["seen_player_phase"] = true
	statuses_changed.emit()


func imprisoned_seen_player_phase() -> bool:
	var s: StatusInstance = get_status(StatusIds.IMPRISONED)
	if s == null:
		return false
	return bool(s.meta.get("seen_player_phase", false))


func clear_imprisoned() -> void:
	if statuses.has(StatusIds.IMPRISONED):
		statuses.erase(StatusIds.IMPRISONED)
		statuses_changed.emit()


func imprisoned_ui_text() -> String:
	if not has_imprisoned():
		return ""
	return "Imprisoned — Skills Disabled"
