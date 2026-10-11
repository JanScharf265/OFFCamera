extends "res://tests/base_test.gd"

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const PATH := "user://test_savegame.json"

var _activities: ActivityCatalogScript
var _events: EventCatalogScript


func _init() -> void:
	SaveSystemScript.delete_save(PATH)
	_activities = ActivityCatalogScript.new()
	_activities.load_file()
	_events = EventCatalogScript.new()
	_events.load_file()


func _new_game() -> GameStateScript:
	return GameStateScript.new(_activities, _events)


func _load() -> Dictionary:
	return SaveSystemScript.load_game(_activities, _events, PATH)


func _write(text: String, path: String = PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Spielt bis nach dem ersten Ereignis (20:00) und entscheidet "accept".
func _played_game() -> GameStateScript:
	var game := _new_game()
	game.activities.start("stream_short")  # 08 -> 10, +25 €
	game.activities.start("eat_out")       # 10 -> 11, -15 €
	game.time.advance(9 * 60)              # 11 -> 20, Ereignis fällig
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
