extends Control

## Einfache 2D-Stadtkarte: Hintergrund, Meer, ein antippbarer Pin pro Ort.
## Positionen kommen aus den Ortsdaten (0–1), die Pins werden bei jeder
## Größenänderung neu gesetzt – keine festen Pixelpositionen.
## Zeigt nur an; was ein Tipp bewirkt, entscheidet der GameScreen.

signal location_pressed(location_id: String)
## Beim Herunterdrücken eines Pins (für die Unterscheidung Tippen/Scrollen).
signal pin_down

const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const LAND := Color(0.12, 0.15, 0.17)
const SEA := Color(0.1, 0.2, 0.32)
const SEA_START := 0.88
const PIN := Color(0.24, 0.24, 0.3)
const PIN_CURRENT := Color(0.22, 0.45, 0.3)
const MAP_HEIGHT := 620
const PIN_HEIGHT := 72

var _catalog: LocationCatalogScript
var _current := ""
var _selected := ""
## location_id -> Button
var _pins := {}


## Vor dem Einfügen in den Baum aufrufen.
func setup(catalog: LocationCatalogScript) -> void:
	_catalog = catalog


func _ready() -> void:
	custom_minimum_size.y = MAP_HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS: Wischgesten auf der Karte erreichen die umgebende ScrollContainer.
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	for id in _catalog.get_ids():
		var pin := Button.new()
		pin.name = "MapPin_%s" % id
		pin.text = _catalog.get_definition(id).display_name
		pin.custom_minimum_size.y = PIN_HEIGHT
		pin.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		pin.mouse_filter = Control.MOUSE_FILTER_PASS
		pin.button_down.connect(func() -> void: pin_down.emit())
		pin.pressed.connect(func() -> void: location_pressed.emit(id))
		add_child(pin)
		_pins[id] = pin
	resized.connect(_layout_pins)
	_update_pins()
	_layout_pins.call_deferred()


## Aktueller und ausgewählter Ort (für Farben und Fahrtlinie).
func set_state(current_id: String, selected_id: String) -> void:
	_current = current_id
	_selected = selected_id
	if is_node_ready():
		_update_pins()
		queue_redraw()


func _update_pins() -> void:
	for id in _pins:
		var color := PIN_CURRENT if id == _current else (UiStyle.ACCENT if id == _selected else PIN)
		var pin: Button = _pins[id]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			pin.add_theme_stylebox_override(state, UiStyle.flat_box(color))


func _point(location_id: String) -> Vector2:
	return _catalog.get_definition(location_id).map_position * size


func _layout_pins() -> void:
	for id in _pins:
		var pin: Button = _pins[id]
		pin.reset_size()
		var top_left := _point(id) - pin.size / 2.0
		pin.position = top_left.clamp(Vector2.ZERO, (size - pin.size).max(Vector2.ZERO))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	draw_rect(Rect2(0, size.y * SEA_START, size.x, size.y * (1.0 - SEA_START)), SEA)
	var font := get_theme_default_font()
	draw_string(font, Vector2(16, size.y - 20), "Mittelmeer", HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	if _catalog.has(_current) and _catalog.has(_selected) and _current != _selected:
		draw_line(_point(_current), _point(_selected), UiStyle.ACCENT, 6.0, true)
	for id in _pins:
		draw_circle(_point(id), 10.0, PIN_CURRENT if id == _current else UiStyle.TEXT)
