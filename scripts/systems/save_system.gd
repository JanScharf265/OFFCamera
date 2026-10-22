class_name SaveSystem
extends RefCounted

## Lokaler, versionierter Spielstand (JSON unter user://).
##
## Schreiben: erst <pfad>.tmp (wieder eingelesen geprüft), dann 3 Backups rotieren, dann .tmp → <pfad>.
## Eine halb geschriebene Datei ersetzt so nie einen funktionierenden Spielstand.
## Laden: gültige liegengebliebene .tmp, sonst Hauptdatei, sonst .bak/.bak2/.bak3; defekte Dateien
## werden aufbewahrt (.corrupt-…) und nie überschrieben. Eine fehlende Datei ist kein Fehler.
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
const ConsistencyCheckScript := preload("res://scripts/core/consistency_check.gd")

const SAVE_VERSION := 13
## Seed für Spielstände, die vor den Zufallsereignissen entstanden sind.
const MIGRATED_SEED := 1
const DEFAULT_PATH := "user://savegame.json"


## Backups: <pfad>.bak (neuestes), .bak2, .bak3.
const BACKUP_SUFFIXES: Array[String] = [".bak", ".bak2", ".bak3"]
const TMP_SUFFIX := ".tmp"
## Defekte Stände werden als <ordner>/<name>.corrupt-<zeit>.json aufbewahrt, höchstens so viele.
const CORRUPT_KEEP := 3


## Speichert atomar. "" = gespeichert, sonst Fehlertext. Ablauf: <pfad>.tmp schreiben und wieder
## einlesen (vollständig?), dann Backups rotieren (.bak2 → .bak3, .bak → .bak2, Hauptdatei → .bak) und
## .tmp zur Hauptdatei machen. Nie während eines Zeitfortschritts (Zustand wäre halb fertig).
static func save(game: GameStateScript, path: String = DEFAULT_PATH) -> String:
	if game.time.is_advancing():
		return "Speichern während eines Zeitfortschritts ist nicht möglich."
	var text := JSON.stringify({"version": SAVE_VERSION, "meta": _meta(game), "game": game.to_dict()}, "\t")
	var tmp_path := path + TMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return "Spielstand konnte nicht geschrieben werden (Fehler %d)." % FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(tmp_path) != text:
		return "Spielstand wurde nicht vollständig geschrieben."
	return _promote_tmp(path)


## Kopf eines Spielstands: nur zur Anzeige und Fehlersuche, beim Laden nicht nötig.
static func _meta(game: GameStateScript) -> Dictionary:
	return {
		"app_version": ProjectSettings.get_setting("application/config/version", "?"),
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"game_minutes": game.time.get_minutes(),
		"day_label": game.time.format_date(),
		"clock": game.time.format_clock(),
		"private_balance_cents": game.ledger.get_balance(LedgerSystemScript.PRIVATE),
		"data_id": game.data.fingerprint if game.data != null else "",
	}


## Rotiert die Backups und macht <pfad>.tmp zur Hauptdatei. "" = ok.
## Rotiert wird nur, wenn es eine Hauptdatei gibt – fehlt sie (z. B. als defekt aufbewahrt),
## bleiben die vorhandenen Backups, wo sie sind.
static func _promote_tmp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return _rename(path + TMP_SUFFIX, path)
	for i in range(BACKUP_SUFFIXES.size() - 1, 0, -1):
		var older := path + BACKUP_SUFFIXES[i]
		var newer := path + BACKUP_SUFFIXES[i - 1]
		if FileAccess.file_exists(newer):
			if FileAccess.file_exists(older):
				DirAccess.remove_absolute(older)
			var rotate_error := DirAccess.rename_absolute(newer, older)
			if rotate_error != OK:
				return "Backup des Spielstands fehlgeschlagen (Fehler %d)." % rotate_error
	var backup_error := DirAccess.rename_absolute(path, path + BACKUP_SUFFIXES[0])
	if backup_error != OK:
		return "Backup des Spielstands fehlgeschlagen (Fehler %d)." % backup_error
	return _rename(path + TMP_SUFFIX, path)


static func _rename(from_path: String, to_path: String) -> String:
	var error := DirAccess.rename_absolute(from_path, to_path)
	if error != OK:
		return "Spielstand konnte nicht abgeschlossen werden (Fehler %d)." % error
	return ""


static func has_save(path: String = DEFAULT_PATH) -> bool:
	for candidate in _candidates(path):
		if FileAccess.file_exists(candidate):
			return true
	return false


