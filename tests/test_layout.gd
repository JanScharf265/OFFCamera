extends "res://tests/base_test.gd"

## Phase 7, Ticket 7.2: Layout auf typischen iPhones im Querformat (tests/layout_helper.gd).
## Geprüft: HUD, Seitenleisten, Hinweis und jedes Fenster liegen in der Safe Area und überlappen sich
## nicht; Hauptmenü und Einstellungen passen in die Höhe. Ungünstige Lage: Unternehmen gegründet
## (4 Buttons links) und ein langer, mehrzeiliger Hinweis.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const SAVE_PATH := "user://test_layout_save.json"
const LONG_TEXT := "Tagesabschluss Tag 12: Umsatz +123,45 € (30,00 € + 40,00 € Filiale + 18,00 € Reichweite · Auslastung 88 % · Ruf +5 %) · Fixkosten -45,00 € · Ergebnis +78,45 €\nMiete Wohnung (Woche 3) automatisch bezahlt: -80,00 €.\nMahnung: Stadtabgabe (für Woche 2) – offen jetzt 25,00 € (+15,00 € Mahngebühr)."


func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


## Spielansicht in ungünstiger Lage: Unternehmen gegründet, langer Hinweis sichtbar.
func _busy_game(app: AppScript) -> Control:
	_press(app, "NewGameButton")
	_press(app, "MapPin_office")
	_press(app, "TravelButton")
	_press(app, "CompanyFoundButton_merch_label")
	_press(app, "WindowCloseButton")
	var screen := app.find_child("CityMap", true, false).get_parent() as Control
	screen.call("show_message", LONG_TEXT)
	return screen


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


