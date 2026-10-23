extends "res://tests/base_test.gd"

## Ticket U.4: Story-Aufträge – Katalog mit Prüfung; Kette startet erst mit der Organisation; „Treffen am Hafen“ wird
## bei der Ankunft im Café am Hafen erledigt (Belohnung genau einmal, auch über Speichern/Laden); neue Aufträge aus
## einem Update starten in alten Ständen; roter Punkt; Fenster; Migration v18 → v19.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const MissionCatalogScript := preload("res://scripts/systems/mission_catalog.gd")

const SAVE_PATH := "user://test_missions_save.json"
const FIRST := "first_deal_meeting"


func _mission(id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "chapter": "Test", "title": "T %s" % id, "giver": "X", "briefing": "B.",
			"goal": {"type": "visit_location", "location": "gym"}, "goal_text": "Z.", "debrief": "D.",
			"reward": {"respect": 2}, "order": 0, "requires": []}
	result.merge(extra, true)
	return result


func _founded_game(data = null) -> GameStateScript:
	var game := Helpers.new_game(data)
	assert_eq(game.organisation.found("Los Lobos"), "")
	return game


func test_real_missions_load() -> void:
	var catalog := MissionCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var first = catalog.get_definition(FIRST)
	assert_eq(first.chapter, "Erster Deal")
	assert_eq(first.goal, {"type": "visit_location", "location": "cafe_harbor"})
	assert_eq(Helpers.game_data().errors, PackedStringArray(), "Verweise der Aufträge")


func test_bad_missions_are_rejected() -> void:
	var catalog := MissionCatalogScript.new()
	for bad in [[_mission("m_a", {"goal": {"type": "teleport"}})], [_mission("m_a", {"goal": {"type": "visit_location"}})],
			[_mission("m_a", {"reward": {"money": 5}})], [_mission("m_a", {"extra": 1})],
			[_mission("m_a", {"requires": ["m_x"]})], [_mission("m_a"), _mission("m_a")],
			[_mission("m_a", {"requires": ["m_b"]}), _mission("m_b", {"requires": ["m_a"]})],
			[_mission("m_a", {"briefing": "x".repeat(MissionCatalogScript.MAX_TEXT_LENGTH + 1)})]]:
		assert_eq(catalog.load_data(bad), false, "angenommen: %s" % [bad])
		assert_eq(catalog.get_all().size(), 0)


func test_chain_starts_only_with_organisation() -> void:
	var game := Helpers.new_game()
	game.missions.update_availability()
	assert_eq(game.missions.get_active().size(), 0, "ohne Organisation keine Aufträge")
	assert_eq(game.organisation.found("Los Lobos"), "")
	assert_eq(game.missions.is_active(FIRST), true)
	assert_eq(game.missions.count_unseen(), 1)
	assert_eq(game.tutorials.was_reported("first_mission_available"), true)
	assert_eq(Array(game.missions.take_notices()), ["Neuer Auftrag: „Treffen am Hafen“ (Erster Deal)"])


func test_meeting_completes_on_arrival_once() -> void:
	var game := _founded_game()
	game.missions.take_notices()
	var respect := game.organisation.get_value("respect")
	game.locations.travel("gym")
	assert_eq(game.missions.is_active(FIRST), true, "falscher Ort")
	game.locations.travel("cafe_harbor")
	assert_eq(game.missions.is_completed(FIRST), true)
	assert_eq(game.organisation.get_value("respect"), respect + 5)
	assert_eq(Array(game.missions.take_notices()), ["Auftrag erledigt: „Treffen am Hafen“ (Respekt +5)",
			"Neuer Auftrag: „Die erste Ware“ (Erster Deal)"])
	game.locations.travel("home")
	game.locations.travel("cafe_harbor")
	assert_eq(game.organisation.get_value("respect"), respect + 5, "Belohnung genau einmal")
	var copy := Helpers.new_game()
	assert_eq(copy.restore(game.to_dict()), "")
	copy.locations.travel("home")
	copy.locations.travel("cafe_harbor")
	assert_eq(copy.organisation.get_value("respect"), respect + 5, "auch nach dem Laden nicht noch einmal")


func test_trip_also_counts_as_arrival() -> void:
	var game := _founded_game()
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	assert_eq(game.trips.run("activity", "coffee")["reason"], "")
	assert_eq(game.missions.is_completed(FIRST), true)


