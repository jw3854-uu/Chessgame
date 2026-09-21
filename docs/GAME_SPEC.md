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

---

## Battlefield Layout (Milestone 5.5 — authoritative)

Grid: 12 columns x 9 rows. Top-left = (0,0). x right, y down.

### Player starts

* P1 (2,6), P2 (1,7), P3 (2,8), P4 (3,7)

### Boss

* Anchor (8,1); footprint (8,1)(9,1)(8,2)(9,2)

### Elites

* Elite 1 (9,5) — Max HP 50, Move 4
* Elite 2 (4,1) — Max HP 50, Move 4

### Water (8)

(10,1), (0,2), (3,2), (7,2), (1,4), (7,6), (10,7), (5,8)

### Cover (8)

(2,0), (6,1), (10,2), (9,3), (3,4), (4,5), (0,6), (11,8)

### Obstacle (5)

(9,0), (1,2), (4,3), (7,5), (7,8)

All other cells are NORMAL.

### Terrain rules

* NORMAL: walkable
* WATER: walkable; prevents/cleanses Burning for players/elites (not Boss)
* COVER: walkable; 50% damage reduction (floor) for players/elites (not Boss)
* OBSTACLE: not walkable/occupiable by players, elites, or Boss; does NOT block ranged attacks or LOS (no LOS system)

---

## Turn Order

ROUND_START -> BOSS_TURN -> PLAYER_PHASE -> ENEMY_PHASE -> ROUND_END

ENEMY_PHASE: Elite 1 then Elite 2.

Boss turn: move toward nearest living player (up to 4 grid steps), then act.

---

## Elite Enemy Rules

### Elite 1 — Controller / Melee

* PHASE_A: Imprison one **random** living player (no movement required)
* PHASE_B: move toward nearest living player (BFS, Move 4), then 10 PHYSICAL if Euclidean melee <= 1; else skip attack

### Elite 2 — Ranged Support

* PHASE_A: 8 MAGICAL to one **random** living player (no lowest-HP priority); stationary
* PHASE_B: heal Boss 20% max HP (44), clamp to max; skip if Boss dead

---

## Boss Stance Cycle

* R1 A, R2 B, R3 A, R4 SPECIAL (enhanced B, once), R5 A, R6 B, ... alternating

Round 4 SPECIAL replaces that round's PHASE_B. After Round 4, resume PHASE_A.

### PHASE_A

Magic immune. Move then 15 PHYSICAL to random Euclidean-adjacent player (range <= 1 from footprint).

### PHASE_B

Physical immune. Move then 8 MAGICAL to all living players + 3 Burning.

### Round 3 Warning

Once at start of Round 3 PLAYER_PHASE: warn that Round 4 Overload is coming.

### Round 4 OVERLOAD (exactly once; NOT round % 4)

Physical immune. Move then:

1. 10 MAGICAL to all living players
2. +4 Burning (Water still blocks)
3. Destroy up to 4 Water (random, no replacement)
4. Destroy up to 4 Cover (random, no replacement)

Destroyed terrain -> NORMAL. Occupied tiles may be destroyed; units stay put.

### Round 5+ ENRAGE (permanent)

* Boss active attack damage x1.5 (floor), attacker-side before Cover
* At every ROUND_START: Boss loses exactly 20 HP (unconditional; can kill Boss before acting)
* Does not multiply Burning, self-damage, elite damage, or healing

### Damage pipeline order

1. Base damage
2. Attacker modifiers (Enrage) + floor
3. Target Vulnerable (future)
4. Cover + floor (Boss targets ignore Cover)
5. Type resist (future)
6. Shield
7. HP
8. Death

Holy Shield remains higher priority (blocks whole instance).

### Boss movement

Move 4. Target nearest living player by Euclidean distance to footprint (ties random). Cardinal BFS anchors; entire 2x2 must be legal (in bounds, no Obstacle, no other units). May occupy Water/Cover without receiving their benefits.

---

## Elite Enemy Rules (Milestone 5 retained)

Imprisoned: blocks skills for one applicable PLAYER_PHASE; movement and basic attacks remain. Not blocked by Cover/Shield/Holy/Water.

Dead elites do not act. Elite attacks use CombatResolver.