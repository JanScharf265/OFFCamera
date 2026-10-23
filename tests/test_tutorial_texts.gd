extends "res://tests/base_test.gd"

## Ticket T.5: Jedes Tutorial aus data/tutorials/tutorials.json in seiner echten Situation, auf allen 4 Geräteklassen:
## Es erscheint, sein Ziel wird gefunden und ausgespart, die Sprechblase verdeckt es nicht und liegt in der Safe Area;
## Tippflächen ≥ 84 px, Schrift ≥ 21 px, nichts abgeschnitten. Dazu: Spielstart mit höchstens 2 Tutorials, jeder
## Auslöser aus den Daten ist in der festen Liste, Texte ≤ 240 Zeichen.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")
const TutorialOverlayScript := preload("res://scripts/ui/tutorial_overlay.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_tutorial_texts_save.json"


func _catalog() -> TutorialCatalogScript:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	return catalog


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


## Neues Spiel, in dem alle Tutorials außer `only` schon gesehen sind; dann die Situation, die `only` auslöst.
func _scenario(only: String, trigger: String) -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	for definition in app.game.tutorials.get_catalog().get_all():
		if definition.id != only:
			app.game.tutorials.mark_seen(definition.id)
	var screen := _screen(app)
	screen.call("close_tutorial")
	match trigger:
		"first_game_start":
			screen.call("_open_due_tutorial")
		"first_window_closed":
			_press(app, "MapPin_home")
			_press(app, "WindowCloseButton")
		"first_location_open", "first_location_elsewhere", "first_trip_offered":
			_jump(app, TimeSystemScript.at(1, 10))
			_press(app, "MapPin_studio")
		"first_action":
			_press(app, "HereButton")
			_press(app, "StartButton_rest")
		"first_calendar_open":
			_press(app, "AppointmentsButton")
		"first_appointment_reminder":
			_jump(app, TimeSystemScript.at(1, 13, 30))
		"first_conflict_popup":
			_jump(app, TimeSystemScript.at(1, 13, 30))
			_press(app, "ReminderLaterButton")
			_press(app, "HereButton")
			_press(app, "StartButton_rest")
		"first_wait_offered":
			app.game.locations.travel("studio")
			_jump(app, TimeSystemScript.at(1, 12, 40))
			_press(app, "MapPin_studio")
		"first_event":
			_jump(app, TimeSystemScript.at(1, 21))
		"first_new_day":
			_jump(app, TimeSystemScript.at(2, 8))
			_press(app, "EventOption_accept")
			_press(app, "WindowCloseButton")  # Kalender bei Tagesbeginn
		_:
			assert_true(false, "Kein Testszenario für Auslöser '%s' (%s)" % [trigger, only])
	return app


func test_every_tutorial_appears_and_fits_every_device() -> void:
	var problems := PackedStringArray()
	for definition in _catalog().get_all():
		for device in Layout.DEVICES:
			var app := _scenario(definition.id, definition.trigger)
			var screen := _screen(app)
			var where := "%s / %s" % [definition.id, device]
			Layout.apply(app, device)
			for child in screen.get_children():
				if String(child.name).begins_with("Window_") or child.name == "ConflictPopup":
					Layout.settle_in_place(child)
			screen.call("_layout")
			var overlay := screen.find_child("TutorialOverlay", false, false) as Control
			if overlay == null or overlay.get("tutorial_id") != definition.id:
				problems.append("%s: erscheint nicht (stattdessen %s)" % [where,
						overlay.get("tutorial_id") if overlay != null else "nichts"])
				app.free()
				continue
			Layout.settle_in_place(overlay)
			screen.call("_layout")
			var bubble_node := overlay.find_child("TutorialBubble", false, false) as Control
			var bubble := Rect2(bubble_node.position, bubble_node.size)
			if not Layout.safe_rect(device).grow(0.5).encloses(bubble):
				problems.append("%s: Sprechblase %s außerhalb der Safe Area" % [where, bubble])
			if not definition.ui_target.is_empty():
				var target := TutorialOverlayScript.find_target(screen, definition.ui_target)
				if target == null or not overlay.call("has_target"):
					problems.append("%s: Ziel '%s' nicht gefunden" % [where, definition.ui_target])
				else:
					var hole: Rect2 = overlay.call("get_hole")
					if bubble.intersects(hole):
						problems.append("%s: Sprechblase %s verdeckt das Ziel %s" % [where, bubble, hole])
			_audit(overlay, where, problems)
			app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	assert_true(problems.is_empty(), "%d Probleme:\n            %s" % [problems.size(), "\n            ".join(problems)])


## Wie der Audit aus G4.7: Tippflächen, Mindestschrift, keine abgeschnittenen einzeiligen Texte, umbrechende ganz.
func _audit(root: Control, where: String, problems: PackedStringArray) -> void:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.size.x < UiStyle.TOUCH_SIZE - 0.5 or button.size.y < UiStyle.TOUCH_SIZE - 0.5:
			problems.append("%s: Tippfläche %s %dx%d" % [where, button.name, button.size.x, button.size.y])
		if button.get_theme_font_size("font_size") < UiStyle.MIN_READ_FONT_SIZE:
			problems.append("%s: Schrift %s zu klein" % [where, button.name])
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.get_theme_font_size("font_size") < UiStyle.MIN_READ_FONT_SIZE:
			problems.append("%s: Schrift „%s“ zu klein" % [where, label.text])
		if label.get_line_count() > label.get_visible_line_count():
			problems.append("%s: „%s“ nicht ganz sichtbar" % [where, label.text])


func test_game_start_shows_at_most_two() -> void:
	var start := _catalog().get_for_trigger("first_game_start")
	assert_true(start.size() <= 2, "zum Spielstart %d Tutorials" % start.size())


func test_data_rules() -> void:
	var catalog := _catalog()
	var mechanics := {}
	for definition in catalog.get_all():
		assert_true(definition.trigger in TutorialCatalogScript.TRIGGERS, definition.id)
		assert_true(definition.text.length() <= TutorialCatalogScript.MAX_TEXT_LENGTH, definition.id)
		assert_true(not mechanics.has(definition.mechanic), "Mechanik '%s' doppelt" % definition.mechanic)
		mechanics[definition.mechanic] = true
	for mechanic in ["map", "map_navigation", "location_open", "travel", "activities", "player_stats", "calendar",
			"reminder", "conflict", "wait", "trip", "events", "saving"]:
		assert_true(mechanics.has(mechanic), "Grundlagen-Mechanik '%s' ohne Tutorial" % mechanic)


## Neue Auslöser (T.5) werden gemeldet – jeweils im passenden Moment.
func test_new_triggers_are_reported() -> void:
	for pair in [["first_window_closed", "tut_map_swipe"], ["first_action", "tut_stats"],
			["first_conflict_popup", "tut_conflict"], ["first_wait_offered", "tut_wait"],
			["first_trip_offered", "tut_trip"], ["first_new_day", "tut_save"]]:
		var app := _scenario(pair[1], pair[0])
		assert_eq(app.game.tutorials.was_reported(pair[0]), true, pair[0])
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Korrektur T.5: Das Kalender-Tutorial liegt über dem offenen Kalender (Pfeil auf die Jetzt-Linie).
func test_calendar_tutorial_lies_over_calendar() -> void:
	var app := _scenario("tut_calendar", "first_calendar_open")
	var screen := _screen(app)
	assert_true(screen.find_child("Window_calendar", false, false) != null, "Kalender zu")
	var overlay := screen.find_child("TutorialOverlay", false, false)
	assert_true(overlay != null and overlay.get("tutorial_id") == "tut_calendar")
	assert_true(overlay.get_index() > screen.find_child("Window_calendar", false, false).get_index(), "unter dem Kalender")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
