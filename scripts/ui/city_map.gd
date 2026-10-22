extends Control

## Isometrische Stadtkarte (Grafik-Ticket G1, seit G2 Vollbild-Hauptbildschirm): Straßen, Strand, Meer, ein Gebäude
## mit Namensschild pro Ort, Markierung am aktuellen Ort und ein Auto, das nach
## einer Fahrt zum Ziel fährt. Wischen verschiebt die Karte.
## Zeigt nur an; was ein Tipp bewirkt, entscheidet der GameScreen. Das Raster
## kommt aus `city_layout.gd`, die Grafiken aus Kenney-CC0-Paketen (assets/kenney/).
## Die Fahranimation ist rein optisch – die Spielzeit ist beim Start schon vorgestellt.

signal location_pressed(location_id: String)

const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const CityLayoutScript := preload("res://scripts/ui/city_layout.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const PIN_HEIGHT := 64
## Zoom (G2): Start 0,75, begrenzt auf 0,5–1,0 (Zwei-Finger-Geste, Mausrad, Trackpad).
const DEFAULT_ZOOM := 0.75
const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.0
const WHEEL_ZOOM_STEP := 1.1
## Ab so viel Bewegung (px) gilt eine Berührung als Wischen, nicht als Tipp.
const DRAG_THRESHOLD := 12.0
const CAR_SCALE := 1.6
const SECONDS_PER_CELL := 0.12
const MIN_TRAVEL_SECONDS := 0.8
const MAX_TRAVEL_SECONDS := 2.5

const SEA := Color(0.33, 0.6, 0.76)
const WAVE := Color(0.55, 0.78, 0.9)
const SAND_TOP := Color(0.94, 0.86, 0.63)
const SAND_LEFT := Color(0.86, 0.76, 0.52)
const SAND_RIGHT := Color(0.74, 0.64, 0.43)
const PIN := Color(0.13, 0.13, 0.16, 0.92)
const PIN_CURRENT := Color(0.22, 0.45, 0.3)
const ROUTE := Color(0.84, 0.27, 0.35, 0.85)

## Kachelmaße (Kenney „Isometric Tiles“): Unterkante einer Bodenkachel liegt 68 px
## unter der Mitte ihrer Oberseite; Etagen sind 35 px hoch, Dächer sitzen 12 px höher.
const TILE_BOTTOM := 68.0
const BASE_TOP := -59.0
const FLOOR_STEP := 35.0
const ROOF_STEP := 12.0

const CITY_DIR := "res://assets/kenney/isometric-city/"
const BUILDING_DIR := "res://assets/kenney/isometric-buildings/"
const VEHICLE_DIR := "res://assets/kenney/isometric-vehicles/"

const TILES := {
	"ground": "cityTiles_066",
	"park": "cityTiles_067",
	"road_ew": "cityTiles_073",
	"road_ns": "cityTiles_081",
	"cross": "cityTiles_089",
	"closed_e": "cityTiles_088",
	"closed_w": "cityTiles_095",
	"closed_n": "cityTiles_096",
	"closed_s": "cityTiles_103",
	"tree": "cityDetails_010",
}

## Aussehen der Gebäude je Ort: Erdgeschoss, Etagen, optionales Dach (Dateinamen ohne .png).
## Ein neuer Ort ohne Eintrag bekommt DEFAULT_BUILDING.
const BUILDINGS := {
	"home": {"base": "buildingTiles_021", "floors": ["buildingTiles_032", "buildingTiles_032"], "roof": "buildingTiles_065"},
	"studio": {"base": "buildingTiles_003", "floors": ["buildingTiles_031"]},
	"cafe_harbor": {"base": "buildingTiles_004", "floors": []},
	"gym": {"base": "buildingTiles_026", "floors": ["buildingTiles_052"]},
	"office": {"base": "buildingTiles_001", "floors": ["buildingTiles_016", "buildingTiles_016", "buildingTiles_016"]},
	"label_store": {"base": "buildingTiles_020", "floors": []},
}
const DEFAULT_BUILDING := {"base": "buildingTiles_019", "floors": ["buildingTiles_016"]}
const FILLER_BUILDINGS: Array[String] = ["buildingTiles_019", "buildingTiles_022", "buildingTiles_030"]

## Fahrtrichtung im Raster -> Kenney-Blickrichtung.
const CAR_DIRECTIONS := {
	Vector2i(1, 0): "SE",
	Vector2i(-1, 0): "NW",
	Vector2i(0, 1): "SW",
	Vector2i(0, -1): "NE",
}


## Wippender Pfeil über dem aktuellen Ort (eigener Knoten, damit die Karte
## für die Animation nicht jedes Bild neu zeichnen muss).
## Wippt nur kurz (BOB_SECONDS) nach restart() und steht dann still: Eine dauernde Bewegung würde
## Godot zwingen, jedes Bild neu zu zeichnen – der Stromsparmodus wäre wirkungslos (gemessen, Phase 7).
class Marker extends Control:
	const SIZE := Vector2(44, 56)
	const BOB_SECONDS := 3.0
	var base_position := Vector2.ZERO:
		set(value):
			base_position = value
			if not is_processing():
				position = value
	var _time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = SIZE
		restart()

	## Kurz wippen lassen (Ankunft, Auswahl, Laden).
	func restart() -> void:
		_time = 0.0
		set_process(true)

	func _process(delta: float) -> void:
		_time += delta
		if _time >= BOB_SECONDS:
			set_process(false)
			position = base_position
			return
		position = base_position + Vector2(0, sin(_time * 4.0) * 6.0)

	func _draw() -> void:
		var tip := Vector2(SIZE.x / 2.0, SIZE.y)
		var arrow := PackedVector2Array([Vector2(4, 18), Vector2(SIZE.x - 4, 18), tip])
		draw_colored_polygon(arrow, Color(0.22, 0.45, 0.3))
		draw_circle(Vector2(SIZE.x / 2.0, 18), 18.0, Color(0.22, 0.45, 0.3))
		draw_circle(Vector2(SIZE.x / 2.0, 18), 8.0, Color.WHITE)


var _catalog: LocationCatalogScript
var _layout: CityLayoutScript
var _current := ""
var _selected := ""
## location_id -> Button (Namensschild)
var _pins := {}
var _marker: Marker
## name -> Texture2D (null, wenn die Datei fehlt – dann wird das Teil ausgelassen)
var _textures := {}

## Bildschirmposition des Welt-Ursprungs.
var _offset := Vector2.ZERO
var _centered := false
var _camera_tween: Tween

var _drag_total := 0.0
var _dragging := false
var _sign_frame := -1

## Auto: Zellfolge, Fortschritt (in Zellen) und Blickrichtung.
var _car_path: Array[Vector2i] = []
var _car_progress := 0.0
var _car_direction := "SW"
var _car_tween: Tween

var _zoom := DEFAULT_ZOOM
## Aktive Finger (Index -> Position) für die Zwei-Finger-Geste.
var _touches := {}
var _pinch_distance := 0.0
var _pinching := false


## Vor dem Einfügen in den Baum aufrufen.
func setup(catalog: LocationCatalogScript) -> void:
	_catalog = catalog
	_layout = CityLayoutScript.new(catalog)


func _ready() -> void:
	# STOP: Wischen auf der Karte verschiebt nur die Karte, nicht die Seite.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_textures()
	for id in _catalog.get_ids():
		var pin := Button.new()
		pin.name = "MapPin_%s" % id
		pin.text = _catalog.get_definition(id).display_name
		pin.custom_minimum_size.y = PIN_HEIGHT
		pin.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		# PASS: Wischen auf einem Schild erreicht die Karte und verschiebt sie.
		pin.mouse_filter = Control.MOUSE_FILTER_PASS
		pin.button_down.connect(_on_sign_down)
		pin.pressed.connect(_on_sign_pressed.bind(id))
		add_child(pin)
		_pins[id] = pin
	_marker = Marker.new()
	_marker.name = "LocationMarker"
	add_child(_marker)
	resized.connect(_on_resized)
	_update_pins()
	_on_resized.call_deferred()


## Aktueller und ausgewählter Ort (für Schilder, Markierung und Route).
func set_state(current_id: String, selected_id: String) -> void:
	var moved := current_id != _current
	_current = current_id
	_selected = selected_id
	if moved and not is_traveling():
		_park_car()
	if moved and _marker != null:
		_marker.restart()
	if is_node_ready():
		_update_pins()
		_layout_overlays()
		queue_redraw()


## Fahranimation von einem Ort zum anderen (nur Darstellung). Die Kamera folgt zum Ziel.
func play_travel(from_id: String, to_id: String) -> void:
	var path := _layout.travel_path(from_id, to_id)
	if path.size() < 3:
		_park_car()
		return
	if _car_tween != null:
		_car_tween.kill()
	_car_path = path.slice(1, path.size() - 1)
	_set_car_progress(0.0)
	var cells := _car_path.size() - 1
	var seconds := clampf(cells * SECONDS_PER_CELL, MIN_TRAVEL_SECONDS, MAX_TRAVEL_SECONDS)
	if not is_inside_tree() or cells == 0:
		finish_travel()
		return
	_car_tween = create_tween()
	_car_tween.tween_method(_set_car_progress, 0.0, float(cells), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_car_tween.finished.connect(finish_travel)
	_move_camera_to(_layout.get_location_cell(to_id), seconds)
	_layout_overlays()


func is_traveling() -> bool:
	return _car_tween != null and _car_tween.is_valid() and _car_tween.is_running()


## Animation sofort beenden (auch für Tests): Auto steht an der Zufahrt des aktuellen Orts.
func finish_travel() -> void:
	if _car_tween != null:
		_car_tween.kill()
		_car_tween = null
	_park_car()
	_layout_overlays()
	if _marker != null:
		_marker.restart()


## Rasterzelle, in der das Auto gerade steht (gerundet).
func get_car_cell() -> Vector2i:
	return Vector2i(_car_position().round())


func get_layout() -> CityLayoutScript:
	return _layout


# --- Eingabe -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return
	if event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_at(event.position, WHEEL_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_ZOOM_STEP)
		accept_event()
		return
	if _pinching:
		# Während zwei Finger zoomen, verschieben/tippen die nachgebildeten Mausereignisse nichts.
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Gehört der Druck nicht zu einem Schild aus diesem Bild, ist eine alte Markierung ungültig.
			if _sign_frame != Engine.get_process_frames():
				_sign_frame = -1
			_begin_touch()
		else:
			_end_touch(event.position)
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_total += event.relative.length()
		if _drag_total > DRAG_THRESHOLD:
			_dragging = true
		_set_offset(_offset + event.relative)
		accept_event()


## Zwei-Finger-Geste: Abstandsänderung der beiden Finger zoomt um ihre Mitte.
## (Ein Finger läuft weiter über die nachgebildeten Mausereignisse.)
func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	else:
		_touches[event.index] = event.position
	if _touches.size() >= 2:
		var points: Array = _touches.values()
		var distance: float = points[0].distance_to(points[1])
		if _pinching and _pinch_distance > 0.0:
			zoom_at((points[0] + points[1]) / 2.0, distance / _pinch_distance)
		_pinching = true
		_dragging = true  # nach dem Zoomen löst Loslassen keinen Tipp aus
		_pinch_distance = distance
	elif _touches.is_empty():
		_pinching = false
		_pinch_distance = 0.0
	accept_event()


func get_zoom() -> float:
	return _zoom


## Zoomt um einen Bildschirmpunkt; der Weltpunkt darunter bleibt stehen. Begrenzung MIN_ZOOM–MAX_ZOOM.
func zoom_at(screen_point: Vector2, factor: float) -> void:
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, _zoom):
		return
	var world := (screen_point - _offset) / _zoom
	_zoom = new_zoom
	_set_offset(screen_point - world * _zoom)


## Schwenkt die Kamera zu einem Ort (z. B. „Hier“-Button).
func center_on(location_id: String) -> void:
	if _catalog.has(location_id):
		_move_camera_to(_layout.get_location_cell(location_id), 0.3)


func _begin_touch() -> void:
	_drag_total = 0.0
	_dragging = false
	if _camera_tween != null:
		_camera_tween.kill()


func _end_touch(screen_position: Vector2) -> void:
	# Ein Tipp auf ein Schild wird schon über dessen `pressed` gemeldet.
	var from_sign := _sign_frame >= 0
	_sign_frame = -1
	if _dragging or from_sign:
		return
	var id := _location_at(screen_position)
	if not id.is_empty():
		location_pressed.emit(id)


func _on_sign_down() -> void:
	_begin_touch()
	_sign_frame = Engine.get_process_frames()


func _on_sign_pressed(location_id: String) -> void:
	if not _dragging:
		location_pressed.emit(location_id)


## Vorderstes Gebäude unter dem Finger.
func _location_at(screen_position: Vector2) -> String:
	var world := (screen_position - _offset) / _zoom
	var best := ""
	var best_depth := -INF
	for id in _pins:
		var cell := _layout.get_location_cell(id)
		var anchor := CityLayoutScript.cell_to_world(cell)
		var top := _building_top(id)
		var rect := Rect2(anchor.x - CityLayoutScript.HALF.x, anchor.y + top,
				CityLayoutScript.HALF.x * 2.0, TILE_BOTTOM - top)
		if rect.has_point(world) and cell.x + cell.y > best_depth:
			best = id
			best_depth = cell.x + cell.y
	return best


# --- Kamera ------------------------------------------------------------------

func _on_resized() -> void:
	if size.x <= 0.0:
		return
	if not _centered and _catalog.has(_current):
		_centered = true
		_set_offset(_offset_for(_layout.get_location_cell(_current)))
	else:
		_set_offset(_offset)


func _offset_for(cell: Vector2i) -> Vector2:
	return size / 2.0 - CityLayoutScript.cell_to_world(Vector2(cell)) * _zoom


func _move_camera_to(cell: Vector2i, seconds: float) -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_method(_set_offset, _offset, _clamped(_offset_for(cell)), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_offset(value: Vector2) -> void:
	_offset = _clamped(value)
	_layout_overlays()
	queue_redraw()


## Die Stadt (inkl. Strand) deckt immer den sichtbaren Ausschnitt ab.
func _clamped(value: Vector2) -> Vector2:
	var bounds := CityLayoutScript.city_bounds()
	var low := size - bounds.end * _zoom
	var high := -bounds.position * _zoom
	var result := value
	result.x = (low.x + high.x) / 2.0 if low.x > high.x else clampf(value.x, low.x, high.x)
	result.y = (low.y + high.y) / 2.0 if low.y > high.y else clampf(value.y, low.y, high.y)
	return result


func _to_screen(world: Vector2) -> Vector2:
	return _offset + world * _zoom


# --- Schilder, Markierung, Auto -------------------------------------------------

func _update_pins() -> void:
	for id in _pins:
		var color := PIN_CURRENT if id == _current else (UiStyle.ACCENT if id == _selected else PIN)
		var pin: Button = _pins[id]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			pin.add_theme_stylebox_override(state, UiStyle.flat_box(color))
		UiStyle.grow_touch_area(pin, PIN_HEIGHT)  # Tippfläche 84 px, sichtbar wie bisher (G4.7)


func _layout_overlays() -> void:
	if _layout == null:
		return
	for id in _pins:
		var pin: Button = _pins[id]
		pin.reset_size()
		var anchor := CityLayoutScript.cell_to_world(_layout.get_location_cell(id))
		var top := _to_screen(anchor + Vector2(0, _building_top(id) - 8.0))
		# Unterkante des SICHTBAREN Schilds bleibt über dem Gebäude (die Tippfläche ragt unsichtbar darüber hinaus).
		pin.position = top - Vector2(pin.size.x / 2.0, pin.size.y - (pin.size.y - PIN_HEIGHT) / 2.0)
	if _marker != null:
		_marker.visible = _pins.has(_current) and not is_traveling()
		if _marker.visible:
			var pin: Button = _pins[_current]
			_marker.base_position = pin.position + Vector2((pin.size.x - _marker.size.x) / 2.0, -_marker.size.y - 4.0)


func _park_car() -> void:
	_car_path = []
	if _layout != null and _catalog.has(_current):
		_car_path = [_layout.access_cell(_current)]
	_car_progress = 0.0
	_car_direction = "SW"
	queue_redraw()


func _set_car_progress(value: float) -> void:
	_car_progress = value
	var index := clampi(int(floor(value)), 0, maxi(_car_path.size() - 2, 0))
	if _car_path.size() >= 2:
		var step := _car_path[index + 1] - _car_path[index]
		_car_direction = CAR_DIRECTIONS.get(step, _car_direction)
	queue_redraw()


func _car_position() -> Vector2:
	if _car_path.is_empty():
		return Vector2(-1, -1)
	var index := clampi(int(floor(_car_progress)), 0, _car_path.size() - 1)
	var next := mini(index + 1, _car_path.size() - 1)
	return Vector2(_car_path[index]).lerp(Vector2(_car_path[next]), _car_progress - index)


# --- Zeichnen ----------------------------------------------------------------

func _load_textures() -> void:
	for key in TILES:
		_textures[key] = _load(CITY_DIR + TILES[key])
	var names: Array = FILLER_BUILDINGS.duplicate()
	for style in BUILDINGS.values() + [DEFAULT_BUILDING]:
		names.append(style["base"])
		names.append_array(style["floors"])
		if style.has("roof"):
			names.append(style["roof"])
	for building_name in names:
		_textures[building_name] = _load(BUILDING_DIR + building_name)
	for direction in CAR_DIRECTIONS.values():
		_textures["car_" + direction] = _load(VEHICLE_DIR + "taxi_%s" % direction)
	_pack_atlas()


## Packt alle Kartengrafiken in eine gemeinsame Textur und ersetzt die Einträge durch Ausschnitte
## (AtlasTexture). Grund: Godot bündelt Zeichenaufrufe nur bei gleicher Textur – mit Einzeltexturen
## waren es ~960 Aufrufe je Bild (gemessen, Phase 7). Klappt das Packen nicht, bleiben die Einzeltexturen.
const ATLAS_WIDTH := 1024
const ATLAS_PADDING := 2

func _pack_atlas() -> void:
	var images := {}
	for key in _textures:
		var texture: Texture2D = _textures[key]
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null or image.is_compressed():
			return
		image.convert(Image.FORMAT_RGBA8)
		images[key] = image
	# Regal-Packen: Zeilen von links nach rechts, nach Höhe sortiert.
	var keys := images.keys()
	keys.sort_custom(func(a, b) -> bool: return images[a].get_height() > images[b].get_height())
	var regions := {}
	var x := 0
	var y := 0
	var row_height := 0
	for key in keys:
		var image: Image = images[key]
		if x + image.get_width() > ATLAS_WIDTH:
			x = 0
			y += row_height + ATLAS_PADDING
			row_height = 0
		regions[key] = Rect2i(x, y, image.get_width(), image.get_height())
		x += image.get_width() + ATLAS_PADDING
		row_height = maxi(row_height, image.get_height())
	var atlas_image := Image.create_empty(ATLAS_WIDTH, y + row_height, false, Image.FORMAT_RGBA8)
	for key in keys:
		var image: Image = images[key]
		atlas_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), regions[key].position)
	var atlas := ImageTexture.create_from_image(atlas_image)
	for key in keys:
		var part := AtlasTexture.new()
		part.atlas = atlas
		part.region = Rect2(regions[key])
		_textures[key] = part


