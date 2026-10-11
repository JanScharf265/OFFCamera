class_name ContentFormatCatalog
extends RefCounted

## Lädt und prüft Content-Formate (JSON, Phase 3). Alles-oder-nichts wie die anderen Kataloge.
## Format pro Eintrag:
##   id, display_name, description (optional), location, duration_minutes (> 0),
##   effects (optional, PlayerStats), channel {followers_base ≥ 0, followers_per_mille ≥ 0,
##   community, reputation}, income {base_cents ≥ 0, per_1000_followers_cents ≥ 0}

const ContentFormatScript := preload("res://scripts/models/content_format.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/content/formats.json"

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
		errors = PackedStringArray(["Content-Formate müssen eine Liste sein."])
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Format '%s': ID kommt doppelt vor." % definition.id)
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
func get_definition(id: String) -> ContentFormatScript:
	return _by_id.get(id)


## IDs in der Reihenfolge der Datei.
func get_ids() -> PackedStringArray:
	return _ids.duplicate()


## IDs aller Formate an einem Ort, in der Reihenfolge der Datei.
func get_ids_at(location_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id in _ids:
		if _by_id[id].location == location_id:
			result.append(id)
	return result


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> ContentFormatScript:
	var where := "Format #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Format '%s'" % id

	var definition := ContentFormatScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, false)
	definition.location = reader.string_field(entry, "location", where, true)
	definition.duration_minutes = reader.int_field(entry, "duration_minutes", where, true)
	definition.effects = reader.effects_field(entry, where)
	if definition.duration_minutes <= 0 and DataReaderScript.is_whole_number(entry.get("duration_minutes")):
		reader.errors.append("%s: 'duration_minutes' muss größer als 0 sein." % where)

	var channel: Variant = entry.get("channel")
	if typeof(channel) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'channel' fehlt oder ist kein Objekt." % where)
	else:
		var context := "%s (channel)" % where
		definition.followers_base = _non_negative(reader, channel, "followers_base", context)
		definition.followers_per_mille = _non_negative(reader, channel, "followers_per_mille", context)
		definition.community = reader.int_field(channel, "community", context, false)
		definition.reputation = reader.int_field(channel, "reputation", context, false)

	var income: Variant = entry.get("income")
	if typeof(income) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'income' fehlt oder ist kein Objekt." % where)
	else:
		var context := "%s (income)" % where
		definition.income_base_cents = _non_negative(reader, income, "base_cents", context)
		definition.income_per_1000_cents = _non_negative(reader, income, "per_1000_followers_cents", context)

	return definition if reader.errors.size() == error_count else null


static func _non_negative(reader: DataReaderScript, entry: Dictionary, field: String, where: String) -> int:
	var value := reader.int_field(entry, field, where, true)
	if value < 0:
		reader.errors.append("%s: '%s' darf nicht negativ sein." % [where, field])
	return value
