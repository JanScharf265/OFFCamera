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
## Versionen: SAVE_VERSION erhöhen, wenn sich das Format ändert, in _run_migration() einen
## Schritt von der alten zur neuen Version ergänzen und eine echte Testdatei
## tests/fixtures/saves/v<neu>.json anlegen (Erzeuger: tests/fixtures/make_save.gd).
## Spielstände aus einer neueren Version werden abgelehnt.

const GameStateScript := preload("res://scripts/core/game_state.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const SAVE_VERSION := 11
## Seed für Spielstände, die vor den Zufallsereignissen entstanden sind.
const MIGRATED_SEED := 1
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
static func load_game(game_data: GameDataScript, path: String = DEFAULT_PATH) -> Dictionary:
	var main_error := ""
	if FileAccess.file_exists(path):
		var main := _load_file(path, game_data)
		if main["game"] != null:
			return main
		main_error = main["error"]

	var backup_path := path + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup := _load_file(backup_path, game_data)
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


static func _load_file(path: String, game_data: GameDataScript) -> Dictionary:
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
	if typeof(data.get("game")) != TYPE_DICTIONARY:
		return failed.call("Der Spielstand enthält keine Spieldaten.")
	var migration_error := _migrate(data, int(version))
	if not migration_error.is_empty():
		return failed.call("Der Spielstand konnte nicht umgewandelt werden: %s" % migration_error)

	var game := GameStateScript.new(game_data)
	var error := game.restore(data["game"])
	if not error.is_empty():
		return failed.call("Der Spielstand ist ungültig: %s" % error)
	return {"game": game, "error": "", "from_backup": false}


## Hebt ältere Formate schrittweise auf SAVE_VERSION an (ändert `data` direkt).
## "" = ok, sonst Fehlertext.
## Neue Formatversion: SAVE_VERSION erhöhen, in _run_migration() einen Schritt n → n + 1 ergänzen
## und eine echte Testdatei tests/fixtures/saves/v<neu>.json anlegen (siehe tests/test_save_fixtures.gd).

## Hebt ältere Formate schrittweise auf SAVE_VERSION an (ändert `data` direkt).
## "" = ok, sonst Fehlertext.
static func _migrate(data: Dictionary, version: int) -> String:
	for step in range(version, SAVE_VERSION):
		var error := _run_migration(step, data["game"])
		if not error.is_empty():
			return error
	data["version"] = SAVE_VERSION
	return ""


## Ein Schritt: hebt `game` von Version `step` auf `step` + 1 (ändert es direkt). "" = ok, sonst Fehlertext.
static func _run_migration(step: int, game: Dictionary) -> String:
	match step:
		1: return _migrate_1_to_2(game)
		2: return _migrate_2_to_3(game)
		3: return _migrate_3_to_4(game)
		4: return _migrate_4_to_5(game)
		5: return _migrate_5_to_6(game)
		6: return _migrate_6_to_7(game)
		7: return _migrate_7_to_8(game)
		8: return _migrate_8_to_9(game)
		9: return _migrate_9_to_10(game)
		10: return _migrate_10_to_11(game)
	return "Kein Migrationsschritt von Version %d." % step


## 1 → 2 (Phase 2): Ort und Termine kommen dazu. Ein alter Spielstand beginnt in der Wohnung;
## Termine, die vor dem Ladezeitpunkt lagen, entfallen ohne Strafe.
static func _migrate_1_to_2(game: Dictionary) -> String:
	var time: Variant = game.get("time")
	if typeof(time) != TYPE_DICTIONARY or not DataReaderScript.is_whole_number(time.get("minutes")):
		return "Zeit fehlt."
	game["location"] = {"current": GameDataScript.START_LOCATION}
	game["appointments"] = {"since_minutes": int(time["minutes"]), "attended": [], "missed": []}
	if not game.has("events"):
		game["events"] = {}
	return ""


## 2 → 3 (Phase 3): Kanalprofil mit Startwerten, leeres Protokoll.
static func _migrate_2_to_3(game: Dictionary) -> String:
	game["channel"] = ChannelSystemScript.initial_dict(GameStateScript.START_FOLLOWERS,
			GameStateScript.START_COMMUNITY, GameStateScript.START_REPUTATION)
	return ""


## 3 → 4 (Phase 3): Ausrüstung – nichts gekauft.
static func _migrate_3_to_4(game: Dictionary) -> String:
	game["equipment"] = {"levels": {}}
	return ""


## 4 → 5 (Phase 3): Seed für Zufallsereignisse (MIGRATED_SEED).
static func _migrate_4_to_5(game: Dictionary) -> String:
	if typeof(game.get("events")) != TYPE_DICTIONARY:
		return "Ereignisse fehlen."
	game["events"]["seed"] = MIGRATED_SEED
	return ""


## 5 → 6 (Phase 4): Konten im Ledger – alte Buchungen gehören zum Privatkonto.
static func _migrate_5_to_6(game: Dictionary) -> String:
	if typeof(game.get("ledger")) != TYPE_DICTIONARY:
		return "Ledger fehlt."
	return LedgerSystemScript.migrate_single_account(game["ledger"])


## 6 → 7 (Phase 4): Unternehmen – noch nicht gegründet.
static func _migrate_6_to_7(game: Dictionary) -> String:
	game["company"] = {"founded": false}
	return ""


## 7 → 8 (Phase 4): Tagesabschluss – gegründete Unternehmen rechnen ab dem laufenden Tag ab,
## frühere Tage nicht nachträglich.
static func _migrate_7_to_8(game: Dictionary) -> String:
	var company: Variant = game.get("company")
	if typeof(company) != TYPE_DICTIONARY:
		return "Unternehmen fehlt."
	if company.get("founded") == true:
		var minutes: Variant = game.get("time", {}).get("minutes")
		if not DataReaderScript.is_whole_number(minutes):
			return "Zeit fehlt."
		company["last_settled_day"] = TimeSystemScript.day_of(int(minutes)) - 1
		company["settlements"] = []
	return ""


## 8 → 9 (Phase 4): Filiale – bei gegründeten Unternehmen noch nicht eröffnet.
static func _migrate_8_to_9(game: Dictionary) -> String:
	var company: Variant = game.get("company")
	if typeof(company) != TYPE_DICTIONARY:
		return "Unternehmen fehlt."
	if company.get("founded") == true:
		company["branch_open"] = false
	return ""


## 9 → 10 (Phase 5): Wertstellung je Buchung (LedgerSystem.migrate_effective_dates()).
static func _migrate_9_to_10(game: Dictionary) -> String:
	if typeof(game.get("ledger")) != TYPE_DICTIONARY:
		return "Ledger fehlt."
	return LedgerSystemScript.migrate_effective_dates(game["ledger"])


## 10 → 11 (Phase 5): Fristen – leer; vergangene Wochen werden nicht nachberechnet.
static func _migrate_10_to_11(game: Dictionary) -> String:
	var minutes: Variant = game.get("time", {}).get("minutes")
	if not DataReaderScript.is_whole_number(minutes):
		return "Zeit fehlt."
	game["obligations"] = {"last_processed_day": TimeSystemScript.day_of(int(minutes)), "instances": []}
	return ""
