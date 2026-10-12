extends "res://tests/base_test.gd"

## Texte und ein Durchklick-Test der App ohne Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")

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
	assert_eq(ActivityText.summary(catalog.get_definition("training")), "1 h 30 min · Energie -15 · Stimmung +10")
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
	assert_eq((_find(app, "LocationLabel") as Label).text, "Ort: Wohnung")

	_travel(app, "studio")  # 08:00 -> 08:20
	(_find(app, "ContentButton_livestream") as Button).pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:20")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 525,00 €")
	assert_eq(app.game.ledger.get_entries().size(), 1)
	assert_eq((_find(app, "LedgerList") as Node).get_child_count(), 1)

	(_find(app, "MenuButton") as Button).pressed.emit()
	var continue_button := _find(app, "ContinueButton") as Button
	assert_true(continue_button != null, "Fortsetzen fehlt nach dem ersten Spiel")
	continue_button.pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:20")
	assert_eq((_find(app, "LocationLabel") as Label).text, "Ort: Studio")

	app.free()


func test_disabled_activity_shows_reason() -> void:
	var app := _start_app()
	if app == null:
		return
	if not _press(app, "NewGameButton"):
		app.free()
		return

	_travel(app, "studio")
	assert_eq((_find(app, "ContentButton_livestream") as Button).disabled, false)

	app.game.stats.apply({"energy": -70})  # 80 -> 10
	_press(app, "MenuButton")
	_press(app, "ContinueButton")
	assert_eq((_find(app, "ContentButton_livestream") as Button).disabled, true)
	assert_true(_screen_has_text(app, "Zu wenig Energie (benötigt 20)."), "Grund wird nicht angezeigt")

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
	_travel(app, "studio")                   # 08:00 -> 08:20
	_press(app, "ContentButton_livestream")  # -> 10:20, +25,00 €
	app.free()  # wie App beenden

	var restarted := _start_app(true)
	assert_true(_find(restarted, "ContinueButton") != null, "Fortsetzen fehlt nach Neustart")
	_press(restarted, "ContinueButton")
	assert_eq((_find(restarted, "ClockLabel") as Label).text, "10:20")
	assert_eq((_find(restarted, "LocationLabel") as Label).text, "Ort: Studio")
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


func test_map_shows_location_and_travel_changes_activities() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_true(_find(app, "CityMap") != null, "Stadtkarte fehlt")
	assert_true(_find(app, "StartButton_rest") != null, "Ausruhen fehlt in der Wohnung")
	assert_true(_find(app, "StartButton_coffee") == null, "Kaffee darf es zu Hause nicht geben")

	_press(app, "MapPin_cafe_harbor")  # nur auswählen, keine Zeit
	assert_eq((_find(app, "ClockLabel") as Label).text, "08:00")
	assert_eq((_find(app, "LocationName") as Label).text, "Café am Hafen")
	assert_eq((_find(app, "LocationHours") as Label).text, "Geöffnet: 07:00–20:00 · jetzt offen")
	assert_eq((_find(app, "LocationDistance") as Label).text, "4,2 km · 20 min Fahrt")
	assert_eq((_find(app, "TravelButton") as Button).text, "Hinfahren (20 min)")

	_press(app, "TravelButton")
	assert_eq((_find(app, "ClockLabel") as Label).text, "08:20")
	assert_eq((_find(app, "LocationLabel") as Label).text, "Ort: Café am Hafen")
	assert_eq((_find(app, "TravelButton") as Button).disabled, true)
	assert_true(_find(app, "StartButton_coffee") != null, "Kaffee fehlt am Hafen")
	assert_true(_find(app, "StartButton_rest") == null, "Ausruhen darf es am Hafen nicht geben")
	app.free()


func test_conflict_warning_needs_second_tap() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())

	_press(app, "StartButton_rest")  # würde den Termin um 14:00 verpassen lassen
	assert_eq(app.game.time.format_clock(), "13:30")
	var feedback := _find(app, "FeedbackLabel") as Label
	assert_true(feedback.text.begins_with("Achtung: Damit verpasst du „Treffen mit der Kamerafrau“"), feedback.text)

	_press(app, "StartButton_rest")  # zweiter Tipp: trotzdem
	assert_eq(app.game.time.format_clock(), "14:30")
	assert_true("Termin verpasst: „Treffen mit der Kamerafrau“ (Stimmung -10)" in feedback.text, feedback.text)
	app.free()


func test_attend_appointment_in_ui() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_true(_find(app, "AttendButton_camera_meeting") == null, "Wahrnehmen darf noch nicht angeboten werden")
	assert_true(_screen_has_text(app, "Wahrnehmen ab Tag 1 · 13:00 möglich."), "Grund fehlt")
	_travel(app, "studio")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_press(app, "MapPin_studio")  # aktualisiert die Anzeige
	assert_true(_press(app, "AttendButton_camera_meeting"), "Wahrnehmen fehlt vor Ort")
	assert_eq(app.game.time.format_clock(), "15:00")
	assert_eq(app.game.appointments.is_attended("camera_meeting"), true)
	assert_true(_find(app, "AttendButton_camera_meeting") == null, "erledigter Termin wird noch angezeigt")
	app.free()


