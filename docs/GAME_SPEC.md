---

description: Core non-negotiable development constraints for the tactical battle demo.
alwaysApply: true
-----------------

# Tactical Demo Core Rules

This is a Godot 4.x GDScript tactical battle prototype with a strict ~12-hour development budget.

Always prioritize:

playability > correctness > readability > extensibility > polish.

## Never do these without explicit approval

* Do not redesign approved gameplay rules.
* Do not expand project scope.
* Do not implement multiplayer.
* Do not implement save/load.
* Do not introduce ECS.
* Do not introduce behavior trees.
* Do not introduce dependency-injection frameworks.
* Do not create generic RPG frameworks.
* Do not perform large unrelated refactors.
* Do not replace working systems simply because another architecture is cleaner.
* Do not begin the next milestone automatically.

## Implementation rules

Use Godot 4.x and GDScript.

Keep balance values easy for the designer to edit.

Prefer simple, explicit gameplay code.

Centralize:

* damage resolution;
* grid occupancy;
* turn progression;
* status duration updates.

The Boss is one logical unit occupying a 2x2 footprint.

Never apply four copies of damage to the Boss simply because an AoE intersects four occupied Boss tiles.

After meaningful modifications:

* validate the project;
* fix parser/runtime errors caused by the change;
* provide manual Godot playtest steps.

If requirements are ambiguous, make the smallest reversible assumption and explicitly report it.

## Elite Enemy Rules (Milestone 5 — authoritative)

Turn order during ENEMY_PHASE (fixed):

1. Elite Enemy 1 acts first.
2. Elite Enemy 2 acts second.
3. Then ROUND_END.

Both elites are stationary for this prototype. Each tracks an independent two-round A/B cycle, starting in PHASE_A.

### Elite Enemy 1 — Controller / Melee

* Max HP: 50
* Melee damage: 10 PHYSICAL
* Melee range: Euclidean distance <= 1 (orthogonal adjacent only; diagonal-only is invalid)

Cycle:

* PHASE_A: Select one **random** living player. Apply Imprisoned.
  - Imprisoned blocks skill usage for exactly one applicable PLAYER_PHASE.
  - Movement and basic attacks remain available.
* PHASE_B: Deal 10 PHYSICAL to one **random valid** living player in melee range.
  - If no valid melee target exists, skip the attack.

Repeat: PHASE_A -> PHASE_B -> PHASE_A -> PHASE_B.

### Elite Enemy 2 — Ranged Magical Support

* Max HP: 50
* Ranged damage: 8 MAGICAL
* Boss heal: exactly 20% of Boss maximum HP (Boss max HP 220 => 44 HP before clamp)

Cycle:

* PHASE_A: Select one **random** living player. Deal 8 MAGICAL damage.
  - Do **not** prioritize lowest-HP targets.
* PHASE_B: Heal Boss by 20% of Boss max HP via centralized healing.
  - Cannot exceed Boss max HP.
  - Cannot revive a dead Boss; skip if Boss is already dead.
  - If Boss is already at full HP, heal safely does nothing meaningful / reports full HP.

Repeat: PHASE_A -> PHASE_B -> PHASE_A -> PHASE_B.

### Shared elite rules

* Dead elites do not act and release their grid cell.
* Elite attacks use the centralized CombatResolver (Cover / Shield / Holy Shield apply).
* Imprisoned is a status effect and is **not** blocked by Cover, Shield, Holy Shield, or Water.
* Burning is not applied by either elite.
