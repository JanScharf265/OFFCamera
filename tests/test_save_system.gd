extends "res://tests/base_test.gd"

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const PATH := "user://test_savegame.json"

var _data: GameDataScript


func _init() -> void:
	SaveSystemScript.delete_save(PATH)
	_data = Helpers.game_data()


func _new_game() -> GameStateScript:
	return GameStateScript.new(_data)


func _load() -> Dictionary:
	return SaveSystemScript.load_game(_data, PATH)


func _write(text: String, path: String = PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Spielt bis nach dem ersten Ereignis (20:00) und entscheidet "accept".
func _played_game() -> GameStateScript:
	var game := _new_game()
	game.locations.travel("studio")        # 08:00 -> 08:20
	game.content.produce("livestream")     # -> 10:20, +25 €
	game.locations.travel("cafe_harbor")   # -> 10:40
	game.activities.start("eat_out")       # -> 11:40, -15 €
	game.time.advance(TimeSystemScript.at(1, 20) - game.time.get_minutes())  # Termin 14:00 verpasst, Ereignis fällig
	game.events.resolve("first_brand_request", "accept")  # +30 €
	return game


func test_missing_save_is_not_an_error() -> void:
	var result := _load()
	assert_true(result["game"] == null, "ohne Datei darf kein Spiel geladen werden")
	assert_eq(result["error"], "")
	assert_eq(SaveSystemScript.has_save(PATH), false)


func test_round_trip_restores_everything() -> void:
	var original := _played_game()
	assert_eq(SaveSystemScript.save(original, PATH), "")
	var result := _load()
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen: %s" % result["error"])
	if loaded == null:
		return
	assert_eq(loaded.time.get_minutes(), original.time.get_minutes())
	assert_eq(loaded.ledger.get_balance(), original.ledger.get_balance())
	assert_eq(loaded.ledger.get_balance(), 50000 + 2500 - 1500 + 3000)
	assert_eq(loaded.ledger.recalculate_balance(), loaded.ledger.get_balance())
	assert_eq(loaded.ledger.to_dict(), original.ledger.to_dict())
	assert_eq(loaded.stats.to_dict(), original.stats.to_dict())
	assert_eq(loaded.locations.get_current(), "cafe_harbor")
	assert_eq(loaded.appointments.is_missed("camera_meeting"), true)
	assert_eq(loaded.appointments.to_dict(), original.appointments.to_dict())
	assert_eq(loaded.events.is_resolved("first_brand_request"), true)
	assert_eq(loaded.events.has_pending(), false)
	assert_eq(result["from_backup"], false)


func test_saving_twice_gives_identical_files() -> void:
	var game := _played_game()
	SaveSystemScript.save(game, PATH)
	var first := FileAccess.get_file_as_string(PATH)
	var loaded: GameStateScript = _load()["game"]
	SaveSystemScript.save(loaded, PATH)
	assert_eq(FileAccess.get_file_as_string(PATH), first)


func test_loading_does_not_retrigger_or_rebook_events() -> void:
	SaveSystemScript.save(_played_game(), PATH)
	var loaded: GameStateScript = _load()["game"]
	var triggered := []
	var on_triggered := func(id: String) -> void: triggered.append(id)
	loaded.events.event_triggered.connect(on_triggered)
	loaded.time.advance(2 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(triggered, [])
	assert_eq(loaded.events.resolve("first_brand_request", "accept"), "Dieses Ereignis ist nicht offen.")
	var again := loaded.ledger.post(3000, "creator", "Test", "event", "", "event:first_brand_request")
	assert_true(again == null, "Schutzschlüssel nach dem Laden verloren")
	assert_eq(loaded.ledger.last_rejection, LedgerSystemScript.Rejection.DUPLICATE)
	loaded.events.event_triggered.disconnect(on_triggered)


func test_pending_event_stays_pending_after_load() -> void:
	var game := _new_game()
	game.time.advance(12 * 60)  # -> 20:00, Ereignis offen
	SaveSystemScript.save(game, PATH)
	var loaded: GameStateScript = _load()["game"]
	assert_eq(loaded.events.get_next_pending().id, "first_brand_request")
	assert_eq(loaded.events.resolve("first_brand_request", "accept"), "")
	assert_eq(loaded.ledger.get_balance(), 53000)


func test_ids_continue_after_load() -> void:
	SaveSystemScript.save(_played_game(), PATH)
	var loaded: GameStateScript = _load()["game"]
	var entry := loaded.ledger.post(-100, "food", "Kaffee", "activity")
	assert_eq(entry.id, "tx_000004")


func test_second_save_keeps_backup_of_first() -> void:
	var game := _new_game()
	SaveSystemScript.save(game, PATH)
	game.activities.start("rest")
	SaveSystemScript.save(game, PATH)
	assert_true(FileAccess.file_exists(PATH + ".bak"), "Backup fehlt")
	assert_eq(FileAccess.file_exists(PATH + ".tmp"), false)


func test_corrupt_save_falls_back_to_backup() -> void:
	var game := _new_game()
	SaveSystemScript.save(game, PATH)       # wird zum Backup
	game.activities.start("rest")
	SaveSystemScript.save(game, PATH)
	_write("{ kaputt")
	var result := _load()
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "Backup wurde nicht geladen")
	assert_eq(result["from_backup"], true)
	assert_true("beschädigt" in result["error"], result["error"])
	assert_eq(loaded.time.format_clock(), "08:00")


func test_corrupt_save_without_backup_reports_error() -> void:
	_write("das ist kein json")
	var result := _load()
	assert_true(result["game"] == null, "kaputte Datei darf nicht laden")
	assert_true("beschädigt" in result["error"], result["error"])


func test_newer_version_is_rejected() -> void:
	_write(JSON.stringify({"version": SaveSystemScript.SAVE_VERSION + 1, "game": {}}))
	var result := _load()
	assert_true(result["game"] == null, "neuere Version darf nicht laden")
	assert_true("neueren" in result["error"], result["error"])


func test_missing_version_is_rejected() -> void:
	_write(JSON.stringify({"game": _new_game().to_dict()}))
	assert_true("Versionsnummer" in _load()["error"], "Versionsfehler erwartet")


func test_invalid_values_are_rejected() -> void:
	var cases := {
		"energy": func(d: Dictionary) -> void: d["game"]["stats"]["energy"] = 150,
		"minutes": func(d: Dictionary) -> void: d["game"]["time"]["minutes"] = -5,
		"entry": func(d: Dictionary) -> void: d["game"]["ledger"]["entries"][0].erase("description"),
		"next_number": func(d: Dictionary) -> void: d["game"]["ledger"]["next_number"] = 1,
		"pending": func(d: Dictionary) -> void: d["game"]["events"]["pending"] = ["unknown_but_not_triggered"],
		"missing_ledger": func(d: Dictionary) -> void: d["game"].erase("ledger"),
		"missing_location": func(d: Dictionary) -> void: d["game"].erase("location"),
		"location_type": func(d: Dictionary) -> void: d["game"]["location"]["current"] = 5,
		"missing_appointments": func(d: Dictionary) -> void: d["game"].erase("appointments"),
		"appointment_both": func(d: Dictionary) -> void: d["game"]["appointments"]["attended"] = ["camera_meeting"],
		"appointment_since": func(d: Dictionary) -> void: d["game"]["appointments"]["since_minutes"] = -1,
	}
	for name in cases:
		var data := {"version": SaveSystemScript.SAVE_VERSION, "game": _played_game().to_dict()}
		data = JSON.parse_string(JSON.stringify(data))  # wie aus einer Datei: Zahlen als float
		cases[name].call(data)
		_write(JSON.stringify(data))
		SaveSystemScript.delete_save(PATH + ".bak")
		var result := _load()
		assert_true(result["game"] == null, "Fall '%s' hätte abgelehnt werden müssen" % name)
		assert_true(not result["error"].is_empty(), "Fall '%s' ohne Fehlermeldung" % name)
	SaveSystemScript.delete_save(PATH)


func test_delete_save_removes_all_files() -> void:
	var game := _new_game()
	SaveSystemScript.save(game, PATH)
	SaveSystemScript.save(game, PATH)
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.has_save(PATH), false)
	assert_eq(FileAccess.file_exists(PATH + ".bak"), false)


