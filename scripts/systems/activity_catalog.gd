class_name ActivityCatalog
extends RefCounted

## Lädt und prüft Aktivitätsdaten (JSON). Alles-oder-nichts: Enthalten die
## Daten einen Fehler, wird nichts übernommen und errors beschreibt alle Fehler.

const ActivityDefinitionScript := preload("res://scripts/models/activity_definition.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")

const DEFAULT_PATH := "res://data/activities/activities.json"

var errors: PackedStringArray = []

var _by_id := {}
var _ids := PackedStringArray()
var _id_regex := RegEx.create_from_string("^[a-z0-9_]+$")


func load_file(path: String = DEFAULT_PATH) -> bool:
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("Datei fehlt: %s" % path)
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("JSON-Fehler in %s, Zeile %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return false
	return load_data(json.data)


## Erwartet ein Array von Objekten (wie im JSON).
func load_data(data: Variant) -> bool:
	errors.clear()
	_by_id.clear()
	_ids.clear()
	if typeof(data) != TYPE_ARRAY:
		errors.append("Aktivitätsdaten müssen eine Liste sein.")
		return false

	var by_id := {}
	var ids := PackedStringArray()
	for i in data.size():
		var definition = _parse(data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			errors.append("Aktivität '%s': ID kommt doppelt vor." % definition.id)
			continue
		by_id[definition.id] = definition
		ids.append(definition.id)

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


func _parse(entry: Variant, index: int) -> ActivityDefinitionScript:
	var where := "Aktivität #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := errors.size()
	var id: Variant = entry.get("id")
	if typeof(id) != TYPE_STRING or _id_regex.search(id) == null:
		errors.append("%s: 'id' fehlt oder ist ungültig (nur a–z, 0–9, _)." % where)
		return null
	where = "Aktivität '%s'" % id

	var definition := ActivityDefinitionScript.new()
	definition.id = id
	definition.display_name = _string_field(entry, "display_name", where, true)
	definition.description = _string_field(entry, "description", where, false)
	definition.category = _string_field(entry, "category", where, false)
	definition.duration_minutes = _int_field(entry, "duration_minutes", where, true)
	definition.money_cents = _int_field(entry, "money_cents", where, false)

	if definition.duration_minutes <= 0 and _is_whole_number(entry.get("duration_minutes")):
		errors.append("%s: 'duration_minutes' muss größer als 0 sein." % where)
	if definition.money_cents != 0 and definition.category.is_empty():
		errors.append("%s: 'category' ist Pflicht, wenn 'money_cents' gesetzt ist." % where)

	var effects: Variant = entry.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		errors.append("%s: 'effects' muss ein Objekt sein." % where)
	else:
		for key in effects:
			if key not in PlayerStatsScript.KEYS:
				errors.append("%s: unbekannter Effekt '%s' (erlaubt: %s)." % [where, key, ", ".join(PackedStringArray(PlayerStatsScript.KEYS))])
			elif not _is_whole_number(effects[key]):
				errors.append("%s: Effekt '%s' muss eine ganze Zahl sein." % [where, key])
			else:
				definition.effects[key] = int(effects[key])

	return definition if errors.size() == error_count else null


func _string_field(entry: Dictionary, field: String, where: String, required: bool) -> String:
	var value: Variant = entry.get(field)
	if value == null:
		if required:
			errors.append("%s: '%s' fehlt." % [where, field])
		return ""
	if typeof(value) != TYPE_STRING or (required and value.is_empty()):
		errors.append("%s: '%s' muss ein nicht-leerer Text sein." % [where, field])
		return ""
	return value


func _int_field(entry: Dictionary, field: String, where: String, required: bool) -> int:
	var value: Variant = entry.get(field)
	if value == null:
		if required:
			errors.append("%s: '%s' fehlt." % [where, field])
		return 0
	if not _is_whole_number(value):
		errors.append("%s: '%s' muss eine ganze Zahl sein." % [where, field])
		return 0
	return int(value)


## JSON liefert Zahlen als float – 120.0 ist ok, 1.5 nicht.
func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)
