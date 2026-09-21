class_name BattleUI
extends CanvasLayer

@export var battle_manager_path: NodePath

@onready var round_label: Label = $Panel/VBox/RoundLabel
@onready var phase_label: Label = $Panel/VBox/PhaseLabel
@onready var selection_label: Label = $Panel/VBox/SelectionLabel
@onready var mode_label: Label = $Panel/VBox/ModeLabel
@onready var combat_log_label: Label = $Panel/VBox/CombatLogLabel
@onready var move_button: Button = $Panel/VBox/ActionRow/MoveButton
@onready var phys_attack_button: Button = $Panel/VBox/ActionRow/PhysAttackButton
@onready var magic_attack_button: Button = $Panel/VBox/ActionRow/MagicAttackButton
@onready var end_phase_button: Button = $Panel/VBox/EndPlayerPhaseButton

@onready var boss_hp_label: Label = $BossPanel/VBox/BossHpLabel
@onready var boss_current_label: Label = $BossPanel/VBox/BossCurrentLabel
@onready var boss_next_label: Label = $BossPanel/VBox/BossNextLabel
@onready var victory_label: Label = $BossPanel/VBox/VictoryLabel

var battle: BattleManager


func _ready() -> void:
	battle = get_node(battle_manager_path) as BattleManager
	end_phase_button.pressed.connect(_on_end_player_phase_pressed)
	move_button.pressed.connect(_on_move_pressed)
	phys_attack_button.pressed.connect(_on_phys_attack_pressed)
	magic_attack_button.pressed.connect(_on_magic_attack_pressed)
	battle.phase_changed.connect(_on_phase_changed)
	battle.round_changed.connect(_on_round_changed)
	battle.selection_changed.connect(_on_selection_changed)
	battle.action_mode_changed.connect(_on_action_mode_changed)
	battle.combat_log_message.connect(_on_combat_log_message)
	battle.boss_telegraph_changed.connect(_on_boss_telegraph_changed)
	battle.temporary_victory.connect(_on_temporary_victory)
	_refresh()
	_refresh_boss_panel()


func _on_end_player_phase_pressed() -> void:
	battle.end_player_phase()


func _on_move_pressed() -> void:
	battle.request_move_mode()


func _on_phys_attack_pressed() -> void:
	battle.request_physical_attack_mode()


func _on_magic_attack_pressed() -> void:
	battle.request_magical_attack_mode()


func _on_phase_changed(_phase: BattleManager.Phase) -> void:
	_refresh()
	_refresh_boss_panel()


func _on_round_changed(_round_number: int) -> void:
	_refresh()


func _on_selection_changed(_unit: Unit) -> void:
	_refresh()


func _on_action_mode_changed(_mode: BattleManager.ActionMode) -> void:
	_refresh()


func _on_combat_log_message(message: String) -> void:
	combat_log_label.text = message
	_refresh()


func _on_boss_telegraph_changed() -> void:
	_refresh_boss_panel()


func _on_temporary_victory() -> void:
	victory_label.visible = true
	victory_label.text = "TEMPORARY VICTORY (prototype)"
	_refresh()
	_refresh_boss_panel()


func _refresh() -> void:
	round_label.text = "Round: %d" % battle.round_number
	phase_label.text = "Phase: %s" % battle.phase_name()
	mode_label.text = "Mode: %s" % battle.action_mode_name()
	if battle.selected_unit != null and is_instance_valid(battle.selected_unit):
		var u := battle.selected_unit
		var move_state := "moved" if u.has_moved_this_round else "can move"
		var atk_state := "attacked" if u.has_attacked_this_round else "can attack"
		selection_label.text = "Selected: %s HP %d/%d (%s, %s)" % [
			u.display_name, u.hp, u.max_hp, move_state, atk_state
		]
	else:
		selection_label.text = "Selected: none"
	var in_player := battle.current_phase == BattleManager.Phase.PLAYER_PHASE and not battle.battle_over
	end_phase_button.disabled = not in_player
	var has_sel := battle.selected_unit != null and is_instance_valid(battle.selected_unit)
	move_button.disabled = (not in_player) or (not has_sel) or battle.selected_unit.has_moved_this_round
	var can_attack := in_player and has_sel and not battle.selected_unit.has_attacked_this_round
	phys_attack_button.disabled = not can_attack
	magic_attack_button.disabled = not can_attack


func _refresh_boss_panel() -> void:
	if not battle.is_boss_alive():
		boss_hp_label.text = "Boss HP: defeated"
		boss_current_label.text = "Current: -"
		boss_next_label.text = "Next: -"
		return
	var b: Boss = battle.boss
	boss_hp_label.text = "Boss HP: %d / %d" % [b.hp, b.max_hp]
	boss_current_label.text = "Current: %s | %s | Action: %s" % [
		b.stance_title(b.stance),
		b.immunity_text(b.stance),
		b.action_text(b.stance),
	]
	var nxt: Boss.StancePhase = b.next_stance()
	boss_next_label.text = "Next: %s | %s | Action: %s" % [
		b.stance_title(nxt),
		b.immunity_text(nxt),
		b.action_text(nxt),
	]