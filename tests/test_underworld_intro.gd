extends "res://tests/base_test.gd"

## Ticket U.3: Einstieg in die Unterwelt – Ereignis „Liegeplatz 14“ ab Tag 2 über den Tageswechsel (ein Code-Pfad für
## neue und alte Spielstände), „Nicht heute“ → kommt nach 2 Tagen wieder, „Zuhören“ → Namenseingabe (nicht
## schließbar) → Organisation gegründet; Fenster „Organisation“ + Seitenbutton; Migration v17 → v18.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_underworld_intro_save.json"
const INTRO := "underworld_intro"


func _to(game: GameStateScript, day: int, hour: int = 8) -> void:
	game.time.advance(TimeSystemScript.at(day, hour) - game.time.get_minutes())


func _resolve_others(game: GameStateScript) -> void:
	for id in game.events.get_triggered_ids():
		if not id.begins_with(INTRO) and not game.events.is_resolved(id):
			game.events.resolve(id, game.events.get_definition_for(id).options[-1].id)


# --- System ---------------------------------------------------------------------------

func test_intro_comes_on_day_two_once() -> void:
	var game := Helpers.new_game()
	_to(game, 1, 23)
	assert_eq(game.events.is_triggered("%s@1" % INTRO), false, "Tag 1 gehört den Grundlagen")
	_to(game, 2)
	assert_eq(game.events.is_triggered("%s@2" % INTRO), true)
	assert_eq(game.organisation.get_intro_state(), "offered")
	_to(game, 3)
	assert_eq(Array(game.events.get_triggered_ids()).filter(func(id: String) -> bool: return id.begins_with(INTRO)).size(), 1,
			"nicht noch einmal, solange es offen ist")


func test_not_now_brings_it_back_after_two_days() -> void:
	var game := Helpers.new_game()
	_to(game, 2)
	_resolve_others(game)
	assert_eq(game.events.resolve("%s@2" % INTRO, "not_now"), "")
	assert_eq(game.organisation.get_intro_state(), "declined")
	_to(game, 3)
	assert_eq(game.events.is_triggered("%s@3" % INTRO), false)
	_to(game, 4)
	assert_eq(game.events.is_triggered("%s@4" % INTRO), true, "nach 2 Tagen wieder")
	assert_eq(game.organisation.is_founded(), false)


func test_listen_needs_name_then_founds() -> void:
	var game := Helpers.new_game()
	_to(game, 2)
	assert_eq(game.events.resolve("%s@2" % INTRO, "listen"), "")
	assert_eq(game.organisation.needs_name(), true)
	assert_eq(game.organisation.found(""), "Der Name ist zu kurz (mindestens 2 Zeichen).")
	assert_eq(game.organisation.found("Los Lobos"), "")
	assert_eq(game.organisation.needs_name(), false)
	assert_eq(game.organisation.get_intro_state(), "done")
	_to(game, 6)
	assert_eq(Array(game.events.get_triggered_ids()).filter(func(id: String) -> bool: return id.begins_with(INTRO)).size(), 1)


func test_states_survive_save_and_load() -> void:
	var game := Helpers.new_game()
	_to(game, 2)
	game.events.resolve("%s@2" % INTRO, "listen")
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.organisation.needs_name(), true, "Name fehlt auch nach dem Laden")
		_to(loaded, 3)
		assert_eq(loaded.events.is_triggered("%s@3" % INTRO), false)
	SaveSystemScript.delete_save(SAVE_PATH)


