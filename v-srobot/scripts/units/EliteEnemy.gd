class_name EliteEnemy
extends Unit

enum EliteKind {
	CONTROLLER, ## Elite 1
	SUPPORT, ## Elite 2
}

enum StancePhase {
	PHASE_A,
	PHASE_B,
}

var elite_kind: EliteKind = EliteKind.CONTROLLER
var stance: StancePhase = StancePhase.PHASE_A


func setup_elite(kind: EliteKind, id: String, label: String, color: Color, cell: Vector2i) -> void:
	elite_kind = kind
	is_player = false
	is_boss = false
	stance = StancePhase.PHASE_A
	move_range = 0
	setup(id, label, color)
	match kind:
		EliteKind.CONTROLLER:
			setup_combat_stats(
				BalanceConfig.ELITE1_MAX_HP,
				BalanceConfig.ELITE1_MELEE_DAMAGE,
				1,
				CombatResolver.DamageType.PHYSICAL
			)
		EliteKind.SUPPORT:
			setup_combat_stats(
				BalanceConfig.ELITE2_MAX_HP,
				BalanceConfig.ELITE2_RANGED_DAMAGE,
				99,
				CombatResolver.DamageType.MAGICAL
			)
	grid_pos = cell


func advance_stance() -> void:
	if stance == StancePhase.PHASE_A:
		stance = StancePhase.PHASE_B
	else:
		stance = StancePhase.PHASE_A


func next_stance() -> StancePhase:
	if stance == StancePhase.PHASE_A:
		return StancePhase.PHASE_B
	return StancePhase.PHASE_A


func current_action_text() -> String:
	return action_text_for(stance)


func next_action_text() -> String:
	return action_text_for(next_stance())


func action_text_for(p_stance: StancePhase) -> String:
	match elite_kind:
		EliteKind.CONTROLLER:
			if p_stance == StancePhase.PHASE_A:
				return "Imprison (random player)"
			return "Melee Strike (10 PHYS, range 1)"
		EliteKind.SUPPORT:
			if p_stance == StancePhase.PHASE_A:
				return "Arcane Shot (8 MAG, random player)"
			return "Heal Boss (+20% max HP)"
	return "Unknown"