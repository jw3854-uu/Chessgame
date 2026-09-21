class_name BattleManager
extends Node

enum Phase {
	ROUND_START,
	BOSS_TURN,
	PLAYER_PHASE,
	ENEMY_PHASE,
	ROUND_END,
}

enum ActionMode {
	NONE,
	MOVE,
	ATTACK_PHYSICAL,
	ATTACK_MAGICAL,
}

signal phase_changed(phase: Phase)
signal round_changed(round_number: int)
signal selection_changed(unit: Unit)
signal action_mode_changed(mode: ActionMode)
signal combat_log_message(message: String)
signal boss_telegraph_changed
signal elite_telegraph_changed
signal temporary_victory

@export var grid_path: NodePath
@export var units_path: NodePath
@export var unit_scene: PackedScene
@export var boss_scene: PackedScene
@export var elite_scene: PackedScene

var grid: GridManager
var units_root: Node2D
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var boss: Boss = null
var elite1: EliteEnemy = null
var elite2: EliteEnemy = null
var selected_unit: Unit = null
var current_phase: Phase = Phase.ROUND_START
var action_mode: ActionMode = ActionMode.NONE
var round_number: int = 0
var battle_over: bool = false
var _highlight_cells: Array[Vector2i] = []


func _ready() -> void:
	grid = get_node(grid_path) as GridManager
	units_root = get_node(units_path) as Node2D
	if unit_scene == null:
		unit_scene = load("res://scenes/units/Unit.tscn") as PackedScene
	if boss_scene == null:
		boss_scene = load("res://scenes/units/Boss.tscn") as PackedScene
	if elite_scene == null:
		elite_scene = load("res://scenes/units/EliteEnemy.tscn") as PackedScene
	grid.cell_clicked.connect(_on_cell_clicked)
	call_deferred("_start_battle")


func _start_battle() -> void:
	_spawn_boss()
	_spawn_placeholder_players()
	_spawn_elites()
	boss_telegraph_changed.emit()
	elite_telegraph_changed.emit()
	_begin_round()


func _spawn_boss() -> void:
	boss = boss_scene.instantiate() as Boss
	units_root.add_child(boss)
	boss.setup_boss(BalanceConfig.BOSS_ANCHOR)
	if not grid.place_boss(boss, BalanceConfig.BOSS_ANCHOR):
		push_error("Failed to place Boss at %s" % BalanceConfig.BOSS_ANCHOR)
		boss.queue_free()
		boss = null


func _spawn_placeholder_players() -> void:
	var starts: Array[Vector2i] = [
		Vector2i(1, 2),
		Vector2i(1, 4),
		Vector2i(1, 6),
		Vector2i(2, 3),
	]
	var colors: Array[Color] = [
		Color(0.25, 0.55, 0.95, 1),
		Color(0.30, 0.75, 0.45, 1),
		Color(0.90, 0.55, 0.25, 1),
		Color(0.75, 0.35, 0.85, 1),
	]
	for i in starts.size():
		var unit := unit_scene.instantiate() as Unit
		units_root.add_child(unit)
		unit.setup("P%d" % (i + 1), "P%d" % (i + 1), colors[i])
		unit.is_player = true
		unit.move_range = BalanceConfig.PLAYER_MOVE_RANGE
		unit.setup_combat_stats(
			BalanceConfig.PLAYER_MAX_HP,
			BalanceConfig.PLAYER_ATTACK_DAMAGE,
			BalanceConfig.PLAYER_ATTACK_RANGE,
			CombatResolver.DamageType.PHYSICAL
		)
		if not grid.place_unit(unit, starts[i]):
			push_error("Failed to place player at %s" % starts[i])
			continue
		player_units.append(unit)


func _spawn_elites() -> void:
	elite1 = _spawn_one_elite(
		EliteEnemy.EliteKind.CONTROLLER,
		"E1",
		"Elite 1",
		Color(0.85, 0.25, 0.25, 1),
		BalanceConfig.ELITE1_START
	)
	elite2 = _spawn_one_elite(
		EliteEnemy.EliteKind.SUPPORT,
		"E2",
		"Elite 2",
		Color(0.55, 0.20, 0.75, 1),
		BalanceConfig.ELITE2_START
	)


