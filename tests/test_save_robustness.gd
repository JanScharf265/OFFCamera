extends "res://tests/base_test.gd"

## Ticket 6.2: robustes Schreiben und Laden – Kopf, 3 Backups, liegengebliebene .tmp,
## defekte Stände aufbewahren und nie überschreiben.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const PATH := "user://test_robust_save.json"


func _init() -> void:
	SaveSystemScript.delete_save(PATH)


func _game_at(hour: int) -> GameStateScript:
	var game := Helpers.new_game()
	game.time.advance(TimeSystemScript.at(1, hour) - game.time.get_minutes())
	return game


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _minutes_in(path: String) -> int:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data["game"]["time"]["minutes"])


func _load() -> Dictionary:
	return SaveSystemScript.load_game(Helpers.game_data(), PATH)


func test_save_writes_header() -> void:
	SaveSystemScript.delete_save(PATH)
	var game := _game_at(10)
	assert_eq(SaveSystemScript.save(game, PATH), "")
	var meta := SaveSystemScript.read_meta(PATH)
	assert_eq(meta["day_label"], "Tag 1 · Mo")
	assert_eq(meta["clock"], "10:00")
	assert_eq(int(meta["private_balance_cents"]), 50000)
	assert_eq(meta["data_id"], game.data.fingerprint)
	assert_true(String(meta["data_id"]).length() == 32, "Datenkennung fehlt")
	assert_true(int(meta["saved_at_unix"]) > 0, "Speicherzeit fehlt")
	SaveSystemScript.delete_save(PATH)


func test_three_backups_rotate() -> void:
	SaveSystemScript.delete_save(PATH)
	for hour in [9, 10, 11, 12, 13]:
		assert_eq(SaveSystemScript.save(_game_at(hour), PATH), "")
	assert_eq(_minutes_in(PATH), TimeSystemScript.at(1, 13))
	assert_eq(_minutes_in(PATH + ".bak"), TimeSystemScript.at(1, 12))
	assert_eq(_minutes_in(PATH + ".bak2"), TimeSystemScript.at(1, 11))
	assert_eq(_minutes_in(PATH + ".bak3"), TimeSystemScript.at(1, 10))
	assert_eq(FileAccess.file_exists(PATH + ".tmp"), false)
	SaveSystemScript.delete_save(PATH)


## Regressionstest (Entscheidung Game Director): Eine halb geschriebene .tmp wird nicht übernommen,
## sondern als defekter Stand aufbewahrt; geladen wird die Hauptdatei.
func test_half_written_tmp_is_ignored_and_kept() -> void:
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(_game_at(10), PATH)
	var newer := JSON.stringify({"version": SaveSystemScript.SAVE_VERSION, "game": _game_at(15).to_dict()}, "\t")
	_write(PATH + ".tmp", newer.substr(0, newer.length() / 2))  # Absturz mitten im Schreiben
	var result := _load()
	assert_true(result["game"] != null, "Hauptdatei nicht geladen: %s" % result["error"])
	if result["game"] != null:
		assert_eq(result["game"].time.format_clock(), "10:00")
	assert_eq(result["source"], "main")
	assert_eq(FileAccess.file_exists(PATH + ".tmp"), false)
	assert_eq(result["corrupt_kept"].size(), 1)
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 1)
	SaveSystemScript.delete_save(PATH)


func test_tmp_that_fails_checks_is_ignored() -> void:
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(_game_at(10), PATH)
	var broken := _game_at(15).to_dict()
	broken["ledger"]["entries"] = "kaputt"  # vollständig lesbar, aber ungültig
	_write(PATH + ".tmp", JSON.stringify({"version": SaveSystemScript.SAVE_VERSION, "game": broken}))
	var result := _load()
	assert_eq(result["game"].time.format_clock(), "10:00")
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 1)
	SaveSystemScript.delete_save(PATH)