static func _load(path_without_extension: String) -> Texture2D:
	var path := path_without_extension + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	if _layout == null:
		return
	draw_set_transform(_offset, 0.0, Vector2(_zoom, _zoom))
	var view := Rect2(-_offset / _zoom, size / _zoom).grow(200.0)
	var low := CityLayoutScript.min_cell()
	var high := CityLayoutScript.max_cell()
	# Maleralgorithmus: hintere Zellen zuerst (kleine gx + gy).
	for depth in range(low.x + low.y, high.x + high.y + 1):
		for x in range(maxi(low.x, depth - high.y), mini(high.x, depth - low.y) + 1):
			var cell := Vector2i(x, depth - x)
			var anchor := CityLayoutScript.cell_to_world(Vector2(cell))
			if view.has_point(anchor):
				_draw_cell(cell, anchor)
	_draw_route()
	_draw_car()
	var font := get_theme_default_font()
	draw_string(font, CityLayoutScript.cell_to_world(Vector2(6, CityLayoutScript.BEACH_ROW + 3)),
			"Mittelmeer", HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiStyle.SMALL_FONT_SIZE / _zoom), Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO)


func _draw_cell(cell: Vector2i, anchor: Vector2) -> void:
	match _layout.kind_at(cell):
		CityLayoutScript.Kind.SEA:
			if CityLayoutScript.variant(cell) % 6 == 0:
				draw_line(anchor + Vector2(-18, 0), anchor + Vector2(18, 9), WAVE, 3.0)
		CityLayoutScript.Kind.BEACH:
			_draw_sand(anchor)
		CityLayoutScript.Kind.ROAD:
			_draw_tile(_textures[_road_tile(cell)], anchor)
		CityLayoutScript.Kind.PARK:
			_draw_tile(_textures["park"], anchor)
		CityLayoutScript.Kind.TREES:
			_draw_tile(_textures["ground"], anchor)
			_draw_tree(anchor + Vector2(-26, -2))
			_draw_tree(anchor + Vector2(22, -10))
			_draw_tree(anchor + Vector2(0, 12))
		CityLayoutScript.Kind.HOUSE:
			var filler := FILLER_BUILDINGS[CityLayoutScript.variant(cell) % FILLER_BUILDINGS.size()]
			_draw_tile(_textures[filler], anchor)
		CityLayoutScript.Kind.LOCATION:
			_draw_building(_layout.get_location_at(cell), anchor)
		_:
			_draw_tile(_textures["ground"], anchor)


