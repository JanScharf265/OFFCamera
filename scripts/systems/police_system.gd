extends RefCounted

## Polizei 1 (U.19): Aufmerksamkeit der Polizei in Stufen nach der Hitze – 0 keine, 1 Beobachtung, 2 Ermittlung.
## Regeln: data/underworld/police.json. Beim Tageswechsel (nach allen Hitze-Änderungen des Tages):
##  - Hitze ≥ observation_heat an days_to_escalate Tagen in Folge → Beobachtung; unter Beobachtung Hitze ≥
##    investigation_heat an days_to_escalate Tagen in Folge → Ermittlung mit erfundener Aktennummer.
##  - Hitze < calm_heat an days_to_calm Tagen in Folge → eine Stufe zurück (Ermittlung: Akte bleibt, ruht).
##  - In der Ermittlung füllt sich die Akte täglich um Hitze/10 × progress_per_10_heat bis 100 % (Folgen ab U.20).
## Jeder Stufenwechsel ist ein Ereignis im EventSystem („scripted“). Ein Anwalt wirft die Akte zurück (Buchung,
## Wartezeit). Verbunden mit Phase 5: Ereignis-Bedingung `min_police_level` und mehr Festnahme-Risiko der Crew.
## Keine Tricks gegen Ermittlungen – nur Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

const DEFAULT_PATH := "res://data/underworld/police.json"
const CATEGORY := "underworld_lawyer"
const SOURCE := "police"
const RULE_FIELDS := ["observation_heat", "investigation_heat", "days_to_escalate", "calm_heat", "days_to_calm",
		"progress_per_10_heat", "lawyer_cost_cents", "lawyer_progress", "lawyer_cooldown_days", "arrest_bonus_per_level"]
const LEVEL_LABELS := ["keine Auffälligkeit", "Beobachtung", "Ermittlung"]
const EVENTS := {"observation": "police_observation", "investigation": "police_investigation", "calm": "police_calm"}
const MAX_PROGRESS := 100


## Regeln. Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/police.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Polizeiregeln müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Polizeiregeln: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Polizeiregeln: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
		if errors.is_empty() and (result["days_to_escalate"] < 1 or result["days_to_calm"] < 1
				or result["calm_heat"] >= result["observation_heat"] or result["observation_heat"] > result["investigation_heat"]):
			errors.append("Polizeiregeln: Tage ≥ 1 und calm_heat < observation_heat ≤ investigation_heat.")
		if not errors.is_empty():
			return false
		values = result
		return true

	func get_value(key: String) -> int:
		return values.get(key, 0)


var _time
var _ledger: LedgerSystemScript
var _rules: Rules
var _organisation
var _get_seed: Callable
var _trigger_scripted: Callable
var _level := 0
var _hot_days := 0
var _calm_days := 0
var _progress := 0
var _case := ""
var _since_day := 0
var _lawyer_day := -100
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, rules: Rules, organisation, get_seed: Callable,
		trigger_scripted: Callable) -> void:
	_time = time
	_ledger = ledger
	_rules = rules
	_organisation = organisation
	_get_seed = get_seed
	_trigger_scripted = trigger_scripted
	_last_processed_day = time.get_day()


func get_rules() -> Rules:
	return _rules


func get_level() -> int:
	return _level


func get_progress() -> int:
	return _progress


func get_case() -> String:
	return _case


func get_since_day() -> int:
	return _since_day


func level_label() -> String:
	return LEVEL_LABELS[_level]


## Mehr Festnahme-Risiko je Stufe (Prozentpunkte) – vom CrewSystem.
func arrest_bonus() -> int:
	return _level * _rules.get_value("arrest_bonus_per_level")


## Für Ereignis-Bedingungen (EventSystem): Stufe 0–2.
func condition_values() -> Dictionary:
	return {"police_level": _level}


## Für Ereignistexte: {case} = Aktennummer.
func text_context(instance_id: String) -> Dictionary:
	return {"case": _case} if instance_id.begins_with(EVENTS["investigation"]) else {}


