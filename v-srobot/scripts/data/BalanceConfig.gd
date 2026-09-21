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

## Milestone 3 Boss values.
const BOSS_MAX_HP: int = 220
const BOSS_PHASE_A_DAMAGE: int = 15
const BOSS_PHASE_B_DAMAGE: int = 8
## Top-left anchor of the stationary 2x2 Boss footprint.
const BOSS_ANCHOR := Vector2i(6, 3)

## Top-left world origin of tile (0, 0). Leaves room for HUD.
const GRID_ORIGIN := Vector2(48, 96)


static func grid_to_world_top_left(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)


static func grid_to_world_center(cell: Vector2i) -> Vector2:
	return grid_to_world_top_left(cell) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


static func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - GRID_ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))


## Chebyshev distance: "within N tiles" including diagonals.
static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func footprint_2x2(anchor: Vector2i) -> Array[Vector2i]:
	return [
		anchor,
		anchor + Vector2i(1, 0),
		anchor + Vector2i(0, 1),
		anchor + Vector2i(1, 1),
	]