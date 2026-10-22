extends RefCounted

## Tagesplan für den Kalender (G5.2): Termine und Fristen eines Tages als sortierte Einträge – eine reine
## Abfrage über die Systeme (AppointmentSystem, ObligationSystem, LocationSystem), ändert nichts. Die UI zeigt nur an.
##
## Eintrag (Dictionary):
##   kind            KIND_APPOINTMENT oder KIND_OBLIGATION
##   id              Termin-ID bzw. Frist-Instanz-ID
##   title           Anzeigename
##   start_minutes   Beginn (Termin) bzw. Fälligkeit (Frist), kanonische Spielzeit
##   end_minutes     Ende (Termin); bei Fristen = start_minutes
##   location_id     Ort des Termins ("" bei Fristen)
##   travel_minutes  Fahrzeit vom aktuellen Ort (0 = schon dort oder Frist)
##   amount_cents    offener bzw. bezahlter Betrag (Fristen), sonst 0
##   state           STATE_* (siehe unten)
##   overdue         true = Frist von einem früheren Tag, noch offen
## Reihenfolge: nach Beginn, bei Gleichstand Fristen vor Terminen, dann nach ID.
## now_index: Anzahl der Einträge, die vor der Jetzt-Linie stehen (Beginn ≤ jetzt) – dort zeichnet die UI die Linie.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ObligationSystemScript := preload("res://scripts/systems/obligation_system.gd")

const KIND_APPOINTMENT := "appointment"
const KIND_OBLIGATION := "obligation"

## Termin vorbei (Ende erreicht, ohne Wahrnehmen und ohne Verpassen-Vermerk)
const STATE_PAST := "past"
const STATE_ATTENDED := "attended"
const STATE_MISSED := "missed"
## der nächste anstehende Termin (Ein Termin „läuft“ nie: Verstreicht sein Beginn, gilt er als verpasst; Wahrnehmen
## verbraucht seine ganze Dauer.)
const STATE_NEXT := "next"
const STATE_UPCOMING := "upcoming"
## Frist bezahlt, erlassen bzw. noch offen
const STATE_PAID := "paid"
const STATE_WAIVED := "waived"
const STATE_OPEN := "open"
## Zustände, die die UI ausgegraut zeigt
const PAST_STATES := [STATE_PAST, STATE_ATTENDED, STATE_MISSED, STATE_PAID, STATE_WAIVED]


## Plan für `day` (Standard: heute). Rückgabe: {"day", "now_minutes", "entries", "now_index", "next_later"}.
## next_later = erster offener Termin nach diesem Tag ({} wenn keiner) – für den Hinweis bei leerem Tag.
static func for_day(game, day: int = -1) -> Dictionary:
	var now: int = game.time.get_minutes()
	if day < 1:
		day = TimeSystemScript.day_of(now)
	var entries: Array[Dictionary] = []
	for definition in game.appointments.get_catalog().get_all():
		if TimeSystemScript.day_of(definition.start_minutes) == day:
			entries.append(_appointment_entry(game, definition, now))
	for instance in game.obligations.get_instances():
		var due_day := TimeSystemScript.day_of(instance["due_minutes"])
		var is_open: bool = instance["status"] == ObligationSystemScript.STATUS_OPEN
		if due_day == day or (is_open and due_day < day and day == TimeSystemScript.day_of(now)):
			entries.append(_obligation_entry(game, instance, due_day < day))
	entries.sort_custom(_comes_before)
	var next_found := false
	var now_index := 0
	for entry in entries:
		if entry["start_minutes"] <= now:
			now_index += 1
		if entry["kind"] == KIND_APPOINTMENT and not next_found \
				and entry["state"] == STATE_UPCOMING:
			entry["state"] = STATE_NEXT
			next_found = true
	return {"day": day, "now_minutes": now, "entries": entries, "now_index": now_index,
			"next_later": _next_later(game, day)}


static func is_past(entry: Dictionary) -> bool:
	return entry["state"] in PAST_STATES


static func _appointment_entry(game, definition, now: int) -> Dictionary:
	var end: int = definition.start_minutes + definition.duration_minutes
	var state := STATE_UPCOMING
	if game.appointments.is_attended(definition.id):
		state = STATE_ATTENDED
	elif game.appointments.is_missed(definition.id):
		state = STATE_MISSED
	elif now >= end:
		state = STATE_PAST
	return {
		"kind": KIND_APPOINTMENT, "id": definition.id, "title": definition.title,
		"start_minutes": definition.start_minutes, "end_minutes": end,
		"location_id": definition.location, "travel_minutes": game.locations.travel_minutes_to(definition.location),
		"amount_cents": 0, "state": state, "overdue": false,
	}


static func _obligation_entry(game, instance: Dictionary, overdue: bool) -> Dictionary:
	var is_open: bool = instance["status"] == ObligationSystemScript.STATUS_OPEN
	var amount: int = game.obligations.open_amount(instance["id"]) if is_open else instance["amount_cents"]
	var state := STATE_OPEN
	if instance["status"] == ObligationSystemScript.STATUS_PAID:
		state = STATE_PAID
	elif instance["status"] == ObligationSystemScript.STATUS_WAIVED:
		state = STATE_WAIVED
	return {
		"kind": KIND_OBLIGATION, "id": instance["id"], "title": game.obligations.get_label(instance["id"]),
		"start_minutes": instance["due_minutes"], "end_minutes": instance["due_minutes"],
		"location_id": "", "travel_minutes": 0, "amount_cents": amount,
		"state": state, "overdue": overdue,
	}


static func _comes_before(a: Dictionary, b: Dictionary) -> bool:
	if a["start_minutes"] != b["start_minutes"]:
		return a["start_minutes"] < b["start_minutes"]
	if a["kind"] != b["kind"]:
		return a["kind"] == KIND_OBLIGATION
	return a["id"] < b["id"]


static func _next_later(game, day: int) -> Dictionary:
	var best = null
	for definition in game.appointments.get_upcoming():
		if TimeSystemScript.day_of(definition.start_minutes) > day \
				and (best == null or definition.start_minutes < best.start_minutes):
			best = definition
	if best == null:
		return {}
	return {"id": best.id, "title": best.title, "start_minutes": best.start_minutes, "location_id": best.location}
