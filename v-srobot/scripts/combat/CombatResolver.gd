class_name CombatResolver
extends RefCounted

## Single entry point for HP damage.
## Later milestones can insert modifiers in the marked pipeline stages
## without rewriting callers.

enum DamageType {
	PHYSICAL,
	MAGICAL,
}


## Applies damage and returns a result dictionary:
## { ok, damage_type, requested, dealt, target_hp, died, immune, reason }
static func apply_damage(
	attacker: Unit,
	target: Unit,
	amount: int,
	damage_type: DamageType
) -> Dictionary:
	var result := {
		"ok": false,
		"damage_type": damage_type,
		"requested": amount,
		"dealt": 0,
		"target_hp": -1,
		"died": false,
		"immune": false,
		"reason": "",
	}

	# 1) Validate target
	if target == null or not is_instance_valid(target):
		result["reason"] = "invalid_target"
		return result
	if target.is_dead():
		result["reason"] = "target_already_dead"
		return result
	if amount <= 0:
		result["reason"] = "non_positive_damage"
		return result

	# 2) Damage type
	var final_damage: int = amount

	# 3) Immunity checks (Boss anti-magic / anti-physical)
	if target.is_immune_to_damage_type(damage_type as int):
		result["ok"] = true
		result["dealt"] = 0
		result["immune"] = true
		result["target_hp"] = target.hp
		result["died"] = false
		result["reason"] = "immune"
		return result

	# 4) FUTURE: Holy Shield
	# 5) FUTURE: attacker modifiers
	# 6) FUTURE: Vulnerable
	# 7) FUTURE: terrain mitigation (Cover)
	# 8) FUTURE: damage-type resistance
	# 9) FUTURE: normal Shield absorption

	# 10) Apply remaining damage to HP (only place that reduces HP)
	var hp_before: int = target.hp
	target.hp = maxi(0, target.hp - final_damage)
	var dealt: int = hp_before - target.hp
	target.refresh_hp_label()

	# 11) FUTURE: on-damage triggers (lifesteal) using `dealt`
	# 12) Death check
	var died: bool = target.hp <= 0

	result["ok"] = true
	result["dealt"] = dealt
	result["target_hp"] = target.hp
	result["died"] = died
	result["reason"] = "applied"
	if attacker != null:
		pass
	return result


static func damage_type_name(damage_type: DamageType) -> String:
	match damage_type:
		DamageType.PHYSICAL:
			return "PHYSICAL"
		DamageType.MAGICAL:
			return "MAGICAL"
	return "UNKNOWN"