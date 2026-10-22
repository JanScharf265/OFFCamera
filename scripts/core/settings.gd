extends RefCounted

## Geräte-Einstellungen (G5.1): gelten fürs Gerät, nicht pro Spielstand – eigene Datei user://settings.cfg
## (ConfigFile), getrennt vom Spielstand, ohne Spielstand-Version. „Spielstand löschen“ lässt sie unberührt.
## Robust: Fehlt die Datei oder ist sie kaputt, gelten die Standardwerte; die kaputte Datei bleibt liegen und wird
## beim nächsten Speichern ersetzt. Unbekannte Schlüssel und Werte vom falschen Typ werden ignoriert.
## Geschrieben wird atomar: erst .tmp, dann umbenennen (wie beim Spielstand).

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "device"
const TMP_SUFFIX := ".tmp"

## Kalender bei Tagesbeginn automatisch öffnen (genutzt ab G5.3).
const CALENDAR_AUTO_OPEN := "calendar_auto_open"
## Vibration bei Warnungen und großen Geldänderungen (genutzt ab G5.9).
const VIBRATION := "vibration"
## Schlüssel -> Standardwert. Alle Schalter sind standardmäßig an.
const DEFAULTS := {CALENDAR_AUTO_OPEN: true, VIBRATION: true}

var path := DEFAULT_PATH
## Grund, warum beim Laden die Standardwerte gelten ("" = Datei gelesen oder einfach noch keine da).
var load_problem := ""

var _values := DEFAULTS.duplicate()


## Lädt die Einstellungen; nie ein Absturz, im Zweifel Standardwerte.
static func load_from(settings_path: String = DEFAULT_PATH):
	var settings = load("res://scripts/core/settings.gd").new()
	settings.path = settings_path
	if not FileAccess.file_exists(settings_path):
		return settings
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK:
		settings.load_problem = "Einstellungen nicht lesbar (%s) – Standardwerte." % error_string(error)
		return settings
	for key in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, DEFAULTS[key])
		if typeof(value) == TYPE_BOOL:
			settings._values[key] = value
	return settings


func get_flag(key: String) -> bool:
	return _values.get(key, DEFAULTS.get(key, false))


## Setzt einen Schalter und speichert sofort. "" = gespeichert, sonst Fehlertext. Unbekannte Schlüssel: Fehler.
func set_flag(key: String, value: bool) -> String:
	if not DEFAULTS.has(key):
		return "Unbekannte Einstellung: %s" % key
	_values[key] = value
	return save()


func save() -> String:
	var config := ConfigFile.new()
	for key in DEFAULTS:
		config.set_value(SECTION, key, _values[key])
	var tmp := path + TMP_SUFFIX
	var error := config.save(tmp)
	if error != OK:
		return "Einstellungen konnten nicht gespeichert werden (%s)." % error_string(error)
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if error != OK:
		return "Einstellungen konnten nicht gespeichert werden (%s)." % error_string(error)
	return ""
