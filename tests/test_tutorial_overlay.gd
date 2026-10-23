extends "res://tests/base_test.gd"

## Ticket T.3: Tutorial-Anzeige – erscheint nach „Neues Spiel“; Ziel ausgespart und hervorgehoben, Sprechblase
## verdeckt es nicht und liegt in der Safe Area (alle 4 Geräteklassen); „Verstanden“ markiert gesehen und zeigt das
## nächste; fehlendes Ziel → mittig, kein Absturz; Reihenfolge Ereignis/Kalender/Erinnerung → Tutorial.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_tutorial_overlay_save.json"


func _app(data = null) -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	if data != null:
		app.preloaded_data = data
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _done(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent() as Control


func _overlay(app: AppScript) -> Control:
	return _screen(app).find_child("TutorialOverlay", false, false) as Control


func _window_kind(app: AppScript) -> String:
	for child in _screen(app).get_children():
		if String(child.name).begins_with("Window_"):
			return String(child.name).trim_prefix("Window_")
	return ""


## Echte Daten, Tutorials ersetzt durch `entries`.
func _data_with_tutorials(entries: Array):
	var data := Helpers.game_data()
	assert_true(data.tutorials.load_data(entries), "; ".join(data.tutorials.errors))
	return data


func _entry(id: String, trigger: String, target: String = "") -> Dictionary:
	return {"id": id, "mechanic": "m_" + id, "trigger": trigger, "title": "Titel %s" % id,
			"text": "Ein kurzer Erklärtext für den Test.", "ui_target": target, "order": 0, "requires": []}


## Prüft Lage der Sprechblase: in der Safe Area, mit Ziel: Ziel ausgespart, nicht verdeckt.
func _check_placement(app: AppScript, device: String, expect_target: String) -> void:
	var overlay := _overlay(app)
	assert_true(overlay != null, "%s: kein Tutorial" % device)
	if overlay == null:
		return
	Layout.apply(app, device)
	Layout.settle_in_place(_screen(app))
	_screen(app).call("_layout")
	var bubble := Rect2(overlay.find_child("TutorialBubble", false, false).position,
			(overlay.find_child("TutorialBubble", false, false) as Control).size)
	assert_true(Layout.safe_rect(device).grow(0.5).encloses(bubble), "%s: Sprechblase %s außerhalb der Safe Area" % [
			device, bubble])
	var button := overlay.find_child("TutorialConfirmButton", true, false) as Button
	assert_true(button.size.y >= UiStyle.TOUCH_SIZE - 0.5, "%s: „Verstanden“ %d px" % [device, button.size.y])
	assert_eq(overlay.size, _screen(app).size, "%s: Overlay deckt nicht alles ab" % device)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP)
	if expect_target.is_empty():
		assert_eq(overlay.call("has_target"), false)
		assert_true(bubble.get_center().distance_to(Layout.safe_rect(device).get_center()) < 1.0,
				"%s: nicht mittig" % device)
		return
	assert_eq(overlay.call("has_target"), true, "%s: Ziel %s nicht gefunden" % [device, expect_target])
	var target := _screen(app).find_child(expect_target, true, false) as Control
	var target_rect := target.get_global_rect()
	target_rect.position -= _screen(app).get_global_rect().position
	var hole: Rect2 = overlay.call("get_hole")
	assert_true(hole.encloses(target_rect.intersection(Rect2(Vector2.ZERO, _screen(app).size))),
			"%s: Aussparung %s umfasst das Ziel %s nicht" % [device, hole, target_rect])
	assert_true(not bubble.intersects(hole), "%s: Sprechblase %s verdeckt das Ziel %s" % [device, bubble, hole])


