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
	assert_eq((_find(app, "BalanceLabel") as Label).text, "500,00 €")
	assert_eq((_find(app, "LocationLabel") as Label).text, "Wohnung")
	# G4.3: Energie und Stimmung als Balken mit Zahl.
	assert_eq((_find(app, "StatValue_energy") as Label).text, "80")
	assert_eq((_find(app, "StatValue_mood") as Label).text, "60")
	assert_eq((_find(app, "StatBar_energy") as ProgressBar).value, 80.0)
	assert_eq((_find(app, "StatBar_mood") as ProgressBar).value, 60.0)
	var mood_icon := _find(app, "Stat_mood").get_child(0) as TextureRect
	assert_true(mood_icon.texture != null and mood_icon.texture.resource_path.ends_with("smiley.svg"), "Smiley fehlt")

	_travel(app, "studio")  # 08:00 -> 08:20
	(_find(app, "ContentButton_livestream") as Button).pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:20")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "525,00 €")
	assert_eq(app.game.ledger.get_entries().size(), 1)
	_press(app, "LedgerButton")
	assert_eq((_find(app, "LedgerList") as Node).get_child_count(), 1)

	(_find(app, "MenuButton") as Button).pressed.emit()
	var continue_button := _find(app, "ContinueButton") as Button
	assert_true(continue_button != null, "Fortsetzen fehlt nach dem ersten Spiel")
	continue_button.pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:20")
	assert_eq((_find(app, "LocationLabel") as Label).text, "Studio")

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
	_press(app, "HereButton")  # Fenster des aktuellen Orts
	assert_eq((_find(app, "ContentButton_livestream") as Button).disabled, true)
	# G4.5: Der Sperrgrund steht im Button der Kachel.
	assert_eq((_find(app, "ContentButton_livestream") as Button).text, "Zu wenig Energie (benötigt 20).")

	app.free()


func test_event_replaces_activities_until_decided() -> void:
	var app := _start_app()
	if app == null:
		return
	if not _press(app, "NewGameButton"):
		app.free()
		return

	app.game.time.advance(11 * 60)  # 08:00 -> 19:00
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # 19:00 -> 20:00, Ereignis wird fällig
	assert_true(_find(app, "EventPanel") != null, "Ereignis-Fenster fehlt")
	assert_true(_find(app, "Window_location") == null, "Ereignis muss das Ortsfenster ersetzen")
	assert_eq((_find(app, "WindowCloseButton") as Button).visible, false)  # erst entscheiden
	_press(app, "MapPin_studio")  # Karte ist gesperrt, solange das Ereignis offen ist
	assert_true(_find(app, "EventPanel") != null, "Ereignis darf nicht weggetippt werden")

	_press(app, "EventOption_accept")
	assert_true(_find(app, "EventPanel") == null, "Ereignis-Fenster noch offen")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "530,00 €")

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
	assert_eq((_find(restarted, "LocationLabel") as Label).text, "Studio")
	assert_eq((_find(restarted, "BalanceLabel") as Label).text, "525,00 €")
	assert_eq(restarted.game.ledger.get_entries().size(), 1)
	restarted.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_new_game_with_existing_save_needs_confirmation() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "HereButton")
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
	assert_true(_find(app, "StartButton_rest") == null, "Ohne Fenster keine Aktivitäten")
	_press(app, "MapPin_home")
	assert_true(_find(app, "StartButton_rest") != null, "Ausruhen fehlt in der Wohnung")
	assert_true(_find(app, "StartButton_coffee") == null, "Kaffee darf es zu Hause nicht geben")

	_press(app, "MapPin_cafe_harbor")  # nur auswählen, keine Zeit
	assert_eq((_find(app, "ClockLabel") as Label).text, "08:00")
	assert_eq((_find(app, "WindowTitle") as Label).text, "Café am Hafen")
	assert_eq((_find(app, "LocationHours") as Label).text, "07:00–20:00 · offen")
	assert_eq((_find(app, "LocationDistance") as Label).text, "4,2 km · 20 min Fahrt")
	assert_eq((_find(app, "TravelButton") as Button).text, "Hinfahren (20 min)")

	_press(app, "TravelButton")
	assert_eq((_find(app, "ClockLabel") as Label).text, "08:20")
	assert_eq((_find(app, "LocationLabel") as Label).text, "Café am Hafen")
	assert_eq((_find(app, "TravelButton") as Button).visible, false)  # schon hier
	assert_true(_find(app, "StartButton_coffee") != null, "Kaffee fehlt am Hafen")
	assert_true(_find(app, "StartButton_rest") == null, "Ausruhen darf es am Hafen nicht geben")
	app.free()


