class_name ObligationCatalog
extends RefCounted

## Lädt und prüft Fristen (JSON, Phase 5). Alles-oder-nichts wie die anderen Kataloge.
## Format je Eintrag:
##   id, display_name, description (optional), account ("private"/"company"), category,
##   requires (optional: "company"), schedule {weekday ("Mo".."So"), first_day ≥ 2},
##   amount {fixed_cents > 0} ODER {profit_percent 1–100},
##   grace_days ≥ 0, reminder_fee_cents ≥ 0,
##   overdue_effects (optional, PlayerStats), overdue_company_effects (optional: utilization, reputation)

const ObligationDefinitionScript := preload("res://scripts/models/obligation_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const DEFAULT_PATH := "res://data/obligations/obligations.json"
const ACCOUNTS := ["private", "company"]
const COMPANY_KEYS := ["utilization", "reputation"]

var errors: PackedStringArray = []

var _by_id := {}
var _ids := PackedStringArray()


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		_by_id.clear()
		_ids.clear()
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_by_id.clear()
	_ids.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Fristen müssen eine Liste sein."])
		return false
	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Frist '%s': ID kommt doppelt vor." % definition.id)
			continue
		by_id[definition.id] = definition
		ids.append(definition.id)
	errors = reader.errors
	if not errors.is_empty():
		return false
	_by_id = by_id
	_ids = ids
	return true


func has(id: String) -> bool:
	return _by_id.has(id)


func get_definition(id: String) -> ObligationDefinitionScript:
	return _by_id.get(id)


## IDs in der Reihenfolge der Datei.
func get_ids() -> PackedStringArray:
	return _ids.duplicate()


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> ObligationDefinitionScript:
	var where := "Frist #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Frist '%s'" % id

	var definition := ObligationDefinitionScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, false)
	definition.account = reader.string_field(entry, "account", where, true)
	if not definition.account.is_empty() and definition.account not in ACCOUNTS:
		reader.errors.append("%s: 'account' muss \"private\" oder \"company\" sein." % where)
	definition.category = reader.string_field(entry, "category", where, true)
	definition.requires = reader.string_field(entry, "requires", where, false)
	if definition.requires not in ["", "company"]:
		reader.errors.append("%s: 'requires' darf nur \"company\" sein." % where)

	var schedule: Variant = entry.get("schedule")
	if typeof(schedule) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'schedule' fehlt oder ist kein Objekt." % where)
	else:
		var weekday: Variant = schedule.get("weekday")
		definition.weekday = TimeSystemScript.WEEKDAY_NAMES.find(weekday) if typeof(weekday) == TYPE_STRING else -1
		if definition.weekday < 0:
			reader.errors.append("%s: 'schedule.weekday' muss einer von %s sein." % [where,
					", ".join(PackedStringArray(TimeSystemScript.WEEKDAY_NAMES))])
		definition.first_day = reader.int_field(schedule, "first_day", "%s (schedule)" % where, true)
		if definition.first_day < 2:
			reader.errors.append("%s: 'schedule.first_day' muss mindestens 2 sein (fällig beim Tageswechsel)." % where)

	var amount: Variant = entry.get("amount")
	if typeof(amount) != TYPE_DICTIONARY or amount.has("fixed_cents") == amount.has("profit_percent"):
		reader.errors.append("%s: 'amount' braucht genau eins von 'fixed_cents' oder 'profit_percent'." % where)
	else:
		definition.fixed_cents = reader.int_field(amount, "fixed_cents", "%s (amount)" % where, false)
		definition.profit_percent = reader.int_field(amount, "profit_percent", "%s (amount)" % where, false)
		if amount.has("fixed_cents") and definition.fixed_cents <= 0:
			reader.errors.append("%s: 'fixed_cents' muss größer als 0 sein." % where)
		if amount.has("profit_percent") and (definition.profit_percent < 1 or definition.profit_percent > 100):
			reader.errors.append("%s: 'profit_percent' muss zwischen 1 und 100 liegen." % where)

	definition.grace_days = reader.int_field(entry, "grace_days", where, true)
	definition.reminder_fee_cents = reader.int_field(entry, "reminder_fee_cents", where, true)
	if definition.grace_days < 0 or definition.reminder_fee_cents < 0:
		reader.errors.append("%s: 'grace_days' und 'reminder_fee_cents' dürfen nicht negativ sein." % where)
	definition.overdue_effects = reader.effects_field(entry, where, "overdue_effects")
	definition.overdue_company_effects = {}
	var company: Variant = entry.get("overdue_company_effects", {})
	if typeof(company) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'overdue_company_effects' muss ein Objekt sein." % where)
	else:
		for key in company:
			if key not in COMPANY_KEYS or not DataReaderScript.is_whole_number(company[key]):
				reader.errors.append("%s: 'overdue_company_effects' enthält ungültigen Wert '%s'." % [where, key])
			else:
				definition.overdue_company_effects[key] = int(company[key])
	return definition if reader.errors.size() == error_count else null
