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
		var names := ["HudBar", "LeftBar", "RightBar", "Toast"]
		var rects := {}
		for node_name in names:
			var control := app.find_child(node_name, true, false) as Control
			rects[node_name] = Layout.rect_of(control)
			assert_true(_inside(safe, rects[node_name]), "%s: %s ragt aus der Safe Area %s: %s" % [device, node_name,
					safe, rects[node_name]])
		for i in names.size():
			for j in range(i + 1, names.size()):
				assert_true(not rects[names[i]].intersects(rects[names[j]]), "%s: %s überlappt %s" % [device,
						names[i], names[j]])
		# G4.3: Die HUD-Leiste geht über die volle Breite der Safe Area, ist schmal, und ihr Inhalt passt hinein.
		var hud := app.find_child("HudBar", true, false) as Control
		assert_true(absf(rects["HudBar"].size.x - safe.size.x) < 0.5, "%s: HUD-Leiste nicht volle Breite" % device)
		assert_true(rects["HudBar"].size.y <= 64.0, "%s: HUD-Leiste zu hoch: %d" % [device, rects["HudBar"].size.y])
		assert_true(hud.get_combined_minimum_size().x <= rects["HudBar"].size.x + 0.5, "%s: HUD-Inhalt zu breit: %d" % [
				device, hud.get_combined_minimum_size().x])
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
			assert_true(_inside(safe, rect), "%s: Fenster %s ragt heraus: %s" % [device, window.name, rect])
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

