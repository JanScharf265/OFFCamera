class_name LocationCatalog
extends RefCounted

## Lädt und prüft Orte (JSON). Alles-oder-nichts wie die anderen Kataloge.
##
## Format je Ort:
##   id, display_name, description (optional), map_position [x, y] mit 0–1,
##   opening_hours {open, close} in vollen Stunden (optional, sonst immer offen),
##   unlocked_by_mission (optional, U.8): Auftrags-ID – bis dahin ist der Ort unbekannt (nicht auf der Karte, nicht anfahrbar)

const LocationDefinitionScript := preload("res://scripts/models/location_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/locations/locations.json"

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
		errors = PackedStringArray(["Ortsdaten müssen eine Liste sein."])
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Ort '%s': ID kommt doppelt vor." % definition.id)
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
func get_definition(id: String) -> LocationDefinitionScript:
	return _by_id.get(id)


func get_ids() -> PackedStringArray:
	return _ids.duplicate()


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> LocationDefinitionScript:
	var where := "Ort #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Ort '%s'" % id

	var definition := LocationDefinitionScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, false)

	var position: Variant = entry.get("map_position")
	if typeof(position) != TYPE_ARRAY or position.size() != 2 \
			or typeof(position[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(position[1]) not in [TYPE_INT, TYPE_FLOAT] \
			or position[0] < 0 or position[0] > 1 or position[1] < 0 or position[1] > 1:
		reader.errors.append("%s: 'map_position' muss [x, y] mit Werten von 0 bis 1 sein." % where)
	else:
		definition.map_position = Vector2(position[0], position[1])

	var hours: Variant = entry.get("opening_hours")
	if hours != null:
		if typeof(hours) != TYPE_DICTIONARY:
			reader.errors.append("%s: 'opening_hours' muss ein Objekt sein." % where)
		else:
			var hours_error_count := reader.errors.size()
			var open_hour := reader.int_field(hours, "open", where + " (opening_hours)", true)
			var close_hour := reader.int_field(hours, "close", where + " (opening_hours)", true)
			if reader.errors.size() == hours_error_count \
					and (open_hour < 0 or close_hour > 24 or open_hour >= close_hour):
				reader.errors.append("%s: 'opening_hours' ungültig (0 ≤ open < close ≤ 24)." % where)
			definition.has_hours = true
			definition.open_hour = open_hour
			definition.close_hour = close_hour

	definition.unlocked_by_mission = reader.string_field(entry, "unlocked_by_mission", where, false)

	return definition if reader.errors.size() == error_count else null
