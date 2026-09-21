class_name GridManager
extends Node2D

signal cell_clicked(cell: Vector2i)
signal terrain_changed

enum TerrainType {
	NORMAL,
	WATER,
	COVER,
	OBSTACLE,
}

const TILE_COLOR_A := Color(0.30, 0.32, 0.35, 1)
const TILE_COLOR_B := Color(0.36, 0.38, 0.41, 1)
const WATER_COLOR := Color(0.45, 0.85, 0.95, 1)
const COVER_COLOR := Color(0.92, 0.94, 0.96, 1)
const OBSTACLE_COLOR := Color(0.45, 0.28, 0.14, 1)
const MOVE_HIGHLIGHT_COLOR := Color(0.25, 0.85, 0.45, 0.45)
const ATTACK_HIGHLIGHT_COLOR := Color(0.95, 0.25, 0.2, 0.5)

var occupancy: Dictionary = {}
var terrain_by_cell: Dictionary = {}

var _tiles: Dictionary = {}
var _highlights: Dictionary = {}
var _highlight_layer: Node2D
var _tile_layer: Node2D


func _ready() -> void:
	_tile_layer = Node2D.new()
	_tile_layer.name = "TileLayer"
	add_child(_tile_layer)
	_highlight_layer = Node2D.new()
	_highlight_layer.name = "HighlightLayer"
	add_child(_highlight_layer)
	_build_grid()
	_apply_battlefield_terrain()


func _build_grid() -> void:
	for y in BalanceConfig.GRID_ROWS:
		for x in BalanceConfig.GRID_COLUMNS:
			var cell := Vector2i(x, y)
			terrain_by_cell[cell] = TerrainType.NORMAL
			var tile := ColorRect.new()
			tile.size = Vector2(BalanceConfig.TILE_SIZE - 2, BalanceConfig.TILE_SIZE - 2)
			tile.position = BalanceConfig.grid_to_world_top_left(cell) + Vector2(1, 1)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var checker: bool = ((x + y) % 2) == 0
			tile.color = TILE_COLOR_A if checker else TILE_COLOR_B
			_tile_layer.add_child(tile)
			_tiles[cell] = tile


func _apply_battlefield_terrain() -> void:
	for cell in BalanceConfig.WATER_CELLS:
		set_terrain(cell, TerrainType.WATER)
	for cell in BalanceConfig.COVER_CELLS:
		set_terrain(cell, TerrainType.COVER)
	for cell in BalanceConfig.OBSTACLE_CELLS:
		set_terrain(cell, TerrainType.OBSTACLE)


func set_terrain(cell: Vector2i, terrain: TerrainType) -> void:
	if not is_in_bounds(cell):
		return
	terrain_by_cell[cell] = terrain
	_refresh_tile_visual(cell)
	terrain_changed.emit()


func get_terrain(cell: Vector2i) -> TerrainType:
	return int(terrain_by_cell.get(cell, TerrainType.NORMAL)) as TerrainType


func is_water(cell: Vector2i) -> bool:
	return get_terrain(cell) == TerrainType.WATER


func is_cover(cell: Vector2i) -> bool:
	return get_terrain(cell) == TerrainType.COVER


func is_obstacle(cell: Vector2i) -> bool:
	return get_terrain(cell) == TerrainType.OBSTACLE


func terrain_name(cell: Vector2i) -> String:
	match get_terrain(cell):
		TerrainType.WATER:
			return "WATER"
		TerrainType.COVER:
			return "COVER"
		TerrainType.OBSTACLE:
			return "OBSTACLE"
		_:
			return "NORMAL"