func test_next_mission_in_chain_starts_and_update_adds_new_ones() -> void:
	var data := Helpers.game_data()
	assert_true(data.missions.load_data([_mission("m_one", {"order": 1}),
			_mission("m_two", {"order": 2, "requires": ["m_one"], "goal": {"type": "visit_location", "location": "office"}})]))
	var game := _founded_game(data)
	assert_eq(game.missions.is_active("m_one"), true)
	assert_eq(game.missions.is_active("m_two"), false)
	game.locations.travel("gym")
	assert_eq(game.missions.is_active("m_two"), true, "nächster Auftrag der Kette")
	# Ein alter Stand, in dem m_one erledigt ist, bekommt einen neu hinzugekommenen Auftrag beim Laden.
	var old := _founded_game(data)
	old.locations.travel("gym")
	var saved := old.to_dict()
	saved["missions"]["active"] = []
	var fresh := Helpers.new_game(data)
	assert_eq(fresh.restore(saved), "")
	assert_eq(fresh.missions.is_active("m_two"), true, "beim Laden gestartet")


func test_restore_rejects_bad_data_without_change() -> void:
	var game := _founded_game()
	var good := game.missions.to_dict()
	for bad in [{"active": "x", "completed": {}, "unseen": []}, {"active": [], "completed": {"a": -1}, "unseen": []},
			{"active": ["a"], "completed": {"a": 5}, "unseen": []}, {"active": [], "unseen": []}]:
		assert_true(not game.missions.restore(bad).is_empty(), "angenommen: %s" % bad)
	assert_eq(game.missions.to_dict(), good)


func test_migration_18_to_19() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v18.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v18 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.missions.to_dict(), {"active": [], "completed": {}, "unseen": []})
	# Stand mit gegründeter Organisation (v18): Die Kette startet beim Laden.
	var founded := _founded_game().to_dict()
	founded.erase("missions")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 18, "game": founded}))
	file.close()
	game = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(game != null and game.missions.is_active(FIRST), "Kette nicht gestartet")
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Spielansicht ---------------------------------------------------------------------

func test_ui_button_badge_window_and_notice() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	var button := app.find_child("MissionsButton", true, false)
	assert_eq((button as Control).visible, false, "vor der Organisation sichtbar")
	screen.call("on_organisation_name_submitted", "Los Lobos")
	assert_eq((button as Control).visible, true)
	assert_eq(button.call("get_badge"), 1)
	assert_true((app.find_child("FeedbackLabel", true, false) as Label).text.contains(
			"Neuer Auftrag: „Treffen am Hafen“ (Erster Deal)"))
	(button as Button).pressed.emit()
	assert_eq(button.call("get_badge"), 0, "Öffnen gilt als gesehen")
	assert_true(app.find_child("MissionNew_%s" % FIRST, true, false) != null, "„Neu“-Markierung fehlt")
	assert_eq((app.find_child("MissionGoal_%s" % FIRST, true, false) as Label).text, "Ziel: Fahr ins Café am Hafen.")
	(app.find_child("WindowCloseButton", true, false) as Button).pressed.emit()
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	(app.find_child("MapPin_cafe_harbor", true, false) as Button).pressed.emit()
	(app.find_child("TravelButton", true, false) as Button).pressed.emit()
	assert_true((app.find_child("FeedbackLabel", true, false) as Label).text.contains(
			"Auftrag erledigt: „Treffen am Hafen“ (Respekt +5)"))
	assert_eq(button.call("get_badge"), 2, "Erledigtes und der nächste Auftrag sind neu")
	(button as Button).pressed.emit()
	assert_true(app.find_child("Mission_first_deal_goods", true, false) != null, "nächster Auftrag fehlt")
	assert_true(app.find_child("Mission_%s" % FIRST, true, false) != null, "erledigt fehlt")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Nachtrag GD: Das Treffen zählt nur, wenn das Café offen ist (07–20 Uhr); wer dort bleibt, bis es öffnet, erfüllt es.
func test_meeting_needs_open_cafe() -> void:
	var game := _founded_game()
	game.missions.take_notices()
	game.time.advance(TimeSystemScript.at(1, 21) - game.time.get_minutes())
	game.events.resolve(game.events.get_next_pending_id(), "decline")
	game.locations.travel("cafe_harbor")  # 21:xx, geschlossen
	assert_eq(game.missions.is_active(FIRST), true, "bei geschlossenem Café erledigt")
	assert_true(Array(game.missions.take_notices()).has(
			"„Treffen am Hafen“: Café am Hafen hat gerade zu – komm wieder, wenn geöffnet ist."))
	game.time.advance(TimeSystemScript.at(2, 6) - game.time.get_minutes())
	assert_eq(game.missions.is_active(FIRST), true, "06:00 noch zu")
	game.time.advance(TimeSystemScript.at(2, 7, 30) - game.time.get_minutes())
	assert_eq(game.missions.is_completed(FIRST), true, "am Ort gewartet, bis offen")