func _spawn_one_elite(
	kind: EliteEnemy.EliteKind,
	id: String,
	label: String,
	color: Color,
	cell: Vector2i
) -> EliteEnemy:
	var elite := elite_scene.instantiate() as EliteEnemy
	units_root.add_child(elite)
	elite.setup_elite(kind, id, label, color, cell)
	if not grid.place_unit(elite, cell):
		push_error("Failed to place %s at %s" % [label, cell])
		elite.queue_free()
		return null
	enemy_units.append(elite)
	return elite


func _begin_round() -> void:
	if battle_over:
		return
	round_number += 1
	round_changed.emit(round_number)
	_set_phase(Phase.ROUND_START)
	for unit in player_units:
		if is_instance_valid(unit):
			unit.reset_round_actions()
	_clear_selection()
	_set_phase(Phase.BOSS_TURN)


func _set_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(phase)
	if phase == Phase.BOSS_TURN:
		call_deferred("_run_boss_turn")
	elif phase == Phase.PLAYER_PHASE:
		_mark_imprisoned_seen_for_player_phase()
	elif phase == Phase.ENEMY_PHASE:
		call_deferred("_run_enemy_phase")
	elif phase == Phase.ROUND_END:
		call_deferred("_finish_round_end")


func _mark_imprisoned_seen_for_player_phase() -> void:
	for unit in player_units:
		if is_instance_valid(unit) and not unit.is_dead():
			StatusResolver.mark_imprisoned_for_player_phase(unit)


func _run_boss_turn() -> void:
	if battle_over:
		return
	if boss == null or not is_instance_valid(boss) or boss.is_dead():
		_set_phase(Phase.PLAYER_PHASE)
		return
	_execute_boss_action()
	# Stance persists for the rest of this round; advances at ROUND_END.
	boss_telegraph_changed.emit()
	_set_phase(Phase.PLAYER_PHASE)


func _execute_boss_action() -> void:
	if boss.stance == Boss.StancePhase.PHASE_A:
		_boss_phase_a_action()
	else:
		_boss_phase_b_action()


func _boss_phase_a_action() -> void:
	var candidates: Array[Unit] = []
	for unit in player_units:
		if not is_instance_valid(unit) or unit.is_dead():
			continue
		if grid.distance_to_unit(unit.grid_pos, boss) <= 1.0:
			candidates.append(unit)
	if candidates.is_empty():
		_emit_log("Boss PHASE_A: no adjacent player — attack skipped.")
		return
	var target: Unit = candidates[randi() % candidates.size()]
	var result: Dictionary = CombatResolver.apply_damage(
		boss,
		target,
		BalanceConfig.BOSS_PHASE_A_DAMAGE,
		CombatResolver.DamageType.PHYSICAL,
		grid
	)
	_apply_attack_result(boss, target, result, CombatResolver.DamageType.PHYSICAL)


func _boss_phase_b_action() -> void:
	_emit_log("Boss PHASE_B: Global Arcane Blast!")
	# Snapshot list so deaths during the loop are safe.
	var targets: Array[Unit] = []
	for unit in player_units:
		if is_instance_valid(unit) and not unit.is_dead():
			targets.append(unit)
	for target in targets:
		var result: Dictionary = CombatResolver.apply_damage(
			boss,
			target,
			BalanceConfig.BOSS_PHASE_B_DAMAGE,
			CombatResolver.DamageType.MAGICAL,
			grid
		)
		_apply_attack_result(boss, target, result, CombatResolver.DamageType.MAGICAL)
		# Separate Burning application (once per living target; Water can block).
		if is_instance_valid(target) and not target.is_dead():
			_try_apply_burning(target, BalanceConfig.BURNING_APPLY_STACKS)


func _run_enemy_phase() -> void:
	if battle_over:
		_set_phase(Phase.ROUND_END)
		return
	_emit_log("ENEMY_PHASE: Elite 1 then Elite 2.")
	_run_elite_turn(elite1)
	_run_elite_turn(elite2)
	elite_telegraph_changed.emit()
	boss_telegraph_changed.emit()
	_set_phase(Phase.ROUND_END)


