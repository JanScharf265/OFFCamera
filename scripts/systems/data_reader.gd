extends RefCounted

## Gemeinsame Hilfen zum Lesen und Prüfen von JSON-Spieldaten.
## Fehler werden in `errors` gesammelt, statt beim ersten abzubrechen,
## damit alle Probleme einer Datei auf einmal sichtbar sind.

const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LocationTabScript := preload("res://scripts/models/location_tab.gd")

var errors: PackedStringArray = []

var _id_regex := RegEx.create_from_string("^[a-z0-9_]+$")


## Inhalt der JSON-Datei oder null (dann steht der Grund in errors).
func read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Datei fehlt: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("JSON-Fehler in %s, Zeile %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Gültige ID (a–z, 0–9, _) oder "" mit Fehler.
func id_field(entry: Dictionary, where: String) -> String:
	var id: Variant = entry.get("id")
	if typeof(id) != TYPE_STRING or _id_regex.search(id) == null:
		errors.append("%s: 'id' fehlt oder ist ungültig (nur a–z, 0–9, _)." % where)
		return ""
	return id


## Pflichtfeld "tab" (G4.6): Reiter im Ortsfenster, eine der IDs aus location_tab.gd.
func tab_field(entry: Dictionary, where: String) -> String:
	var tab := string_field(entry, "tab", where, true)
	if not tab.is_empty() and tab not in LocationTabScript.IDS:
		errors.append("%s: 'tab' muss einer von %s sein, nicht '%s'." % [where, ", ".join(LocationTabScript.IDS), tab])
		return ""
	return tab


func string_field(entry: Dictionary, field: String, where: String, required: bool) -> String:
	var value: Variant = entry.get(field)
	if value == null:
		if required:
			errors.append("%s: '%s' fehlt." % [where, field])
		return ""
	if typeof(value) != TYPE_STRING or (required and value.is_empty()):
		errors.append("%s: '%s' muss ein nicht-leerer Text sein." % [where, field])
		return ""
	return value


func int_field(entry: Dictionary, field: String, where: String, required: bool, default: int = 0) -> int:
	var value: Variant = entry.get(field)
	if value == null:
		if required:
			errors.append("%s: '%s' fehlt." % [where, field])
		return default
	if not is_whole_number(value):
		errors.append("%s: '%s' muss eine ganze Zahl sein." % [where, field])
		return default
	return int(value)


## Optionales Effekte-Objekt, nur Schlüssel aus PlayerStats.KEYS mit ganzen Zahlen.
func effects_field(entry: Dictionary, where: String, field: String = "effects") -> Dictionary:
	var result := {}
	var effects: Variant = entry.get(field, {})
	if typeof(effects) != TYPE_DICTIONARY:
		errors.append("%s: '%s' muss ein Objekt sein." % [where, field])
		return result
	for key in effects:
		if key not in PlayerStatsScript.KEYS:
			errors.append("%s: unbekannter Effekt '%s' (erlaubt: %s)." % [where, key, ", ".join(PackedStringArray(PlayerStatsScript.KEYS))])
		elif not is_whole_number(effects[key]):
			errors.append("%s: Effekt '%s' muss eine ganze Zahl sein." % [where, key])
		else:
			result[key] = int(effects[key])
	return result


## Zeitpunkt {day >= 1, hour 0–23, minute 0–59 (optional)} als kanonische Minuten,
## oder -1 mit Fehler.
func time_point_field(entry: Dictionary, field: String, where: String) -> int:
	var point: Variant = entry.get(field)
	if typeof(point) != TYPE_DICTIONARY:
		errors.append("%s: '%s' fehlt oder ist kein Objekt." % [where, field])
		return -1
	var context := "%s (%s)" % [where, field]
	var error_count := errors.size()
	var day := int_field(point, "day", context, true)
	var hour := int_field(point, "hour", context, true)
	var minute := int_field(point, "minute", context, false)
	if errors.size() != error_count:
		return -1
	if day < 1 or hour < 0 or hour >= TimeSystemScript.HOURS_PER_DAY \
			or minute < 0 or minute >= TimeSystemScript.MINUTES_PER_HOUR:
		errors.append("%s: '%s' ungültig (day ab 1, hour 0–23, minute 0–59)." % [where, field])
		return -1
	return TimeSystemScript.at(day, hour, minute)


## Prüft die Regel "category ist Pflicht, wenn money_cents gesetzt ist".
func check_money_category(money_cents: int, category: String, where: String) -> void:
	if money_cents != 0 and category.is_empty():
		errors.append("%s: 'category' ist Pflicht, wenn 'money_cents' gesetzt ist." % where)


## JSON liefert Zahlen als float – 120.0 ist ok, 1.5 nicht.
static func is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)
