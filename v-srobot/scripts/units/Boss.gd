class_name Boss
extends Unit

enum StancePhase {
	PHASE_A,
	PHASE_B,
}

var stance: StancePhase = StancePhase.PHASE_A
var anchor_cell: Vector2i = Vector2i.ZERO


func setup_boss(anchor: Vector2i) -> void:
	is_boss = true
	is_player = false
	anchor_cell = anchor
	grid_pos = anchor
	stance = StancePhase.PHASE_A
	setup("BOSS", "BOSS", Color(0.55, 0.15, 0.65, 1))
	setup_combat_stats(BalanceConfig.BOSS_MAX_HP, 0, 0, 0)
	_apply_boss_visual()
	_sync_boss_world_position()


func _apply_boss_visual() -> void:
	_ensure_nodes()
	# Cover roughly the full 2x2 footprint.
	var span: float = float(BalanceConfig.TILE_SIZE) * 2.0 - 8.0
	body.offset_left = -span * 0.5
	body.offset_top = -span * 0.5
	body.offset_right = span * 0.5
	body.offset_bottom = span * 0.5
	select_ring.offset_left = -span * 0.5 - 6.0
	select_ring.offset_top = -span * 0.5 - 6.0
	select_ring.offset_right = span * 0.5 + 6.0
	select_ring.offset_bottom = span * 0.5 + 6.0
	name_label.offset_top = -span * 0.5 - 24.0
	name_label.offset_bottom = -span * 0.5 - 4.0
	hp_label.offset_top = span * 0.5 + 2.0
	hp_label.offset_bottom = span * 0.5 + 22.0


func _sync_boss_world_position() -> void:
	# Center visually on the midpoint of the 2x2 footprint.
	var c0 := BalanceConfig.grid_to_world_center(anchor_cell)
	var c3 := BalanceConfig.grid_to_world_center(anchor_cell + Vector2i(1, 1))
	position = (c0 + c3) * 0.5


func set_grid_pos(cell: Vector2i) -> void:
	# Stationary boss: keep anchor as logical grid_pos; ignore 1-tile centering.
	grid_pos = cell
	anchor_cell = cell
	_sync_boss_world_position()


func get_occupied_cells() -> Array[Vector2i]:
	return BalanceConfig.footprint_2x2(anchor_cell)


func is_immune_to_damage_type(damage_type: int) -> bool:
	if stance == StancePhase.PHASE_A:
		return damage_type == 1 ## MAGICAL
	if stance == StancePhase.PHASE_B:
		return damage_type == 0 ## PHYSICAL
	return false


func advance_stance() -> void:
	if stance == StancePhase.PHASE_A:
		stance = StancePhase.PHASE_B
	else:
		stance = StancePhase.PHASE_A


func stance_name(p_stance: StancePhase = stance) -> String:
	match p_stance:
		StancePhase.PHASE_A:
			return "PHASE_A"
		StancePhase.PHASE_B:
			return "PHASE_B"
	return "UNKNOWN"


func stance_title(p_stance: StancePhase = stance) -> String:
	match p_stance:
		StancePhase.PHASE_A:
			return "ANTI-MAGIC"
		StancePhase.PHASE_B:
			return "ANTI-PHYSICAL"
	return "UNKNOWN"


func immunity_text(p_stance: StancePhase = stance) -> String:
	match p_stance:
		StancePhase.PHASE_A:
			return "Immune to Magical Damage"
		StancePhase.PHASE_B:
			return "Immune to Physical Damage"
	return ""


func action_text(p_stance: StancePhase = stance) -> String:
	match p_stance:
		StancePhase.PHASE_A:
			return "Heavy Physical Strike (15 PHYS, adjacent)"
		StancePhase.PHASE_B:
			return "Global Arcane Blast (8 MAG to all players)"
	return ""


func next_stance() -> StancePhase:
	if stance == StancePhase.PHASE_A:
		return StancePhase.PHASE_B
	return StancePhase.PHASE_A