## Kopf des Spielstands, der beim Laden zuerst versucht würde (Hauptdatei, sonst Backup), ohne zu laden –
## für die Anzeige im Hauptmenü. {} wenn keiner lesbar ist oder er keinen Kopf hat.
static func read_meta(path: String = DEFAULT_PATH) -> Dictionary:
	for candidate in [path] + _backup_paths(path):
		if not FileAccess.file_exists(candidate):
			continue
		var json := JSON.new()  # parse() statt parse_string(): kein Fehler im Log bei kaputten Dateien
		if json.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var data: Variant = json.data
		if typeof(data) == TYPE_DICTIONARY and typeof(data.get("meta")) == TYPE_DICTIONARY:
			return data["meta"]
	return {}


## Lädt den neuesten gültigen Stand. Reihenfolge: liegengebliebene .tmp (abgebrochenes Speichern –
## nur wenn vollständig lesbar und alle Prüfungen bestanden; dann wird das Speichern zu Ende geführt),
## Hauptdatei, .bak, .bak2, .bak3. Defekte Dateien werden als .corrupt-<zeit> aufbewahrt und entfernt,
## damit sie nie ein gutes Backup verdrängen; Dateien einer neueren Spielversion bleiben unberührt.
## Ergebnis: {"game": GameState oder null, "error": String, "from_backup": bool, "source": String,
##            "corrupt_kept": Array[String], "notices": PackedStringArray (entfernte Daten)}
## Nach dem Laden prüft ConsistencyCheck die Regeln über System-Grenzen; unstimmig = wie defekt.
## game == null und error == "" bedeutet: Es gibt keinen Spielstand.
static func load_game(game_data: GameDataScript, path: String = DEFAULT_PATH) -> Dictionary:
	var kept: Array[String] = []
	var first_error := ""

	var tmp_path := path + TMP_SUFFIX
	if FileAccess.file_exists(tmp_path):
		var tmp := _load_file(tmp_path, game_data)
		if tmp["game"] != null and _promote_tmp(path).is_empty():
			tmp["source"] = "tmp"
			tmp["corrupt_kept"] = kept
			return tmp
		_keep_corrupt(tmp_path, kept)

	for candidate in [path] + _backup_paths(path):
		if not FileAccess.file_exists(candidate):
			continue
		var result := _load_file(candidate, game_data)
		if result["game"] != null:
			result["from_backup"] = candidate != path
			result["source"] = "main" if candidate == path else candidate.get_extension()
			result["error"] = first_error
			result["corrupt_kept"] = kept
			return result
		if first_error.is_empty():
			first_error = result["error"]
		if not result.get("newer", false):
			_keep_corrupt(candidate, kept)

	return {"game": null, "error": first_error, "from_backup": false, "source": "", "corrupt_kept": kept}


## Löscht Spielstand, Backups, Zwischendatei und aufbewahrte defekte Stände.
static func delete_save(path: String = DEFAULT_PATH) -> void:
	for file_path in _candidates(path) + corrupt_files(path):
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


## Aufbewahrte defekte Stände, älteste zuerst.
static func corrupt_files(path: String = DEFAULT_PATH) -> Array[String]:
	var result: Array[String] = []
	var dir := path.get_base_dir()
	var prefix := path.get_file().get_basename() + ".corrupt-"
	for file_name in DirAccess.get_files_at(dir):
		if file_name.begins_with(prefix) and file_name.ends_with(".json"):
			result.append(dir.path_join(file_name))
	result.sort()
	return result


static func _backup_paths(path: String) -> Array[String]:
	var result: Array[String] = []
	for suffix in BACKUP_SUFFIXES:
		result.append(path + suffix)
	return result


static func _candidates(path: String) -> Array[String]:
	var result: Array[String] = [path, path + TMP_SUFFIX]
	result.append_array(_backup_paths(path))
	return result


## Verschiebt eine defekte Datei nach <name>.corrupt-<zeit>-<n>.json; behält höchstens CORRUPT_KEEP.
static func _keep_corrupt(file_path: String, kept: Array[String]) -> void:
	var base := file_path.get_base_dir().path_join(_corrupt_base(file_path))
	# Mikrosekunden: Namen sortieren zeitlich richtig, auch bei mehreren Dateien pro Sekunde.
	var stamp := "%017.6f" % Time.get_unix_time_from_system()
	var number := 1
	var target := "%s.corrupt-%s-%d.json" % [base, stamp, number]
	while FileAccess.file_exists(target):  # mehrere defekte Dateien in derselben Sekunde
		number += 1
		target = "%s.corrupt-%s-%d.json" % [base, stamp, number]
	if DirAccess.rename_absolute(file_path, target) != OK:
		DirAccess.remove_absolute(file_path)
		return
	kept.append(target)
	var existing := corrupt_files(base + ".json")
	while existing.size() > CORRUPT_KEEP:
		DirAccess.remove_absolute(existing.pop_front())