func get_cells_of_terrain(terrain: TerrainType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in terrain_by_cell.keys():
		if get_terrain(cell) == terrain:
			result.append(cell)
	return result


func destroy_terrain_to_normal(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var current: TerrainType = get_terrain(cell)
	if current != TerrainType.WATER and current != TerrainType.COVER:
		return false
	set_terrain(cell, TerrainType.NORMAL)
	return true


func _refresh_tile_visual(cell: Vector2i) -> void:
	if not _tiles.has(cell):
		return
	var tile: ColorRect = _tiles[cell]
	match get_terrain(cell):
		TerrainType.WATER:
			tile.color = WATER_COLOR
		TerrainType.COVER:
			tile.color = COVER_COLOR
		TerrainType.OBSTACLE:
			tile.color = OBSTACLE_COLOR
		_:
			var checker: bool = ((cell.x + cell.y) % 2) == 0
			tile.color = TILE_COLOR_A if checker else TILE_COLOR_B


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var cell := BalanceConfig.world_to_grid(get_global_mouse_position())
			if is_in_bounds(cell):
				cell_clicked.emit(cell)
				get_viewport().set_input_as_handled()


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BalanceConfig.GRID_COLUMNS and cell.y < BalanceConfig.GRID_ROWS


func get_unit_at(cell: Vector2i) -> Unit:
	return occupancy.get(cell, null) as Unit


func is_occupied(cell: Vector2i) -> bool:
	return occupancy.has(cell)


## Walkable for 1-tile units (players / elites). Obstacles block.
func is_walkable_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if is_obstacle(cell):
		return false
	return true


func place_unit(unit: Unit, cell: Vector2i) -> bool:
	if unit != null and unit.is_boss:
		return place_boss(unit, cell)
	if not is_walkable_cell(cell):
		push_error("place_unit blocked/out of bounds: %s" % cell)
		return false
	if is_occupied(cell):
		push_error("place_unit target occupied: %s" % cell)
		return false
	occupancy[cell] = unit
	unit.set_grid_pos(cell)
	return true


func can_boss_occupy_anchor(boss: Unit, anchor: Vector2i) -> bool:
	var cells: Array[Vector2i] = BalanceConfig.footprint_2x2(anchor)
	for cell in cells:
		if not is_in_bounds(cell):
			return false
		if is_obstacle(cell):
			return false
		var occupant: Unit = get_unit_at(cell)
		if occupant != null and occupant != boss:
			return false
	return true


func place_boss(boss: Unit, anchor: Vector2i) -> bool:
	if not can_boss_occupy_anchor(boss, anchor):
		push_error("place_boss invalid at %s" % anchor)
		return false
	var cells: Array[Vector2i] = BalanceConfig.footprint_2x2(anchor)
	for cell in cells:
		occupancy[cell] = boss
	boss.set_grid_pos(anchor)
	return true


func move_unit(unit: Unit, to_cell: Vector2i) -> bool:
	if unit != null and unit.is_boss:
		return move_boss(unit as Boss, to_cell)
	if not is_walkable_cell(to_cell):
		return false
	if is_occupied(to_cell):
		return false
	if not occupancy.has(unit.grid_pos) or occupancy[unit.grid_pos] != unit:
		push_error("move_unit occupancy mismatch for %s" % unit.unit_id)
		return false
	occupancy.erase(unit.grid_pos)
	occupancy[to_cell] = unit
	unit.set_grid_pos(to_cell)
	return true


func move_boss(boss: Boss, new_anchor: Vector2i) -> bool:
	if boss == null:
		return false
	if new_anchor == boss.anchor_cell:
		return true
	if not can_boss_occupy_anchor(boss, new_anchor):
		return false
	remove_unit(boss)
	return place_boss(boss, new_anchor)


func remove_unit(unit: Unit) -> void:
	if unit == null:
		return
	var stale: Array[Vector2i] = []
	for cell in occupancy.keys():
		if occupancy[cell] == unit:
			stale.append(cell)
	for cell in stale:
		occupancy.erase(cell)


func distance_to_unit(from_cell: Vector2i, unit: Unit) -> float:
	if unit == null:
		return INF
	return BalanceConfig.distance_to_footprint(from_cell, unit.get_occupied_cells())


## Cardinal BFS reachability for 1-tile units. Obstacles and foreign occupancy block.
func get_reachable_cells(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
	var max_range: int = unit.move_range
	var start: Vector2i = unit.grid_pos
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append({"cell": start, "dist": 0})
	visited[start] = true
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var cell: Vector2i = item["cell"]
		var dist: int = item["dist"]
		if cell != start:
			result.append(cell)
		if dist >= max_range:
			continue
		for dir in dirs:
			var next: Vector2i = cell + dir
			if visited.has(next):
				continue
			if not is_walkable_cell(next):
				continue
			if is_occupied(next) and get_unit_at(next) != unit:
				continue
			visited[next] = true
			queue.append({"cell": next, "dist": dist + 1})
	return result


## Cardinal BFS of legal Boss anchors within move_range (footprint-validated).
func get_reachable_boss_anchors(boss: Boss) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if boss == null:
		return result
	var max_range: int = boss.move_range
	var start: Vector2i = boss.anchor_cell
	var visited: Dictionary = {}
	var queue: Array = []
	queue.append({"cell": start, "dist": 0})
	visited[start] = true
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var cell: Vector2i = item["cell"]
		var dist: int = item["dist"]
		if cell != start:
			result.append(cell)
		if dist >= max_range:
			continue
		for dir in dirs:
			var next: Vector2i = cell + dir
			if visited.has(next):
				continue
			if not can_boss_occupy_anchor(boss, next):
				continue
			visited[next] = true
			queue.append({"cell": next, "dist": dist + 1})
	return result


## Among reachable cells, pick one minimizing Euclidean distance to target cell.
func pick_move_toward_cell(unit: Unit, target_cell: Vector2i) -> Vector2i:
	if unit == null:
		return Vector2i.ZERO
	var best: Vector2i = unit.grid_pos
	var best_dist: float = BalanceConfig.grid_distance(unit.grid_pos, target_cell)
	for cell in get_reachable_cells(unit):
		var d: float = BalanceConfig.grid_distance(cell, target_cell)
		if d < best_dist:
			best_dist = d
			best = cell
	return best


## Among reachable Boss anchors, minimize Euclidean distance from footprint to target.
func pick_boss_anchor_toward(boss: Boss, target_cell: Vector2i) -> Vector2i:
	if boss == null:
		return Vector2i.ZERO
	var best: Vector2i = boss.anchor_cell
	var best_dist: float = BalanceConfig.distance_to_footprint(target_cell, boss.get_occupied_cells())
	for anchor in get_reachable_boss_anchors(boss):
		var footprint: Array[Vector2i] = BalanceConfig.footprint_2x2(anchor)
		var d: float = BalanceConfig.distance_to_footprint(target_cell, footprint)
		if d < best_dist:
			best_dist = d
			best = anchor
	return best


func get_attack_target_cells(attacker: Unit, enemies_only: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if attacker == null:
		return result
	var seen_units: Dictionary = {}
	for cell in occupancy.keys():
		var other: Unit = occupancy[cell] as Unit
		if other == null or other == attacker:
			continue
		if other.is_dead():
			continue
		if enemies_only and other.is_player == attacker.is_player:
			continue
		if seen_units.has(other):
			continue
		if distance_to_unit(attacker.grid_pos, other) > float(attacker.attack_range):
			continue
		seen_units[other] = true
		for occ in other.get_occupied_cells():
			result.append(occ)
	return result


func set_move_highlights(cells: Array[Vector2i]) -> void:
	_set_highlights(cells, MOVE_HIGHLIGHT_COLOR)


func set_attack_highlights(cells: Array[Vector2i]) -> void:
	_set_highlights(cells, ATTACK_HIGHLIGHT_COLOR)


func _set_highlights(cells: Array[Vector2i], color: Color) -> void:
	clear_highlights()
	for cell in cells:
		var rect := ColorRect.new()
		rect.size = Vector2(BalanceConfig.TILE_SIZE - 2, BalanceConfig.TILE_SIZE - 2)
		rect.position = BalanceConfig.grid_to_world_top_left(cell) + Vector2(1, 1)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = color
		_highlight_layer.add_child(rect)
		_highlights[cell] = rect


func clear_highlights() -> void:
	for key in _highlights.keys():
		var node: Node = _highlights[key]
		if is_instance_valid(node):
			node.queue_free()
	_highlights.clear()


func clear_move_highlights() -> void:
	clear_highlights()


func is_highlighted(cell: Vector2i) -> bool:
	return _highlights.has(cell)