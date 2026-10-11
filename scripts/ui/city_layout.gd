extends RefCounted

## Rasterplan der isometrischen Stadtkarte – nur Darstellung, keine Spielregeln.
## Baut aus den Kartenpositionen der Orte (0–1) deterministisch ein Raster:
## Straßennetz, Strand, Meer, ein Grundstück pro Ort und Füllbebauung.
## Die Fahrstrecke des Autos folgt den Straßen; Reisezeit und Entfernung
## berechnet weiterhin allein das LocationSystem (Luftlinie).
##
## Raster: gx nach rechts unten, gy nach links unten (Datenkarte: x → gx, y → gy).
## Kartenpositionen landen in den Zellen 0..LAND_LAST, darunter Promenade, Strand, Meer.

const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")

enum Kind { GROUND, PARK, TREES, HOUSE, LOCATION, ROAD, BEACH, SEA }

## Innere Stadt: 15 × 15 Zellen (0..14).
const SIZE := 15
## Straßen auf diesen Zeilen/Spalten; die letzte Zeile ist die Strandpromenade.
const ROAD_LINES: Array[int] = [1, 5, 9, 13]
const PROMENADE := 13
const BEACH_ROW := 14
## Letzte Zeile, in die Orte gesetzt werden (über der Promenade).
const LAND_LAST := 12
## Umland außerhalb der inneren Stadt, damit beim Verschieben keine leeren Ecken sichtbar werden.
const MARGIN := 9

## Halbe Kachelgröße in Weltpixeln (Kenney-Kacheln: 132 × 66 Draufsicht).
const HALF := Vector2(66, 33)

## location_id -> Vector2i
var _location_cells := {}
## Vector2i -> location_id
var _cell_locations := {}


func _init(catalog: LocationCatalogScript) -> void:
	var ids := Array(catalog.get_ids())
	ids.sort()
	for id in ids:
		var cell := _nearest_free_lot(catalog.get_definition(id).map_position * float(PROMENADE))
		_location_cells[id] = cell
		_cell_locations[cell] = id


## Zellbereich, der gezeichnet wird (inklusive Umland und Meer).
static func min_cell() -> Vector2i:
	return Vector2i(-MARGIN, -MARGIN)


static func max_cell() -> Vector2i:
	return Vector2i(SIZE - 1 + MARGIN, SIZE - 1 + MARGIN)


## Mitte der Kachel-Oberseite in Weltpixeln.
static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


static func world_to_cell(world: Vector2) -> Vector2:
	var a := world.x / HALF.x
	var b := world.y / HALF.y
	return Vector2((a + b) / 2.0, (b - a) / 2.0)


## Weltrechteck der inneren Stadt inkl. Strand und etwas Meer (Grenze fürs Verschieben).
static func city_bounds() -> Rect2:
	var left := cell_to_world(Vector2(0, BEACH_ROW + 1)).x - HALF.x
	var right := cell_to_world(Vector2(SIZE - 1, 0)).x + HALF.x
	var top := cell_to_world(Vector2.ZERO).y - 6.0 * HALF.y
	var bottom := cell_to_world(Vector2(SIZE - 1, BEACH_ROW + 2)).y
	return Rect2(left, top, right - left, bottom - top)


func get_location_cell(location_id: String) -> Vector2i:
	return _location_cells.get(location_id, Vector2i(-1, -1))


func get_location_at(cell: Vector2i) -> String:
	return _cell_locations.get(cell, "")


func kind_at(cell: Vector2i) -> Kind:
	if cell.y > BEACH_ROW:
		return Kind.SEA
	if cell.y == BEACH_ROW:
		return Kind.BEACH
	if is_road(cell):
		return Kind.ROAD
	if _cell_locations.has(cell):
		return Kind.LOCATION
	var inside := cell.x >= 0 and cell.x < SIZE and cell.y >= 0
	var roll := variant(cell) % 10
	if inside and _next_to_road(cell) and not _next_to_location(cell):
		if roll < 4:
			return Kind.HOUSE
		if roll < 6:
			return Kind.PARK
		return Kind.GROUND
	if roll < 5:
		return Kind.TREES
	return Kind.GROUND


## Straßen laufen über den Kartenrand hinaus; Spalten enden an der Promenade.
func is_road(cell: Vector2i) -> bool:
	if cell.y > PROMENADE:
		return false
	return cell.y in ROAD_LINES or cell.x in ROAD_LINES


## Offene Seiten einer Straßenzelle: {"e": +gx, "w": -gx, "s": +gy, "n": -gy}.
func road_links(cell: Vector2i) -> Dictionary:
	return {
		"e": is_road(cell + Vector2i(1, 0)),
		"w": is_road(cell + Vector2i(-1, 0)),
		"s": is_road(cell + Vector2i(0, 1)),
		"n": is_road(cell + Vector2i(0, -1)),
	}


## Straßenzelle direkt vor dem Grundstück eines Orts (Zufahrt).
func access_cell(location_id: String) -> Vector2i:
	var cell := get_location_cell(location_id)
	for direction in _directions():
		if is_road(cell + direction):
			return cell + direction
	return cell


## Fahrstrecke als Zellfolge: Grundstück → Zufahrt → Straßen (kürzester Weg) → Zufahrt → Grundstück.
## Leer, wenn ein Ort unbekannt ist oder Start = Ziel.
func travel_path(from_id: String, to_id: String) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _location_cells.has(from_id) or not _location_cells.has(to_id) or from_id == to_id:
		return path
	path.append(get_location_cell(from_id))
	path.append_array(_road_route(access_cell(from_id), access_cell(to_id)))
	path.append(get_location_cell(to_id))
	return path


## Breitensuche über Straßenzellen der inneren Stadt (feste Nachbarreihenfolge = deterministisch).
func _road_route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var came_from := {start: start}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			break
		for direction in _directions():
			var next: Vector2i = cell + direction
			if came_from.has(next) or not is_road(next) or not _inside(next):
				continue
			came_from[next] = cell
			queue.append(next)
	var route: Array[Vector2i] = []
	if not came_from.has(goal):
		return route
	var cell := goal
	while cell != start:
		route.push_front(cell)
		cell = came_from[cell]
	route.push_front(start)
	return route


func _nearest_free_lot(target: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(0, LAND_LAST + 1):
		for x in range(0, SIZE):
			var cell := Vector2i(x, y)
			if is_road(cell) or _cell_locations.has(cell) or not _next_to_road(cell):
				continue
			var distance := target.distance_squared_to(Vector2(cell))
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


func _next_to_road(cell: Vector2i) -> bool:
	for direction in _directions():
		if is_road(cell + direction):
			return true
	return false


func _next_to_location(cell: Vector2i) -> bool:
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if _cell_locations.has(cell + direction):
			return true
	return false


static func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE


## Reihenfolge: zuerst nach vorn (Richtung Betrachter), dann seitlich.
static func _directions() -> Array[Vector2i]:
	return [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]


## Fester Streuwert pro Zelle für Bäume und Füllbebauung (kein Zufall, keine Uhr).
static func variant(cell: Vector2i) -> int:
	return absi((cell.x + 50) * 73856093 ^ (cell.y + 50) * 19349663) % 1000003
