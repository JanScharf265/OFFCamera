extends RefCounted

## Regeln der Organisation (U.2) aus data/underworld/organisation.json – Startwerte und wie schnell die Hitze an
## ruhigen Tagen sinkt. Vorläufige Spielwerte (Feinschliff in Phase 8). Alles-oder-nichts wie die Kataloge.
##
## Format: start {respect, heat, stability} (je 0–100), heat_decay_per_quiet_day (0–100),
##         name_min_length (≥ 1), name_max_length (≥ name_min_length, ≤ 40)

const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/organisation.json"
const VALUE_KEYS := ["respect", "heat", "stability"]

var errors: PackedStringArray = []
var start := {"respect": 0, "heat": 0, "stability": 50}
var heat_decay_per_quiet_day := 3
var name_min_length := 2
var name_max_length := 24


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	if typeof(data) != TYPE_DICTIONARY:
		errors = PackedStringArray(["Organisationsregeln müssen ein Objekt sein."])
		return false
	var where := "Organisation"
	var raw_start: Variant = data.get("start")
	var parsed_start := {}
	if typeof(raw_start) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'start' fehlt oder ist kein Objekt." % where)
	else:
		for key in VALUE_KEYS:
			var value := reader.int_field(raw_start, key, where + " (start)", true)
			if value < 0 or value > 100:
				reader.errors.append("%s: 'start.%s' muss zwischen 0 und 100 liegen." % [where, key])
			parsed_start[key] = value
		for key in raw_start:
			if String(key) not in VALUE_KEYS:
				reader.errors.append("%s: unbekannter Startwert '%s'." % [where, key])
	var decay := reader.int_field(data, "heat_decay_per_quiet_day", where, true)
	if decay < 0 or decay > 100:
		reader.errors.append("%s: 'heat_decay_per_quiet_day' muss zwischen 0 und 100 liegen." % where)
	var min_length := reader.int_field(data, "name_min_length", where, true)
	var max_length := reader.int_field(data, "name_max_length", where, true)
	if min_length < 1 or max_length < min_length or max_length > 40:
		reader.errors.append("%s: Namenslänge ungültig (1 ≤ min ≤ max ≤ 40)." % where)
	errors = reader.errors
	if not errors.is_empty():
		return false
	start = parsed_start
	heat_decay_per_quiet_day = decay
	name_min_length = min_length
	name_max_length = max_length
	return true