func _run_elite_turn(elite: EliteEnemy) -> void:
	if elite == null or not is_instance_valid(elite) or elite.is_dead():
		return
	match elite.elite_kind:
		EliteEnemy.EliteKind.CONTROLLER:
			_elite1_act(elite)
		EliteEnemy.EliteKind.SUPPORT:
			_elite2_act(elite)
	if is_instance_valid(elite) and not elite.is_dead():
		elite.advance_stance()


func _elite1_act(elite: EliteEnemy) -> void:
	if elite.stance == EliteEnemy.StancePhase.PHASE_A:
		_elite1_imprison(elite)
	else:
		_elite1_melee(elite)


func _elite1_imprison(elite: EliteEnemy) -> void:
	var living: Array[Unit] = _living_players()
	if living.is_empty():
		_emit_log("%s: no living players to imprison." % elite.display_name)
		return
	var target: Unit = living[randi() % living.size()]
	StatusResolver.apply_imprisoned(target)
	_emit_log("%s imprisons %s." % [elite.display_name, target.display_name])
	_emit_log("%s is Imprisoned (skills disabled next Player Phase)." % target.display_name)
	if selected_unit == target:
		selection_changed.emit(selected_unit)


func _elite1_melee(elite: EliteEnemy) -> void:
	var candidates: Array[Unit] = []
	for unit in player_units:
		if not is_instance_valid(unit) or unit.is_dead():
			continue
		if BalanceConfig.is_within_range(elite.grid_pos, unit.grid_pos, BalanceConfig.ELITE1_MELEE_RANGE):
			candidates.append(unit)
	if candidates.is_empty():
		_emit_log("%s melee: no player in range — attack skipped." % elite.display_name)
		return
	var target: Unit = candidates[randi() % candidates.size()]
	var result: Dictionary = CombatResolver.apply_damage(
		elite,
		target,
		BalanceConfig.ELITE1_MELEE_DAMAGE,
		CombatResolver.DamageType.PHYSICAL,
		grid
	)
	_apply_attack_result(elite, target, result, CombatResolver.DamageType.PHYSICAL)


func _elite2_act(elite: EliteEnemy) -> void:
	if elite.stance == EliteEnemy.StancePhase.PHASE_A:
		_elite2_ranged(elite)
	else:
		_elite2_heal_boss(elite)


func _elite2_ranged(elite: EliteEnemy) -> void:
	var target: Unit = _lowest_hp_living_player()
	if target == null:
		_emit_log("%s Arcane Shot: no living players." % elite.display_name)
		return
	var result: Dictionary = CombatResolver.apply_damage(
		elite,
		target,
		BalanceConfig.ELITE2_RANGED_DAMAGE,
		CombatResolver.DamageType.MAGICAL,
		grid
	)
	_apply_attack_result(elite, target, result, CombatResolver.DamageType.MAGICAL)


func _elite2_heal_boss(elite: EliteEnemy) -> void:
	if not is_boss_alive():
		_emit_log("%s heal: Boss is dead — heal skipped." % elite.display_name)
		return
	var amount: int = int(floor(float(boss.max_hp) * BalanceConfig.ELITE2_BOSS_HEAL_RATIO))
	if boss.hp >= boss.max_hp:
		_emit_log("Boss is already at full HP.")
		return
	var result: Dictionary = CombatResolver.apply_healing(boss, amount)
	if not result.get("ok", false):
		_emit_log("%s heal failed: %s" % [elite.display_name, str(result.get("reason", "unknown"))])
		return
	var healed: int = int(result.get("healed", 0))
	_emit_log("%s heals Boss for %d HP (now %d / %d)." % [elite.display_name, healed, boss.hp, boss.max_hp])
	boss_telegraph_changed.emit()


func _living_players() -> Array[Unit]:
	var living: Array[Unit] = []
	for unit in player_units:
		if is_instance_valid(unit) and not unit.is_dead():
			living.append(unit)
	return living


func _lowest_hp_living_player() -> Unit:
	var best: Unit = null
	for unit in _living_players():
		if best == null or unit.hp < best.hp:
			best = unit
	return best


func _finish_round_end() -> void:
	# 1-3) Burning DOT then stack decay (centralized).
	_resolve_round_end_statuses()
	# 4) Imprisoned expiry after one applicable PLAYER_PHASE
	_resolve_imprisoned_expiry()
	# 5-6) Existing ROUND_END cleanup + Boss stance flip
	if is_boss_alive():
		boss.advance_stance()
		boss_telegraph_changed.emit()
	# 7) Next round
	_begin_round()


