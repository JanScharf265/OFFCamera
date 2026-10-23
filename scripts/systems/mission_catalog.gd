extends RefCounted

## Lädt und prüft Story-Aufträge (U.4, data/underworld/missions.json). Alles-oder-nichts wie die anderen Kataloge.
##
## Format je Auftrag (alle Felder Pflicht, andere sind ein Fehler):
##   id, chapter, title, giver, briefing, goal_text, debrief (Texte; Briefing/Debrief ≤ MAX_TEXT_LENGTH),
##   goal {type: einer aus GOAL_TYPES, + Felder des Typs}, reward {respect|heat|stability: ganze Zahl},
##   order ≥ 0, requires [Auftrags-IDs, ohne Zyklen].
## Zieltypen: "visit_location" {location: Orts-ID} – erfüllt bei der Ankunft dort (geöffnet);
##            "have_stock" {min_units ≥ 1} – erfüllt, sobald so viele Einheiten Ware im Bestand sind (U.6).

const MissionDefinitionScript := preload("res://scripts/models/mission_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/missions.json"
const FIELDS := ["id", "chapter", "title", "giver", "briefing", "goal", "goal_text", "debrief", "reward", "order",
		"requires"]
const GOAL_VISIT_LOCATION := "visit_location"
## Zieltyp -> Pflichtfelder (außer "type")
const GOAL_HAVE_STOCK := "have_stock"
## Zieltyp -> {Feld: Typ} ("string" = nicht-leerer Text, "count" = ganze Zahl ≥ 1)
const GOAL_TYPES := {GOAL_VISIT_LOCATION: {"location": "string"}, GOAL_HAVE_STOCK: {"min_units": "count"}}
const REWARD_KEYS := ["respect", "heat", "stability"]
const MAX_TEXT_LENGTH := 320

var errors: PackedStringArray = []

var _definitions: Array = []


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
		errors = PackedStringArray(["Auftragsdaten müssen eine Liste sein."])
		return false
	var definitions: Array = []
	var by_id := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Auftrag '%s': ID kommt doppelt vor." % definition.id)
			continue
		by_id[definition.id] = definition
		definitions.append(definition)
	for definition in definitions:
		for required in definition.requires:
			if not by_id.has(required):
				reader.errors.append("Auftrag '%s': 'requires' verweist auf unbekannten Auftrag '%s'." % [definition.id,
						required])
	if reader.errors.is_empty() and _has_cycle(definitions, by_id):
		reader.errors.append("Aufträge: Zyklus in 'requires'.")
	errors = reader.errors
	if not errors.is_empty():
		return false
	definitions.sort_custom(func(a, b) -> bool: return a.order < b.order or (a.order == b.order and a.id < b.id))
	_definitions = definitions
	return true


## Alle Aufträge, sortiert nach order, dann ID (Kopie).
func get_all() -> Array:
	return _definitions.duplicate()


func get_definition(id: String):
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func has(id: String) -> bool:
	return get_definition(id) != null


func _parse(reader: DataReaderScript, entry: Variant, index: int):
	var where := "Auftrag #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Auftrag '%s'" % id
	for key in entry:
		if String(key) not in FIELDS:
			reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
	var definition := MissionDefinitionScript.new()
	definition.id = id
	for field in ["chapter", "title", "giver", "briefing", "goal_text", "debrief"]:
		definition.set(field, reader.string_field(entry, field, where, true))
	for field in ["briefing", "debrief"]:
		if String(definition.get(field)).length() > MAX_TEXT_LENGTH:
			reader.errors.append("%s: '%s' ist zu lang (höchstens %d Zeichen)." % [where, field, MAX_TEXT_LENGTH])
	var goal: Variant = entry.get("goal")
	if typeof(goal) != TYPE_DICTIONARY or typeof(goal.get("type")) != TYPE_STRING or goal["type"] not in GOAL_TYPES:
		reader.errors.append("%s: 'goal' braucht einen 'type' aus %s." % [where, ", ".join(GOAL_TYPES.keys())])
	else:
		var fields: Dictionary = GOAL_TYPES[goal["type"]]
		definition.goal = goal.duplicate()
		for field in fields:
			var value: Variant = goal.get(field)
			var ok: bool = typeof(value) == TYPE_STRING and not String(value).is_empty() if fields[field] == "string" \
					else DataReaderScript.is_whole_number(value) and int(value) >= 1
			if not ok:
				reader.errors.append("%s: Ziel '%s' braucht '%s'." % [where, goal["type"], field])
			elif fields[field] == "count":
				definition.goal[field] = int(value)
		for key in goal:
			if key != "type" and not fields.has(key):
				reader.errors.append("%s: Ziel '%s' hat unbekanntes Feld '%s'." % [where, goal["type"], key])
	var reward: Variant = entry.get("reward")
	if typeof(reward) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'reward' fehlt oder ist kein Objekt." % where)
	else:
		for key in reward:
			if String(key) not in REWARD_KEYS or not DataReaderScript.is_whole_number(reward[key]):
				reader.errors.append("%s: ungültige Belohnung '%s'." % [where, key])
			else:
				definition.reward[key] = int(reward[key])
	definition.order = reader.int_field(entry, "order", where, true)
	if definition.order < 0:
		reader.errors.append("%s: 'order' darf nicht negativ sein." % where)
	var requires: Variant = entry.get("requires")
	if typeof(requires) != TYPE_ARRAY:
		reader.errors.append("%s: 'requires' fehlt oder ist keine Liste." % where)
	else:
		for required in requires:
			if typeof(required) != TYPE_STRING or required.is_empty() or required == id:
				reader.errors.append("%s: 'requires' enthält eine ungültige ID." % where)
			else:
				definition.requires.append(required)
	return definition if reader.errors.size() == error_count else null


func _has_cycle(definitions: Array, by_id: Dictionary) -> bool:
	var state := {}
	for definition in definitions:
		if _visit(definition.id, by_id, state):
			return true
	return false


func _visit(id: String, by_id: Dictionary, state: Dictionary) -> bool:
	if state.get(id, 0) == 2:
		return false
	if state.get(id, 0) == 1:
		return true
	state[id] = 1
	for required in by_id[id].requires:
		if _visit(required, by_id, state):
			return true
	state[id] = 2
	return false
