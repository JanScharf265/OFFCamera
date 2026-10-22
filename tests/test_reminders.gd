extends "res://tests/base_test.gd"

## Ticket G5.6: Erinnerung ≤ 30 Spielminuten vor einem Termin – genau einmal je Termin, auch nach Laden;
## „Du schaffst es noch“ / „Du kommst zu spät“; kein Erinnern nach einem Sprung über das Fenster; Reihenfolge
## Ereignis → Kalender → Erinnerung; Migration v13 → v14.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const MEETING := "camera_meeting"  # Studio, Tag 1, 14:00; Wohnung → Studio 20 min
const SAVE_PATH := "user://test_reminders_save.json"
const SETTINGS_PATH := "user://test_reminders_settings.cfg"
const OLD_PATH := "user://test_reminders_old.json"


func _advance_to(game: GameStateScript, minutes: int) -> void:
	game.time.advance(minutes - game.time.get_minutes())


# --- System ---------------------------------------------------------------------------

func test_reminder_comes_once_inside_30_minutes() -> void:
	var game := Helpers.new_game()
	_advance_to(game, TimeSystemScript.at(1, 13, 29))
	assert_eq(game.reminders.get_due(), "", "31 min vorher noch nicht")
	_advance_to(game, TimeSystemScript.at(1, 13, 30))
	var before := game.time.get_minutes()
	assert_eq(game.reminders.take_due(), MEETING)
	assert_eq(game.reminders.take_due(), "", "kein zweites Mal")
	_advance_to(game, TimeSystemScript.at(1, 13, 45))
	assert_eq(game.reminders.take_due(), "", "auch später nicht")
	assert_eq(game.reminders.is_reminded(MEETING), true)
	assert_eq(before, TimeSystemScript.at(1, 13, 30))


func test_reminder_costs_no_time() -> void:
	var game := Helpers.new_game()
	_advance_to(game, TimeSystemScript.at(1, 13, 40))
	var minutes := game.time.get_minutes()
	game.reminders.take_due()
	game.reminders.describe(MEETING)
	assert_eq(game.time.get_minutes(), minutes)


func test_not_again_after_save_and_load() -> void:
	var game := Helpers.new_game()
	_advance_to(game, TimeSystemScript.at(1, 13, 35))
	assert_eq(game.reminders.take_due(), MEETING)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null, "lädt nicht")
	if loaded != null:
		assert_eq(loaded.reminders.get_due(), "", "nach dem Laden nicht noch einmal")
		assert_eq(loaded.reminders.to_dict(), game.reminders.to_dict())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_on_time_versus_late() -> void:
	var game := Helpers.new_game()  # Wohnung
	_advance_to(game, TimeSystemScript.at(1, 13, 40))
	var info := game.reminders.describe(MEETING)
	assert_eq(info["travel_minutes"], 20)
	assert_eq(info["minutes_left"], 20)
	assert_eq(info["on_time"], true, "13:40 + 20 min = 14:00 – schafft es")
	assert_eq(info["here"], false)
	_advance_to(game, TimeSystemScript.at(1, 13, 41))
	assert_eq(game.reminders.describe(MEETING)["on_time"], false, "14:01 – zu spät")
	game.locations.travel("studio")  # 14:01 → verpasst; neues Spiel für „dort“
	var there := Helpers.new_game()
	there.locations.travel("studio")
	_advance_to(there, TimeSystemScript.at(1, 13, 50))
	info = there.reminders.describe(MEETING)
	assert_eq(info["here"], true)
	assert_eq(info["travel_minutes"], 0)
	assert_eq(info["on_time"], true)


func test_jump_over_window_gives_no_reminder() -> void:
	var game := Helpers.new_game()
	_advance_to(game, TimeSystemScript.at(1, 13))
	_advance_to(game, TimeSystemScript.at(1, 15))  # Aktion über 13:30–14:00 hinweg
	assert_eq(game.reminders.get_due(), "")
	assert_eq(game.appointments.is_missed(MEETING), true)
	var exact := Helpers.new_game()
	_advance_to(exact, TimeSystemScript.at(1, 14))  # landet genau auf dem Beginn
	assert_eq(exact.reminders.get_due(), "", "Termin beginnt jetzt – keine Erinnerung")


func test_restore_rejects_bad_values_without_change() -> void:
	var game := Helpers.new_game()
	assert_eq(game.reminders.restore({"reminded": ["a"], "reminded_until_minutes": 10}), "")
	for bad in [{"reminded": [], "reminded_until_minutes": -1}, {"reminded": "x", "reminded_until_minutes": 0},
			{"reminded": [3], "reminded_until_minutes": 0}, {"reminded": []}]:
		assert_true(not game.reminders.restore(bad).is_empty(), "angenommen: %s" % bad)
	assert_eq(game.reminders.to_dict(), {"reminded": ["a"], "reminded_until_minutes": 10})


# --- Migration ------------------------------------------------------------------------

## Ein Spielstand im Format v13 zu `minutes` (aktueller Stand ohne den Abschnitt „reminders“).
func _write_v13_at(minutes: int) -> void:
	var game := Helpers.new_game()
	_advance_to(game, minutes)
	var data := game.to_dict()
	data.erase("reminders")
	SaveSystemScript.delete_save(OLD_PATH)
	var file := FileAccess.open(OLD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 13, "game": data}))
	file.close()