func _resolve_imprisoned_expiry() -> void:
	for unit in player_units:
		if not is_instance_valid(unit) or unit.is_dead():
			continue
		var expire: Dictionary = StatusResolver.try_expire_imprisoned(unit)
		if expire.get("expired", false):
			_emit_log("%s is no longer Imprisoned." % unit.display_name)
			if selected_unit == unit:
				selection_changed.emit(selected_unit)


func end_player_phase() -> void:
	if current_phase != Phase.PLAYER_PHASE or battle_over:
		return
	_clear_selection()
	_set_phase(Phase.ENEMY_PHASE)


func set_action_mode(mode: ActionMode) -> void:
	if current_phase != Phase.PLAYER_PHASE or battle_over:
		return
	if selected_unit == null:
		return
	if mode == ActionMode.MOVE and selected_unit.has_moved_this_round:
		_emit_log("%s already moved this round." % selected_unit.display_name)
		return
	if (
		(mode == ActionMode.ATTACK_PHYSICAL or mode == ActionMode.ATTACK_MAGICAL)
		and selected_unit.has_attacked_this_round
	):
		_emit_log("%s already attacked this round." % selected_unit.display_name)
		return
	action_mode = mode
	action_mode_changed.emit(action_mode)
	_refresh_action_highlights()


func request_move_mode() -> void:
	set_action_mode(ActionMode.MOVE)


func request_physical_attack_mode() -> void:
	set_action_mode(ActionMode.ATTACK_PHYSICAL)


func request_magical_attack_mode() -> void:
	set_action_mode(ActionMode.ATTACK_MAGICAL)


func _on_cell_clicked(cell: Vector2i) -> void:
	if current_phase != Phase.PLAYER_PHASE or battle_over:
		return
	var unit_at := grid.get_unit_at(cell)
	if unit_at != null and unit_at.is_player:
		_select_unit(unit_at)
		return
	if selected_unit == null:
		return
	if action_mode == ActionMode.MOVE and grid.is_highlighted(cell):
		_try_move_selected(cell)
		return
	if (
		(action_mode == ActionMode.ATTACK_PHYSICAL or action_mode == ActionMode.ATTACK_MAGICAL)
		and grid.is_highlighted(cell)
	):
		_try_attack_selected(cell)
		return


func _select_unit(unit: Unit) -> void:
	if selected_unit != null and selected_unit != unit:
		selected_unit.set_selected(false)
	selected_unit = unit
	selected_unit.set_selected(true)
	selection_changed.emit(selected_unit)
	if not selected_unit.has_moved_this_round:
		action_mode = ActionMode.MOVE
	elif not selected_unit.has_attacked_this_round:
		action_mode = ActionMode.ATTACK_PHYSICAL
	else:
		action_mode = ActionMode.NONE
	action_mode_changed.emit(action_mode)
	_refresh_action_highlights()


func _refresh_action_highlights() -> void:
	grid.clear_highlights()
	_highlight_cells.clear()
	if selected_unit == null:
		return
	match action_mode:
		ActionMode.MOVE:
			if selected_unit.has_moved_this_round:
				return
			_highlight_cells = grid.get_reachable_cells(selected_unit)
			grid.set_move_highlights(_highlight_cells)
		ActionMode.ATTACK_PHYSICAL, ActionMode.ATTACK_MAGICAL:
			if selected_unit.has_attacked_this_round:
				return
			_highlight_cells = grid.get_attack_target_cells(selected_unit, true)
			grid.set_attack_highlights(_highlight_cells)
		_:
			pass


func _try_move_selected(cell: Vector2i) -> void:
	if selected_unit == null:
		return
	if selected_unit.has_moved_this_round:
		return
	if not grid.is_highlighted(cell):
		return
	if grid.move_unit(selected_unit, cell):
		selected_unit.mark_moved()
		_emit_log("%s moved to %s." % [selected_unit.display_name, str(cell)])
		_handle_post_move_terrain(selected_unit)
		if not selected_unit.has_attacked_this_round:
			action_mode = ActionMode.ATTACK_PHYSICAL
		else:
			action_mode = ActionMode.NONE
		action_mode_changed.emit(action_mode)
		_refresh_action_highlights()
		selection_changed.emit(selected_unit)


