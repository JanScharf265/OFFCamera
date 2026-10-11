class_name SaveSystem
extends RefCounted

## Lokaler, versionierter Spielstand (JSON unter user://).
##
## Schreiben: erst in <pfad>.tmp, dann den bisherigen Stand nach <pfad>.bak
## umbenennen, dann .tmp nach <pfad>. Eine halb geschriebene Datei ersetzt so nie
## einen funktionierenden Spielstand.
## Laden: Hauptdatei; ist sie defekt oder fehlt sie, das Backup. Eine fehlende
## Datei ist kein Fehler (= noch kein Spielstand).
##
## Versionen: SAVE_VERSION erhöhen, wenn sich das Format ändert, und in
## _migrate() einen Schritt von der alten zur neuen Version ergänzen.
## Spielstände aus einer neueren Version werden abgelehnt.

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


## "" = gespeichert, sonst Fehlertext.
static func save(game: GameStateScript, path: String = DEFAULT_PATH) -> String:
	var text := JSON.stringify({"version": SAVE_VERSION, "game": game.to_dict()}, "\t")
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return "Spielstand konnte nicht geschrieben werden (Fehler %d)." % FileAccess.get_open_error()
	file.store_string(text)
	file.close()

	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK:
			return "Backup des Spielstands fehlgeschlagen (Fehler %d)." % backup_error
	var rename_error := DirAccess.rename_absolute(tmp_path, path)
	if rename_error != OK:
		return "Spielstand konnte nicht abgeschlossen werden (Fehler %d)." % rename_error
	return ""


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Ergebnis: {"game": GameState oder null, "error": String, "from_backup": bool}
## game == null und error == "" bedeutet: Es gibt keinen Spielstand.
static func load_game(activity_catalog: ActivityCatalogScript, event_catalog: EventCatalogScript,
		path: String = DEFAULT_PATH) -> Dictionary:
	var main_error := ""
	if FileAccess.file_exists(path):
		var main := _load_file(path, activity_catalog, event_catalog)
		if main["game"] != null:
			return main
		main_error = main["error"]

	var backup_path := path + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup := _load_file(backup_path, activity_catalog, event_catalog)
		if backup["game"] != null:
			backup["from_backup"] = true
			backup["error"] = main_error
			return backup
		if main_error.is_empty():
			main_error = backup["error"]

	return {"game": null, "error": main_error, "from_backup": false}


## Löscht Spielstand, Backup und Zwischendatei.
static func delete_save(path: String = DEFAULT_PATH) -> void:
	for file_path in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


static func _load_file(path: String, activity_catalog: ActivityCatalogScript,
		event_catalog: EventCatalogScript) -> Dictionary:
	var failed := func(message: String) -> Dictionary:
		return {"game": null, "error": message, "from_backup": false}

	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return failed.call("Der Spielstand ist leer oder nicht lesbar.")
	var json := JSON.new()
	if json.parse(text) != OK:
		return failed.call("Der Spielstand ist beschädigt (Zeile %d)." % json.get_error_line())
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return failed.call("Der Spielstand hat ein unbekanntes Format.")

	var version: Variant = data.get("version")
	if not DataReaderScript.is_whole_number(version) or int(version) < 1:
		return failed.call("Der Spielstand hat keine gültige Versionsnummer.")
	if int(version) > SAVE_VERSION:
		return failed.call("Der Spielstand stammt aus einer neueren Spielversion (%d) und kann nicht geladen werden." % int(version))
	data = _migrate(data, int(version))

	if typeof(data.get("game")) != TYPE_DICTIONARY:
		return failed.call("Der Spielstand enthält keine Spieldaten.")
	var game := GameStateScript.new(activity_catalog, event_catalog)
	var error := game.restore(data["game"])
	if not error.is_empty():
		return failed.call("Der Spielstand ist ungültig: %s" % error)
	return {"game": game, "error": "", "from_backup": false}


## Hebt ältere Formate schrittweise auf SAVE_VERSION an. Version 1 ist aktuell.
static func _migrate(data: Dictionary, _version: int) -> Dictionary:
	return data
