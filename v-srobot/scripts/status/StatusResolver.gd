class_name StatusResolver
extends RefCounted

## Centralized Burning apply / tick helpers.
## Callers must still route HP changes through CombatResolver.


## Attempts to add Burning stacks. Water blocks application entirely.
## Returns { applied, blocked_by_water, before, after }
static func try_apply_burning(unit: Unit, stacks_to_add: int, grid: GridManager) -> Dictionary:
	var result := {
		"applied": false,
		"blocked_by_water": false,
		"before": 0,
		"after": 0,
	}
	if unit == null or not is_instance_valid(unit) or unit.is_dead():
		return result
	if stacks_to_add <= 0:
		return result
	result["before"] = unit.get_burning_stacks()
	# Boss ignores Water protection.
	if grid != null and grid.is_water(unit.grid_pos) and not unit.is_boss:
		result["blocked_by_water"] = true
		result["after"] = result["before"]
		return result
	result["after"] = unit.add_burning_stacks(stacks_to_add)
	result["applied"] = true
	return result


## Removes Burning immediately (e.g. entering Water).
## Returns { cleansed, before }
static func cleanse_burning(unit: Unit) -> Dictionary:
	var result := {"cleansed": false, "before": 0}
	if unit == null or not is_instance_valid(unit):
		return result
	result["before"] = unit.get_burning_stacks()
	if result["before"] <= 0:
		return result
	unit.clear_burning()
	result["cleansed"] = true
	return result

## Applies Imprisoned. Does NOT go through the damage pipeline.
## Timing: applied during ENEMY_PHASE; active for the next PLAYER_PHASE;
## expires at ROUND_END after that PLAYER_PHASE has been seen.
## Returns { applied, refreshed }
static func apply_imprisoned(unit: Unit) -> Dictionary:
	var result := {"applied": false, "refreshed": false}
	if unit == null or not is_instance_valid(unit) or unit.is_dead():
		return result
	result["refreshed"] = unit.has_imprisoned()
	unit.apply_imprisoned()
	result["applied"] = true
	return result


## Call when entering PLAYER_PHASE so Imprisoned lasts exactly one applicable player turn.
static func mark_imprisoned_for_player_phase(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_dead():
		return
	if unit.has_imprisoned():
		unit.mark_imprisoned_seen_player_phase()


## Expires Imprisoned only after it has affected one PLAYER_PHASE.
## Returns { expired }
static func try_expire_imprisoned(unit: Unit) -> Dictionary:
	var result := {"expired": false}
	if unit == null or not is_instance_valid(unit):
		return result
	if not unit.has_imprisoned():
		return result
	if not unit.imprisoned_seen_player_phase():
		return result
	unit.clear_imprisoned()
	result["expired"] = true
	return result