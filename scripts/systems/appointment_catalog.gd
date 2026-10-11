class_name AppointmentCatalog
extends RefCounted

## Lädt und prüft feste Termine (JSON). Alles-oder-nichts wie die anderen Kataloge.
##
## Format je Termin:
##   id, title, description (optional), location (Orts-ID),
##   start {day, hour, minute?}, duration_minutes (> 0),
##   money_cents/category/effects (optional, beim Wahrnehmen),
##   missed_effects (Pflicht, mit negativem "mood": verpasst kostet Stimmung)

const AppointmentDefinitionScript := preload("res://scripts/models/appointment_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/appointments/appointments.json"

var errors: PackedStringArray = []

var _definitions: Array[AppointmentDefinitionScript] = []


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		_definitions.clear()
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_definitions.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Termindaten müssen eine Liste sein."])
		return false

	var definitions: Array[AppointmentDefinitionScript] = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Termin '%s': ID kommt doppelt vor." % definition.id)
			continue
		seen[definition.id] = true
		definitions.append(definition)

	errors = reader.errors
	if not errors.is_empty():
		return false
	definitions.sort_custom(func(a: AppointmentDefinitionScript, b: AppointmentDefinitionScript) -> bool:
		return a.start_minutes < b.start_minutes or (a.start_minutes == b.start_minutes and a.id < b.id))
	_definitions = definitions
	return true


## Alle Termine, sortiert nach Beginn (Kopie der Liste).
func get_all() -> Array[AppointmentDefinitionScript]:
	return _definitions.duplicate()


## null, wenn es die ID nicht gibt.
func get_definition(id: String) -> AppointmentDefinitionScript:
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> AppointmentDefinitionScript:
	var where := "Termin #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Termin '%s'" % id

	var definition := AppointmentDefinitionScript.new()
	definition.id = id
	definition.title = reader.string_field(entry, "title", where, true)
	definition.description = reader.string_field(entry, "description", where, false)
	definition.location = reader.string_field(entry, "location", where, true)
	definition.start_minutes = reader.time_point_field(entry, "start", where)
	definition.duration_minutes = reader.int_field(entry, "duration_minutes", where, true)
	definition.money_cents = reader.int_field(entry, "money_cents", where, false)
	definition.category = reader.string_field(entry, "category", where, false)
	definition.effects = reader.effects_field(entry, where)
	definition.missed_effects = reader.effects_field(entry, where, "missed_effects")

	if definition.duration_minutes <= 0 and DataReaderScript.is_whole_number(entry.get("duration_minutes")):
		reader.errors.append("%s: 'duration_minutes' muss größer als 0 sein." % where)
	if reader.errors.size() == error_count and definition.missed_effects.get("mood", 0) >= 0:
		reader.errors.append("%s: 'missed_effects' braucht einen negativen Wert für 'mood' (verpasst kostet Stimmung)." % where)
	reader.check_money_category(definition.money_cents, definition.category, where)

	return definition if reader.errors.size() == error_count else null