func _road_tile(cell: Vector2i) -> String:
	var links := _layout.road_links(cell)
	var open_count := links.values().count(true)
	if open_count == 3:
		for side in ["e", "w", "n", "s"]:
			if not links[side]:
				return "closed_" + side
	if open_count == 2 and links["e"] and links["w"]:
		return "road_ew"
	if open_count == 2 and links["n"] and links["s"]:
		return "road_ns"
	return "cross"


## Bodenteile sitzen mit ihrer Unterkante auf der Kachel.
func _draw_tile(texture: Texture2D, anchor: Vector2) -> void:
	if texture != null:
		draw_texture(texture, anchor + Vector2(-texture.get_width() / 2.0, TILE_BOTTOM - texture.get_height()))


func _draw_tree(position_on_tile: Vector2) -> void:
	var texture: Texture2D = _textures["tree"]
	if texture != null:
		draw_texture(texture, position_on_tile - Vector2(texture.get_width() / 2.0, texture.get_height()))


func _draw_building(location_id: String, anchor: Vector2) -> void:
	var style: Dictionary = BUILDINGS.get(location_id, DEFAULT_BUILDING)
	_draw_tile(_textures[style["base"]], anchor)
	var y := anchor.y + BASE_TOP
	for floor_name in style["floors"]:
		y -= FLOOR_STEP
		_draw_part(_textures[floor_name], anchor.x, y)
	if style.has("roof"):
		_draw_part(_textures[style["roof"]], anchor.x, y - ROOF_STEP)


