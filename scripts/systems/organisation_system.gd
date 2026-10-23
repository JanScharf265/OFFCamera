extends RefCounted

## Die Organisation (U.2): Name, Respekt in der Szene, Hitze (Aufmerksamkeit der Polizei) und Stabilität, je 0–100 –
## reine Spielwerte. Gegründet wird sie erst durch den Einstieg in die Unterwelt (U.3); bis dahin ist nichts
## sichtbar und nichts ändert sich. Hitze sinkt an jedem ruhigen Tag (ohne neue Hitze am Vortag) um
## `heat_decay_per_quiet_day` – als Schritt im DayCycle, jeder Tag höchstens einmal (auch nach dem Laden).
## Werte ändern nur Systeme über change(); die UI zeigt an.
##
## Einstieg (U.3): Ab `intro.first_day` löst der Tageswechsel das Ereignis „Liegeplatz 14“ aus (EventSystem,
## „scripted“) – ein Code-Pfad für neue und alte Spielstände. „Zuhören“ → der Name fehlt noch (needs_name()), die UI
## fragt ihn ab und ruft found(); jede andere Antwort → das Ereignis kommt nach `intro.retry_days` wieder.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const OrganisationRulesScript := preload("res://scripts/systems/organisation_rules.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal founded(organisation_name: String)
signal changed(key: String, old_value: int, new_value: int)

const KEYS := ["respect", "heat", "stability"]
## Stand des Einstiegs: noch nichts, Ereignis offen, angenommen (Name fehlt), abgelehnt (kommt wieder), gegründet
const INTRO_NONE := "none"
const INTRO_OFFERED := "offered"
const INTRO_ACCEPTED := "accepted"
const INTRO_DECLINED := "declined"
const INTRO_DONE := "done"
const INTRO_STATES := [INTRO_NONE, INTRO_OFFERED, INTRO_ACCEPTED, INTRO_DECLINED, INTRO_DONE]
const LABELS := {"respect": "Respekt", "heat": "Hitze", "stability": "Stabilität"}
const MIN_VALUE := 0
const MAX_VALUE := 100
## Anzeige der Hitze (nur Farbe, keine Spielregel): ab 30 gelb, ab 60 rot.
const HEAT_WARN_FROM := 30
const HEAT_DANGER_FROM := 60

var _time: TimeSystemScript
var _rules: OrganisationRulesScript
var _founded := false
var _name := ""
var _values := {}
## Letzter Tag, an dem die Hitze gestiegen ist (0 = nie).
var _heat_raised_day := 0
## Letzter Tag, dessen Tageswechsel verarbeitet wurde.
var _last_processed_day := 0
var _intro_state := INTRO_NONE
## Ab diesem Tag kommt das Einstiegs-Ereignis (wieder).
var _next_offer_day := 2
var _events


func _init(time: TimeSystemScript, rules: OrganisationRulesScript) -> void:
	_time = time
	_rules = rules
	_values = rules.start.duplicate()
	_last_processed_day = time.get_day()
	_next_offer_day = rules.intro_first_day


## Vom GameState (U.3): Das EventSystem löst den Einstieg aus; seine Antwort kommt über event_resolved.
func set_events(events) -> void:
	_events = events
	events.event_resolved.connect(_on_event_resolved)


func get_intro_state() -> String:
	return _intro_state


## true, wenn „Zuhören“ gewählt wurde und der Name noch fehlt – dann fragt die UI ihn ab.
func needs_name() -> bool:
	return _intro_state == INTRO_ACCEPTED and not _founded


func is_founded() -> bool:
	return _founded


func get_name() -> String:
	return _name


func get_value(key: String) -> int:
	return int(_values.get(key, 0))


## 0 = ruhig, 1 = erhöht, 2 = gefährlich (nur für die Anzeige).
static func heat_level(value: int) -> int:
	if value >= HEAT_DANGER_FROM:
		return 2
	if value >= HEAT_WARN_FROM:
		return 1
	return 0


## "" wenn die Organisation mit diesem Namen gegründet werden kann, sonst der Grund.
func check_found(organisation_name: String) -> String:
	if _founded:
		return "Die Organisation gibt es schon."
	var trimmed := organisation_name.strip_edges()
	if trimmed.length() < _rules.name_min_length:
		return "Der Name ist zu kurz (mindestens %d Zeichen)." % _rules.name_min_length
	if trimmed.length() > _rules.name_max_length:
		return "Der Name ist zu lang (höchstens %d Zeichen)." % _rules.name_max_length
	return ""