func test_hud_bars_and_hint_fit_every_device() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _busy_game(app)
		Layout.apply(app, device)
		var safe := Layout.safe_rect(device)
		var names := ["HudBar", "MenuButton", "LifeGroup", "BusinessGroup", "HereButton", "Toast"]
		var rects := {}
		for node_name in names:
			var control := app.find_child(node_name, true, false) as Control
			rects[node_name] = Layout.rect_of(control)
			assert_true(_inside(safe, rects[node_name]), "%s: %s ragt aus der Safe Area %s: %s" % [device, node_name,
					safe, rects[node_name]])
		for i in names.size():
			for j in range(i + 1, names.size()):
				if [names[i], names[j]] == ["HudBar", "MenuButton"]:
					continue  # Das Zahnrad sitzt absichtlich in der Leiste (G4.4).
				assert_true(not rects[names[i]].intersects(rects[names[j]]), "%s: %s überlappt %s" % [device,
						names[i], names[j]])
		# G4.3: Die HUD-Leiste geht über die volle Breite der Safe Area, ist schmal, und ihr Inhalt passt hinein.
		var hud := app.find_child("HudBar", true, false) as Control
		assert_true(absf(rects["HudBar"].size.x - safe.size.x) < 0.5, "%s: HUD-Leiste nicht volle Breite" % device)
		assert_true(rects["HudBar"].size.y <= 64.0, "%s: HUD-Leiste zu hoch: %d" % [device, rects["HudBar"].size.y])
		assert_true(hud.get_combined_minimum_size().x <= rects["HudBar"].size.x + 0.5, "%s: HUD-Inhalt zu breit: %d" % [
				device, hud.get_combined_minimum_size().x])
		# G4.4: Platz in der Leiste für das Zahnrad – kein HUD-Text liegt unter dem Kreis.
		Layout.sort_containers(screen)
		var gear := Layout.screen_rect((app.find_child("MenuButton", true, false) as Control).find_child("Circle",
				true, false) as Control, screen)
		var space := Layout.screen_rect(hud.find_child("MenuSpace", true, false) as Control, screen)
		assert_true(gear.position.x >= space.position.x - 0.5, "%s: Zahnrad liegt über HUD-Text" % device)
		assert_true(gear.position.y >= rects["HudBar"].position.y and gear.end.y <= rects["HudBar"].end.y,
				"%s: Zahnrad nicht in der Leiste: %s" % [device, gear])
		var map := app.find_child("CityMap", true, false) as Control
		assert_eq(map.size, screen.size, "%s: Karte nicht Vollbild" % device)
		assert_eq((app.find_child("CompanyButton", true, false) as Button).visible, true)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_every_window_fits_every_device() -> void:
	var openers := ["MapPin_office", "AppointmentsButton", "ObligationsButton", "ChannelButton", "CompanyButton",
			"LedgerButton"]
	for device in Layout.DEVICES:
		var app := _app()
		_busy_game(app)
		Layout.apply(app, device)
		var safe := Layout.safe_rect(device)
		for opener in openers:
			_press(app, opener)
			var window: Control = null
			for child in app.find_child("CityMap", true, false).get_parent().get_children():
				if String(child.name).begins_with("Window_"):
					window = child
			assert_true(window != null, "%s: Fenster für %s fehlt" % [device, opener])
			if window == null:
				continue
			var rect := Layout.rect_of(window)
			# Das Ortsfenster darf unten den Grundabstand mitnutzen (G4.5, eigener Test unten).
			var allowed := safe.grow_side(SIDE_BOTTOM, Layout.PADDING - 8.0) if window.name == "Window_location" else safe
			assert_true(_inside(allowed, rect), "%s: Fenster %s ragt heraus: %s" % [device, window.name, rect])
			if window.name != "Window_location":  # Ortsfenster: eigenes Maß (G4.5), Test unten
				assert_true(rect.size.x <= UiStyle.WINDOW_MAX_WIDTH + 0.5, "%s: Fenster zu breit" % device)
			assert_true(rect.size.y >= 300.0, "%s: Fenster zu niedrig" % device)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_menus_fit_every_device() -> void:
	for device in Layout.DEVICES:
		var safe := Layout.safe_rect(device)
		var app := _app()
		_press(app, "NewGameButton")
		_press(app, "MenuButton")  # Hauptmenü mit „Fortsetzen“ und Spielstand-Info – der normale Fall
		Layout.apply(app, device)
		var menu := app.find_child("NewGameButton", true, false).get_parent() as Control
		Layout.settle_labels(menu, UiStyle.COLUMN_WIDTH)
		var needed := menu.get_combined_minimum_size()
		assert_true(needed.y <= safe.size.y + 0.5, "%s: Hauptmenü braucht %d px, verfügbar %d" % [device, needed.y, safe.size.y])
		assert_true(needed.x <= safe.size.x + 0.5, "%s: Hauptmenü zu breit" % device)
		_press(app, "SettingsButton")
		var settings := app.find_child("DeleteSaveButton", true, false).get_parent() as Control
		Layout.settle_labels(settings, UiStyle.COLUMN_WIDTH)
		assert_true(settings.get_combined_minimum_size().y <= safe.size.y + 0.5, "%s: Einstellungen zu hoch" % device)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Ungünstigster Fall (lange Fehlermeldung + Spielstand-Info): Das Menü darf scrollen, aber nichts verlieren.
func test_menu_with_long_message_is_scrollable() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	_press(app, "MenuButton")
	app.show_main_menu("Der Spielstand konnte nicht geladen werden: lange Fehlermeldung mit vielen Details.\nDie defekte Datei wurde aufbewahrt. Mit „Neues Spiel“ kannst du neu beginnen.")
	var menu := app.find_child("NewGameButton", true, false).get_parent() as Control
	var scroll := app.find_child("MenuScroll", true, false) as ScrollContainer
	assert_true(scroll != null and scroll.is_ancestor_of(menu), "Menü liegt nicht im Scrollbereich")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## G4.4: Jeder runde Button hat eine Tippfläche von mindestens 84 px (≈ 44 pt) und einen 64-px-Kreis;