## G5.4: Konflikt-Popup statt „zweimal tippen“ – Aktivität: Abbrechen ändert nichts, Trotzdem starten startet einmal.
func test_conflict_popup_for_activity() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_press(app, "HereButton")
	var before := JSON.stringify(app.game.to_dict())
	_press(app, "StartButton_rest")  # 1 h – der Termin um 14:00 würde verpasst
	assert_true(_find(app, "ConflictPopup") != null, "kein Popup")
	assert_eq((_find(app, "ConflictTitle") as Label).text, "Termin verpassen?")
	assert_eq((_find(app, "ConflictAction") as Label).text, "Ausruhen · 1 h · Ende 14:30")
	assert_true(_screen_has_text(app, "„Treffen mit der Kamerafrau“ · Tag 1 · 14:00 · Studio"), "Termin fehlt")
	assert_true(_screen_has_text(app, "Verpasst: Stimmung -10"), "Kosten fehlen")
	assert_eq(JSON.stringify(app.game.to_dict()), before, "Popup allein ändert etwas")
	_press(app, "ConflictCancelButton")
	assert_true(_find(app, "ConflictPopup") == null, "Popup nach Abbrechen noch da")
	assert_eq(JSON.stringify(app.game.to_dict()), before, "Abbrechen ändert etwas")
	_press(app, "StartButton_rest")
	var confirm := _find(app, "ConflictConfirmButton") as Button
	confirm.pressed.emit()
	confirm.pressed.emit()  # zweiter Tipp auf denselben Button: darf nichts mehr tun
	assert_eq(app.game.time.format_clock(), "14:30", "nicht genau einmal gestartet")
	assert_eq(app.game.stats.get_value("energy"), 95, "Ausruhen nicht genau einmal (80 + 15)")
	var feedback := _find(app, "FeedbackLabel") as Label
	assert_true("Termin verpasst: „Treffen mit der Kamerafrau“ (Stimmung -10)" in feedback.text, feedback.text)
	assert_true(_find(app, "ConflictPopup") == null, "Popup nach dem Start noch da")
	app.free()


func test_conflict_popup_for_travel() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 50) - app.game.time.get_minutes())
	_press(app, "MapPin_cafe_harbor")
	_press(app, "TravelButton")  # 20 min → 14:10
	assert_eq((_find(app, "ConflictAction") as Label).text, "Fahrt nach Café am Hafen · 20 min · Ende 14:10")
	_press(app, "ConflictConfirmButton")
	assert_eq(app.game.locations.get_current(), "cafe_harbor")
	assert_eq(app.game.time.format_clock(), "14:10")
	app.free()


func test_no_conflict_no_popup() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # 08:00 → 09:00, kein Termin dazwischen
	assert_true(_find(app, "ConflictPopup") == null, "Popup ohne Konflikt")
	assert_eq(app.game.time.format_clock(), "09:00")
	app.free()