func test_migration_13_to_14_counts_close_appointments_as_reminded() -> void:
	_write_v13_at(TimeSystemScript.at(1, 13, 40))
	var result := SaveSystemScript.load_game(Helpers.game_data(), OLD_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v13 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.reminders.get_due(), "", "Termin ≤ 30 min entfernt gilt als erinnert")
		assert_eq(game.reminders.is_reminded(MEETING), true)
	# Weiter entfernt: Die Erinnerung kommt später ganz normal.
	_write_v13_at(TimeSystemScript.at(1, 12))
	game = SaveSystemScript.load_game(Helpers.game_data(), OLD_PATH)["game"]
	assert_true(game != null)
	if game != null:
		assert_eq(game.reminders.is_reminded(MEETING), false)
		_advance_to(game, TimeSystemScript.at(1, 13, 35))
		assert_eq(game.reminders.take_due(), MEETING)
	assert_true(not SaveSystemScript._run_migration(13, {"time": "kaputt"}).is_empty(), "kaputte Zeit angenommen")
	SaveSystemScript.delete_save(OLD_PATH)


func test_v13_fixture_migrates() -> void:
	SaveSystemScript.delete_save(OLD_PATH)
	var file := FileAccess.open(OLD_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v13.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), OLD_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v13 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.reminders.to_dict(), {"reminded": [],
				"reminded_until_minutes": game.time.get_minutes() + 30})
	SaveSystemScript.delete_save(OLD_PATH)


# --- Spielansicht ---------------------------------------------------------------------

func _remove_settings() -> void:
	for p in [SETTINGS_PATH, SETTINGS_PATH + SettingsScript.TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(data = null) -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	app.new_game_seed = Helpers.TEST_SEED
	if data != null:
		app.preloaded_data = data
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


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent() as Control


func _jump(app: AppScript, minutes: int) -> void:
	app.game.time.advance(minutes - app.game.time.get_minutes())
	_screen(app).call("_refresh")


func _window_kind(app: AppScript) -> String:
	for child in _screen(app).get_children():
		if String(child.name).begins_with("Window_"):
			return String(child.name).trim_prefix("Window_")
	return ""


func _text(app: AppScript, node_name: String) -> String:
	var label := app.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


func test_window_at_home_says_on_time_and_travels() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	_jump(app, TimeSystemScript.at(1, 13, 30))
	assert_eq(_window_kind(app), "reminder")
	assert_eq((app.find_child("WindowTitle", true, false) as Label).text, "Termin in 30 min")
	assert_eq(_text(app, "ReminderAppointment"), "Treffen mit der Kamerafrau")
	assert_eq(_text(app, "ReminderWhen"), "14:00 · Studio")
	assert_eq(_text(app, "ReminderTravel"), "Fahrt von hier: 20 min")
	assert_eq(_text(app, "ReminderVerdict"), "Du schaffst es noch")
	assert_true(app.find_child("ReminderWaitButton", true, false) == null, "Warten, obwohl nicht dort")
	assert_eq(app.game.time.format_clock(), "13:30", "Erinnerung kostet keine Zeit")
	_press(app, "ReminderTravelButton")
	assert_eq(app.game.locations.get_current(), "studio")
	assert_eq(app.game.time.format_clock(), "13:50")
	assert_eq(_window_kind(app), "", "keine zweite Erinnerung")
	_done(app)


func test_window_late_and_later_button() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	_jump(app, TimeSystemScript.at(1, 13, 50))
	assert_eq(_text(app, "ReminderVerdict"), "Du kommst zu spät: Fahrt 20 min")
	_press(app, "ReminderLaterButton")
	assert_eq(_window_kind(app), "")
	assert_eq(app.game.time.format_clock(), "13:50")
	_screen(app).call("_refresh")
	assert_eq(_window_kind(app), "", "„Später“ – nicht noch einmal")
	_done(app)


func test_window_on_site_offers_wait() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	app.game.locations.travel("studio")
	_jump(app, TimeSystemScript.at(1, 13, 40))
	assert_eq(_text(app, "ReminderTravel"), "Du bist dort.")
	assert_true(app.find_child("ReminderTravelButton", true, false) == null, "Hinfahren, obwohl dort")
	assert_eq((app.find_child("ReminderWaitButton", true, false) as Button).text, "Warten bis 14:00")
	_press(app, "ReminderWaitButton")
	assert_eq(app.game.time.format_clock(), "14:00")
	assert_eq(app.game.appointments.check(MEETING), "")
	_done(app)


## Test-Termin am Tag 2 um 00:20 zu Hause: Ein Sprung von 19:00 auf 00:00 bringt das Ereignis (20:00), den Kalender
## (Tagesbeginn) und die Erinnerung – nacheinander, nie übereinander.
func test_order_event_then_calendar_then_reminder() -> void:
	var data := Helpers.game_data()
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/appointments/appointments.json"))
	list.append({"id": "night_call", "title": "Nachtanruf", "location": "home", "start": {"day": 2, "hour": 0, "minute": 20},
			"duration_minutes": 15, "missed_effects": {"mood": -2}})
	assert_true(data.appointments.load_data(list), "; ".join(data.appointments.errors))
	var app := _app(data)
	_press(app, "NewGameButton")
	_jump(app, TimeSystemScript.at(1, 19))
	_jump(app, TimeSystemScript.at(2, 0))
	assert_eq(_window_kind(app), "event", "zuerst das Ereignis")
	assert_eq(app.game.reminders.is_reminded("night_call"), false, "Erinnerung wartet")
	_press(app, "EventOption_accept")
	assert_eq(_window_kind(app), "calendar", "dann der Kalender")
	assert_eq(app.game.reminders.is_reminded("night_call"), false, "Erinnerung wartet auf den Kalender")
	_press(app, "WindowCloseButton")
	assert_eq(_window_kind(app), "reminder", "dann die Erinnerung")
	assert_eq(_text(app, "ReminderAppointment"), "Nachtanruf")
	assert_eq(_screen(app).get_children().filter(func(c): return String(c.name).begins_with("Window_")).size(), 1)
	_done(app)
