class_name LocationSystem
extends RefCounted

## Aktueller Ort, Reisezeiten, Öffnungszeiten und Fahrten.
##
## Reisezeit: 5 min + 3 min pro km, aufgerundet auf volle 5 min.
## Die Karte (Positionen 0–1) steht für MAP_SIZE_KM × MAP_SIZE_KM; Entfernungen
## sind Luftlinie, gerundet auf 100 m. Gerechnet wird danach nur mit ganzen
## Zahlen, damit das Ergebnis auf jedem Gerät gleich ist.
##
## travel() ist alles-oder-nichts wie ActivitySystem.start(): erst prüfen, dann
## Ort setzen und die Fahrzeit über das TimeSystem vergehen lassen.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const LocationDefinitionScript := preload("res://scripts/models/location_definition.gd")

signal traveled(from_id: String, to_id: String)

const MAP_SIZE_KM := 8.0
const BASE_TRAVEL_MINUTES := 5
const MINUTES_PER_KM := 3
const TRAVEL_ROUNDING_MINUTES := 5

var _time: TimeSystemScript
var _catalog: LocationCatalogScript
var _start_id: String
var _current: String


## Hinweise des letzten restore() zu entfernten Daten (Phase 6), für die Anzeige nach dem Laden.
var restore_notices := PackedStringArray()

func _init(time: TimeSystemScript, catalog: LocationCatalogScript, start_id: String) -> void:
	_time = time
	_catalog = catalog
	_start_id = start_id
	_current = start_id


func get_catalog() -> LocationCatalogScript:
	return _catalog


func get_current() -> String:
	return _current


func get_current_definition() -> LocationDefinitionScript:
	return _catalog.get_definition(_current)


## Luftlinie zwischen zwei Orten in 100-m-Schritten (z. B. 36 = 3,6 km).
func distance_tenths(from_id: String, to_id: String) -> int:
	var from := _catalog.get_definition(from_id)
	var to := _catalog.get_definition(to_id)
	if from == null or to == null:
		return 0
	return roundi(from.map_position.distance_to(to.map_position) * MAP_SIZE_KM * 10.0)


## Reisezeit für eine Entfernung in 100-m-Schritten.
@warning_ignore("integer_division")
static func travel_minutes_for(distance_tenths_km: int) -> int:
	# In Zehntelminuten rechnen: 5 min + 3 min/km = 50 + 3 · Zehntel-km.
	var tenth_minutes := BASE_TRAVEL_MINUTES * 10 + MINUTES_PER_KM * distance_tenths_km
	var step := TRAVEL_ROUNDING_MINUTES * 10
	return (tenth_minutes + step - 1) / step * TRAVEL_ROUNDING_MINUTES


## Fahrzeit vom aktuellen Ort; 0 für den aktuellen Ort selbst.
func travel_minutes_to(location_id: String) -> int:
	if location_id == _current:
		return 0
	return travel_minutes_for(distance_tenths(_current, location_id))


## "" wenn die Fahrt jetzt möglich ist, sonst ein Grund für die Anzeige.
func check_travel(location_id: String) -> String:
	if not _catalog.has(location_id):
		return "Unbekannter Ort: %s" % location_id
	if location_id == _current:
		return "Du bist schon hier."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	return ""


## Fährt zum Ort. Rückgabe wie check_travel(): "" = angekommen.
func travel(location_id: String) -> String:
	var reason := check_travel(location_id)
	if not reason.is_empty():
		return reason
	var from := _current
	var minutes := travel_minutes_to(location_id)
	_current = location_id
	_time.advance(minutes)
	traveled.emit(from, location_id)
	return ""


func is_open_at(location_id: String, minutes: int) -> bool:
	var definition := _catalog.get_definition(location_id)
	if definition == null:
		return false
	if not definition.has_hours:
		return true
	var minute_of_day := minutes % TimeSystemScript.MINUTES_PER_DAY
	return minute_of_day >= definition.open_hour * 60 and minute_of_day < definition.close_hour * 60


## "" wenn der Ort von start_minutes an für duration_minutes durchgehend offen ist,
## sonst ein Grund für die Anzeige. Über Mitternacht geht nur bei "immer geöffnet".
func check_open_during(location_id: String, start_minutes: int, duration_minutes: int) -> String:
	var definition := _catalog.get_definition(location_id)
	if definition == null:
		return "Unbekannter Ort: %s" % location_id
	if not definition.has_hours:
		return ""
	var begin := start_minutes % TimeSystemScript.MINUTES_PER_DAY
	var end := begin + duration_minutes
	if begin < definition.open_hour * 60 or begin >= definition.close_hour * 60:
		return "%s ist geschlossen (geöffnet %s)." % [definition.display_name, format_hours(definition)]
	if end > definition.close_hour * 60:
		return "%s schließt vorher (geöffnet %s)." % [definition.display_name, format_hours(definition)]
	return ""


## z. B. "07:00–20:00" oder "immer".
static func format_hours(definition: LocationDefinitionScript) -> String:
	if not definition.has_hours:
		return "immer"
	return "%02d:00–%02d:00" % [definition.open_hour, definition.close_hour]


func to_dict() -> Dictionary:
	return {"current": _current}


## Stellt den gespeicherten Ort her. Gibt es den Ort in den Daten nicht mehr,
## beginnt der Spieler wieder am Startort. "" = ok, sonst Fehlertext (dann unverändert).
func restore(data: Dictionary) -> String:
	var current: Variant = data.get("current")
	if typeof(current) != TYPE_STRING or current.is_empty():
		return "Ort: 'current' fehlt oder ist ungültig."
	restore_notices = PackedStringArray()
	if not _catalog.has(current):
		restore_notices.append("Den Ort „%s“ gibt es nicht mehr – du bist wieder am Startort." % current)
	_current = current if _catalog.has(current) else _start_id
	return ""