func test_conflict_popup_lists_all_conflicts() -> void:
	SaveSystemScript.delete_save(TEST_SAVE_PATH)
	var data := Helpers.game_data()
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/appointments/appointments.json"))
	list.append({"id": "extra_call", "title": "Anruf vom Label", "location": "office", "start": {"day": 1, "hour": 16},
			"duration_minutes": 30, "effects": {}, "missed_effects": {"mood": -3}})
	assert_true(data.appointments.load_data(list), "; ".join(data.appointments.errors))
	var app := AppScript.new()
	app.save_path = TEST_SAVE_PATH
	app.preloaded_data = data
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_press(app, "HereButton")
	_press(app, "StartButton_sleep")  # 8 h: 14:00 und 16:00
	assert_true(_find(app, "ConflictEntry_0") != null and _find(app, "ConflictEntry_1") != null, "nicht alle Konflikte")
	assert_true(_screen_has_text(app, "„Anruf vom Label“ · Tag 1 · 16:00 · Büro"), "zweiter Termin fehlt")
	assert_true(_screen_has_text(app, "Verpasst: Stimmung -3"), "Kosten des zweiten fehlen")
	_press(app, "ConflictCancelButton")
	assert_eq(app.game.time.format_clock(), "13:30")
	app.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_calendar_window_shows_day_plan() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "AppointmentsButton")
	assert_eq((_find(app, "WindowTitle") as Label).text, "Kalender · Tag 1 · Mo")
	var row := _find(app, "CalendarEntry_camera_meeting")
	assert_true(row != null, "Termin fehlt im Kalender")
	assert_true(_screen_has_text(app, "Studio · 14:00–15:00 · 20 min Fahrt"), "Ort/Zeit/Fahrzeit fehlen")
	assert_eq((_find(app, "CalendarState_camera_meeting") as Label).text, "als Nächstes")
	var now_line := _find(app, "CalendarNowLine")
	assert_true(now_line != null and now_line.get_index() < row.get_index(), "Jetzt-Linie nicht vor dem Termin")
	assert_true(_screen_has_text(app, "Nächster Termin: Tag 2 · 09:00 · Probetraining (Fitnessstudio)"), "Hinweis fehlt")
	_press(app, "WindowCloseButton")
	# Termin verstreicht → grau und „verpasst“, die Jetzt-Linie steht danach.
	app.game.time.advance(TimeSystemScript.at(1, 16) - app.game.time.get_minutes())
	_press(app, "AppointmentsButton")
	assert_eq((_find(app, "CalendarState_camera_meeting") as Label).text, "verpasst")
	assert_true((_find(app, "CalendarEntry_camera_meeting").get_child(2) as Control).modulate.a < 1.0, "nicht ausgegraut")
	assert_true(_find(app, "CalendarNowLine").get_index() > _find(app, "CalendarEntry_camera_meeting").get_index())
	# Leerer Tag
	_press(app, "WindowCloseButton")
	app.game.time.advance(TimeSystemScript.at(4, 9) - app.game.time.get_minutes())
	_press(app, "AppointmentsButton")
	assert_true(_screen_has_text(app, "Heute keine Termine und Fristen."), "Leerzustand fehlt")
	app.free()


func test_attend_appointment_in_ui() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "AppointmentsButton")
	assert_true(_find(app, "AttendButton_camera_meeting") == null, "Wahrnehmen darf noch nicht angeboten werden")
	assert_true(_screen_has_text(app, "Wahrnehmen ab Tag 1 · 13:00 möglich."), "Grund fehlt")
	_travel(app, "studio")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_press(app, "AppointmentsButton")  # öffnet die Termine neu
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
	_press(app, "HereButton")
	assert_true(_find(app, "EquipmentButton_camera") == null, "Ausrüstung darf es zu Hause nicht geben")
	_travel(app, "studio")
	assert_eq((_find(app, "TileTitle_camera") as Label).text, "Kamera")
	assert_eq((_find(app, "TileTime_camera") as Label).text, "Stufe 0/3 · nichts")
	_press(app, "EquipmentButton_camera")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "380,00 €")
	assert_eq((_find(app, "TileTime_camera") as Label).text, "Stufe 1/3 · Webcam HD")
	# Einnahme des Livestreams steigt mit der Qualität (letzter Chip der Kachel = Geld).
	var chips := _find(app, "TileEffects_livestream").get_children()
	var money := (chips[chips.size() - 1] as Control).get_child(-1) as Label
	assert_eq(money.text, "+26,25 €")
	app.free()