## Spielstand im Format von Version 1 (Phase 1): ohne Ort und Termine.
func _version_1_text(minutes: int) -> String:
	var game := _new_game().to_dict()
	game.erase("location")
	game.erase("appointments")
	game.erase("channel")
	game["time"]["minutes"] = minutes
	return JSON.stringify({"version": 1, "game": game})


func test_save_file_has_current_version_with_location_and_appointments() -> void:
	SaveSystemScript.save(_new_game(), PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), 3)
	assert_eq(data["game"]["location"], {"current": "home"})
	assert_eq(int(data["game"]["appointments"]["since_minutes"]), TimeSystemScript.at(1, 8))


func test_version_1_is_migrated_to_home_without_penalties() -> void:
	_write(_version_1_text(TimeSystemScript.at(1, 15)))  # nach dem Termin um 14:00
	var result := _load()
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "Migration fehlgeschlagen: %s" % result["error"])
	if loaded == null:
		return
	assert_eq(loaded.locations.get_current(), "home")
	assert_eq(loaded.time.format_clock(), "15:00")
	# Der Termin von 14:00 lag vor dem Laden: entfällt ohne Strafe.
	assert_eq(loaded.appointments.is_open("camera_meeting"), false)
	var mood := loaded.stats.mood
	loaded.activities.start("rest")
	assert_eq(loaded.appointments.is_missed("camera_meeting"), false)
	assert_eq(loaded.stats.mood, mood + 3)
	# Spätere Termine gelten normal.
	assert_eq(loaded.appointments.is_open("gym_trial"), true)