## "" wenn ein Anwalt jetzt etwas tun kann, sonst ein Grund.
func check_lawyer() -> String:
	if _level < 2:
		return "Es gibt keine Ermittlung."
	if _progress <= 0:
		return "Die Akte ist leer."
	var wait: int = _lawyer_day + _rules.get_value("lawyer_cooldown_days") - _time.get_day()
	if wait > 0:
		return "Der Anwalt arbeitet noch (%d Tag%s)." % [wait, "" if wait == 1 else "e"]
	var cost := _rules.get_value("lawyer_cost_cents")
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## Anwalt: Buchung → Akte zurück. "" = erledigt.
func hire_lawyer() -> String:
	var reason := check_lawyer()
	if not reason.is_empty():
		return reason
	var cost := _rules.get_value("lawyer_cost_cents")
	var entry := _ledger.post(-cost, CATEGORY, "Anwalt: %s" % _case, SOURCE, _case,
			"police:lawyer:%d" % _time.get_day(), false, payment_account(cost))
	if entry == null:
		return "Die Buchung ist fehlgeschlagen."
	_progress = maxi(0, _progress - _rules.get_value("lawyer_progress"))
	_lawyer_day = _time.get_day()
	return ""


func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle (nach allen Hitze-Änderungen des Tages).
@warning_ignore("integer_division")
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	if not _organisation.is_founded():
		return
	var heat: int = _organisation.get_value("heat")
	var threshold := _rules.get_value("observation_heat") if _level == 0 else _rules.get_value("investigation_heat")
	_hot_days = _hot_days + 1 if _level < 2 and heat >= threshold else 0
	_calm_days = _calm_days + 1 if _level > 0 and heat < _rules.get_value("calm_heat") else 0
	if _hot_days >= _rules.get_value("days_to_escalate"):
		_level += 1
		_hot_days = 0
		_since_day = day
		if _level == 2 and _case.is_empty():
			_case = "MB-%04d" % (EventSystemScript.fnv1a("%d:case" % _get_seed.call()) % 10000)
		_trigger(EVENTS["observation"] if _level == 1 else EVENTS["investigation"], day)
	elif _calm_days >= _rules.get_value("days_to_calm"):
		_level -= 1
		_calm_days = 0
		_since_day = day
		_trigger(EVENTS["calm"], day)
	if _level == 2 and _progress < MAX_PROGRESS:
		_progress = mini(MAX_PROGRESS, _progress + heat / 10 * _rules.get_value("progress_per_10_heat"))
		if _progress >= MAX_PROGRESS:
			_notices.append("Akte %s: Die Ermittler haben genug zusammen. Es kann jederzeit so weit sein." % _case)


func _trigger(event_id: String, day: int) -> void:
	if _trigger_scripted.is_valid():
		_trigger_scripted.call(event_id, day)


func to_dict() -> Dictionary:
	return {"level": _level, "hot_days": _hot_days, "calm_days": _calm_days, "progress": _progress, "case": _case,
			"since_day": _since_day, "lawyer_day": _lawyer_day, "last_processed_day": _last_processed_day}


## "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	for key in ["level", "hot_days", "calm_days", "progress", "since_day", "last_processed_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Polizei: '%s' fehlt oder ist ungültig." % key
	if int(data["level"]) > 2 or int(data["progress"]) > MAX_PROGRESS or typeof(data.get("case")) != TYPE_STRING \
			or not DataReaderScript.is_whole_number(data.get("lawyer_day")):
		return "Polizei: Stufe, Akte oder Anwalt ungültig."
	_level = int(data["level"])
	_hot_days = int(data["hot_days"])
	_calm_days = int(data["calm_days"])
	_progress = int(data["progress"])
	_case = data["case"]
	_since_day = int(data["since_day"])
	_lawyer_day = int(data["lawyer_day"])
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
