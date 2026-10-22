extends "res://tests/base_test.gd"

## Ticket T.4: Schalter „Tutorials anzeigen“ (aus → kein Overlay, bleibt fällig, kommt nach dem Einschalten; bleibt
## nach App-Neustart), „Tutorials zurücksetzen“ (gesehen leer, kommen wieder genau einmal) und „Hilfe / Lexikon“
## (nur Gesehenes, Antippen zeigt den vollen Text).

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")

const SAVE_PATH := "user://test_tutorial_settings_save.json"
const SETTINGS_PATH := "user://test_tutorial_settings.cfg"


func _remove_settings() -> void:
	for p in [SETTINGS_PATH, SETTINGS_PATH + SettingsScript.TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(keep: bool = false) -> AppScript:
	if not keep:
		SaveSystemScript.delete_save(SAVE_PATH)
		_remove_settings()
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _done(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _overlay(app: AppScript) -> Node:
	return app.find_child("TutorialOverlay", true, false)


func test_switch_off_hides_and_keeps_due_then_on_shows() -> void:
	var app := _app()
	app.settings.set_flag(SettingsScript.TUTORIALS, false)
	_press(app, "NewGameButton")
	assert_true(_overlay(app) == null, "Overlay trotz Schalter aus")
	assert_eq(app.game.tutorials.get_next_due(), "tut_map", "bleibt fällig")
	_press(app, "MapPin_studio")
	assert_true(_overlay(app) == null)
	_press(app, "MenuButton")
	_press(app, "SettingsButton")
	var toggle := app.find_child("SettingTutorials", true, false) as CheckButton
	assert_eq(toggle.button_pressed, false)
	toggle.button_pressed = true  # löst toggled aus → speichert
	_press(app, "BackButton")
	_press(app, "ContinueButton")
	var overlay := _overlay(app)
	assert_true(overlay != null and overlay.get("tutorial_id") == "tut_map", "nach dem Einschalten kommt es")
	_done(app)


func test_switch_survives_app_restart() -> void:
	var app := _app()
	_press(app, "SettingsButton")
	(app.find_child("SettingTutorials", true, false) as CheckButton).button_pressed = false
	app.free()
	var again := _app(true)
	assert_eq(again.settings.get_flag(SettingsScript.TUTORIALS), false)
	_press(again, "SettingsButton")
	assert_eq((again.find_child("SettingTutorials", true, false) as CheckButton).button_pressed, false)
	_done(again)


func test_reset_brings_tutorials_back_exactly_once() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	_press(app, "TutorialConfirmButton")
	_press(app, "TutorialConfirmButton")
	assert_true(_overlay(app) == null)
	_press(app, "MenuButton")
	_press(app, "SettingsButton")
	_press(app, "ResetTutorialsButton")  # erster Tipp: nur Rückfrage
	assert_eq(app.game.tutorials.is_seen("tut_map"), true, "ohne Bestätigung zurückgesetzt")
	assert_eq((app.find_child("ResetTutorialsButton", true, false) as Button).text,
			"Wirklich? Nochmal tippen")
	_press(app, "ResetTutorialsButton")
	assert_eq(app.game.tutorials.get_seen(), [], "gesehen nicht leer")
	assert_true(app.find_child("MessageLabel", true, false).text == "Die Tutorials kommen wieder.")
	# Gespeichert: auch ein neu geladener Stand hat nichts gesehen.
	var saved = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_eq(saved.tutorials.get_seen(), [])
	_press(app, "BackButton")
	_press(app, "ContinueButton")
	assert_eq(_overlay(app).get("tutorial_id"), "tut_map", "Spielstart-Tutorial sofort wieder da")
	_press(app, "TutorialConfirmButton")
	_press(app, "TutorialConfirmButton")
	assert_true(_overlay(app) == null)
	app.find_child("CityMap", true, false).get_parent().call("_refresh")
	assert_true(_overlay(app) == null, "nicht noch einmal")
	_done(app)


func test_reset_in_migrated_game_brings_game_start_tutorials() -> void:
	var game := Helpers.new_game()
	assert_eq(game.tutorials.restore({"fired": [], "seen": [], "seen_triggers": ["first_game_start"]}), "")
	assert_eq(game.tutorials.get_due(), PackedStringArray())
	game.tutorials.reset_seen()
	assert_eq(game.tutorials.get_due(), PackedStringArray(["tut_map"]))
	assert_eq(game.time.format_clock(), "08:00", "kostet keine Spielzeit")


func test_reset_without_save_is_disabled() -> void:
	var app := _app()
	_press(app, "SettingsButton")
	assert_eq((app.find_child("ResetTutorialsButton", true, false) as Button).disabled, true)
	_done(app)


func test_lexicon_shows_only_seen_and_expands() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	_press(app, "TutorialConfirmButton")  # nur „Karte“ gesehen
	_press(app, "MenuButton")
	_press(app, "SettingsButton")
	_press(app, "LexiconButton")
	assert_true(app.find_child("LexiconEntry_tut_map", true, false) != null, "Gesehenes fehlt")
	assert_true(app.find_child("LexiconEntry_tut_map_tap_building", true, false) == null, "Spoiler: ungesehen gezeigt")
	assert_true(app.find_child("LexiconEntry_tut_travel", true, false) == null, "Spoiler: ungesehen gezeigt")
	var text := app.find_child("LexiconText_tut_map", true, false) as Label
	assert_eq(text.visible, false)
	_press(app, "LexiconTitle_tut_map")
	assert_eq(text.visible, true, "voller Text nach Antippen")
	assert_eq(text.text, app.game.tutorials.get_catalog().get_definition("tut_map").text)
	_press(app, "BackButton")
	assert_true(app.find_child("SettingTutorials", true, false) != null, "zurück zu den Einstellungen")
	_done(app)


func test_lexicon_from_saved_game_and_without_game() -> void:
	var app := _app()
	_press(app, "SettingsButton")
	_press(app, "LexiconButton")
	assert_true(app.find_child("LexiconEmpty", true, false) != null, "ohne Spielstand: Hinweis")
	app.free()
	var game := Helpers.new_game()
	for id in ["tut_map", "tut_map_tap_building", "tut_travel"]:
		game.tutorials.mark_seen(id)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var again := _app(true)
	_press(again, "SettingsButton")
	_press(again, "LexiconButton")
	var names := []
	for node in again.find_children("LexiconEntry_*", "", true, false):
		names.append(String(node.name))
	assert_eq(names, ["LexiconEntry_location_open".replace("location_open", "tut_map_tap_building"),
			"LexiconEntry_tut_map", "LexiconEntry_tut_travel"], "nach Bereich (mechanic) sortiert")
	_done(again)