func test_random_event_is_decided_in_panel_with_channel_effects() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	app.game.events._trigger("tech_failure@3")  # wie nach einem Tageswechsel gewürfelt
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # nächste Aktion aktualisiert die Anzeige
	assert_true(_find(app, "EventPanel") != null, "Ereignis-Fenster fehlt")
	assert_true(_screen_has_text(app, "Stimmung -5 · Community -4 · Ruf -1"), "Kanal-Folgen fehlen")
	_press(app, "EventOption_improvise")
	assert_true(_find(app, "EventPanel") == null, "Ereignis-Fenster noch offen")
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
	_press(app, "ChannelButton")
	assert_eq((_find(app, "ChannelLabel") as Label).text, "Kanal: 120 Follower · Community 50 · Ruf 50")
	assert_true(_screen_has_text(app, "Noch keine Änderungen."), "Leerzustand fehlt")
	_travel(app, "studio")
	_press(app, "ContentButton_livestream")
	_press(app, "ChannelButton")
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
	assert_eq((_find(app, "BalanceLabel") as Label).text, "150,00 €")
	assert_eq((_find(app, "CompanyInfo_merch_label") as Label).text, "Gegründet · Firmenkonto 200,00 € · Auslastung 50 · Ruf 50")
	assert_eq((_find(app, "CompanyFoundButton_merch_label") as Button).visible, false)
	app.free()


func test_company_section_before_and_after_founding() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).visible, false)
	assert_eq((_find(app, "CompanyButton") as Button).visible, false)  # erst nach der Gründung
	_travel(app, "office")
	_press(app, "CompanyFoundButton_merch_label")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).text, "200,00 €")
	assert_eq((_find(app, "CompanyButton") as Button).visible, true)
	_press(app, "CompanyButton")
	assert_eq((_find(app, "CompanyName") as Label).text, "Merch-Label")
	assert_eq((_find(app, "CompanyValue_utilization") as Label).text, "Auslastung 50/100")
	assert_eq((_find(app, "CompanyForecast") as Label).text,
			"Heute erwartet: Umsatz +15,90 € · Fixkosten -20,00 € · Ergebnis -4,10 € (abgerechnet beim Tageswechsel; Auslastung -3 ohne Pflege)")
	assert_eq((_find(app, "CompanyBranch") as Label).text, "Filiale Merch-Laden: noch nicht eröffnet (im Ladenlokal)")
	_press(app, "LedgerButton")
	assert_true(_screen_contains(app, "Gründung: Merch-Label"), "Buchung fehlt")
	app.free()


func test_deposit_and_withdraw_buttons_move_money() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_travel(app, "office")
	_press(app, "CompanyFoundButton_merch_label")  # privat 150 €, Firma 200 €
	_press(app, "CompanyButton")
	_press(app, "CompanyDepositButton")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "50,00 €")
	assert_eq((_find(app, "CompanyBalanceLabel") as Label).text, "300,00 €")
	assert_eq((_find(app, "CompanyDepositButton") as Button).disabled, true)  # nur noch 50 € privat
	_press(app, "CompanyWithdrawButton")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "150,00 €")
	_press(app, "LedgerButton")
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
	_press(app, "EventOption_decline")  # Ereignis von 20:00 zuerst entscheiden
	_press(app, "HereButton")
	_press(app, "StartButton_sleep")  # über Mitternacht -> Tagesabschluss Tag 1
	var feedback := (_find(app, "FeedbackLabel") as Label).text
	assert_true("Tagesabschluss Tag 1: Umsatz" in feedback, feedback)
	_press(app, "CompanyButton")
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


func test_project_saves_battery() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/low_processor_mode"), true)
	assert_eq(ProjectSettings.get_setting("application/run/max_fps"), 60)


## G4.2: EINE feste Querformat-Richtung – „umgekehrt“ ergibt im iOS-Export UIInterfaceOrientationLandscapeRight
## (Home-Seite rechts, Dynamic Island links; Entscheidung 038).
func test_project_is_landscape() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), DisplayServer.SCREEN_REVERSE_LANDSCAPE)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)


# --- Querformat-Spielansicht (G2) ------------------------------------------------------

func test_windows_open_one_at_a_time_and_close() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	assert_true(_find(app, "Window_location") == null, "Start ohne Fenster")
	_press(app, "ChannelButton")
	assert_true(_find(app, "Window_channel") != null, "Kanal-Fenster fehlt")
	_press(app, "LedgerButton")
	assert_true(_find(app, "Window_channel") == null, "Es darf nur ein Fenster offen sein")
	assert_true(_find(app, "Window_ledger") != null, "Buchungen-Fenster fehlt")
	_press(app, "WindowCloseButton")
	assert_true(_find(app, "Window_ledger") == null, "Fenster nicht geschlossen")
	assert_eq((_find(app, "Dim") as Control).visible, false)
	app.free()


