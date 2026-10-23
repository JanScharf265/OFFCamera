extends RefCounted

## Die Organisation (U.2): Name, Respekt in der Szene, Hitze (Aufmerksamkeit der Polizei) und Stabilität, je 0–100 –
## reine Spielwerte. Gegründet wird sie erst durch den Einstieg in die Unterwelt (U.3); bis dahin ist nichts
## sichtbar und nichts ändert sich. Hitze sinkt an jedem ruhigen Tag (ohne neue Hitze am Vortag) um
## `heat_decay_per_quiet_day` – als Schritt im DayCycle, jeder Tag höchstens einmal (auch nach dem Laden).
## Werte ändern nur Systeme über change(); die UI zeigt an.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const OrganisationRulesScript := preload("res://scripts/systems/organisation_rules.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal founded(organisation_name: String)
signal changed(key: String, old_value: int, new_value: int)

const KEYS := ["respect", "heat", "stability"]
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


func _init(time: TimeSystemScript, rules: OrganisationRulesScript) -> void:
	_time = time
	_rules = rules
	_values = rules.start.duplicate()
	_last_processed_day = time.get_day()


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
	if not _founded or get_value("heat") <= 0 or _heat_raised_day >= day - 1:
		return
	var old_value := get_value("heat")
	_values["heat"] = maxi(old_value - _rules.heat_decay_per_quiet_day, MIN_VALUE)
	if _values["heat"] != old_value:
		changed.emit("heat", old_value, _values["heat"])


func to_dict() -> Dictionary:
	return {"founded": _founded, "name": _name, "respect": get_value("respect"), "heat": get_value("heat"),
			"stability": get_value("stability"), "heat_raised_day": _heat_raised_day,
			"last_processed_day": _last_processed_day}


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
	for key in ["heat_raised_day", "last_processed_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Organisation: '%s' fehlt oder ist ungültig." % key
	if data["founded"] and String(data["name"]).strip_edges().is_empty():
		return "Organisation: gegründet, aber ohne Namen."
	_founded = data["founded"]
	_name = data["name"]
	_values = values
	_heat_raised_day = int(data["heat_raised_day"])
	_last_processed_day = int(data["last_processed_day"])
	return ""
