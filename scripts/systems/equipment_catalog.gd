class_name EquipmentCatalog
extends RefCounted

## Lädt und prüft Ausrüstung (JSON, Phase 3). Alles-oder-nichts wie die anderen Kataloge.
## Format pro Eintrag:
##   id, display_name, location, formats (Liste von Format-IDs, mind. 1),
##   levels (mind. 1): {name, price_cents > 0, quality_percent > 0}, Bonus je Stufe steigend.

const EquipmentDefinitionScript := preload("res://scripts/models/equipment_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/equipment/equipment.json"

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
		errors = PackedStringArray(["Ausrüstungsdaten müssen eine Liste sein."])
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Ausrüstung '%s': ID kommt doppelt vor." % definition.id)
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
func get_definition(id: String) -> EquipmentDefinitionScript:
	return _by_id.get(id)


## IDs in der Reihenfolge der Datei.
func get_ids() -> PackedStringArray:
	return _ids.duplicate()


## IDs aller Teile, die man an einem Ort kaufen kann.
func get_ids_at(location_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id in _ids:
		if _by_id[id].location == location_id:
			result.append(id)
	return result


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> EquipmentDefinitionScript:
	var where := "Ausrüstung #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Ausrüstung '%s'" % id

	var definition := EquipmentDefinitionScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.location = reader.string_field(entry, "location", where, true)

	var formats: Variant = entry.get("formats")
	if typeof(formats) != TYPE_ARRAY or formats.is_empty():
		reader.errors.append("%s: 'formats' muss eine nicht-leere Liste sein." % where)
	else:
		for format_id in formats:
			if typeof(format_id) != TYPE_STRING or format_id.is_empty():
				reader.errors.append("%s: 'formats' enthält einen ungültigen Eintrag." % where)
				break
			definition.formats.append(format_id)

	var levels: Variant = entry.get("levels")
	if typeof(levels) != TYPE_ARRAY or levels.is_empty():
		reader.errors.append("%s: 'levels' muss eine nicht-leere Liste sein." % where)
	else:
		var previous_bonus := 0
		for i in levels.size():
			var level: Variant = levels[i]
			var context := "%s, Stufe %d" % [where, i + 1]
			if typeof(level) != TYPE_DICTIONARY:
				reader.errors.append("%s: muss ein Objekt sein." % context)
				continue
			var name := reader.string_field(level, "name", context, true)
			var price := reader.int_field(level, "price_cents", context, true)
			var bonus := reader.int_field(level, "quality_percent", context, true)
			if price <= 0 or bonus <= 0:
				reader.errors.append("%s: 'price_cents' und 'quality_percent' müssen größer als 0 sein." % context)
			elif bonus <= previous_bonus:
				reader.errors.append("%s: 'quality_percent' muss höher sein als in der Stufe davor." % context)
			previous_bonus = bonus
			definition.levels.append({"name": name, "price_cents": price, "quality_percent": bonus})

	return definition if reader.errors.size() == error_count else null
