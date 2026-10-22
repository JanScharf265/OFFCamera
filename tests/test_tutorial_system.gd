extends "res://tests/base_test.gd"

## Ticket T.2: TutorialSystem – Auslöser → fällig; requires und Reihenfolge; genau einmal nach mark_seen; nach Laden
## nicht doppelt; unbestätigt bleibt fällig (auch nach Laden); Migration v14 → v15 mit der Spielstart-Regel;
## kein Zeit-/Geldeffekt; Auslöser aus Systemen und Spielansicht.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")
const TutorialSystemScript := preload("res://scripts/systems/tutorial_system.gd")

const SAVE_PATH := "user://test_tutorial_system_save.json"


func _entry(id: String, trigger: String, order: int, requires: Array = []) -> Dictionary:
	return {"id": id, "mechanic": "m_" + id, "trigger": trigger, "title": "T", "text": "Text.", "ui_target": "",
			"order": order, "requires": requires}


## Testkatalog: zwei Spielstart-Tutorials (b vor a nach order), c braucht a, d an einem anderen Auslöser.
func _system() -> TutorialSystemScript:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_data([
		_entry("tut_a", "first_game_start", 20),
		_entry("tut_b", "first_game_start", 10),
		_entry("tut_c", "first_location_open", 5, ["tut_a"]),
		_entry("tut_d", "first_calendar_open", 1),
	]), "; ".join(catalog.errors))
	return TutorialSystemScript.new(catalog)


func test_trigger_makes_matching_tutorials_due_in_order() -> void:
	var system := _system()
	assert_eq(system.get_due(), PackedStringArray(), "ohne Auslöser nichts")
	assert_eq(system.report("first_game_start"), true)
	assert_eq(system.get_due(), PackedStringArray(["tut_b", "tut_a"]), "nach order")
	assert_eq(system.get_next_due(), "tut_b")
	system.report("first_calendar_open")
	assert_eq(system.get_due(), PackedStringArray(["tut_d", "tut_b", "tut_a"]))
	assert_eq(system.report("no_such_trigger"), false)
	assert_eq(system.was_reported("no_such_trigger"), false)


func test_requires_wait_until_seen() -> void:
	var system := _system()
	system.report("first_location_open")
	assert_eq(system.get_due(), PackedStringArray(), "tut_c braucht tut_a")
	system.report("first_game_start")
	assert_eq(system.mark_seen("tut_a"), "")
	assert_eq(system.get_due(), PackedStringArray(["tut_c", "tut_b"]), "jetzt fällig, nach order")


func test_exactly_once_after_mark_seen() -> void:
	var system := _system()
	system.report("first_game_start")
	assert_eq(system.mark_seen("tut_b"), "")
	assert_eq(system.get_due(), PackedStringArray(["tut_a"]))
	system.report("first_game_start")  # erneut gemeldet
	assert_eq(system.get_due(), PackedStringArray(["tut_a"]), "tut_b nicht noch einmal")
	assert_eq(system.mark_seen("nope"), "Unbekanntes Tutorial: nope")
	assert_eq(system.is_seen("nope"), false)


func test_due_signal() -> void:
	var system := _system()
	var due := []
	system.tutorial_due.connect(func(id: String) -> void: due.append(id))
	system.report("first_game_start")
	system.report("first_game_start")
	assert_eq(due, ["tut_b"], "einmal je neuem Auslöser")


func test_round_trip_keeps_seen_and_unconfirmed_due() -> void:
	var system := _system()
	system.report("first_game_start")
	system.mark_seen("tut_b")
	var copy := _system()
	assert_eq(copy.restore(system.to_dict()), "")
	assert_eq(copy.get_due(), PackedStringArray(["tut_a"]), "unbestätigt bleibt fällig, bestätigt kommt nicht wieder")
	assert_eq(copy.to_dict(), {"fired": ["first_game_start"], "seen": ["tut_b"], "seen_triggers": []})
	for bad in [{"fired": [], "seen": "x", "seen_triggers": []}, {"fired": [1], "seen": [], "seen_triggers": []},
			{"fired": [], "seen": []}]:
		assert_true(not copy.restore(bad).is_empty(), "angenommen: %s" % bad)
	assert_eq(copy.get_due(), PackedStringArray(["tut_a"]), "bei Fehler unverändert")


func test_seen_triggers_count_as_seen() -> void:
	var system := _system()
	assert_eq(system.restore({"fired": [], "seen": [], "seen_triggers": ["first_game_start"]}), "")
	system.report("first_game_start")
	system.report("first_location_open")
	assert_eq(system.get_due(), PackedStringArray(["tut_c"]), "Spielstart gilt als gesehen, tut_c (braucht tut_a) frei")


