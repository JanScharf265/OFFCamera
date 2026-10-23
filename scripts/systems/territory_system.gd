extends RefCounted

## Gebiete übernehmen, halten, verlieren (U.13). Regeln: data/underworld/territory.json, Gebiete: DistrictCatalog.
## Einfluss je Gebiet 0–100: Dealer, die einem Gebiet zugeteilt sind und am Tag verkauft haben, bringen Einfluss
## (CrewSystem ruft `add_influence` bei der Abrechnung). Danach (eigener DayCycle-Schritt) drücken die Rivalen:
## −Rivalen/`rival_divisor` je Tag, bei eigenen Gebieten nur `controlled_pressure_percent` davon. Ab
## `claim_min_influence` kann man ein Gebiet beanspruchen (Buchung, Respekt +); fällt der Einfluss eines eigenen
## Gebiets unter `lose_below`, ist es weg (Respekt und Stabilität −). Eigene Gebiete: Dealer dort verkaufen
## `controlled_unit_bonus` Einheiten mehr. Reine Spielwerte, keine Gewalt – nur Zahlen und Folgen.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const DistrictCatalogScript := preload("res://scripts/systems/district_catalog.gd")

signal claimed(district_id: String)

const DEFAULT_PATH := "res://data/underworld/territory.json"
const CATEGORY := "underworld_territory"
const SOURCE := "territory"
const RULE_FIELDS := ["claim_min_influence", "claim_cost_cents", "claim_respect", "lose_below", "loss_respect",
		"loss_stability", "influence_base", "influence_skill_per_point", "rival_divisor", "controlled_pressure_percent",
		"controlled_unit_bonus"]
const MAX_INFLUENCE := 100


## Regeln (ganze Zahlen ≥ 0). Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/territory.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Gebietsregeln müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Gebietsregeln: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Gebietsregeln: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
		if errors.is_empty() and (result["rival_divisor"] < 1 or result["influence_skill_per_point"] < 1
				or result["claim_min_influence"] > MAX_INFLUENCE or result["lose_below"] >= result["claim_min_influence"]):
			errors.append("Gebietsregeln: Teiler ≥ 1, claim_min_influence ≤ 100 und lose_below < claim_min_influence.")
		if not errors.is_empty():
			return false
		values = result
		return true

	func get_value(key: String) -> int:
		return values.get(key, 0)


var _time
var _ledger: LedgerSystemScript
var _districts: DistrictCatalogScript
var _rules: Rules
var _organisation
## district_id -> Einfluss (nur Gebiete mit Einfluss > 0)
var _influence := {}
## district_id -> Tag der Übernahme
var _controlled := {}
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, districts: DistrictCatalogScript, rules: Rules, organisation) -> void:
	_time = time
	_ledger = ledger
	_districts = districts
	_rules = rules
	_organisation = organisation
	_last_processed_day = time.get_day()


func get_districts() -> DistrictCatalogScript:
	return _districts


func get_rules() -> Rules:
	return _rules


func get_influence(district_id: String) -> int:
	return int(_influence.get(district_id, 0))


func is_controlled(district_id: String) -> bool:
	return _controlled.has(district_id)


func controlled_since(district_id: String) -> int:
	return int(_controlled.get(district_id, -1))


func count_controlled() -> int:
	return _controlled.size()


## Einfluss, den ein Dealer mit diesem Können an einem Tag bringt.
@warning_ignore("integer_division")
func influence_for_skill(skill: int) -> int:
	return _rules.get_value("influence_base") + skill / _rules.get_value("influence_skill_per_point")


## Druck der Rivalen je Tag (eigenes Gebiet: nur ein Teil).
@warning_ignore("integer_division")
func rival_pressure(district_id: String) -> int:
	var district = _districts.get_definition(district_id)
	if district == null:
		return 0
	var pressure: int = district.rivals / _rules.get_value("rival_divisor")
	if is_controlled(district_id):
		pressure = pressure * _rules.get_value("controlled_pressure_percent") / 100
	return pressure


