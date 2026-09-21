class_name BattleUI
extends CanvasLayer

@export var battle_manager_path: NodePath

@onready var round_label: Label = $Root/RightPanel/Margin/VBox/RoundLabel
@onready var phase_label: Label = $Root/RightPanel/Margin/VBox/PhaseLabel
@onready var boss_hp_label: Label = $Root/RightPanel/Margin/VBox/BossHpLabel
@onready var boss_current_label: Label = $Root/RightPanel/Margin/VBox/BossCurrentLabel
@onready var boss_next_label: Label = $Root/RightPanel/Margin/VBox/BossNextLabel
@onready var elite1_label: Label = $Root/RightPanel/Margin/VBox/Elite1Label
@onready var elite2_label: Label = $Root/RightPanel/Margin/VBox/Elite2Label
@onready var selection_label: Label = $Root/RightPanel/Margin/VBox/SelectionLabel
@onready var status_label: Label = $Root/RightPanel/Margin/VBox/StatusLabel
@onready var mode_label: Label = $Root/RightPanel/Margin/VBox/ModeLabel
@onready var combat_log_label: Label = $Root/RightPanel/Margin/VBox/CombatLogLabel
@onready var move_button: Button = $Root/RightPanel/Margin/VBox/ActionRow/MoveButton
@onready var phys_attack_button: Button = $Root/RightPanel/Margin/VBox/ActionRow/PhysAttackButton
@onready var magic_attack_button: Button = $Root/RightPanel/Margin/VBox/ActionRow/MagicAttackButton
@onready var test_shield_button: Button = $Root/RightPanel/Margin/VBox/TestRow/TestShieldButton
@onready var test_holy_button: Button = $Root/RightPanel/Margin/VBox/TestRow/TestHolyButton
@onready var end_phase_button: Button = $Root/RightPanel/Margin/VBox/EndPlayerPhaseButton
@onready var victory_label: Label = $Root/RightPanel/Margin/VBox/VictoryLabel

var battle: BattleManager


func _ready() -> void:
	battle = get_node(battle_manager_path) as BattleManager
	end_phase_button.pressed.connect(_on_end_player_phase_pressed)
	move_button.pressed.connect(_on_move_pressed)
	phys_attack_button.pressed.connect(_on_phys_attack_pressed)
	magic_attack_button.pressed.connect(_on_magic_attack_pressed)
	test_shield_button.pressed.connect(_on_test_shield_pressed)
	test_holy_button.pressed.connect(_on_test_holy_pressed)
	battle.phase_changed.connect(_on_phase_changed)
	battle.round_changed.connect(_on_round_changed)
	battle.selection_changed.connect(_on_selection_changed)
	battle.action_mode_changed.connect(_on_action_mode_changed)
	battle.combat_log_message.connect(_on_combat_log_message)
	battle.boss_telegraph_changed.connect(_on_boss_telegraph_changed)
	battle.elite_telegraph_changed.connect(_on_elite_telegraph_changed)
	battle.temporary_victory.connect(_on_temporary_victory)
	_refresh()
	_refresh_boss_panel()
	_refresh_elite_panel()


func _on_end_player_phase_pressed() -> void:
	battle.end_player_phase()


func _on_move_pressed() -> void:
	battle.request_move_mode()


func _on_phys_attack_pressed() -> void:
	battle.request_physical_attack_mode()


func _on_magic_attack_pressed() -> void:
	battle.request_magical_attack_mode()


func _on_test_shield_pressed() -> void:
	battle.debug_add_shield_to_selected()


func _on_test_holy_pressed() -> void:
	battle.debug_grant_holy_shield_to_selected()


func _on_phase_changed(_phase: BattleManager.Phase) -> void:
	_refresh()
	_refresh_boss_panel()
	_refresh_elite_panel()


func _on_round_changed(_round_number: int) -> void:
	_refresh()


func _on_selection_changed(_unit: Unit) -> void:
	_refresh()


func _on_action_mode_changed(_mode: BattleManager.ActionMode) -> void:
	_refresh()


func _on_combat_log_message(message: String) -> void:
	combat_log_label.text = "Log: %s" % message
	_refresh()
	_refresh_boss_panel()
	_refresh_elite_panel()