func test_buy_equipment_in_studio_raises_quality() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_true(_find(app, "EquipmentButton_camera") == null, "Ausrüstung darf es zu Hause nicht geben")
	_travel(app, "studio")
	assert_eq((_find(app, "EquipmentTitle_camera") as Label).text, "Kamera · Stufe 0/3 (nichts)")
	_press(app, "EquipmentButton_camera")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 380,00 €")
	assert_eq((_find(app, "EquipmentTitle_camera") as Label).text, "Kamera · Stufe 1/3 (Webcam HD)")
	var summary := (_find(app, "ContentSummary_livestream") as Label).text
	assert_true(summary.ends_with("+26,25 €"), summary)
	app.free()


func test_random_event_is_decided_in_panel_with_channel_effects() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	app.game.events._trigger("tech_failure@3")  # wie nach einem Tageswechsel gewürfelt
	_press(app, "MapPin_home")  # aktualisiert die Anzeige
	assert_eq((_find(app, "EventPanel") as Control).visible, true)
	assert_true(_screen_has_text(app, "Stimmung -5 · Community -4 · Ruf -1"), "Kanal-Folgen fehlen")
	_press(app, "EventOption_improvise")
	assert_eq((_find(app, "EventPanel") as Control).visible, false)
	assert_eq(app.game.channel.community, 46)
	assert_eq(app.game.events.is_resolved("tech_failure@3"), true)
	app.free()


func test_number_formatting() -> void:
	assert_eq(ActivityText.format_int(0), "0")
	assert_eq(ActivityText.format_int(1234567), "1.234.567")
	assert_eq(ActivityText.signed_int(1200), "+1.200")
	assert_eq(ActivityText.signed_int(-35), "-35")


func test_channel_change_text_explains_brake_and_limits() -> void:
	var channel := ChannelSystemScript.new(TimeSystemScript.new(TimeSystemScript.at(1, 8, 20)), 500000, 98)
	var braked := channel.apply({"followers": 2000, "community": 5}, "content", "Livestream · Qualität 100 %")
	var lines := ActivityText.channel_change_text(braked)
	assert_eq(lines[0], "Tag 1 · 08:20  Livestream · Qualität 100 %")
	assert_eq(lines[1], "+1.000 Follower · Community +2 (gewünscht: +2.000 Follower · Community +5 · Wachstumsbremse, Grenze erreicht)")
	var plain := channel.apply({"reputation": -3}, "event", "Shitstorm: Aussitzen")
	assert_eq(ActivityText.channel_change_text(plain)[1], "Ruf -3")


func test_channel_panel_and_history_after_livestream() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_eq((_find(app, "ChannelLabel") as Label).text, "Kanal: 120 Follower · Community 50 · Ruf 50")
	assert_true(_screen_has_text(app, "Noch keine Änderungen."), "Leerzustand fehlt")
	_travel(app, "studio")
	_press(app, "ContentButton_livestream")
	assert_eq((_find(app, "ChannelLabel") as Label).text, "Kanal: 137 Follower · Community 52 · Ruf 50")
	assert_eq((_find(app, "FollowersLabel") as Label).text, "137 Follower")
	assert_eq((_find(app, "GrowthLabel") as Label).text, "Wachstumsbremse: 99 % neuer Follower kommen an (Maximum 1.000.000).")
	assert_true(_screen_has_text(app, "Tag 1 · 08:20  Livestream · Qualität 100 %"), "Begründung fehlt im Verlauf")
	assert_true(_screen_has_text(app, "+17 Follower · Community +2"), "Änderung fehlt im Verlauf")
	app.free()


func test_found_company_in_office() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_travel(app, "office")
	assert_eq((_find(app, "CompanyInfo_merch_label") as Label).text, "1 h · Gebühr 150,00 € · Einlage 200,00 € aufs Firmenkonto")
	_press(app, "CompanyFoundButton_merch_label")
	assert_eq((_find(app, "ClockLabel") as Label).text, "09:20")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 150,00 €")
	assert_eq((_find(app, "CompanyInfo_merch_label") as Label).text, "Gegründet · Firmenkonto 200,00 € · Auslastung 50 · Ruf 50")
	assert_eq((_find(app, "CompanyFoundButton_merch_label") as Button).visible, false)
	app.free()


