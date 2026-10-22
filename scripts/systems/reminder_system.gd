extends RefCounted

## Erinnerung vor Terminen (G5.6): Beginnt ein offener Termin in höchstens REMINDER_MINUTES Spielminuten (und noch
## nicht jetzt), ist genau einmal je Termin eine Erinnerung fällig – auch nach Speichern/Laden. Die Spielansicht fragt
## nach jeder Aktion mit take_due() (nach Ereignis und Kalender). Springt eine Aktion über das ganze Fenster, ist der
## Termin danach verpasst und es kommt keine Erinnerung (dafür gibt es das Konflikt-Popup, G5.4). Kostet keine Spielzeit.
##
## Gespeichert: `reminded` (IDs, sortiert) und `reminded_until_minutes` – Termine mit Beginn ≤ diesem Wert gelten als
## erinnert (Migration 13 → 14: alte Spielstände, deren Termine schon ≤ 30 min entfernt sind, erinnern nicht nachträglich).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const AppointmentSystemScript := preload("res://scripts/systems/appointment_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const REMINDER_MINUTES := 30

var _time: TimeSystemScript
var _appointments: AppointmentSystemScript
var _locations: LocationSystemScript
## appointment_id -> true
var _reminded := {}
var _reminded_until := 0


func _init(time: TimeSystemScript, appointments: AppointmentSystemScript, locations: LocationSystemScript) -> void:
	_time = time
	_appointments = appointments
	_locations = locations


func is_reminded(appointment_id: String) -> bool:
	if _reminded.has(appointment_id):
		return true
	var definition = _appointments.get_catalog().get_definition(appointment_id)
	return definition != null and definition.start_minutes <= _reminded_until


## ID des Termins, an den jetzt erinnert werden soll, oder "" – ohne etwas zu merken.
func get_due() -> String:
	if _time.is_advancing():
		return ""
	var now := _time.get_minutes()
	for definition in _appointments.get_upcoming():  # sortiert nach Beginn
		var left: int = definition.start_minutes - now
		if left > 0 and left <= REMINDER_MINUTES and not is_reminded(definition.id):
			return definition.id
	return ""


## Wie get_due(), merkt den Termin aber als erinnert (genau einmal je Termin).
func take_due() -> String:
	var id := get_due()
	if not id.is_empty():
		_reminded[id] = true
	return id


## Was die Erinnerung anzeigt: {"id", "title", "start_minutes", "minutes_left", "location_id", "here",
## "travel_minutes", "on_time"} – on_time = mit der Fahrt vom aktuellen Ort vor dem Beginn da. {} bei unbekannter ID.
func describe(appointment_id: String) -> Dictionary:
	var definition = _appointments.get_catalog().get_definition(appointment_id)
	if definition == null:
		return {}
	var now := _time.get_minutes()
	var travel := _locations.travel_minutes_to(definition.location)
	return {
		"id": definition.id, "title": definition.title, "start_minutes": definition.start_minutes,
		"minutes_left": definition.start_minutes - now, "location_id": definition.location,
		"here": _locations.get_current() == definition.location, "travel_minutes": travel,
		"on_time": now + travel <= definition.start_minutes,
	}


func to_dict() -> Dictionary:
	var ids := _reminded.keys()
	ids.sort()
	return {"reminded": ids, "reminded_until_minutes": _reminded_until}


## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var until: Variant = data.get("reminded_until_minutes")
	if not DataReaderScript.is_whole_number(until) or int(until) < 0:
		return "Erinnerungen: 'reminded_until_minutes' fehlt oder ist ungültig."
	var raw: Variant = data.get("reminded")
	if typeof(raw) != TYPE_ARRAY:
		return "Erinnerungen: 'reminded' muss eine Liste sein."
	var reminded := {}
	for id in raw:
		if typeof(id) != TYPE_STRING:
			return "Erinnerungen: ungültige ID in 'reminded'."
		reminded[id] = true
	_reminded = reminded
	_reminded_until = int(until)
	return ""