func test_valid_tmp_finishes_interrupted_save() -> void:
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(_game_at(10), PATH)
	# Absturz nach dem Schreiben der .tmp, vor dem Umbenennen:
	_write(PATH + ".tmp", JSON.stringify({"version": SaveSystemScript.SAVE_VERSION, "game": _game_at(15).to_dict()}))
	var result := _load()
	assert_eq(result["source"], "tmp")
	assert_eq(result["game"].time.format_clock(), "15:00")
	assert_eq(_minutes_in(PATH), TimeSystemScript.at(1, 15))  # Speichern zu Ende geführt
	assert_eq(_minutes_in(PATH + ".bak"), TimeSystemScript.at(1, 10))
	assert_eq(FileAccess.file_exists(PATH + ".tmp"), false)
	SaveSystemScript.delete_save(PATH)


func test_corrupt_main_is_kept_and_never_overwritten() -> void:
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(_game_at(10), PATH)
	SaveSystemScript.save(_game_at(11), PATH)
	_write(PATH, "{ kaputt")
	var result := _load()
	assert_eq(result["from_backup"], true)
	assert_eq(result["source"], "bak")
	assert_eq(result["game"].time.format_clock(), "10:00")
	var kept := SaveSystemScript.corrupt_files(PATH)
	assert_eq(kept.size(), 1)
	if kept.size() == 1:
		assert_eq(FileAccess.get_file_as_string(kept[0]), "{ kaputt")
	# Weiterspielen und speichern: Die defekte Datei bleibt, das gute Backup wird nicht verdrängt.
	SaveSystemScript.save(result["game"], PATH)
	assert_eq(FileAccess.get_file_as_string(kept[0]), "{ kaputt")
	assert_eq(_minutes_in(PATH + ".bak"), TimeSystemScript.at(1, 10))
	SaveSystemScript.delete_save(PATH)


func test_at_most_three_corrupt_copies_are_kept() -> void:
	SaveSystemScript.delete_save(PATH)
	for i in 5:
		_write(PATH, "kaputt %d" % i)
		_load()
	var kept := SaveSystemScript.corrupt_files(PATH)
	assert_eq(kept.size(), 3)
	if kept.size() == 3:
		assert_eq(FileAccess.get_file_as_string(kept[2]), "kaputt 4")
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 0)


func test_newer_version_is_left_untouched() -> void:
	SaveSystemScript.delete_save(PATH)
	_write(PATH, JSON.stringify({"version": SaveSystemScript.SAVE_VERSION + 1, "game": {}}))
	var result := _load()
	assert_true(result["game"] == null, "neuere Version geladen")
	assert_true("neueren Spielversion" in result["error"], result["error"])
	assert_eq(FileAccess.file_exists(PATH), true)  # nicht als defekt verschoben
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 0)
	SaveSystemScript.delete_save(PATH)


func test_backups_are_tried_in_order() -> void:
	SaveSystemScript.delete_save(PATH)
	for hour in [9, 10, 11, 12]:
		SaveSystemScript.save(_game_at(hour), PATH)
	_write(PATH, "kaputt")
	_write(PATH + ".bak", "kaputt")
	var result := _load()
	assert_eq(result["source"], "bak2")
	assert_eq(result["game"].time.format_clock(), "10:00")
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 2)
	SaveSystemScript.delete_save(PATH)


func test_has_save_sees_any_backup() -> void:
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.has_save(PATH), false)
	_write(PATH + ".bak3", "x")
	assert_eq(SaveSystemScript.has_save(PATH), true)
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.has_save(PATH), false)


func test_no_save_during_time_advance() -> void:
	SaveSystemScript.delete_save(PATH)
	var game := Helpers.new_game()
	var errors: Array[String] = []
	game.time.time_advanced.connect(func(_from: int, _to: int) -> void:
		errors.append(SaveSystemScript.save(game, PATH)))
	game.time.advance(60)
	assert_eq(errors, ["Speichern während eines Zeitfortschritts ist nicht möglich."] as Array[String])
	assert_eq(SaveSystemScript.has_save(PATH), false)
	SaveSystemScript.delete_save(PATH)


func test_old_saves_without_header_still_load() -> void:
	SaveSystemScript.delete_save(PATH)
	_write(PATH, JSON.stringify({"version": SaveSystemScript.SAVE_VERSION, "game": _game_at(10).to_dict()}))
	assert_true(_load()["game"] != null, "Stand ohne Kopf lädt nicht")
	assert_eq(SaveSystemScript.read_meta(PATH), {})
	SaveSystemScript.delete_save(PATH)
