class_name EventCatalog
extends RefCounted

## Lädt und prüft Ereignisdaten (JSON). Alles-oder-nichts wie beim ActivityCatalog.
##
## Format je Ereignis:
##   id, title, text, priority (optional, Standard 0),
##   trigger {day >= 1, hour 0–23, minute 0–59 (optional)},
##   options [ {id, label, money_cents?, category?, effects?}, … ] (mindestens eine)

const EventDefinitionScript := preload("res://scripts/models/event_definition.gd")
const EventOptionScript := preload("res://scripts/models/event_option.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const DEFAULT_PATH := "res://data/events/events.json"

var errors: PackedStringArray = []

var _definitions: Array[EventDefinitionScript] = []


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
		errors = PackedStringArray(["Ereignisdaten müssen eine Liste sein."])
		return false

	var definitions: Array[EventDefinitionScript] = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Ereignis '%s': ID kommt doppelt vor." % definition.id)
			continue
		seen[definition.id] = true
		definitions.append(definition)

	errors = reader.errors
	if not errors.is_empty():
		return false
	_definitions = definitions
	return true


## Alle Ereignisse in der Reihenfolge der Datei (Kopie der Liste).
func get_all() -> Array[EventDefinitionScript]:
	return _definitions.duplicate()


## null, wenn es die ID nicht gibt.
func get_definition(id: String) -> EventDefinitionScript:
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> EventDefinitionScript:
	var where := "Ereignis #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Ereignis '%s'" % id

	var definition := EventDefinitionScript.new()
	definition.id = id
	definition.title = reader.string_field(entry, "title", where, true)
	definition.text = reader.string_field(entry, "text", where, true)
	definition.priority = reader.int_field(entry, "priority", where, false)
	definition.due_minutes = _parse_trigger(reader, entry.get("trigger"), where)

	var options: Variant = entry.get("options")
	if typeof(options) != TYPE_ARRAY or options.is_empty():
		reader.errors.append("%s: 'options' muss eine nicht-leere Liste sein." % where)
	else:
		for j in options.size():
			var option = _parse_option(reader, options[j], "%s, Option #%d" % [where, j + 1])
			if option == null:
				continue
			if definition.get_option(option.id) != null:
				reader.errors.append("%s: Option '%s' kommt doppelt vor." % [where, option.id])
				continue
			definition.options.append(option)

	return definition if reader.errors.size() == error_count else null


func _parse_trigger(reader: DataReaderScript, trigger: Variant, where: String) -> int:
	if typeof(trigger) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'trigger' fehlt oder ist kein Objekt." % where)
		return 0
	var day := reader.int_field(trigger, "day", where + " (trigger)", true)
	var hour := reader.int_field(trigger, "hour", where + " (trigger)", true)
	var minute := reader.int_field(trigger, "minute", where + " (trigger)", false)
	if day < 1 or hour < 0 or hour >= TimeSystemScript.HOURS_PER_DAY \
			or minute < 0 or minute >= TimeSystemScript.MINUTES_PER_HOUR:
		reader.errors.append("%s: 'trigger' ungültig (day ab 1, hour 0–23, minute 0–59)." % where)
		return 0
	return TimeSystemScript.at(day, hour, minute)


func _parse_option(reader: DataReaderScript, entry: Variant, where: String) -> EventOptionScript:
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var option := EventOptionScript.new()
	option.id = reader.id_field(entry, where)
	option.label = reader.string_field(entry, "label", where, true)
	option.money_cents = reader.int_field(entry, "money_cents", where, false)
	option.category = reader.string_field(entry, "category", where, false)
	option.effects = reader.effects_field(entry, where)
	reader.check_money_category(option.money_cents, option.category, where)
	return option if reader.errors.size() == error_count else null