## Zusätzliche Einheiten für einen Dealer in diesem Gebiet.
func unit_bonus(district_id: String) -> int:
	return _rules.get_value("controlled_unit_bonus") if is_controlled(district_id) else 0


## Von der Dealer-Abrechnung (CrewSystem).
func add_influence(district_id: String, amount: int) -> void:
	if _districts.get_definition(district_id) == null or amount <= 0:
		return
	_influence[district_id] = mini(MAX_INFLUENCE, get_influence(district_id) + amount)


## Konto für eine Zahlung: Schwarzgeld, wenn es reicht, sonst Privatkonto.
func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## "" wenn das Gebiet jetzt beansprucht werden kann, sonst ein Grund.
func check_claim(district_id: String) -> String:
	if _districts.get_definition(district_id) == null:
		return "Unbekanntes Gebiet: %s" % district_id
	if not _organisation.is_founded():
		return "Erst eine Organisation gründen."
	if is_controlled(district_id):
		return "Gehört schon dir."
	var needed := _rules.get_value("claim_min_influence")
	if get_influence(district_id) < needed:
		return "Erst %d Einfluss (jetzt %d)." % [needed, get_influence(district_id)]
	var cost := _rules.get_value("claim_cost_cents")
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Beansprucht: Buchung → Besitz → Respekt. "" = übernommen.
func claim(district_id: String) -> String:
	var reason := check_claim(district_id)
	if not reason.is_empty():
		return reason
	var district = _districts.get_definition(district_id)
	var cost := _rules.get_value("claim_cost_cents")
	if cost > 0:
		var entry := _ledger.post(-cost, CATEGORY, "Gebiet beansprucht: %s" % district.display_name, SOURCE, district_id,
				"territory:%s:%d" % [district_id, _time.get_day()], false, payment_account(cost))
		if entry == null:
			return "Die Buchung ist fehlgeschlagen."
	_controlled[district_id] = _time.get_day()
	_organisation.change({"respect": _rules.get_value("claim_respect")})
	claimed.emit(district_id)
	return ""


## Hinweise (Gebiet verloren) seit dem letzten Aufruf.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle (nach der Dealer-Abrechnung): Druck der Rivalen, dann ggf. Verlust.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	for district in _districts.get_all():
		var influence := get_influence(district.id)
		if influence <= 0:
			continue
		influence = maxi(0, influence - rival_pressure(district.id))
		if influence == 0:
			_influence.erase(district.id)
		else:
			_influence[district.id] = influence
		if is_controlled(district.id) and influence < _rules.get_value("lose_below"):
			_controlled.erase(district.id)
			_organisation.change({"respect": -_rules.get_value("loss_respect"),
					"stability": -_rules.get_value("loss_stability")})
			_notices.append("Gebiet verloren: %s – die Rivalen haben übernommen (Respekt −%d, Stabilität −%d)." % [
					district.display_name, _rules.get_value("loss_respect"), _rules.get_value("loss_stability")])


func to_dict() -> Dictionary:
	return {"influence": _influence.duplicate(), "controlled": _controlled.duplicate(),
			"last_processed_day": _last_processed_day}


## Unbekannte Gebiete (aus den Daten entfernt) bleiben erhalten. "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var influence := {}
	var controlled := {}
	for pair in [["influence", influence, MAX_INFLUENCE], ["controlled", controlled, -1]]:
		var raw: Variant = data.get(pair[0])
		if typeof(raw) != TYPE_DICTIONARY:
			return "Gebiete: '%s' fehlt oder ist kein Objekt." % pair[0]
		for id in raw:
			var value: Variant = raw[id]
			if typeof(id) != TYPE_STRING or not DataReaderScript.is_whole_number(value) or int(value) < 0 \
					or (pair[2] > 0 and int(value) > pair[2]):
				return "Gebiete: ungültiger Eintrag in '%s'." % pair[0]
			pair[1][id] = int(value)
	if not DataReaderScript.is_whole_number(data.get("last_processed_day")) or int(data["last_processed_day"]) < 0:
		return "Gebiete: 'last_processed_day' fehlt oder ist ungültig."
	_influence = influence
	_controlled = controlled
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