func _try_attack_selected(cell: Vector2i) -> void:
	if selected_unit == null:
		return
	if selected_unit.has_attacked_this_round:
		return
	if not grid.is_highlighted(cell):
		return
	var target := grid.get_unit_at(cell)
	if target == null or target.is_player:
		return
	var damage_type: CombatResolver.DamageType = CombatResolver.DamageType.PHYSICAL
	if action_mode == ActionMode.ATTACK_MAGICAL:
		damage_type = CombatResolver.DamageType.MAGICAL
	var result: Dictionary = CombatResolver.apply_damage(
		selected_unit,
		target,
		BalanceConfig.PLAYER_ATTACK_DAMAGE,
		damage_type,
		grid
	)
	if not result.get("ok", false):
		_emit_log("Attack failed: %s" % str(result.get("reason", "unknown")))
		return
	selected_unit.mark_attacked()
	_apply_attack_result(selected_unit, target, result, damage_type)
	if not selected_unit.has_moved_this_round:
		action_mode = ActionMode.MOVE
	else:
		action_mode = ActionMode.NONE
	action_mode_changed.emit(action_mode)
	_refresh_action_highlights()
	selection_changed.emit(selected_unit)


func _apply_attack_result(
	attacker: Unit,
	target: Unit,
	result: Dictionary,
	damage_type: CombatResolver.DamageType
) -> void:
	var type_name := CombatResolver.damage_type_name(damage_type)
	if result.get("immune", false):
		target.show_damage_popup(0, true, false)
		_emit_log(
			"%s attacked %s — IMMUNE to %s."
			% [attacker.display_name, target.display_name, type_name]
		)
		return
	_log_damage_notes(target, result)
	if result.get("holy_blocked", false):
		target.show_damage_popup(0, false, true)
		_emit_log(
			"%s attacked %s — Holy Shield blocked %s."
			% [attacker.display_name, target.display_name, type_name]
		)
		selection_changed.emit(selected_unit)
		return
	var dealt: int = int(result.get("dealt", 0))
	target.show_damage_popup(dealt, false, false)
	_emit_log(
		"%s hit %s for %d %s HP (HP %d, Shield %d)."
		% [attacker.display_name, target.display_name, dealt, type_name, target.hp, target.shield]
	)
	selection_changed.emit(selected_unit)
	if result.get("died", false):
		_handle_unit_death(target)


func _log_damage_notes(target: Unit, result: Dictionary) -> void:
	var notes: Array = result.get("notes", [])
	for note in notes:
		_emit_log("%s: %s" % [target.display_name, str(note)])


func debug_add_shield_to_selected() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	if not selected_unit.is_player:
		return
	var before: int = selected_unit.shield
	selected_unit.add_shield(BalanceConfig.TEST_SHIELD_AMOUNT)
	_emit_log(
		"%s Shield: %d -> %d (+%d TEST)."
		% [selected_unit.display_name, before, selected_unit.shield, BalanceConfig.TEST_SHIELD_AMOUNT]
	)
	selection_changed.emit(selected_unit)


func debug_grant_holy_shield_to_selected() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	if not selected_unit.is_player:
		return
	selected_unit.grant_holy_shield()
	_emit_log("%s gains Holy Shield (TEST)." % selected_unit.display_name)
	selection_changed.emit(selected_unit)