func test_new_game_shows_tutorials_in_order_and_confirm_marks_seen() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	var overlay := _overlay(app)
	assert_true(overlay != null, "kein Tutorial nach „Neues Spiel“")
	assert_eq(overlay.get("tutorial_id"), "tut_map")
	assert_eq((overlay.find_child("TutorialTitle", true, false) as Label).text, "Willkommen in Marbella")
	_check_placement(app, "iPhone 15/16 Pro Max (Dynamic Island)", "")
	assert_eq((app.find_child("Toast", true, false) as Control).visible, false, "alte Hinweiszeile/leerer Kasten noch da")
	var clock: String = app.game.time.format_clock()
	_press(app, "TutorialConfirmButton")
	assert_eq(app.game.tutorials.is_seen("tut_map"), true)
	overlay = _overlay(app)
	assert_true(overlay != null and overlay.get("tutorial_id") == "tut_map_tap_building", "nächstes fehlt")
	_check_placement(app, "iPhone 15/16 Pro Max (Dynamic Island)", "MapPin_studio")
	_press(app, "TutorialConfirmButton")
	assert_true(_overlay(app) == null, "kein weiteres fällig")
	assert_eq(app.game.time.format_clock(), clock, "kostet keine Spielzeit")
	# Gespeichert: nach dem Laden nicht noch einmal.
	app.free()
	var again := AppScript.new()
	again.save_path = SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(again)
	_press(again, "ContinueButton")
	assert_true(_overlay(again) == null, "nach dem Laden erneut gezeigt")
	_done(again)


func test_placement_on_every_device() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		_press(app, "NewGameButton")
		Layout.apply(app, device)
		_check_placement(app, device, "")
		_press(app, "TutorialConfirmButton")
		Layout.apply(app, device)
		_check_placement(app, device, "MapPin_studio")
		_press(app, "TutorialConfirmButton")
		# „Hinfahren“ im Ortsfenster des Studios (von der Wohnung aus).
		_press(app, "MapPin_studio")
		Layout.apply(app, device)
		var overlay := _overlay(app)
		assert_true(overlay != null and overlay.get("tutorial_id") == "tut_activities", "%s: Kachel-Tutorial fehlt" % device)
		Layout.settle_in_place(_screen(app).find_child("Window_location", false, false))
		_check_placement(app, device, "Tile_livestream")
		_press(app, "TutorialConfirmButton")
		overlay = _overlay(app)
		assert_true(overlay != null and overlay.get("tutorial_id") == "tut_travel", "%s: Hinfahren-Tutorial fehlt" % device)
		Layout.settle_in_place(_screen(app).find_child("Window_location", false, false))
		_check_placement(app, device, "TravelButton")
		_done(app)


func test_missing_target_is_centered_without_crash() -> void:
	var app := _app(_data_with_tutorials([_entry("tut_ghost", "first_game_start", "DoesNotExist")]))
	_press(app, "NewGameButton")
	_check_placement(app, "iPhone 15/16 Pro Max (Dynamic Island)", "")
	_press(app, "TutorialConfirmButton")
	assert_eq(app.game.tutorials.is_seen("tut_ghost"), true)
	_done(app)


func test_tutorial_waits_for_event() -> void:
	var app := _app(_data_with_tutorials([_entry("tut_event", "first_event")]))
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 21) - app.game.time.get_minutes())
	_screen(app).call("_refresh")
	assert_eq(_window_kind(app), "event")
	assert_true(_overlay(app) == null, "Tutorial über dem Ereignis")
	_press(app, "EventOption_accept")
	assert_true(_overlay(app) != null, "nach dem Ereignis kein Tutorial")
	_done(app)


func test_tutorial_waits_for_calendar() -> void:
	var app := _app(_data_with_tutorials([_entry("tut_calendar", "first_calendar_open")]))
	_press(app, "NewGameButton")
	_press(app, "AppointmentsButton")
	assert_eq(_window_kind(app), "calendar")
	assert_true(_overlay(app) == null, "Tutorial über dem Kalender")
	_press(app, "WindowCloseButton")
	assert_true(_overlay(app) != null, "nach dem Kalender kein Tutorial")
	_done(app)


func test_tutorial_waits_for_reminder() -> void:
	var app := _app(_data_with_tutorials([_entry("tut_reminder", "first_appointment_reminder")]))
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_screen(app).call("_refresh")
	assert_eq(_window_kind(app), "reminder")
	assert_true(_overlay(app) == null, "Tutorial über der Erinnerung")
	_press(app, "ReminderLaterButton")
	assert_true(_overlay(app) != null, "nach der Erinnerung kein Tutorial")
	_done(app)


func test_confirm_works_only_once() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	var button := app.find_child("TutorialConfirmButton", true, false) as Button
	button.pressed.emit()
	button.pressed.emit()  # alter Button (schon weg) – darf das nächste nicht mitbestätigen
	assert_eq(app.game.tutorials.is_seen("tut_map_tap_building"), false)
	_done(app)
