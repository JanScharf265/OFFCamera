extends RefCounted

## Waschen über die Tarnfirma (U.16) – reine Spielmechanik: Schwarzgeld wird mit einer Gebühr zu Geld auf dem
## Firmenkonto. Regeln: data/underworld/laundering.json (Gebühr %, Tageslimit, Schrittweite, Hitze je 1.000 €).
## Zwei Buchungen im Ledger (Schwarzgeld − Betrag, Firmenkonto + Betrag − Gebühr), keine Spielzeit, Hitze als Risiko.
## Nur mit gegründeter Organisation und gegründetem Unternehmen. Keine realen Abläufe – ein Button und Zahlen.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/laundering.json"
const CATEGORY_OUT := "underworld_laundering"
const CATEGORY_IN := "laundered_revenue"
const SOURCE := "laundering"
const RULE_FIELDS := ["fee_percent", "daily_limit_cents", "step_cents", "heat_per_1000_euro"]


## Regeln. Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/laundering.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Waschregeln müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Waschregeln: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Waschregeln: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
		if errors.is_empty() and (result["fee_percent"] > 100 or result["step_cents"] < 1
				or result["daily_limit_cents"] < result["step_cents"]):
			errors.append("Waschregeln: fee_percent ≤ 100, step_cents ≥ 1 und daily_limit_cents ≥ step_cents.")
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
var _company
## Tag und heute schon gewaschener Betrag (Cent); insgesamt gewaschen (Cent)
var _day := 0
var _today_cents := 0
var _total_cents := 0
var _count := 0


func _init(time, ledger: LedgerSystemScript, rules: Rules, organisation, company) -> void:
	_time = time
	_ledger = ledger
	_rules = rules
	_organisation = organisation
	_company = company


func get_rules() -> Rules:
	return _rules


## Abschnitt sichtbar: Organisation und Unternehmen gegründet.
func is_available() -> bool:
	return _organisation.is_founded() and _company.is_founded()


## Heute noch möglich (Cent).
func remaining_today() -> int:
	var used := _today_cents if _day == _time.get_day() else 0
	return maxi(0, _rules.get_value("daily_limit_cents") - used)


func get_total() -> int:
	return _total_cents


@warning_ignore("integer_division")
func fee_for(amount_cents: int) -> int:
	return amount_cents * _rules.get_value("fee_percent") / 100


@warning_ignore("integer_division")
func heat_for(amount_cents: int) -> int:
	return amount_cents * _rules.get_value("heat_per_1000_euro") / 100000


## "" wenn der Betrag jetzt gewaschen werden kann, sonst ein Grund.
func check(amount_cents: int) -> String:
	if not _organisation.is_founded():
		return "Erst eine Organisation gründen."
	if not _company.is_founded():
		return "Dafür braucht es ein Unternehmen."
	var step := _rules.get_value("step_cents")
	if amount_cents < step or amount_cents % step != 0:
		return "Betrag in Schritten von %s." % LedgerSystemScript.format_cents(step)
	if amount_cents > remaining_today():
		return "Heute noch %s möglich." % LedgerSystemScript.format_cents(remaining_today()) if remaining_today() > 0 \
				else "Für heute ist das Limit erreicht."
	if not _ledger.can_afford(amount_cents, LedgerSystemScript.BLACK):
		return "Nicht genug Schwarzgeld (%s)." % LedgerSystemScript.format_cents(_ledger.get_balance(LedgerSystemScript.BLACK))
	return ""


## Wäscht: Schwarzgeld − Betrag → Firmenkonto + (Betrag − Gebühr) → Hitze. "" = gewaschen.
func launder(amount_cents: int) -> String:
	var reason := check(amount_cents)
	if not reason.is_empty():
		return reason
	var key := "launder:%d:%d" % [_time.get_day(), _count + 1]
	var out := _ledger.post(-amount_cents, CATEGORY_OUT, "Waschen über die Firma", SOURCE, key, key + "|out", false,
			LedgerSystemScript.BLACK)
	if out == null:
		return "Die Buchung ist fehlgeschlagen."
	var net := amount_cents - fee_for(amount_cents)
	if net > 0:
		var into := _ledger.post(net, CATEGORY_IN, "Umsatz (gewaschen, Gebühr %d %%)" % _rules.get_value("fee_percent"),
				SOURCE, key, key + "|in", false, LedgerSystemScript.COMPANY)
		if into == null:
			push_error("LaunderingSystem: Gutschrift '%s' abgelehnt." % key)
	if _day != _time.get_day():
		_day = _time.get_day()
		_today_cents = 0
	_today_cents += amount_cents
	_total_cents += amount_cents
	_count += 1
	var heat := heat_for(amount_cents)
	if heat > 0:
		_organisation.change({"heat": heat})
	return ""


func to_dict() -> Dictionary:
	return {"day": _day, "today_cents": _today_cents, "total_cents": _total_cents, "count": _count}


## "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	for key in ["day", "today_cents", "total_cents", "count"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Waschen: '%s' fehlt oder ist ungültig." % key
	_day = int(data["day"])
	_today_cents = int(data["today_cents"])
	_total_cents = int(data["total_cents"])
	_count = int(data["count"])
	return ""