func _draw_part(texture: Texture2D, center_x: float, top_y: float) -> void:
	if texture != null:
		draw_texture(texture, Vector2(center_x - texture.get_width() / 2.0, top_y))


## Oberkante des Gebäudes relativ zur Kachelmitte (negativ = darüber).
func _building_top(location_id: String) -> float:
	var style: Dictionary = BUILDINGS.get(location_id, DEFAULT_BUILDING)
	var top: float = BASE_TOP - FLOOR_STEP * style["floors"].size()
	if style.has("roof"):
		top -= ROOF_STEP
	return top


func _draw_sand(anchor: Vector2) -> void:
	var half := CityLayoutScript.HALF
	var drop := 6.0
	var top := anchor + Vector2(0, drop)
	var thickness := TILE_BOTTOM - half.y - drop
	var left := top + Vector2(-half.x, 0)
	var right := top + Vector2(half.x, 0)
	var front := top + Vector2(0, half.y)
	var down := Vector2(0, thickness)
	draw_colored_polygon(PackedVector2Array([left, front, front + down, left + down]), SAND_LEFT)
	draw_colored_polygon(PackedVector2Array([front, right, right + down, front + down]), SAND_RIGHT)
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -half.y), right, front, left]), SAND_TOP)


func _draw_route() -> void:
	if not _catalog.has(_current) or not _catalog.has(_selected) or _current == _selected or is_traveling():
		return
	var points := PackedVector2Array()
	for cell in _layout.travel_path(_current, _selected):
		points.append(CityLayoutScript.cell_to_world(Vector2(cell)) + Vector2(0, 4))
	if points.size() >= 2:
		draw_polyline(points, ROUTE, 10.0, true)


func _draw_car() -> void:
	if _car_path.is_empty():
		return
	var texture: Texture2D = _textures.get("car_" + _car_direction)
	if texture == null:
		return
	var car_size := texture.get_size() * CAR_SCALE
	var center := CityLayoutScript.cell_to_world(_car_position()) + Vector2(0, -4)
	draw_texture_rect(texture, Rect2(center - car_size / 2.0, car_size), false)
