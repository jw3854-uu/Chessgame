class_name CombatResolver
extends RefCounted

## Single entry point for HP damage.

enum DamageType {
	PHYSICAL,
	MAGICAL,
	DIRECT, ## DOT / true-style; bypasses Boss phys/mag immunity, Cover, normal Shield
}


## Pipeline order:
## 1 validate, 2 type, 3 immunity, 4 Holy Shield, 5 attacker mods (future),
## 6 Vulnerable (future), 7 Cover, 8 type resist (future), 9 Shield, 10 HP,
## 11 on-damage (future), 12 death.
##
## Cover rounding: floor(damage * 0.5).
static func apply_damage(
	attacker: Unit,
	target: Unit,
	amount: int,
	damage_type: DamageType,
	grid: GridManager = null
) -> Dictionary:
	var result := {
		"ok": false,
		"damage_type": damage_type,
		"requested": amount,
		"dealt": 0,
		"target_hp": -1,
		"died": false,
		"immune": false,
		"holy_blocked": false,
		"cover_from": -1,
		"cover_to": -1,
		"shield_absorbed": 0,
		"reason": "",
		"notes": [],
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
	var is_direct: bool = damage_type == DamageType.DIRECT

	# 3) Immunity checks (Boss anti-magic / anti-physical). DIRECT skips.
	if not is_direct and target.is_immune_to_damage_type(damage_type as int):
		result["ok"] = true
		result["dealt"] = 0
		result["immune"] = true
		result["target_hp"] = target.hp
		result["died"] = false
		result["reason"] = "immune"
		return result

	# 4) Holy Shield — blocks entire instance (PHYS/MAG/DIRECT), before Cover/Shield.
	if target.has_holy_shield():
		target.consume_holy_shield()
		result["ok"] = true
		result["dealt"] = 0
		result["holy_blocked"] = true
		result["target_hp"] = target.hp
		result["died"] = false
		result["reason"] = "holy_shield"
		result["notes"].append("Holy Shield blocks the attack.")
		if attacker != null:
			pass
		return result

	# 5) FUTURE: attacker modifiers
	# 6) FUTURE: Vulnerable

	# 7) Cover — PHYS/MAG only; floor(50%). DIRECT ignores Cover.
	if not is_direct and grid != null and grid.is_cover(target.grid_pos):
		var before_cover: int = final_damage
		final_damage = int(floor(float(final_damage) * BalanceConfig.COVER_DAMAGE_MULTIPLIER))
		result["cover_from"] = before_cover
		result["cover_to"] = final_damage
		result["notes"].append("Cover reduces %d damage to %d." % [before_cover, final_damage])

	# 8) FUTURE: damage-type resistance

	# 9) Normal Shield — PHYS/MAG only; DIRECT bypasses.
	var shield_absorbed: int = 0
	if not is_direct and target.shield > 0 and final_damage > 0:
		shield_absorbed = mini(target.shield, final_damage)
		target.shield -= shield_absorbed
		final_damage -= shield_absorbed
		result["shield_absorbed"] = shield_absorbed
		if shield_absorbed > 0:
			result["notes"].append("Shield absorbs %d damage." % shield_absorbed)

	# 10) Apply remaining damage to HP
	var hp_before: int = target.hp
	if final_damage > 0:
		target.hp = maxi(0, target.hp - final_damage)
	var dealt: int = hp_before - target.hp
	target.refresh_hp_label()
	if dealt > 0:
		result["notes"].append("%d damage reaches HP." % dealt)

	# 11) FUTURE: on-damage triggers (lifesteal)
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
		DamageType.DIRECT:
			return "DIRECT"
	return "UNKNOWN"

## Centralized healing. Clamps to max HP. Does not revive dead units.
## Returns { ok, requested, healed, target_hp, reason }
static func apply_healing(target: Unit, amount: int) -> Dictionary:
	var result := {
		"ok": false,
		"requested": amount,
		"healed": 0,
		"target_hp": -1,
		"reason": "",
	}
	if target == null or not is_instance_valid(target):
		result["reason"] = "invalid_target"
		return result
	if target.is_dead():
		result["reason"] = "target_dead"
		return result
	if amount <= 0:
		result["reason"] = "non_positive_heal"
		return result
	var before: int = target.hp
	target.hp = mini(target.max_hp, target.hp + amount)
	var healed: int = target.hp - before
	target.refresh_hp_label()
	result["ok"] = true
	result["healed"] = healed
	result["target_hp"] = target.hp
	result["reason"] = "applied"
	return result