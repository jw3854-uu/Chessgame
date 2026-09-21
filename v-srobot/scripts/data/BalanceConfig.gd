class_name BalanceConfig
extends RefCounted

## Designer-facing tunables for the tactical prototype.

const GRID_COLUMNS: int = 12
const GRID_ROWS: int = 9
const TILE_SIZE: int = 64

## Temporary placeholder movement for player units.
const PLAYER_MOVE_RANGE: int = 4

## Milestone 2 temporary combat values.
const PLAYER_MAX_HP: int = 30
const PLAYER_ATTACK_DAMAGE: int = 8
const PLAYER_ATTACK_RANGE: int = 2

const ENEMY_MAX_HP: int = 20

## Milestone 5 Elite enemies (stationary placeholders).
const ELITE1_MAX_HP: int = 50
const ELITE1_MELEE_DAMAGE: int = 10
const ELITE1_MELEE_RANGE: float = 1.0
const ELITE2_MAX_HP: int = 50
const ELITE2_RANGED_DAMAGE: int = 8
## Heal amount = floor(Boss max HP * this ratio). With BOSS_MAX_HP 220 => 44.
const ELITE2_BOSS_HEAL_RATIO: float = 0.20
const ELITE1_START := Vector2i(5, 5)
const ELITE2_START := Vector2i(10, 2)

## Milestone 3 Boss values.
const BOSS_MAX_HP: int = 220
const BOSS_PHASE_A_DAMAGE: int = 15
const BOSS_PHASE_B_DAMAGE: int = 8
## Top-left anchor of the stationary 2x2 Boss footprint.
const BOSS_ANCHOR := Vector2i(6, 3)

## Milestone 4A Burning.
const BURNING_APPLY_STACKS: int = 3
## Each stack deals this much DIRECT damage at ROUND_END before decaying by 1.
const BURNING_DAMAGE_PER_STACK: int = 1

## Milestone 4B Cover / Shield.
const COVER_DAMAGE_MULTIPLIER: float = 0.5
const TEST_SHIELD_AMOUNT: int = 5

## Top-left world origin of tile (0, 0). Leaves room for HUD / right panel.
const GRID_ORIGIN := Vector2(48, 96)

## Temporary test Water cluster (reachable, outside Boss footprint).
const TEST_WATER_CELLS: Array[Vector2i] = [
	Vector2i(3, 2),
	Vector2i(4, 2),
	Vector2i(3, 3),
	Vector2i(4, 3),
	Vector2i(3, 4),
]

## Temporary Cover cluster (away from Water and Boss footprint).
const TEST_COVER_CELLS: Array[Vector2i] = [
	Vector2i(8, 6),
	Vector2i(9, 6),
	Vector2i(8, 7),
	Vector2i(9, 7),
]


static func grid_to_world_top_left(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)


static func grid_to_world_center(cell: Vector2i) -> Vector2:
	return grid_to_world_top_left(cell) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - GRID_ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))


## Euclidean grid distance for RANGE / targeting checks (not movement path cost).
static func grid_distance(a: Vector2i, b: Vector2i) -> float:
	var dx: float = float(a.x - b.x)
	var dy: float = float(a.y - b.y)
	return sqrt(dx * dx + dy * dy)


static func is_within_range(source: Vector2i, target: Vector2i, allowed_range: float) -> bool:
	return grid_distance(source, target) <= allowed_range


## Minimum Euclidean distance from a cell to any cell in a footprint.
static func distance_to_footprint(cell: Vector2i, footprint_cells: Array) -> float:
	var best: float = INF
	for other in footprint_cells:
		var other_cell: Vector2i = other as Vector2i
		best = minf(best, grid_distance(cell, other_cell))
	return best


static func footprint_2x2(anchor: Vector2i) -> Array[Vector2i]:
	return [
		anchor,
		anchor + Vector2i(1, 0),
		anchor + Vector2i(0, 1),
		anchor + Vector2i(1, 1),
	]