## Gründet die Organisation (Startwerte aus den Regeln). "" = gegründet.
func found(organisation_name: String) -> String:
	var reason := check_found(organisation_name)
	if not reason.is_empty():
		return reason
	_founded = true
	_name = organisation_name.strip_edges()
	_values = _rules.start.duplicate()
	_intro_state = INTRO_DONE
	founded.emit(_name)
	return ""


## Ändert Werte (z. B. {"heat": 5}); Ergebnis wird auf 0–100 begrenzt. Ohne Organisation passiert nichts (false).
func change(deltas: Dictionary) -> bool:
	if not _founded:
		return false
	for key in deltas:
		if key not in KEYS:
			push_error("OrganisationSystem: unbekannter Wert '%s'." % key)
			return false
	for key in deltas:
		var old_value := get_value(key)
		var new_value := clampi(old_value + int(deltas[key]), MIN_VALUE, MAX_VALUE)
		_values[key] = new_value
		if key == "heat" and int(deltas[key]) > 0:
			_heat_raised_day = _time.get_day()
		if new_value != old_value:
			changed.emit(key, old_value, new_value)
	return true


## Vom DayCycle: Ruhige Tage kühlen ab. Ein Tag ist ruhig, wenn am Vortag keine Hitze dazukam.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	_offer_intro(day)
	if not _founded or get_value("heat") <= 0 or _heat_raised_day >= day - 1:
		return
	var old_value := get_value("heat")
	_values["heat"] = maxi(old_value - _rules.heat_decay_per_quiet_day, MIN_VALUE)
	if _values["heat"] != old_value:
		changed.emit("heat", old_value, _values["heat"])


func _offer_intro(day: int) -> void:
	if _founded or _events == null or _intro_state not in [INTRO_NONE, INTRO_DECLINED] or day < _next_offer_day:
		return
	if _events.get_definition_for(_rules.intro_event) == null:
		return  # Daten ohne Einstiegs-Ereignis (nur in Tests mit eigenen Daten; die echten prüft GameData)
	if not _events.trigger_scripted(_rules.intro_event, day).is_empty():
		_intro_state = INTRO_OFFERED


func _on_event_resolved(instance_id: String, option_id: String) -> void:
	if instance_id.get_slice("@", 0) != _rules.intro_event or _intro_state != INTRO_OFFERED:
		return
	if option_id == _rules.intro_accept_option:
		_intro_state = INTRO_ACCEPTED
	else:
		_intro_state = INTRO_DECLINED
		_next_offer_day = _time.get_day() + _rules.intro_retry_days


func to_dict() -> Dictionary:
	return {"founded": _founded, "name": _name, "respect": get_value("respect"), "heat": get_value("heat"),
			"stability": get_value("stability"), "heat_raised_day": _heat_raised_day,
			"last_processed_day": _last_processed_day, "intro_state": _intro_state, "next_offer_day": _next_offer_day}


## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	if typeof(data.get("founded")) != TYPE_BOOL:
		return "Organisation: 'founded' fehlt."
	if typeof(data.get("name")) != TYPE_STRING:
		return "Organisation: 'name' fehlt."
	var values := {}
	for key in KEYS:
		var value: Variant = data.get(key)
		if not DataReaderScript.is_whole_number(value) or int(value) < MIN_VALUE or int(value) > MAX_VALUE:
			return "Organisation: '%s' fehlt oder liegt nicht zwischen 0 und 100." % key
		values[key] = int(value)
	if typeof(data.get("intro_state")) != TYPE_STRING or data["intro_state"] not in INTRO_STATES:
		return "Organisation: 'intro_state' fehlt oder ist ungültig."
	if data["founded"] != (data["intro_state"] == INTRO_DONE) and data["founded"]:
		return "Organisation: gegründet, aber Einstieg nicht abgeschlossen."
	for key in ["heat_raised_day", "last_processed_day", "next_offer_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Organisation: '%s' fehlt oder ist ungültig." % key
	if data["founded"] and String(data["name"]).strip_edges().is_empty():
		return "Organisation: gegründet, aber ohne Namen."
	_founded = data["founded"]
	_name = data["name"]
	_values = values
	_heat_raised_day = int(data["heat_raised_day"])
	_last_processed_day = int(data["last_processed_day"])
	_intro_state = data["intro_state"]
	_next_offer_day = int(data["next_offer_day"])
	return ""
