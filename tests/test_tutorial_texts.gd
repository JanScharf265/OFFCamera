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
func _scenario(only: String, trigger: String, device: String = "iPhone 15/16 Pro Max (Dynamic Island)") -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	Layout.apply(app, device)  # Gerätegröße vor dem Auslöser (Reiter, Lage der Ziele)
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
			_resolve_events(app)  # 20:00-Ereignis und „Liegeplatz 14“ (U.3, „Nicht heute“)
			_press(app, "WindowCloseButton")  # Kalender bei Tagesbeginn
		"first_channel_open":
			_press(app, "ChannelButton")
		"first_ledger_open":
			_press(app, "LedgerButton")
		"first_content_quality", "first_equipment_offered":
			app.game.locations.travel("studio")
			_jump(app, TimeSystemScript.at(1, 10))
			_press(app, "MapPin_studio")
		"first_effect_symbols":
			_jump(app, TimeSystemScript.at(1, 10))
			_press(app, "MapPin_studio")
		"first_company_offered":
			_jump(app, TimeSystemScript.at(1, 10))
			_press(app, "MapPin_office")
		"first_branch_offered":
			_jump(app, TimeSystemScript.at(1, 12))
			_press(app, "MapPin_label_store")
		"first_company_open":
			_found_company(app)
			_press(app, "CompanyButton")
		"first_settlement":
			_found_company(app)
			_jump(app, TimeSystemScript.at(2, 8))
			_resolve_events(app)
			_press(app, "WindowCloseButton")  # Kalender bei Tagesbeginn
		"first_black_money":
			var black: String = load("res://scripts/systems/ledger_system.gd").BLACK
			assert_true(app.game.ledger.post(25000, "test", "Test: Schwarzgeld", "test", "", "", false, black) != null)
			_screen(app).call("_refresh")
		"first_organisation_founded", "first_mission_available":
			assert_eq(app.game.organisation.found("Los Testigos"), "")
			_screen(app).call("_refresh")
		"first_supplier_open":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_jump(app, TimeSystemScript.at(1, 10))
			app.game.locations.travel("cafe_harbor")  # „Treffen am Hafen“ → El Rubio erreichbar
			_screen(app).call("open_supplier", "el_rubio")
		"first_credit_offered":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_jump(app, TimeSystemScript.at(1, 10))
			app.game.locations.travel("cafe_harbor")
			_force_delivery(app)
			_screen(app).call("open_supplier", "el_rubio")
		"first_site_offered":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_jump(app, TimeSystemScript.at(1, 10))
			app.game.locations.travel("cafe_harbor")
			_force_delivery(app)
			app.game.supply.restore(_with_stock(app.game.supply.to_dict()))
			app.game.missions.update_availability()  # „Die erste Ware“ erledigt → Garage bekannt
			_screen(app).call("_refresh")
			app.game.locations.travel("garage")
			_screen(app).call("_refresh")
			_press(app, "MapPin_garage")
		"first_sale_offered":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_jump(app, TimeSystemScript.at(1, 10))
			app.game.locations.travel("cafe_harbor")
			_force_delivery(app)
			app.game.supply.restore(_with_stock(app.game.supply.to_dict()))
			app.game.missions.update_availability()
			app.game.locations.travel("garage")
			assert_eq(app.game.sites.acquire("garage_san_pedro"), "")
			app.game.locations.travel("cafe_harbor")
			_screen(app).call("_refresh")
			_screen(app).call("open_sale", "harbor_after_hours")
		"first_crew_open":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			var data: Dictionary = app.game.missions.to_dict()
			for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
				data["completed"][id] = 0
			data["active"] = []
			assert_eq(app.game.missions.restore(data), "")
			app.game.missions.update_availability()
			_screen(app).call("_refresh")
			_screen(app).call("open_crew")
		"first_dealer_in_crew", "first_promotion_possible":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			var data: Dictionary = app.game.missions.to_dict()
			for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
				data["completed"][id] = 0
			data["active"] = []
			assert_eq(app.game.missions.restore(data), "")
			app.game.missions.update_availability()
			var crew: Dictionary = app.game.crew.to_dict()
			crew["members"].append({"id": "d1", "name": "Chema L.", "role": "dealer", "skill": 40, "loyalty": 50,
					"greed": 50, "wage_cents": 4000, "hired_day": 0, "rank": 1, "district": ""})
			crew["last_processed_day"] = 99
			assert_eq(app.game.crew.restore(crew), "")
			if trigger == "first_promotion_possible":
				app.game.ledger.post(100000, "test", "Start", "test", "t", "", false, "black")
				_jump(app, TimeSystemScript.at(3, 10))
				_resolve_events(app)
			_screen(app).call("_refresh")
			_screen(app).call("open_crew")
		"first_view_toggle_shown", "first_underworld_view":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			if trigger == "first_underworld_view":
				_screen(app).call("set_underworld_view", true)
			_screen(app).call("_refresh")
			_screen(app).call("_open_due_tutorial")
		"first_district_window":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_screen(app).call("set_underworld_view", true)
			_screen(app).call("_refresh")
			_press(app, "DistrictLabel_san_pedro")
		"first_rivals_open":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			var data: Dictionary = app.game.missions.to_dict()
			for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer"]:
				data["completed"][id] = 0
			data["active"] = []
			assert_eq(app.game.missions.restore(data), "")
			app.game.ledger.post(100000, "test", "Start", "test", "t", "", false, "black")
			_screen(app).call("_refresh")
			_screen(app).call("open_rivals")
		"first_crew_risk_shown":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			var data: Dictionary = app.game.missions.to_dict()
			for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
				data["completed"][id] = 0
			data["active"] = []
			assert_eq(app.game.missions.restore(data), "")
			var crew: Dictionary = app.game.crew.to_dict()
			crew["members"].append({"id": "d1", "name": "Chema L.", "role": "dealer", "skill": 40, "loyalty": 50,
					"greed": 50, "wage_cents": 4000, "hired_day": 0, "rank": 1, "district": ""})
			assert_eq(app.game.crew.restore(crew), "")
			_screen(app).call("_refresh")
			_screen(app).call("open_crew")
		"first_laundering_offered":
			assert_eq(app.game.organisation.found("Los Lobos"), "")
			_found_company(app)
			app.game.ledger.post(200000, "test", "Start", "test", "t", "", false, "black")
			_screen(app).call("_refresh")
			_press(app, "OrganisationButton")
		"first_obligation_due":
			_jump(app, TimeSystemScript.at(8, 9))
			_resolve_events(app)
			if _screen(app).find_child("Window_calendar", false, false) != null:
				_press(app, "WindowCloseButton")
		_:
			assert_true(false, "Kein Testszenario für Auslöser '%s' (%s)" % [trigger, only])
	return app