func test_location_window_elsewhere_shows_locked_actions() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "MapPin_studio")
	assert_eq((_find(app, "WindowTitle") as Label).text, "Studio")
	assert_eq((_find(app, "ContentButton_livestream") as Button).disabled, true)
	assert_eq((_find(app, "ContentButton_livestream") as Button).text, "Nur vor Ort möglich: Studio.")
	assert_eq((_find(app, "TravelButton") as Button).visible, true)
	app.free()


func test_long_feedback_stays_until_tapped() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	var screen := _find(app, "CityMap").get_parent()
	screen.call("show_message", "Kurz.")
	var timer := screen.find_children("*", "Timer", false, false)[0] as Timer
	assert_eq(timer.is_stopped(), false)
	screen.call("show_message", "Erste Zeile\nZweite Zeile")
	assert_eq(timer.is_stopped(), true)
	assert_eq((_find(app, "Toast") as Control).visible, true)
	app.free()


# --- Finanzen und Fristen (Phase 5) ------------------------------------------------------

## Neues Spiel, Privatkonto auf 50 €, dann bis Montag (Tag 8): Wohnungsmiete bleibt offen.
func _app_with_open_rent() -> AppScript:
	var app := _start_app()
	if app == null:
		return null
	_press(app, "NewGameButton")
	app.game.ledger.post(-45000, "test", "Ausgabe für Test", "test")
	app.game.appointments.restore({"since_minutes": 99999, "attended": [], "missed": []})
	app.game.time.advance(TimeSystemScript.at(7, 22) - app.game.time.get_minutes())
	while app.game.events.has_pending():
		var instance: String = app.game.events.get_next_pending_id()
		app.game.events.resolve(instance, app.game.events.get_definition_for(instance).options[-1].id)
	_press(app, "HereButton")
	_press(app, "StartButton_sleep")  # über Mitternacht -> Montag, Tag 8
	while app.game.events.has_pending():
		var instance: String = app.game.events.get_next_pending_id()
		_press(app, "EventOption_%s" % app.game.events.get_definition_for(instance).options[-1].id)
	return app


func test_obligations_button_shows_open_count_and_pay_works() -> void:
	var app := _app_with_open_rent()
	if app == null:
		return
	# G4.4: roter Zählerpunkt statt „Fristen (1)“.
	assert_eq(_find(app, "ObligationsButton").call("get_badge"), 1)
	assert_eq((_find(app, "ObligationsButton").find_child("BadgeLabel", true, false) as Label).text, "1")
	assert_true("Miete Wohnung (Woche 2) fällig" in (_find(app, "FeedbackLabel") as Label).text,
			(_find(app, "FeedbackLabel") as Label).text)
	_press(app, "ObligationsButton")
	assert_eq((_find(app, "ObligationAmount_rent_home_8") as Label).text, "Offen: 80,00 €")
	assert_eq((_find(app, "ObligationPayButton_rent_home_8") as Button).disabled, true)  # nur 10 €
	app.game.ledger.post(10000, "test", "Einnahme für Test", "test")
	_press(app, "ObligationsButton")  # neu öffnen
	assert_eq((_find(app, "ObligationPayButton_rent_home_8") as Button).disabled, false)
	_press(app, "ObligationPayButton_rent_home_8")
	assert_eq(_find(app, "ObligationsButton").call("get_badge"), 0)
	assert_eq((_find(app, "ObligationsButton").find_child("Badge", true, false) as Control).visible, false)
	assert_true("Miete Wohnung (Woche 2) bezahlt: -80,00 €." in (_find(app, "FeedbackLabel") as Label).text,
			(_find(app, "FeedbackLabel") as Label).text)
	assert_true(_screen_has_text(app, "Keine offenen Fristen."), "Leerzustand fehlt")
	app.free()