## rechts zwei Spalten (Leben | Geschäft), links nur „Hier“ – auf allen Geräteklassen.
func test_round_buttons_have_touch_size_and_sit_right() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _busy_game(app)
		Layout.apply(app, device)
		Layout.sort_containers(screen)
		var safe := Layout.safe_rect(device)
		var life := Layout.rect_of(app.find_child("LifeGroup", true, false) as Control)
		var business := Layout.rect_of(app.find_child("BusinessGroup", true, false) as Control)
		assert_true(life.end.x <= business.position.x + 0.5, "%s: Leben nicht links von Geschäft" % device)
		assert_true(business.end.x >= safe.end.x - 0.5, "%s: Geschäft nicht am rechten Rand" % device)
		for node_name in ["AppointmentsButton", "ObligationsButton", "ChannelButton", "CompanyButton", "LedgerButton",
				"MenuButton", "HereButton"]:
			var button := app.find_child(node_name, true, false) as Control
			var rect := Layout.screen_rect(button, screen)
			assert_true(rect.size.x >= UiStyle.TOUCH_SIZE - 0.5 and rect.size.y >= UiStyle.TOUCH_SIZE - 0.5,
					"%s: Tippfläche %s zu klein: %s" % [device, node_name, rect.size])
			assert_true(_inside(safe, rect), "%s: %s ragt aus der Safe Area" % [device, node_name])
			var circle := button.find_child("Circle", true, false) as Control
			var expected := UiStyle.MENU_ROUND_SIZE if node_name == "MenuButton" else UiStyle.ROUND_BUTTON_SIZE
			assert_eq(circle.size, Vector2(expected, expected), "%s: Kreis %s" % [device, node_name])
		var here := Layout.rect_of(app.find_child("HereButton", true, false) as Control)
		assert_true(here.end.x < safe.position.x + safe.size.x / 2.0, "%s: „Hier“ nicht links" % device)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## G4.4: Kurze Hinweise lassen Tipps auf die Karte durch, lange muss man antippen.
func test_short_hint_lets_taps_through() -> void:
	var app := _app()
	var screen := _busy_game(app)
	var toast := app.find_child("Toast", true, false) as Control
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_STOP)  # langer Hinweis aus _busy_game
	screen.call("show_message", "Kurz.")
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## G4.5: Jedes Ortsfenster zeigt alle Kacheln ohne Scrollen, 3–4 Spalten, liegt in der Safe Area, unter der
## HUD-Leiste und neben den Button-Spalten; alle Start-Buttons einer Reihe auf einer Höhe; Tippflächen ≥ 74 px.
## Ungünstige Lage: Unternehmen gegründet, für jeden Ort einmal „hier“ (Studio) und einmal „woanders“.
func test_location_windows_fit_without_scrolling() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _busy_game(app)
		var game = app.get("game")
		# 12:40: längere Aktionen ließen den Termin um 14:00 verpassen → Hinweiszeilen mit Konflikt prüfen.
		game.time.advance(TimeSystemScript.at(1, 12, 40) - game.time.get_minutes())
		for location_id in game.locations.get_catalog().get_ids():
			_press(app, "MapPin_%s" % location_id)
			Layout.apply(app, device)
			var window := screen.find_child("Window_location", false, false) as Control
			assert_true(window != null, "%s: Ortsfenster %s fehlt" % [device, location_id])
			if window == null:
				continue
			var content := window.find_child("LocationWindowContent", true, false) as Control
			var scroll := window.find_child("WindowScroll", true, false) as ScrollContainer
			Layout.settle_in_place(window)
			var safe := Layout.safe_rect(device)
			# Unten darf das Ortsfenster den Grundabstand (24 px) mitnutzen, nicht aber den Bereich des Geräts.
			var device_safe := safe.grow_side(SIDE_BOTTOM, Layout.PADDING - 8.0)
			var rect := Layout.rect_of(window)
			var tag := "%s / %s" % [device, location_id]
			assert_true(_inside(device_safe, rect), "%s: Fenster ragt heraus: %s" % [tag, rect])
			var hud := Layout.rect_of(app.find_child("HudBar", true, false) as Control)
			assert_true(rect.position.y >= hud.end.y, "%s: Fenster verdeckt die HUD-Leiste" % tag)
			# G4.7 (Entscheidung 049): volle Breite der Safe Area – die Button-Spalten liegen abgedunkelt darunter.
			assert_true(absf(rect.size.x - safe.size.x) < 0.5, "%s: Fenster nicht volle Breite" % tag)
			var columns: int = content.call("get_columns")
			assert_true(columns >= 3 and columns <= 4, "%s: %d Spalten" % [tag, columns])
			var needed := content.get_combined_minimum_size().y
			# G4.6: keine Ausnahmen mehr – wo nötig, zeigt das Fenster Reiter; dann muss jeder Reiter passen.
			assert_true(needed <= scroll.size.y + 0.5, "%s: braucht %d px, sichtbar %d – müsste scrollen" % [tag,
					needed, scroll.size.y])
			if content.call("has_tabs"):
				for tab_button in window.find_child("LocationTabs", true, false).get_children():
					(tab_button as Button).pressed.emit()
					Layout.settle_in_place(window)
					var tab_needed := content.get_combined_minimum_size().y
					assert_true(tab_needed <= scroll.size.y + 0.5, "%s / %s: braucht %d px, sichtbar %d" % [tag,
							tab_button.name, tab_needed, scroll.size.y])
				(window.find_child("LocationTabs", true, false).get_child(0) as Button).pressed.emit()
			# Tippflächen, Schrift und Abschneiden aller Texte prüft test_touch_and_fonts.gd (G4.7) – für alle Fenster.
			var tops := {}
			for tile in content.find_child("TileGrid", true, false).get_children():
				var tile_control := tile as Control
				if not tile_control.visible:
					continue  # Kachel eines anderen Reiters
				var row := roundi(tile_control.position.y)
				var bottom := tile_control.position.y + tile_control.size.y
				if tops.has(row):
					assert_true(absf(tops[row] - bottom) < 0.5, "%s: Kacheln einer Reihe unterschiedlich hoch" % tag)
				tops[row] = bottom
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Reiter im Ortsfenster (G4.6) --------------------------------------------------------