func _found_company(app: AppScript) -> void:
	app.game.locations.travel("office")
	_jump(app, TimeSystemScript.at(1, 10))
	assert_eq(app.game.company.found("merch_label"), "")
	_screen(app).call("_refresh")


## Eine angekommene Lieferung bei El Rubio (für den Kredit), unabhängig vom Zufall.
func _force_delivery(app: AppScript) -> void:
	var data: Dictionary = app.game.supply.to_dict()
	data["delivered_before_trim"] = {"el_rubio": 1}
	assert_eq(app.game.supply.restore(data), "")


## Bestand für „Die erste Ware“ (ohne Zufall der Lieferung).
func _with_stock(data: Dictionary) -> Dictionary:
	data["stock"] = {"weed": 5}
	return data


func _resolve_events(app: AppScript) -> void:
	while app.game.events.has_pending():
		var instance: String = app.game.events.get_next_pending_id()
		app.game.events.resolve(instance, app.game.events.get_definition_for(instance).options[-1].id)
	_screen(app).call("_refresh")


func test_every_tutorial_appears_and_fits_every_device() -> void:
	var problems := PackedStringArray()
	for definition in _catalog().get_all():
		for device in Layout.DEVICES:
			var app := _scenario(definition.id, definition.trigger, device)
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
			"reminder", "conflict", "wait", "trip", "events", "saving", "channel", "content_quality", "equipment",
			"effect_symbols", "company_found", "company_money", "branch", "settlement", "obligations", "ledger",
			"black_money", "heat", "organisation", "missions", "products", "supplier", "credit", "sites", "selling", "crew", "dealer_sales", "promotion", "underworld_view", "districts", "district_control", "rivals", "crew_risks", "laundering"]:
		assert_true(mechanics.has(mechanic), "Grundlagen-Mechanik '%s' ohne Tutorial" % mechanic)


