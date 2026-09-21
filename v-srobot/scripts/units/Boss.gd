class_name Boss
extends Unit

enum StancePhase {
	PHASE_A,
	PHASE_B,
}

var stance: StancePhase = StancePhase.PHASE_A
var anchor_cell: Vector2i = Vector2i.ZERO
var enraged: bool = false
## Round 4 SPECIAL uses PHASE_B immunity but distinct telegraph/action.
var is_overload_action: bool = false


func setup_boss(anchor: Vector2i) -> void:
	is_boss = true
	is_player = false
	anchor_cell = anchor
	grid_pos = anchor
	stance = StancePhase.PHASE_A
	enraged = false
	is_overload_action = false
	move_range = BalanceConfig.BOSS_MOVE_RANGE
	setup("BOSS", "BOSS", Color(0.08, 0.08, 0.10, 1))
	setup_combat_stats(BalanceConfig.BOSS_MAX_HP, 0, 0, 0)
	_apply_boss_visual()
	_sync_boss_world_position()


func _apply_boss_visual() -> void:
	_ensure_nodes()
	var span: float = float(BalanceConfig.TILE_SIZE) * 2.0 - 8.0
	body.offset_left = -span * 0.5
	body.offset_top = -span * 0.5
	body.offset_right = span * 0.5
	body.offset_bottom = span * 0.5
	body.color = Color(0.08, 0.08, 0.10, 1)
	select_ring.offset_left = -span * 0.5 - 6.0
	select_ring.offset_top = -span * 0.5 - 6.0
	select_ring.offset_right = span * 0.5 + 6.0
	select_ring.offset_bottom = span * 0.5 + 6.0
	name_label.offset_top = -span * 0.5 - 24.0
	name_label.offset_bottom = -span * 0.5 - 4.0
	hp_label.offset_top = span * 0.5 + 2.0
	hp_label.offset_bottom = span * 0.5 + 22.0


func _sync_boss_world_position() -> void:
	var c0 := BalanceConfig.grid_to_world_center(anchor_cell)
	var c3 := BalanceConfig.grid_to_world_center(anchor_cell + Vector2i(1, 1))
	position = (c0 + c3) * 0.5


func set_grid_pos(cell: Vector2i) -> void:
	grid_pos = cell
	anchor_cell = cell
	_sync_boss_world_position()


func get_occupied_cells() -> Array[Vector2i]:
	return BalanceConfig.footprint_2x2(anchor_cell)


func is_immune_to_damage_type(damage_type: int) -> bool:
	# Overload is enhanced PHASE_B: Physical immune.
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


func stance_title(p_stance: StancePhase = stance, overload: bool = false) -> String:
	if overload:
		return "OVERLOAD"
	match p_stance:
		StancePhase.PHASE_A:
			return "ANTI-MAGIC"
		StancePhase.PHASE_B:
			return "ANTI-PHYSICAL"
	return "UNKNOWN"


func immunity_text(p_stance: StancePhase = stance, overload: bool = false) -> String:
	if overload:
		return "Immune to Physical Damage"
	match p_stance:
		StancePhase.PHASE_A:
			return "Immune to Magical Damage"
		StancePhase.PHASE_B:
			return "Immune to Physical Damage"
	return ""


func action_text(p_stance: StancePhase = stance, overload: bool = false, p_enraged: bool = false) -> String:
	var enrage_note := " [ENRAGED x1.5]" if p_enraged else ""
	if overload:
		return "OVERLOAD: 10 MAG AoE + 4 Burning + terrain destroy"
	match p_stance:
		StancePhase.PHASE_A:
			var dmg: int = BalanceConfig.BOSS_PHASE_A_DAMAGE
			if p_enraged:
				dmg = int(floor(float(dmg) * BalanceConfig.BOSS_ENRAGE_DAMAGE_MULT))
			return "Heavy Physical Strike (%d PHYS, adjacent)%s" % [dmg, enrage_note]
		StancePhase.PHASE_B:
			var dmg_b: int = BalanceConfig.BOSS_PHASE_B_DAMAGE
			if p_enraged:
				dmg_b = int(floor(float(dmg_b) * BalanceConfig.BOSS_ENRAGE_DAMAGE_MULT))
			return "Global Arcane Blast (%d MAG + 3 Burning)%s" % [dmg_b, enrage_note]
	return ""


func next_stance() -> StancePhase:
	if stance == StancePhase.PHASE_A:
		return StancePhase.PHASE_B
	return StancePhase.PHASE_A