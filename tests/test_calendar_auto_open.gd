extends "res://tests/base_test.gd"

## Ticket G5.3: Kalender öffnet sich bei Tagesbeginn genau einmal – auch über übersprungene Tage, nach Speichern/
## Laden und erst nach offenen Ereignissen; der Geräte-Schalter schaltet es ab. Dazu Migration v12 → v13.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DayStartSystemScript := preload("res://scripts/systems/day_start_system.gd")

const SAVE_PATH := "user://test_calendar_auto_save.json"
const SETTINGS_PATH := "user://test_calendar_auto_settings.cfg"
const FIXTURE_PATH := "user://test_calendar_auto_fixture.json"


func _remove_settings() -> void:
	for p in [SETTINGS_PATH, SETTINGS_PATH + SettingsScript.TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(keep_save: bool = false) -> AppScript:
	if not keep_save:
		SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent() as Control


## Wie nach einer Aktion: Spielzeit vorstellen, dann aktualisiert die Spielansicht. Den Einstieg in die Unterwelt
## (U.3, Ereignis ab Tag 2) lehnt der Test mit „Nicht heute“ ab – hier geht es nur um den Kalender.
func _advance_to(app: AppScript, day: int, hour: int) -> void:
	app.game.time.advance(TimeSystemScript.at(day, hour) - app.game.time.get_minutes())
	_screen(app).call("_refresh")
	_decline_intro(app)


func _decline_intro(app: AppScript) -> void:
	var button := app.find_child("EventOption_not_now", true, false) as Button
	if button != null:
		button.pressed.emit()


## Das feste Ereignis an Tag 1 um 20:00 vorab entscheiden (sonst kommt es zu Recht vor dem Kalender).
func _skip_first_event(app: AppScript) -> void:
	_advance_to(app, 1, 21)
	_press(app, "EventOption_accept")


func _window_kind(app: AppScript) -> String:
	for child in _screen(app).get_children():
		if String(child.name).begins_with("Window_"):
			return String(child.name).trim_prefix("Window_")
	return ""


# --- System ---------------------------------------------------------------------------

func test_system_is_due_once_per_day_and_skips_to_the_current_day() -> void:
	var game := Helpers.new_game()
	assert_eq(game.day_start.is_calendar_due(), false, "Tag 1 gilt als begonnen")
	game.time.advance(TimeSystemScript.at(4, 9) - game.time.get_minutes())  # drei Tageswechsel auf einmal
	assert_eq(game.day_start.take_calendar_due(true), true)
	assert_eq(game.day_start.get_calendar_shown_day(), 4, "nur der aktuelle Tag, nicht jeder übersprungene")
	assert_eq(game.day_start.take_calendar_due(true), false, "kein zweites Mal am selben Tag")
	game.time.advance(TimeSystemScript.at(5, 7) - game.time.get_minutes())
	assert_eq(game.day_start.take_calendar_due(false), false, "Schalter aus")
	assert_eq(game.day_start.is_calendar_due(), false, "Tag trotzdem erledigt")
	assert_eq(game.time.get_minutes(), TimeSystemScript.at(5, 7), "kostet keine Spielzeit")


func test_system_round_trip_and_bad_values() -> void:
	var game := Helpers.new_game()
	var system := DayStartSystemScript.new(game.time, 0)
	assert_eq(system.restore({"calendar_shown_day": 7}), "")
	assert_eq(system.to_dict(), {"calendar_shown_day": 7})
	assert_true(not system.restore({"calendar_shown_day": -1}).is_empty(), "negativer Tag angenommen")
	assert_true(not system.restore({"calendar_shown_day": "x"}).is_empty(), "Text angenommen")
	assert_true(not system.restore({}).is_empty(), "fehlender Wert angenommen")
	assert_eq(system.get_calendar_shown_day(), 7, "bei Fehler unverändert")


# --- Spielansicht ---------------------------------------------------------------------

func test_new_day_opens_calendar_once_and_next_day_again() -> void:
	_remove_settings()
	var app := _app()
	_press(app, "NewGameButton")
	assert_eq(_window_kind(app), "", "beim Spielstart (Tag 1) kein Kalender")
	_skip_first_event(app)
	_advance_to(app, 2, 8)
	assert_eq(_window_kind(app), "calendar")
	assert_eq((app.find_child("WindowTitle", true, false) as Label).text, "Kalender · Tag 2 · Di")
	_press(app, "WindowCloseButton")
	_screen(app).call("_refresh")
	assert_eq(_window_kind(app), "", "am selben Tag kein zweites Mal")
	_advance_to(app, 3, 7)
	assert_eq(_window_kind(app), "calendar", "nächster Tag: wieder")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_switch_off_never_opens() -> void:
	_remove_settings()
	var app := _app()
	app.settings.set_flag(SettingsScript.CALENDAR_AUTO_OPEN, false)
	_press(app, "NewGameButton")
	_skip_first_event(app)
	_advance_to(app, 2, 8)
	assert_eq(_window_kind(app), "")
	_advance_to(app, 5, 8)
	assert_eq(_window_kind(app), "")
	assert_eq(app.game.day_start.get_calendar_shown_day(), 5, "Tage gelten trotzdem als erledigt")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()


func test_event_first_then_calendar() -> void:
	_remove_settings()
	var app := _app()
	_press(app, "NewGameButton")
	# Über 20:00 (festes Ereignis) in den nächsten Tag: zuerst das Ereignis, kein Kalender darüber.
	_advance_to(app, 2, 8)
	assert_eq(_window_kind(app), "event")
	assert_eq(app.game.day_start.is_calendar_due(), true, "Kalender wartet auf das Ereignis")
	_press(app, "EventOption_accept")
	_decline_intro(app)
	assert_eq(_window_kind(app), "calendar", "nach dem Ereignis der Kalender")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_loading_does_not_open_it_twice() -> void:
	_remove_settings()
	var app := _app()
	_press(app, "NewGameButton")
	_advance_to(app, 2, 8)
	if app.find_child("EventOption_accept", true, false) != null:
		_press(app, "EventOption_accept")
	_decline_intro(app)
	assert_eq(_window_kind(app), "calendar")
	_press(app, "WindowCloseButton")
	_press(app, "MenuButton")  # speichert
	app.free()
	var again := _app(true)
	_press(again, "ContinueButton")
	assert_eq(_window_kind(again), "", "nach dem Laden nicht noch einmal")
	assert_eq(again.game.day_start.get_calendar_shown_day(), 2)
	again.free()
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Migration ------------------------------------------------------------------------

func test_migration_12_to_13_counts_current_day_as_shown() -> void:
	SaveSystemScript.delete_save(FIXTURE_PATH)
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v12.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), FIXTURE_PATH)
	var game = result["game"]
	assert_true(game != null, "v12 lädt nicht: %s" % result["error"])
	if game != null:
		var day := TimeSystemScript.day_of(game.time.get_minutes())
		assert_eq(game.day_start.get_calendar_shown_day(), day)
		assert_eq(game.day_start.is_calendar_due(), false, "alter Stand öffnet den Kalender nicht sofort")
		game.time.advance(TimeSystemScript.at(day + 1, 8) - game.time.get_minutes())
		assert_eq(game.day_start.is_calendar_due(), true, "ab dem nächsten Tag wie gewohnt")
	var broken := {"time": "kaputt"}
	assert_true(not SaveSystemScript._run_migration(12, broken).is_empty(), "kaputte Zeit angenommen")
	SaveSystemScript.delete_save(FIXTURE_PATH)