func test_company_section_before_and_after_founding() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).visible, false)
	assert_true(_screen_has_text(app, "Noch kein Unternehmen. Gründen möglich: Merch-Label (Büro)."), "Hinweis fehlt")
	_travel(app, "office")
	_press(app, "CompanyFoundButton_merch_label")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).text, "Firmenkonto: 200,00 €")
	assert_eq((_find(app, "CompanyName") as Label).text, "Merch-Label")
	assert_eq((_find(app, "CompanyValue_utilization") as Label).text, "Auslastung 50/100")
	assert_eq((_find(app, "CompanyForecast") as Label).text,
			"Heute erwartet: Umsatz +15,90 € · Fixkosten -20,00 € · Ergebnis -4,10 € (abgerechnet beim Tageswechsel; Auslastung -3 ohne Pflege)")
	assert_eq((_find(app, "CompanyBranch") as Label).text, "Filiale Merch-Laden: noch nicht eröffnet (im Ladenlokal)")
	assert_true(_screen_contains(app, "Gründung: Merch-Label"), "Buchung fehlt")
	app.free()


func test_deposit_and_withdraw_buttons_move_money() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_travel(app, "office")
	_press(app, "CompanyFoundButton_merch_label")  # privat 150 €, Firma 200 €
	_press(app, "CompanyDepositButton")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 50,00 €")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).text, "Firmenkonto: 300,00 €")
	assert_eq((_find(app, "CompanyDepositButton") as Button).disabled, true)  # nur noch 50 € privat
	_press(app, "CompanyWithdrawButton")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 150,00 €")
	assert_true(_screen_contains(app, "Einlage ins Unternehmen (Firma)"), "Firmenbuchung nicht markiert")
	app.free()


func test_settlement_appears_in_feedback_and_list() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_travel(app, "office")
	_press(app, "CompanyFoundButton_merch_label")  # 09:20
	_press(app, "StartButton_order_stock")         # Auslastung 56, 10:20
	app.game.time.advance(TimeSystemScript.at(1, 23) - app.game.time.get_minutes())
	_travel(app, "home")
	_press(app, "StartButton_sleep")  # über Mitternacht -> Tagesabschluss Tag 1
	var feedback := (_find(app, "FeedbackLabel") as Label).text
	assert_true("Tagesabschluss Tag 1: Umsatz" in feedback, feedback)
	assert_true(_screen_contains(app, "Tag 1: ohne Pflege sinkt die Auslastung"), "Protokoll fehlt")
	assert_true(_screen_has_text(app, "Auslastung -3"), "Änderung fehlt")
	app.free()


## Querformat (G2.1): Beispielwerte wie ein iPhone mit Notch, 2556 × 1179 Pixel quer.
func test_safe_margins_for_notch_left_and_right() -> void:
	var window := Vector2(2556, 1179)
	var viewport := Vector2(1560, 720)  # Stretch "expand": Höhe 720, Breite folgt dem Seitenverhältnis
	var scale := viewport.x / window.x
	# Notch links (177 px), Home-Balken unten (63 px).
	var left := AppScript.safe_margins(window, Rect2(177, 0, 2556 - 177 - 177, 1179 - 63), viewport, 24)
	assert_true(absf(left[0] - (24 + 177 * scale)) < 0.01, str(left))
	assert_eq(left[1], 24.0)
	assert_true(absf(left[2] - (24 + 177 * scale)) < 0.01, "iOS hält beide Seiten frei: %s" % [left])
	assert_true(absf(left[3] - (24 + 63 * viewport.y / window.y)) < 0.01, str(left))
	# Gedreht (Notch rechts): nur die Seite wechselt, die Abstände bleiben symmetrisch berechnet.
	var right := AppScript.safe_margins(window, Rect2(0, 0, 2556 - 177, 1179 - 63), viewport, 24)
	assert_eq(right[0], 24.0)
	assert_true(absf(right[2] - (24 + 177 * scale)) < 0.01, str(right))
	# Ohne Gerät (Desktop/Tests): nur der Grundabstand.
	assert_eq(AppScript.safe_margins(Vector2.ZERO, Rect2(), viewport, 24), [24.0, 24.0, 24.0, 24.0] as Array[float])


func test_project_is_landscape() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)


func _travel(app: Node, location_id: String) -> void:
	_press(app, "MapPin_%s" % location_id)
	_press(app, "TravelButton")


## Wie _screen_has_text, aber Teiltext (z. B. Zeilen mit vorangestelltem Zeitstempel).
func _screen_contains(root: Node, text: String) -> bool:
	for label in root.find_children("*", "Label", true, false):
		if text in (label as Label).text and (label as Label).visible:
			return true
	return false


func _screen_has_text(root: Node, text: String) -> bool:
	for label in root.find_children("*", "Label", true, false):
		if (label as Label).text == text and (label as Label).visible:
			return true
	return false


## App in den Baum hängen; null (mit Fehlermeldung), wenn _ready() nicht lief.
## Startet immer ohne vorhandenen Spielstand (eigener Testpfad).
func _start_app(keep_save: bool = false) -> AppScript:
	if not keep_save:
		SaveSystemScript.delete_save(TEST_SAVE_PATH)
	var app := AppScript.new()
	app.save_path = TEST_SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
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
