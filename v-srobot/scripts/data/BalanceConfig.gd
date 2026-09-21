class_name BalanceConfig
extends RefCounted

## Designer-facing tunables for the tactical prototype.

const GRID_COLUMNS: int = 12
const GRID_ROWS: int = 9
const TILE_SIZE: int = 64

const PLAYER_MOVE_RANGE: int = 4
const PLAYER_MAX_HP: int = 30
const PLAYER_ATTACK_DAMAGE: int = 8
const PLAYER_ATTACK_RANGE: int = 2

const ENEMY_MAX_HP: int = 20

## Milestone 5 / 5.5 Elites
const ELITE1_MAX_HP: int = 50
const ELITE1_MELEE_DAMAGE: int = 10
const ELITE1_MELEE_RANGE: float = 1.0
const ELITE2_MAX_HP: int = 50
const ELITE2_RANGED_DAMAGE: int = 8
const ELITE2_BOSS_HEAL_RATIO: float = 0.20
const ELITE_MOVE_RANGE: int = 4
const ELITE1_START := Vector2i(9, 5)
const ELITE2_START := Vector2i(4, 1)

## Boss
const BOSS_MAX_HP: int = 220
const BOSS_MOVE_RANGE: int = 4
const BOSS_PHASE_A_DAMAGE: int = 15
const BOSS_PHASE_B_DAMAGE: int = 8
const BOSS_OVERLOAD_DAMAGE: int = 10
const BOSS_OVERLOAD_BURNING_STACKS: int = 4
const BOSS_ENRAGE_DAMAGE_MULT: float = 1.5
const BOSS_ENRAGE_SELF_DAMAGE: int = 20
const BOSS_ENRAGE_START_ROUND: int = 5
const BOSS_OVERLOAD_ROUND: int = 4
const BOSS_OVERLOAD_WARNING_ROUND: int = 3
const BOSS_OVERLOAD_TERRAIN_DESTROY_COUNT: int = 4
const BOSS_ANCHOR := Vector2i(8, 1)

const PLAYER_STARTS: Array[Vector2i] = [
	Vector2i(2, 6),
	Vector2i(1, 7),
	Vector2i(2, 8),
	Vector2i(3, 7),
]

const BURNING_APPLY_STACKS: int = 3
const BURNING_DAMAGE_PER_STACK: int = 1

const COVER_DAMAGE_MULTIPLIER: float = 0.5
const TEST_SHIELD_AMOUNT: int = 5

const GRID_ORIGIN := Vector2(48, 96)

## Final Milestone 5.5 battlefield terrain (authoritative).
const WATER_CELLS: Array[Vector2i] = [
	Vector2i(10, 1),
	Vector2i(0, 2),
	Vector2i(3, 2),
	Vector2i(7, 2),
	Vector2i(1, 4),
	Vector2i(7, 6),
	Vector2i(10, 7),
	Vector2i(5, 8),
]

const COVER_CELLS: Array[Vector2i] = [
	Vector2i(2, 0),
	Vector2i(6, 1),
	Vector2i(10, 2),
	Vector2i(9, 3),
	Vector2i(3, 4),
	Vector2i(4, 5),
	Vector2i(0, 6),
	Vector2i(11, 8),
]

const OBSTACLE_CELLS: Array[Vector2i] = [
	Vector2i(9, 0),
	Vector2i(1, 2),
	Vector2i(4, 3),
	Vector2i(7, 5),
	Vector2i(7, 8),
]


static func grid_to_world_top_left(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)


static func grid_to_world_center(cell: Vector2i) -> Vector2:
	return grid_to_world_top_left(cell) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - GRID_ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))


static func grid_distance(a: Vector2i, b: Vector2i) -> float:
	var dx: float = float(a.x - b.x)
	var dy: float = float(a.y - b.y)
	return sqrt(dx * dx + dy * dy)


static func is_within_range(source: Vector2i, target: Vector2i, allowed_range: float) -> bool:
	return grid_distance(source, target) <= allowed_range


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