func _on_boss_telegraph_changed() -> void:
	_refresh_boss_panel()


func _on_elite_telegraph_changed() -> void:
	_refresh_elite_panel()


func _on_temporary_victory() -> void:
	victory_label.visible = true
	victory_label.text = "TEMPORARY VICTORY (prototype)"
	_refresh()
	_refresh_boss_panel()
	_refresh_elite_panel()


func _refresh() -> void:
	round_label.text = "Round: %d" % battle.round_number
	phase_label.text = "Phase: %s" % battle.phase_name()
	mode_label.text = "Mode: %s" % battle.action_mode_name()
	if battle.selected_unit != null and is_instance_valid(battle.selected_unit):
		var u := battle.selected_unit
		var move_state := "moved" if u.has_moved_this_round else "can move"
		var atk_state := "attacked" if u.has_attacked_this_round else "can attack"
		var terrain_name := "NORMAL"
		if battle.grid != null:
			terrain_name = battle.grid.terrain_name(u.grid_pos)
		var holy_text := "Active" if u.has_holy_shield() else "None"
		var skills_text := "Disabled" if not u.can_use_skills() else "Allowed"
		selection_label.text = (
			"Selected: %s\nHP: %d / %d\nShield: %d\nHoly Shield: %s\nSkills: %s\nTerrain: %s\nMove: %s\nAttack: %s"
			% [u.display_name, u.hp, u.max_hp, u.shield, holy_text, skills_text, terrain_name, move_state, atk_state]
		)
		var status_parts: Array[String] = []
		var imprison_text := u.imprisoned_ui_text()
		if imprison_text != "":
			status_parts.append(imprison_text)
		var burn_text := u.burning_ui_text()
		if burn_text != "":
			status_parts.append(burn_text)
		if status_parts.is_empty():
			status_label.text = "Statuses: none"
		else:
			status_label.text = "Statuses:\n" + "\n".join(status_parts)
	else:
		selection_label.text = "Selected: none"
		status_label.text = "Statuses: -"
	var in_player := battle.current_phase == BattleManager.Phase.PLAYER_PHASE and not battle.battle_over
	end_phase_button.disabled = not in_player
	var has_sel := battle.selected_unit != null and is_instance_valid(battle.selected_unit)
	move_button.disabled = (not in_player) or (not has_sel) or battle.selected_unit.has_moved_this_round
	var can_attack := in_player and has_sel and not battle.selected_unit.has_attacked_this_round
	phys_attack_button.disabled = not can_attack
	magic_attack_button.disabled = not can_attack
	test_shield_button.disabled = (not in_player) or (not has_sel)
	test_holy_button.disabled = (not in_player) or (not has_sel)


func _refresh_boss_panel() -> void:
	if not battle.is_boss_alive():
		boss_hp_label.text = "Boss HP: defeated"
		boss_current_label.text = "Current stance: -"
		boss_next_label.text = "Next stance: -"
		return
	var b: Boss = battle.boss
	boss_hp_label.text = "Boss HP: %d / %d" % [b.hp, b.max_hp]
	boss_current_label.text = "Current: %s\n%s\nAction: %s" % [
		b.stance_title(b.stance),
		b.immunity_text(b.stance),
		b.action_text(b.stance),
	]
	var nxt: Boss.StancePhase = b.next_stance()
	boss_next_label.text = "Next (after ROUND_END): %s\n%s\nAction: %s" % [
		b.stance_title(nxt),
		b.immunity_text(nxt),
		b.action_text(nxt),
	]


func _refresh_elite_panel() -> void:
	elite1_label.text = _format_elite_block(battle.elite1, "Elite 1")
	elite2_label.text = _format_elite_block(battle.elite2, "Elite 2")


func _format_elite_block(elite: EliteEnemy, fallback_name: String) -> String:
	if elite == null or not is_instance_valid(elite) or elite.is_dead():
		return "%s: defeated" % fallback_name
	return "%s\nHP: %d / %d\nPhase: %s\nNext: %s" % [
		elite.display_name,
		elite.hp,
		elite.max_hp,
		"A" if elite.stance == EliteEnemy.StancePhase.PHASE_A else "B",
		elite.current_action_text(),
	]