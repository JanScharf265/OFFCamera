extends "res://tests/base_test.gd"

## Texte und ein Durchklick-Test der App ohne Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const TEST_SAVE_PATH := "user://test_ui_savegame.json"


func test_format_duration() -> void:
	assert_eq(TimeSystemScript.format_duration(45), "45 min")
	assert_eq(TimeSystemScript.format_duration(60), "1 h")
	assert_eq(TimeSystemScript.format_duration(90), "1 h 30 min")


func test_format_stamp() -> void:
	assert_eq(TimeSystemScript.format_stamp(TimeSystemScript.at(2, 14, 5)), "Tag 2 · 14:05")


func test_activity_summaries() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	assert_eq(ActivityText.summary(catalog.get_definition("stream_short")), "2 h · Energie -20 · Stimmung +5 · +25,00 €")
	assert_eq(ActivityText.summary(catalog.get_definition("rest")), "1 h · Energie +15 · Stimmung +3")
	assert_eq(ActivityText.summary(catalog.get_definition("eat_out")), "1 h · Energie +10 · Stimmung +5 · -15,00 €")


func test_click_through_new_game_activity_menu_and_continue() -> void:
	var app := _start_app()
	if app == null:
		return

	var new_game := _find(app, "NewGameButton") as Button
	assert_true(new_game != null, "NewGameButton fehlt")
	assert_true(_find(app, "ContinueButton") == null, "Fortsetzen darf ohne Spiel nicht da sein")
	if new_game == null:
		app.free()
		return
	new_game.pressed.emit()

	assert_eq((_find(app, "ClockLabel") as Label).text, "08:00")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 500,00 €")

	(_find(app, "StartButton_stream_short") as Button).pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:00")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 525,00 €")
	assert_eq(app.game.ledger.get_entries().size(), 1)
	assert_eq((_find(app, "LedgerList") as Node).get_child_count(), 1)

	(_find(app, "MenuButton") as Button).pressed.emit()
	var continue_button := _find(app, "ContinueButton") as Button
	assert_true(continue_button != null, "Fortsetzen fehlt nach dem ersten Spiel")
	continue_button.pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:00")

	app.free()


func test_disabled_activity_shows_reason() -> void:
	var app := _start_app()
	if app == null:
		return
	if not _press(app, "NewGameButton"):
		app.free()
		return

	app.game.stats.apply({"energy": -75})  # 80 -> 5
	(_find(app, "StartButton_rest") as Button).pressed.emit()  # 5 -> 20, aktualisiert die Anzeige
	app.game.stats.apply({"energy": -5})  # 20 -> 15
	(_find(app, "StartButton_rest") as Button).pressed.emit()  # 15 -> 30
	assert_eq((_find(app, "StartButton_stream_short") as Button).disabled, false)

	app.game.stats.apply({"energy": -20})  # 30 -> 10
	(_find(app, "MenuButton") as Button).pressed.emit()
	(_find(app, "ContinueButton") as Button).pressed.emit()
	assert_eq((_find(app, "StartButton_stream_short") as Button).disabled, true)

	app.free()


func test_event_replaces_activities_until_decided() -> void:
	var app := _start_app()
	if app == null:
		return
	if not _press(app, "NewGameButton"):
		app.free()
		return

	app.game.time.advance(11 * 60)  # 08:00 -> 19:00
	_press(app, "StartButton_rest")  # 19:00 -> 20:00, Ereignis wird fällig
	var panel := _find(app, "EventPanel") as Control
	var scroll := _find(app, "ActivityScroll") as Control
	assert_eq(panel.visible, true)
	assert_eq(scroll.visible, false)

	_press(app, "EventOption_accept")
	assert_eq(panel.visible, false)
	assert_eq(scroll.visible, true)
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 530,00 €")

	app.free()


func test_save_and_continue_after_restart() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "StartButton_stream_short")  # 08:00 -> 10:00, +25,00 €
	app.free()  # wie App beenden

	var restarted := _start_app(true)
	assert_true(_find(restarted, "ContinueButton") != null, "Fortsetzen fehlt nach Neustart")
	_press(restarted, "ContinueButton")
	assert_eq((_find(restarted, "ClockLabel") as Label).text, "10:00")
	assert_eq((_find(restarted, "BalanceLabel") as Label).text, "Konto: 525,00 €")
	assert_eq(restarted.game.ledger.get_entries().size(), 1)
	restarted.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_new_game_with_existing_save_needs_confirmation() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "StartButton_rest")  # 08:00 -> 09:00
	_press(app, "MenuButton")

	_press(app, "NewGameButton")  # erster Tipp: nur Rückfrage
	assert_eq(app.game.time.format_clock(), "09:00")
	_press(app, "NewGameButton")  # zweiter Tipp: neues Spiel
	assert_eq(app.game.time.format_clock(), "08:00")
	app.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_delete_save_in_settings() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "MenuButton")
	_press(app, "SettingsButton")
	_press(app, "DeleteSaveButton")  # Rückfrage
	assert_true(SaveSystemScript.has_save(TEST_SAVE_PATH), "nach erstem Tipp darf noch nichts gelöscht sein")
	_press(app, "DeleteSaveButton")
	assert_eq(SaveSystemScript.has_save(TEST_SAVE_PATH), false)
	assert_true(app.game == null, "Sitzung sollte verworfen sein")
	_press(app, "BackButton")
	assert_true(_find(app, "ContinueButton") == null, "Fortsetzen darf ohne Spielstand nicht da sein")
	app.free()


## App in den Baum hängen; null (mit Fehlermeldung), wenn _ready() nicht lief.
## Startet immer ohne vorhandenen Spielstand (eigener Testpfad).
func _start_app(keep_save: bool = false) -> AppScript:
	if not keep_save:
		SaveSystemScript.delete_save(TEST_SAVE_PATH)
	var app := AppScript.new()
	app.save_path = TEST_SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	assert_true(app.is_inside_tree(), "App hängt nicht im Szenenbaum")
	if not app.is_inside_tree():
		app.free()
		return null
	return app


func _press(root: Node, node_name: String) -> bool:
	var button := _find(root, node_name) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()
	return button != null


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