## T.6: nie mehr als 3 Tutorials hintereinander – der Rest kommt bei der nächsten Gelegenheit.
func test_at_most_three_in_a_row() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	_press(app, "TutorialConfirmButton")
	_press(app, "TutorialConfirmButton")
	_jump(app, TimeSystemScript.at(1, 10))
	_press(app, "MapPin_studio")  # aus der Ferne: Kacheln, Hinfahren, Kombi, Symbole … fällig
	var shown := []
	while _screen(app).find_child("TutorialOverlay", false, false) != null and shown.size() < 10:
		shown.append(_screen(app).find_child("TutorialOverlay", false, false).get("tutorial_id"))
		_press(app, "TutorialConfirmButton")
	assert_eq(shown.size(), 3, "hintereinander: %s" % [shown])
	assert_true(not app.game.tutorials.get_due().is_empty(), "nichts mehr fällig – Test zu schwach")
	_press(app, "WindowCloseButton")
	_press(app, "MapPin_studio")  # nächste Gelegenheit
	assert_true(_screen(app).find_child("TutorialOverlay", false, false) != null, "Rest kommt nicht")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## T.6b: Tipp auf den Ortsnamen öffnet die Info-Blase mit der Beschreibung (in der Safe Area, Schrift ≥ 21 px),
## Tipp daneben schließt sie; auf allen 4 Geräteklassen.
func test_location_info_bubble() -> void:
	for device in Layout.DEVICES:
		SaveSystemScript.delete_save(SAVE_PATH)
		var app := AppScript.new()
		app.save_path = SAVE_PATH
		(Engine.get_main_loop() as SceneTree).root.add_child(app)
		_press(app, "NewGameButton")
		_screen(app).call("close_tutorial")
		_screen(app).set("show_tutorials", false)
		_press(app, "MapPin_studio")
		Layout.apply(app, device)
		Layout.settle_in_place(_screen(app).find_child("Window_location", false, false))
		var title_button := app.find_child("WindowTitleButton", true, false) as Button
		assert_true(title_button != null, "%s: Ortsname nicht antippbar" % device)
		assert_true(title_button.size.y >= UiStyle.TOUCH_SIZE - 0.5 and title_button.size.x >= UiStyle.TOUCH_SIZE - 0.5,
				"%s: Tippfläche %s" % [device, title_button.size])
		assert_eq((app.find_child("LocationWindowContent", true, false) as Control).tooltip_text, "", "Tooltip noch da")
		title_button.pressed.emit()
		var text := app.find_child("LocationInfoText", true, false) as Label
		assert_true(text != null, "%s: keine Info-Blase" % device)
		if text == null:
			app.free()
			continue
		assert_eq(text.text, app.game.locations.get_catalog().get_definition("studio").description)
		assert_true(text.get_theme_font_size("font_size") >= UiStyle.MIN_READ_FONT_SIZE)
		var bubble := app.find_child("LocationInfoBubble", true, false) as Control
		assert_true(Layout.safe_rect(device).grow(0.5).encloses(Rect2(bubble.position, bubble.size)),
				"%s: Info-Blase außerhalb der Safe Area" % device)
		assert_true(text.get_line_count() <= text.get_visible_line_count(), "%s: Text abgeschnitten" % device)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		(app.find_child("LocationInfo", true, false) as Control).gui_input.emit(release)
		assert_true(app.find_child("LocationInfo", true, false) == null, "%s: schließt nicht" % device)
		assert_true(_screen(app).find_child("Window_location", false, false) != null, "Ortsfenster mit geschlossen")
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Neue Auslöser (T.5) werden gemeldet – jeweils im passenden Moment.
func test_new_triggers_are_reported() -> void:
	for pair in [["first_window_closed", "tut_map_swipe"], ["first_action", "tut_stats"],
			["first_conflict_popup", "tut_conflict"], ["first_wait_offered", "tut_wait"],
			["first_trip_offered", "tut_trip"], ["first_new_day", "tut_save"],
			["first_channel_open", "tut_channel"], ["first_content_quality", "tut_content"],
			["first_equipment_offered", "tut_equipment"], ["first_effect_symbols", "tut_symbols"],
			["first_company_offered", "tut_company"], ["first_company_open", "tut_transfer"],
			["first_branch_offered", "tut_branch"], ["first_settlement", "tut_settlement"],
			["first_ledger_open", "tut_ledger"], ["first_obligation_due", "tut_obligations"],
			["first_black_money", "tut_black_money"], ["first_organisation_founded", "tut_heat"],
			["first_mission_available", "tut_missions"], ["first_supplier_open", "tut_supplier"],
			["first_credit_offered", "tut_credit"], ["first_site_offered", "tut_sites"],
			["first_sale_offered", "tut_selling"], ["first_crew_open", "tut_crew"],
			["first_dealer_in_crew", "tut_dealer_sales"], ["first_promotion_possible", "tut_promotion"],
			["first_view_toggle_shown", "tut_underworld_view"], ["first_underworld_view", "tut_districts"],
			["first_district_window", "tut_district_control"],
			["first_rivals_open", "tut_rivals"], ["first_crew_risk_shown", "tut_crew_risks"],
			["first_laundering_offered", "tut_laundering"]]:
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
