class_name ActivityCatalog
extends RefCounted

## Lädt und prüft Aktivitätsdaten (JSON). Alles-oder-nichts: Enthalten die
## Daten einen Fehler, wird nichts übernommen und errors beschreibt alle Fehler.

const ActivityDefinitionScript := preload("res://scripts/models/activity_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/activities/activities.json"

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
		errors = PackedStringArray(["Aktivitätsdaten müssen eine Liste sein."])
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Aktivität '%s': ID kommt doppelt vor." % definition.id)
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
func get_definition(id: String) -> ActivityDefinitionScript:
	return _by_id.get(id)


## IDs in der Reihenfolge der Datei.
func get_ids() -> PackedStringArray:
	return _ids.duplicate()


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> ActivityDefinitionScript:
	var where := "Aktivität #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Aktivität '%s'" % id

	var definition := ActivityDefinitionScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, false)
	definition.category = reader.string_field(entry, "category", where, false)
	definition.duration_minutes = reader.int_field(entry, "duration_minutes", where, true)
	definition.money_cents = reader.int_field(entry, "money_cents", where, false)
	definition.effects = reader.effects_field(entry, where)

	if definition.duration_minutes <= 0 and DataReaderScript.is_whole_number(entry.get("duration_minutes")):
		reader.errors.append("%s: 'duration_minutes' muss größer als 0 sein." % where)
	reader.check_money_category(definition.money_cents, definition.category, where)

	return definition if reader.errors.size() == error_count else null
