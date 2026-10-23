extends RefCounted

## Doppelleben (U.22): Der Kanal wirkt auf die Unterwelt. Ein guter Ruf tarnt – jeder Hitze-Anstieg fällt etwas
## kleiner aus (Ruf über cover_reputation_from, höchstens cover_max_percent). Bekanntheit zieht Blicke an – jeder
## Hitze-Anstieg fällt größer aus (Follower über fame_followers_from, höchstens fame_max_percent). Beides zusammen ist
## ein Faktor auf positive Hitze-Änderungen (OrganisationSystem). Dazu Ereignisse (Paparazzi, Leak, Gerüchte,
## Skandal, Abwesenheit) als Daten mit Bedingungen auf Follower, Hitze, Polizei und Haft. Kein eigener Spielstand.
## Regeln: data/underworld/double_life.json.

const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/double_life.json"
const RULE_FIELDS := ["cover_reputation_from", "cover_reputation_per_percent", "cover_max_percent",
		"fame_followers_from", "fame_followers_per_percent", "fame_max_percent"]


## Regeln. Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/double_life.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Regeln fürs Doppelleben müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Doppelleben: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Doppelleben: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
		if errors.is_empty() and (result["cover_reputation_per_percent"] < 1 or result["fame_followers_per_percent"] < 1
				or result["cover_max_percent"] > 90):
			errors.append("Doppelleben: Teiler ≥ 1, cover_max_percent ≤ 90.")
		if not errors.is_empty():
			return false
		values = result
		return true

	func get_value(key: String) -> int:
		return values.get(key, 0)


var _rules: Rules
var _channel


func _init(rules: Rules, channel) -> void:
	_rules = rules
	_channel = channel


func get_rules() -> Rules:
	return _rules


## Tarnung durch den Ruf des Kanals (Prozent weniger Hitze-Anstieg).
@warning_ignore("integer_division")
func cover_percent() -> int:
	var above: int = _channel.reputation - _rules.get_value("cover_reputation_from")
	return clampi(above / _rules.get_value("cover_reputation_per_percent"), 0, _rules.get_value("cover_max_percent"))


## Aufmerksamkeit durch Bekanntheit (Prozent mehr Hitze-Anstieg).
@warning_ignore("integer_division")
func fame_percent() -> int:
	var above: int = _channel.followers - _rules.get_value("fame_followers_from")
	return clampi(above / _rules.get_value("fame_followers_per_percent"), 0, _rules.get_value("fame_max_percent"))


## Faktor auf positive Hitze-Änderungen (Prozent, 100 = unverändert) – vom OrganisationSystem.
func heat_gain_percent() -> int:
	return 100 - cover_percent() + fame_percent()