func test_migrated_save_is_written_as_current_version() -> void:
	_write(_version_1_text(TimeSystemScript.at(1, 9)))
	var loaded: GameStateScript = _load()["game"]
	SaveSystemScript.save(loaded, PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), SaveSystemScript.SAVE_VERSION)
	assert_eq(loaded.appointments.is_open("camera_meeting"), true)


func test_version_1_without_time_is_rejected() -> void:
	_write(JSON.stringify({"version": 1, "game": {"ledger": {}}}))
	var result := _load()
	assert_true(result["game"] == null, "kaputter v1-Stand darf nicht laden")
	assert_true("umgewandelt" in result["error"], result["error"])


func test_unknown_location_falls_back_to_home() -> void:
	var data := {"version": SaveSystemScript.SAVE_VERSION, "game": _new_game().to_dict()}
	data["game"]["location"]["current"] = "abgerissen"
	_write(JSON.stringify(data))
	var loaded: GameStateScript = _load()["game"]
	assert_true(loaded != null, "unbekannter Ort sollte nicht abbrechen")
	if loaded != null:
		assert_eq(loaded.locations.get_current(), "home")


## Spielstand im Format von Version 2 (Phase 2): ohne Kanal.
func _version_2_text() -> String:
	var game := _played_game().to_dict()
	game.erase("channel")
	return JSON.stringify({"version": 2, "game": game})


func test_version_2_is_migrated_with_channel_start_values() -> void:
	var played := _played_game()
	_write(_version_2_text())
	var result := _load()
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "Migration fehlgeschlagen: %s" % result["error"])
	if loaded == null:
		return
	assert_eq(loaded.channel.followers, GameStateScript.START_FOLLOWERS)
	assert_eq(loaded.channel.community, GameStateScript.START_COMMUNITY)
	assert_eq(loaded.channel.reputation, GameStateScript.START_REPUTATION)
	assert_true(loaded.channel.get_history().is_empty(), "Protokoll sollte leer sein")
	# Alles andere bleibt wie gespeichert.
	assert_eq(loaded.time.get_minutes(), played.time.get_minutes())
	assert_eq(loaded.ledger.get_balance(), played.ledger.get_balance())


func test_channel_survives_save_and_load() -> void:
	var game := _new_game()
	game.channel.apply({"followers": 30, "reputation": 4}, "test", "Testlauf")
	SaveSystemScript.save(game, PATH)
	var loaded: GameStateScript = _load()["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded == null:
		return
	assert_eq(loaded.channel.followers, 150)
	assert_eq(loaded.channel.reputation, 54)
	assert_eq(loaded.channel.get_history().size(), 1)
	assert_eq(loaded.channel.get_history()[0].reason, "Testlauf")