## "user://savegame.json.bak2" -> "user://savegame"
static func _corrupt_base(file_path: String) -> String:
	var name := file_path.get_file()
	return name.substr(0, name.find(".json")) if name.find(".json") >= 0 else name.get_basename()


static func _load_file(path: String, game_data: GameDataScript) -> Dictionary:
	var failed := func(message: String, newer: bool = false) -> Dictionary:
		return {"game": null, "error": message, "from_backup": false, "newer": newer}

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
		return failed.call("Der Spielstand stammt aus einer neueren Spielversion (%d) und kann nicht geladen werden." % int(version), true)
	if typeof(data.get("game")) != TYPE_DICTIONARY:
		return failed.call("Der Spielstand enthält keine Spieldaten.")
	var migration_error := _migrate(data, int(version))
	if not migration_error.is_empty():
		return failed.call("Der Spielstand konnte nicht umgewandelt werden: %s" % migration_error)

	var game := GameStateScript.new(game_data)
	var error := game.restore(data["game"])
	if not error.is_empty():
		return failed.call("Der Spielstand ist ungültig: %s" % error)
	var problems := ConsistencyCheckScript.check(game)
	if not problems.is_empty():
		return failed.call("Der Spielstand ist unstimmig: %s" % "; ".join(problems))
	return {"game": game, "error": "", "from_backup": false, "notices": game.load_notices()}


## Neue Formatversion: SAVE_VERSION erhöhen, in _run_migration() einen Schritt n → n + 1 ergänzen
## und eine echte Testdatei tests/fixtures/saves/v<neu>.json anlegen (siehe tests/test_save_fixtures.gd).
## Hebt ältere Formate schrittweise auf SAVE_VERSION an (ändert `data` direkt). "" = ok, sonst Fehlertext.
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
		11: return _migrate_11_to_12(game)
		12: return _migrate_12_to_13(game)
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
	if typeof(company.get("founded")) == TYPE_BOOL and company["founded"]:
		var minutes: Variant = _saved_minutes(game)
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
	if typeof(company.get("founded")) == TYPE_BOOL and company["founded"]:
		company["branch_open"] = false
	return ""


## 9 → 10 (Phase 5): Wertstellung je Buchung (LedgerSystem.migrate_effective_dates()).
static func _migrate_9_to_10(game: Dictionary) -> String:
	if typeof(game.get("ledger")) != TYPE_DICTIONARY:
		return "Ledger fehlt."
	return LedgerSystemScript.migrate_effective_dates(game["ledger"])


## 10 → 11 (Phase 5): Fristen – leer; vergangene Wochen werden nicht nachberechnet.
static func _migrate_10_to_11(game: Dictionary) -> String:
	var minutes: Variant = _saved_minutes(game)
	if not DataReaderScript.is_whole_number(minutes):
		return "Zeit fehlt."
	game["obligations"] = {"last_processed_day": TimeSystemScript.day_of(int(minutes)), "instances": []}
	return ""


## 11 → 12 (Phase 6): Frist-Instanzen speichern Konto, Kategorie und Bezeichnung selbst. Hier leer;
## ObligationSystem.restore() ergänzt sie aus den Daten (oder Ersatzwerte, wenn die Frist entfallen ist).
static func _migrate_11_to_12(game: Dictionary) -> String:
	var obligations: Variant = game.get("obligations")
	if typeof(obligations) != TYPE_DICTIONARY or typeof(obligations.get("instances")) != TYPE_ARRAY:
		return "Fristen fehlen."
	for instance in obligations["instances"]:
		if typeof(instance) != TYPE_DICTIONARY:
			return "Frist-Instanz ungültig."
		for field in ["account", "category", "label"]:
			if not instance.has(field):
				instance[field] = ""
	return ""


## 12 → 13 (G5.3): Tagesbeginn – der Kalender für den aktuellen Tag gilt als schon gezeigt (sonst würde er sich
## beim ersten Laden eines alten Stands sofort öffnen); ab dem nächsten Tageswechsel öffnet er sich wie gewohnt.
static func _migrate_12_to_13(game: Dictionary) -> String:
	var minutes: Variant = _saved_minutes(game)
	if not DataReaderScript.is_whole_number(minutes) or int(minutes) < 0:
		return "Zeit fehlt."
	game["day_start"] = {"calendar_shown_day": TimeSystemScript.day_of(int(minutes))}
	return ""


## Gespeicherte Spielzeit oder null – robust gegen beschädigte Dateien (falscher Typ von "time").
static func _saved_minutes(game: Dictionary) -> Variant:
	var time: Variant = game.get("time")
	return time.get("minutes") if typeof(time) == TYPE_DICTIONARY else null