# --- Im Spiel ------------------------------------------------------------------------

func test_real_game_save_load_not_double_and_no_effects() -> void:
	var game := Helpers.new_game()
	var before := {"minutes": game.time.get_minutes(), "balance": game.ledger.get_balance(), "energy": game.stats.energy,
			"mood": game.stats.mood, "entries": game.ledger.get_entries().size()}
	game.tutorials.report("first_game_start")
	assert_eq(game.tutorials.get_next_due(), "tut_map")
	assert_eq(game.tutorials.mark_seen("tut_map"), "")
	assert_eq(game.tutorials.get_next_due(), "tut_map_tap_building", "noch nicht bestätigt")
	assert_eq({"minutes": game.time.get_minutes(), "balance": game.ledger.get_balance(), "energy": game.stats.energy,
			"mood": game.stats.mood, "entries": game.ledger.get_entries().size()}, before, "kein Zeit-/Geldeffekt")
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.tutorials.is_seen("tut_map"), true)
		assert_eq(loaded.tutorials.get_due(), PackedStringArray(["tut_map_tap_building"]),
				"nach Laden: gesehen bleibt gesehen, unbestätigt bleibt fällig")
		loaded.tutorials.mark_seen("tut_map_tap_building")
		assert_eq(loaded.tutorials.get_due(), PackedStringArray())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_system_signals_report_event_and_obligation() -> void:
	var game := Helpers.new_game()
	game.time.advance(TimeSystemScript.at(1, 21) - game.time.get_minutes())
	assert_eq(game.tutorials.was_reported("first_event"), true)
	assert_eq(game.tutorials.was_reported("first_obligation_due"), false)
	game.events.resolve(game.events.get_next_pending_id(), "decline")
	game.time.advance(TimeSystemScript.at(8, 9) - game.time.get_minutes())  # Montag: Miete fällig
	assert_eq(game.tutorials.was_reported("first_obligation_due"), true)


func test_game_screen_reports_triggers() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var tutorials = app.game.tutorials
	assert_eq(tutorials.was_reported("first_game_start"), true)
	assert_eq(tutorials.was_reported("first_location_open"), false)
	(app.find_child("MapPin_home", true, false) as Button).pressed.emit()
	assert_eq(tutorials.was_reported("first_location_open"), true)
	assert_eq(tutorials.was_reported("first_location_elsewhere"), false, "Wohnung = hier")
	(app.find_child("MapPin_studio", true, false) as Button).pressed.emit()
	assert_eq(tutorials.was_reported("first_location_elsewhere"), true)
	(app.find_child("AppointmentsButton", true, false) as Button).pressed.emit()
	assert_eq(tutorials.was_reported("first_calendar_open"), true)
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	app.find_child("CityMap", true, false).get_parent().call("_refresh")
	assert_eq(tutorials.was_reported("first_appointment_reminder"), false, "Kalender offen – Erinnerung wartet")
	(app.find_child("WindowCloseButton", true, false) as Button).pressed.emit()
	assert_eq(tutorials.was_reported("first_appointment_reminder"), true)
	assert_eq(app.game.time.format_clock(), "13:30", "Melden kostet keine Zeit")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Migration ------------------------------------------------------------------------

func _load_old(json_text: String) -> GameStateScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(json_text)
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	assert_true(result["game"] != null, "lädt nicht: %s" % result["error"])
	return result["game"]


func test_migration_14_to_15_counts_game_start_as_seen() -> void:
	var game := _load_old(FileAccess.get_file_as_string("res://tests/fixtures/saves/v14.json"))
	if game != null:
		assert_eq(game.tutorials.to_dict(), {"fired": [], "seen": [], "seen_triggers": ["first_game_start"]})
		game.tutorials.report("first_game_start")
		assert_eq(game.tutorials.is_seen("tut_map"), true, "Spielstart-Erklärung gilt als gesehen")
		assert_eq(game.tutorials.get_due(), PackedStringArray(), "nichts vom Spielstart fällig")
		game.tutorials.report("first_location_elsewhere")
		assert_eq(game.tutorials.get_due(), PackedStringArray(["tut_travel"]), "andere Tutorials kommen normal")
	# Ein selbst gebauter v14-Stand (ohne Abschnitt) wird genauso migriert.
	var current := Helpers.new_game().to_dict()
	current.erase("tutorials")
	game = _load_old(JSON.stringify({"version": 14, "game": current}))
	if game != null:
		assert_eq(game.tutorials.to_dict()["seen_triggers"], ["first_game_start"])
	SaveSystemScript.delete_save(SAVE_PATH)
