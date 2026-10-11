class_name CompanyTypeCatalog
extends RefCounted

## Lädt und prüft Unternehmensarten (JSON, Phase 4). Alles-oder-nichts wie die anderen Kataloge.
## Pflichtfelder je Eintrag: id, display_name, found_location, founding_minutes > 0,
## founding_fee_cents > 0, min_deposit_cents > 0, start_utilization/start_reputation 0–100,
## fixed_costs_per_day_cents ≥ 0, base_revenue_per_day_cents ≥ 0, revenue_per_1000_followers_cents ≥ 0,
## utilization_decay_per_day ≥ 0. Optional: description.

const CompanyTypeScript := preload("res://scripts/models/company_type.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/company/company_types.json"
const POSITIVE_FIELDS := ["founding_minutes", "founding_fee_cents", "min_deposit_cents"]
const NON_NEGATIVE_FIELDS := ["fixed_costs_per_day_cents", "base_revenue_per_day_cents",
		"revenue_per_1000_followers_cents", "utilization_decay_per_day"]
const SCORE_FIELDS := ["start_utilization", "start_reputation"]

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


## Erwartet ein Array von Objekten (wie im JSON).
func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_by_id.clear()
	_ids.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Unternehmensarten müssen eine Liste sein."])
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Unternehmensart '%s': ID kommt doppelt vor." % definition.id)
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


## null, wenn es die ID nicht gibt.
func get_definition(id: String) -> CompanyTypeScript:
	return _by_id.get(id)


## IDs in der Reihenfolge der Datei.
func get_ids() -> PackedStringArray:
	return _ids.duplicate()


## IDs aller Arten, die an einem Ort gegründet werden können.
func get_ids_at(location_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id in _ids:
		if _by_id[id].found_location == location_id:
			result.append(id)
	return result


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> CompanyTypeScript:
	var where := "Unternehmensart #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Unternehmensart '%s'" % id

	var definition := CompanyTypeScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, false)
	definition.found_location = reader.string_field(entry, "found_location", where, true)
	for field in POSITIVE_FIELDS + NON_NEGATIVE_FIELDS + SCORE_FIELDS:
		var value := reader.int_field(entry, field, where, true)
		if field in POSITIVE_FIELDS and value <= 0:
			reader.errors.append("%s: '%s' muss größer als 0 sein." % [where, field])
		elif field in NON_NEGATIVE_FIELDS and value < 0:
			reader.errors.append("%s: '%s' darf nicht negativ sein." % [where, field])
		elif field in SCORE_FIELDS and (value < 0 or value > 100):
			reader.errors.append("%s: '%s' muss zwischen 0 und 100 liegen." % [where, field])
		definition.set(field, value)

	return definition if reader.errors.size() == error_count else null
