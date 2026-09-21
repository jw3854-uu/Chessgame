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