## Alter Spielstand (v17, gespeichert an Tag 9): derselbe Code-Pfad – beim nächsten Tageswechsel kommt der Einstieg.
func test_old_save_gets_intro_at_next_day_change() -> void:
	var game := Helpers.new_game()
	_to(game, 9)
	var data := game.to_dict()
	data["organisation"].erase("intro_state")
	data["organisation"].erase("next_offer_day")
	data["events"]["triggered"] = []
	data["events"]["pending"] = []
	data["events"]["resolved"] = {}
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 17, "game": data}))
	file.close()
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.organisation.get_intro_state(), "none")
		assert_eq(loaded.events.has_pending(), false, "nicht sofort beim Laden")
		_to(loaded, 10)
		assert_eq(loaded.events.is_triggered("%s@10" % INTRO), true)
	assert_true(not SaveSystemScript._run_migration(17, {"organisation": "kaputt"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_v17_fixture_migrates() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v17.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v17 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.organisation.get_intro_state(), "none")
	SaveSystemScript.delete_save(SAVE_PATH)


func test_scripted_event_only_by_system() -> void:
	var game := Helpers.new_game()
	assert_eq(game.events.get_triggered_ids().size(), 0)
	print("          (die folgende ERROR-Meldung ist erwartet)")
	assert_eq(game.events.trigger_scripted("first_brand_request", 1), "", "zeitgesteuertes Ereignis nicht per Skript")
	assert_eq(game.events.trigger_scripted(INTRO, 1), "%s@1" % INTRO)
	assert_eq(game.events.trigger_scripted(INTRO, 1), "", "nicht zweimal am selben Tag")


# --- Spielansicht ---------------------------------------------------------------------

func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	app.find_child("CityMap", true, false).get_parent().set("show_tutorials", false)
	return app


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent() as Control


func _window_kind(app: AppScript) -> String:
	for child in _screen(app).get_children():
		if String(child.name).begins_with("Window_"):
			return String(child.name).trim_prefix("Window_")
	return ""


## Bis zum Einstieg: Tag 2, 08:00 – zuerst das feste Ereignis von Tag 1, dann „Liegeplatz 14“.
func _to_intro(app: AppScript) -> void:
	app.game.time.advance(TimeSystemScript.at(2, 8) - app.game.time.get_minutes())
	app.game.events.resolve("first_brand_request", "decline")
	_screen(app).call("_refresh")


func test_ui_listen_name_then_calendar_and_organisation_window() -> void:
	var app := _app()
	assert_eq((app.find_child("OrganisationButton", true, false) as Control).visible, false, "Button vor der Gründung")
	_to_intro(app)
	assert_eq(_window_kind(app), "event")
	assert_eq((app.find_child("WindowTitle", true, false) as Label).text, "Ereignis: Liegeplatz 14")
	_press(app, "EventOption_listen")
	assert_eq(_window_kind(app), "organisation_name", "Namenseingabe nach „Zuhören“")
	assert_eq((app.find_child("WindowCloseButton", true, false) as Control).visible, false, "Namensfenster schließbar")
	assert_eq(app.game.day_start.is_calendar_due(), true, "Kalender wartet auf den Namen")
	var content := app.find_child("OrganisationNameContent", true, false)
	_press(app, "OrganisationFoundButton")  # leer
	var reason := app.find_child("OrganisationNameReason", true, false) as Label
	assert_eq(reason.visible, true)
	assert_eq(reason.text, "Der Name ist zu kurz (mindestens 2 Zeichen).")
	assert_eq(app.game.organisation.is_founded(), false)
	content.call("set_name_text", "  Los Lobos ")
	_press(app, "OrganisationFoundButton")
	assert_eq(app.game.organisation.get_name(), "Los Lobos")
	assert_eq(_window_kind(app), "calendar", "danach der Kalender des Tages")
	_press(app, "WindowCloseButton")
	var button := app.find_child("OrganisationButton", true, false) as Control
	assert_eq(button.visible, true)
	assert_eq((app.find_child("HeatBlock", true, false) as Control).visible, true)
	_press(app, "OrganisationButton")
	assert_eq((app.find_child("WindowTitle", true, false) as Label).text, "Organisation · Los Lobos")
	assert_eq((app.find_child("OrganisationValue_stability", true, false) as Label).text, "50")
	assert_eq((app.find_child("OrganisationValue_respect", true, false) as Label).text, "0")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_name_window_comes_back_after_load() -> void:
	var app := _app()
	_to_intro(app)
	_press(app, "EventOption_listen")
	_press(app, "MenuButton")  # speichert
	app.free()
	var again := AppScript.new()
	again.save_path = SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(again)
	_press(again, "ContinueButton")
	assert_eq(_window_kind(again), "organisation_name", "Name fehlt noch – Fenster wieder da")
	again.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_not_now_closes_and_nothing_founded() -> void:
	var app := _app()
	_to_intro(app)
	_press(app, "EventOption_not_now")
	assert_true(_window_kind(app) in ["", "calendar"], _window_kind(app))
	assert_eq(app.game.organisation.is_founded(), false)
	assert_eq((app.find_child("OrganisationButton", true, false) as Control).visible, false)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Selbstprüfung U.3: Die Antworten zeigen ihre Folge statt „Keine Folgen“.
func test_intro_options_explain_consequences() -> void:
	var app := _app()
	_to_intro(app)
	var texts := []
	for label in app.find_child("EventPanel", true, false).find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true("Du gründest deine eigene Organisation" in texts, str(texts))
	assert_true("Er meldet sich in zwei Tagen wieder" in texts, str(texts))
	assert_true(not "Keine Folgen" in texts, str(texts))
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