func test_reminder_fee_is_shown_as_open_not_booked() -> void:
	var app := _app_with_open_rent()
	if app == null:
		return
	app.game.time.advance(TimeSystemScript.at(11, 8) - app.game.time.get_minutes())  # Mahnung
	_press(app, "ObligationsButton")
	assert_eq((_find(app, "ObligationAmount_rent_home_8") as Label).text, "Offen: 90,00 €")
	assert_true(_screen_has_text(app, "davon Mahngebühr 10,00 € (wird erst beim Bezahlen gebucht)"), "Hinweis fehlt")
	assert_eq(app.game.ledger.get_entries_by_category("reminder_fee").size(), 0)
	app.free()


func test_ledger_window_shows_week_summary() -> void:
	var app := _app_with_open_rent()
	if app == null:
		return
	_press(app, "LedgerButton")
	var week2 := (_find(app, "LedgerWeek_2_private") as Label).text
	assert_eq(week2, "Woche 2 (läuft) · Privatkonto: Einnahmen 0,00 € · Ausgaben -40,00 € · Ergebnis -40,00 €")
	assert_true(_find(app, "LedgerWeek_1_private") != null, "Vorwoche fehlt")
	app.free()


# --- Spielstand im Menü und defekte Stände (Phase 6) -------------------------------------

## Ticket G3.3: Schriftzug im Hauptmenü mit der freien Schrift, Startbild eingetragen.
func test_main_menu_shows_logo() -> void:
	var app := _start_app()
	if app == null:
		return
	var off := _find(app, "Off") as Label
	var camera := _find(app, "Camera") as Label
	assert_true(off != null and camera != null, "Schriftzug fehlt")
	if off != null and camera != null:
		assert_eq(off.text + " " + camera.text, "OFF CAMERA")
		var font := off.get_theme_font("font") as FontVariation
		assert_true(font != null and font.base_font.resource_path.ends_with("BebasNeue-Regular.ttf"), "falsche Schrift")
	assert_true(FileAccess.file_exists("res://assets/fonts/bebas_neue/OFL.txt"), "Schriftlizenz fehlt")
	assert_eq(ProjectSettings.get_setting("application/boot_splash/image"), "res://assets/splash/splash.png")
	app.free()


func test_main_menu_shows_save_info() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # 09:00, gespeichert
	_press(app, "MenuButton")
	var info := (_find(app, "SaveInfoLabel") as Label).text
	assert_true(info.begins_with("Tag 1 · Mo, 09:00 · 500,00 € · gespeichert "), info)
	app.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_corrupt_save_loads_backup_and_says_so() -> void:
	var app := _start_app()
	if app == null:
		return
	_press(app, "NewGameButton")
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # zweites Speichern -> Backup vorhanden
	app.free()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ kaputt")
	file.close()
	var restarted := _start_app(true)
	_press(restarted, "ContinueButton")
	var feedback := (_find(restarted, "FeedbackLabel") as Label).text
	assert_true("Backup wurde geladen, die defekte Datei aufbewahrt" in feedback, feedback)
	assert_eq(SaveSystemScript.corrupt_files(TEST_SAVE_PATH).size(), 1)
	restarted.free()
	SaveSystemScript.delete_save(TEST_SAVE_PATH)


func test_unloadable_save_keeps_copies_when_starting_new_game() -> void:
	SaveSystemScript.delete_save(TEST_SAVE_PATH)
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("kaputt")
	file.close()
	var app := _start_app(true)
	_press(app, "ContinueButton")
	assert_true(_screen_contains(app, "Die defekte Datei wurde aufbewahrt."), "Hinweis fehlt")
	var kept := SaveSystemScript.corrupt_files(TEST_SAVE_PATH)
	assert_eq(kept.size(), 1)
	_press(app, "NewGameButton")
	_press(app, "NewGameButton")  # zweiter Tipp, weil es einen (defekten) Stand gab
	assert_true(app.game != null, "neues Spiel nicht gestartet")
	assert_eq(FileAccess.get_file_as_string(kept[0]), "kaputt")  # nicht überschrieben
	_press(app, "MenuButton")
	_press(app, "SettingsButton")
	assert_true(_screen_contains(app, "Aufbewahrte defekte Spielstände: 1"), "Anzeige in den Einstellungen fehlt")
	_press(app, "DeleteSaveButton")
	_press(app, "DeleteSaveButton")
	assert_eq(SaveSystemScript.corrupt_files(TEST_SAVE_PATH).size(), 0)
	app.free()


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
