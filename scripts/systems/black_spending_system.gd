extends RefCounted

## Schwarzgeld ausgeben (U.17): Ist der Schalter an, bezahlen Aktivitäten und Ausrüstung („Alltag“) aus Schwarzgeld –
## nur wenn es reicht und das Tageslimit nicht überschritten wird, sonst wie bisher vom Privatkonto. Eingeschränkt:
## Miete, Fristen, Firma, Termine und Ereignisse zahlen nie aus Schwarzgeld. Jede Zahlung aus Schwarzgeld macht
## Hitze (je 100 €, mindestens `min_heat`). Regeln: data/underworld/black_spending.json. Die Systeme fragen
## `account_for` vor der Buchung und melden sie danach mit `record` (gebundene Methoden, keine Referenzen zurück).

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/black_spending.json"
const RULE_FIELDS := ["daily_limit_cents", "heat_per_100_euro", "min_heat"]


## Regeln. Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/black_spending.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Regeln fürs Schwarzgeld-Ausgeben müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Schwarzgeld ausgeben: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Schwarzgeld ausgeben: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
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
var _enabled := false
var _day := 0
var _spent_today := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, rules: Rules, organisation) -> void:
	_time = time
	_ledger = ledger
	_rules = rules
	_organisation = organisation


func get_rules() -> Rules:
	return _rules


## Schalter sichtbar: Organisation gegründet.
func is_available() -> bool:
	return _organisation.is_founded()


func is_enabled() -> bool:
	return _enabled


func set_enabled(on: bool) -> void:
	_enabled = on


func remaining_today() -> int:
	var used := _spent_today if _day == _time.get_day() else 0
	return maxi(0, _rules.get_value("daily_limit_cents") - used)


@warning_ignore("integer_division")
func heat_for(cost_cents: int) -> int:
	return maxi(_rules.get_value("min_heat"), cost_cents * _rules.get_value("heat_per_100_euro") / 10000)


## Konto für eine Alltags-Ausgabe: Schwarzgeld, wenn der Schalter an ist, es reicht und das Limit es erlaubt.
func account_for(cost_cents: int) -> String:
	if _enabled and is_available() and cost_cents > 0 and cost_cents <= remaining_today() \
			and _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK):
		return LedgerSystemScript.BLACK
	return LedgerSystemScript.PRIVATE


## Nach einer Buchung aus Schwarzgeld: Tagesbetrag und Hitze.
func record(cost_cents: int, label: String) -> void:
	if _day != _time.get_day():
		_day = _time.get_day()
		_spent_today = 0
	_spent_today += cost_cents
	var heat := heat_for(cost_cents)
	_organisation.change({"heat": heat})
	_notices.append("Bezahlt mit Schwarzgeld: %s %s (Hitze +%d)." % [label, LedgerSystemScript.format_cents(cost_cents), heat])


func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


func to_dict() -> Dictionary:
	return {"enabled": _enabled, "day": _day, "spent_today_cents": _spent_today}


## "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	if typeof(data.get("enabled")) != TYPE_BOOL:
		return "Schwarzgeld ausgeben: 'enabled' fehlt."
	for key in ["day", "spent_today_cents"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Schwarzgeld ausgeben: '%s' fehlt oder ist ungültig." % key
	_enabled = data["enabled"]
	_day = int(data["day"])
	_spent_today = int(data["spent_today_cents"])
	_notices.clear()
	return ""