const GameScreenScript := preload("res://scripts/ui/game_screen.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TEST_TABS := {"alltag": 6, "content": 5, "geschaeft": 4}


## Echte Daten plus ein Test-Ort „Testmarkt“ mit vielen Aktivitäten in drei Reitern – nur hier, nicht in data/.
func _data_with_test_market():
	var data := Helpers.game_data()
	var locations: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/locations/locations.json"))
	locations.append({"id": "test_market", "display_name": "Testmarkt", "description": "Nur für Tests.",
			"map_position": [0.4, 0.55]})
	assert_true(data.locations.load_data(locations), "; ".join(data.locations.errors))
	var activities: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/activities/activities.json"))
	for tab in TEST_TABS:
		for i in TEST_TABS[tab]:
			activities.append({"id": "test_%s_%d" % [tab, i], "display_name": "Probe %d" % (i + 1), "tab": tab,
					"location": "test_market", "duration_minutes": 30, "effects": {"energy": -5, "mood": 2}})
	assert_true(data.activities.load_data(activities), "; ".join(data.activities.errors))
	assert_true(data.check_references().is_empty(), "; ".join(data.check_references()))
	return data


func _screen_on(device: String, data) -> Control:
	var screen := GameScreenScript.new()
	screen.call("setup", GameStateScript.new(data, Helpers.TEST_SEED))
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var margins: Array[float] = []
	for value in Layout.DEVICES[device]["margins"]:
		margins.append(float(value))
	screen.size = Layout.DEVICES[device]["size"]
	screen.call("set_safe_margins", margins)
	return screen


func _visible_tile_ids(content: Control) -> PackedStringArray:
	var ids := PackedStringArray()
	for tile in content.find_child("TileGrid", true, false).get_children():
		if (tile as Control).visible:
			ids.append(String(tile.name).trim_prefix("Tile_"))
	return ids


func test_many_activities_get_tabs_that_fit() -> void:
	var data = _data_with_test_market()
	for device in Layout.DEVICES:
		var screen := _screen_on(device, data)
		_press(screen, "MapPin_test_market")
		var window := screen.find_child("Window_location", false, false) as Control
		var content := window.find_child("LocationWindowContent", true, false) as Control
		var scroll := window.find_child("WindowScroll", true, false) as ScrollContainer
		Layout.settle_in_place(window)
		assert_eq(content.call("has_tabs"), true, "%s: keine Reiter" % device)
		var bar := window.find_child("LocationTabs", true, false) as Control
		var names := PackedStringArray()
		for button in bar.get_children():
			names.append(String(button.name))
		# Feste Reihenfolge, leere Reiter (Unterwelt) fehlen; geöffnet wird der erste.
		assert_eq(names, PackedStringArray(["LocationTab_alltag", "LocationTab_content", "LocationTab_geschaeft"]))
		assert_eq(content.call("get_current_tab"), "alltag")
		var rect := Layout.rect_of(window)
		assert_true(_inside(Layout.safe_rect(device).grow_side(SIDE_BOTTOM, Layout.PADDING - 8.0), rect),
				"%s: Fenster ragt heraus: %s" % [device, rect])
		for tab in TEST_TABS:
			_press(screen, "LocationTab_%s" % tab)
			Layout.settle_in_place(window)
			var ids := _visible_tile_ids(content)
			assert_eq(ids.size(), TEST_TABS[tab], "%s / %s: %s" % [device, tab, ids])
			for id in ids:
				assert_true(id.begins_with("test_%s_" % tab), "%s / %s: falsche Kachel %s" % [device, tab, id])
			var needed := content.get_combined_minimum_size().y
			assert_true(needed <= scroll.size.y + 0.5, "%s / %s: braucht %d px, sichtbar %d" % [device, tab, needed,
					scroll.size.y])
			var tab_button := screen.find_child("LocationTab_%s" % tab, true, false) as Button
			assert_true(tab_button.size.y >= UiStyle.TOUCH_SIZE - 0.5, "%s: Reiter-Tippfläche %d px" % [device,
					tab_button.size.y])
			assert_true(tab_button.get_theme_font_size("font_size") >= UiStyle.MIN_READ_FONT_SIZE, device)
			# Aktiver Reiter klar erkennbar: Akzentfarbe, die anderen nicht.
			for other in TEST_TABS:
				var box := (screen.find_child("LocationTab_%s" % other, true, false) as Button) \
						.get_theme_stylebox("normal") as StyleBoxFlat
				assert_eq(box.bg_color == UiStyle.ACCENT, other == tab, "%s: aktiver Reiter %s" % [device, other])
		screen.free()


func test_location_reopens_on_first_tab() -> void:
	var data = _data_with_test_market()
	var screen := _screen_on("iPhone 15/16 Pro Max (Dynamic Island)", data)
	_press(screen, "MapPin_test_market")
	_press(screen, "LocationTab_geschaeft")
	_press(screen, "WindowCloseButton")
	_press(screen, "MapPin_test_market")
	var content := screen.find_child("LocationWindowContent", true, false)
	assert_eq(content.call("get_current_tab"), "alltag")
	screen.free()


func test_locations_that_fit_show_no_tabs() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		_busy_game(app)
		for location_id in ["home", "cafe_harbor", "gym", "office", "label_store"]:
			_press(app, "MapPin_%s" % location_id)
			Layout.apply(app, device)
			var window := app.find_child("Window_location", true, false) as Control
			var content := window.find_child("LocationWindowContent", true, false)
			assert_eq(content.call("has_tabs"), false, "%s / %s: Reiter ohne Not" % [device, location_id])
			assert_eq((window.find_child("LocationTabs", true, false) as Control).visible, false)
		# Das Studio passt auf echten Geräten ohne Reiter, nur im „Grenzfall“ (3 Spalten) braucht es sie.
		_press(app, "MapPin_studio")
		Layout.apply(app, device)
		var studio := app.find_child("LocationWindowContent", true, false)
		assert_eq(studio.call("has_tabs"), device.begins_with("Grenzfall"), "%s / studio" % device)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## G4.6: Im Studio VOR ORT (Buttons frei, Hinweiszeilen sichtbar) um 12:40 mit Terminkonflikt – Kachel-Namen und
## Hinweise auf keiner Geräteklasse abgeschnitten, auch im aktiven Reiter des „Grenzfalls“.
func test_studio_on_site_texts_not_cut() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		_press(app, "NewGameButton")
		_press(app, "MapPin_studio")
		_press(app, "TravelButton")
		var game = app.get("game")
		game.time.advance(TimeSystemScript.at(1, 12, 40) - game.time.get_minutes())
		_press(app, "HereButton")
		Layout.apply(app, device)
		var window := app.find_child("Window_location", true, false) as Control
		Layout.settle_in_place(window)
		var checked := 0
		for node in window.find_children("*", "Label", true, false):
			var label := node as Label
			var name_text := String(label.name)
			if not label.is_visible_in_tree() or not (name_text.begins_with("TileTitle_") or name_text.begins_with("TileHint_")):
				continue
			checked += 1
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					label.get_theme_font_size("font_size")).x
			assert_true(width <= label.size.x + 0.5, "%s: „%s“ abgeschnitten (%d > %d px)" % [device, label.text, width,
					label.size.x])
		assert_true(checked >= 6, "%s: nur %d Texte geprüft" % [device, checked])
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