func _handle_unit_death(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var was_boss: bool = unit.is_boss
	_emit_log("%s was defeated." % unit.display_name)
	grid.remove_unit(unit)
	player_units.erase(unit)
	enemy_units.erase(unit)
	if unit == elite1:
		elite1 = null
		elite_telegraph_changed.emit()
	elif unit == elite2:
		elite2 = null
		elite_telegraph_changed.emit()
	if selected_unit == unit:
		_clear_selection()
	if was_boss:
		boss = null
		battle_over = true
		_emit_log("TEMPORARY VICTORY: Boss defeated (prototype end condition).")
		temporary_victory.emit()
		boss_telegraph_changed.emit()
	unit.queue_free()


func _clear_selection() -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = null
	action_mode = ActionMode.NONE
	_highlight_cells.clear()
	grid.clear_highlights()
	selection_changed.emit(null)
	action_mode_changed.emit(action_mode)


func _emit_log(message: String) -> void:
	combat_log_message.emit(message)


func phase_name() -> String:
	match current_phase:
		Phase.ROUND_START:
			return "ROUND_START"
		Phase.BOSS_TURN:
			return "BOSS_TURN"
		Phase.PLAYER_PHASE:
			return "PLAYER_PHASE"
		Phase.ENEMY_PHASE:
			return "ENEMY_PHASE"
		Phase.ROUND_END:
			return "ROUND_END"
	return "UNKNOWN"


func action_mode_name() -> String:
	match action_mode:
		ActionMode.MOVE:
			return "MOVE"
		ActionMode.ATTACK_PHYSICAL:
			return "ATTACK_PHYSICAL"
		ActionMode.ATTACK_MAGICAL:
			return "ATTACK_MAGICAL"
		_:
			return "NONE"


func _handle_post_move_terrain(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not grid.is_water(unit.grid_pos):
		return
	var cleanse: Dictionary = StatusResolver.cleanse_burning(unit)
	if cleanse.get("cleansed", false):
		_emit_log(
			"Water removes Burning from %s (%d -> 0)."
			% [unit.display_name, int(cleanse.get("before", 0))]
		)
		selection_changed.emit(selected_unit)


func _try_apply_burning(unit: Unit, stacks: int) -> void:
	var before: int = unit.get_burning_stacks()
	var apply_result: Dictionary = StatusResolver.try_apply_burning(unit, stacks, grid)
	if apply_result.get("blocked_by_water", false):
		_emit_log("%s is protected from Burning by Water." % unit.display_name)
		return
	if apply_result.get("applied", false):
		var after: int = int(apply_result.get("after", 0))
		_emit_log(
			"%s Burning: %d -> %d (+%d)."
			% [unit.display_name, before, after, stacks]
		)
		if selected_unit == unit:
			selection_changed.emit(selected_unit)


func _resolve_round_end_statuses() -> void:
	# Snapshot living units that may carry statuses.
	var units: Array[Unit] = []
	for unit in player_units:
		if is_instance_valid(unit) and not unit.is_dead():
			units.append(unit)
	for unit in enemy_units:
		if is_instance_valid(unit) and not unit.is_dead():
			units.append(unit)
	for unit in units:
		if not is_instance_valid(unit) or unit.is_dead():
			continue
		_resolve_burning_tick(unit)


func _resolve_burning_tick(unit: Unit) -> void:
	var stacks: int = unit.get_burning_stacks()
	if stacks <= 0:
		return
	var burn_damage: int = stacks * BalanceConfig.BURNING_DAMAGE_PER_STACK
	# Damage MUST resolve before stack reduction.
	var result: Dictionary = CombatResolver.apply_damage(
		null,
		unit,
		burn_damage,
		CombatResolver.DamageType.DIRECT,
		grid
	)
	if result.get("ok", false):
		_log_damage_notes(unit, result)
		if result.get("holy_blocked", false):
			unit.show_damage_popup(0, false, true)
			_emit_log("%s Burning tick blocked by Holy Shield." % unit.display_name)
		else:
			var dealt: int = int(result.get("dealt", 0))
			unit.show_damage_popup(dealt, false, false)
			_emit_log("%s takes %d Burning damage." % [unit.display_name, dealt])
		if result.get("died", false):
			_emit_log("%s Burning: %d -> removed (unit died)." % [unit.display_name, stacks])
			_handle_unit_death(unit)
			return
	# Then decay stacks by exactly 1.
	var new_stacks: int = stacks - 1
	if new_stacks <= 0:
		unit.clear_burning()
		_emit_log("%s Burning: %d -> 0 (removed)." % [unit.display_name, stacks])
	else:
		unit.set_burning_stacks(new_stacks)
		_emit_log("%s Burning: %d -> %d." % [unit.display_name, stacks, new_stacks])
	if selected_unit == unit:
		selection_changed.emit(selected_unit)


func is_boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and not boss.is_dead()


func is_elite_alive(elite: EliteEnemy) -> bool:
	return elite != null and is_instance_valid(elite) and not elite.is_dead()