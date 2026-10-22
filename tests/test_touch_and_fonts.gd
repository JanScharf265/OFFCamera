extends "res://tests/base_test.gd"

## Ticket G4.7: Tippflächen und Mindestschrift in Spielansicht (Karte, HUD-Leiste, runde Buttons) und in JEDEM
## Fenster, auf allen 4 Geräteklassen aus 7.2. Tippfläche ≥ 84 px (≈ 44 pt); Lesetext ≥ 21 px (≈ 11 pt),
## Mini-Beschriftungen (Meta "mini_caption": unter runden Buttons, „Privat“, „LEBEN“ …) ≥ 19 px (≈ 10 pt);
## Beschriftungen werden nicht abgeschnitten.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_touch_fonts_save.json"
const WINDOW_OPENERS := ["AppointmentsButton", "ObligationsButton", "ChannelButton", "CompanyButton", "LedgerButton"]


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


## Spiel mit gegründeter Firma (alle Buttons sichtbar), Spielansicht zurück.
func _game(app: AppScript) -> Control:
	_press(app, "NewGameButton")
	_press(app, "MapPin_office")
	_press(app, "TravelButton")
	_press(app, "CompanyFoundButton_merch_label")
	_press(app, "WindowCloseButton")
	return app.find_child("CityMap", true, false).get_parent() as Control


## Prüft alles Sichtbare unter `root` (Koordinaten relativ zu `screen`); Probleme kommen in `problems`.
func _audit(root: Node, screen: Control, where: String, problems: PackedStringArray) -> void:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.is_visible_in_tree():
			continue
		if button.size.x < UiStyle.TOUCH_SIZE - 0.5 or button.size.y < UiStyle.TOUCH_SIZE - 0.5:
			problems.append("%s: Tippfläche %s %dx%d" % [where, button.name, button.size.x, button.size.y])
		if not button.text.is_empty() and button.get_theme_font_size("font_size") < UiStyle.MIN_READ_FONT_SIZE:
			problems.append("%s: Schrift %s „%s“ %d px" % [where, button.name, button.text,
					button.get_theme_font_size("font_size")])
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var mini: bool = label.get_meta("mini_caption", false)
		var minimum := UiStyle.MINI_FONT_SIZE if mini else UiStyle.MIN_READ_FONT_SIZE
		var font_size := label.get_theme_font_size("font_size")
		if font_size < minimum:
			problems.append("%s: Schrift „%s“ %d px (mind. %d)" % [where, label.text, font_size, minimum])
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size).x
			if width > label.size.x + 0.5:
				problems.append("%s: „%s“ abgeschnitten (%d > %d px)" % [where, label.text, width, label.size.x])


func _report(problems: PackedStringArray) -> void:
	assert_true(problems.is_empty(), "%d Probleme:\n            %s" % [problems.size(), "\n            ".join(problems)])


## G4.7: Die HUD-Leiste ist voll deckend – keine Kartenschilder scheinen durch.
func test_hud_bar_is_opaque() -> void:
	var app := _app()
	var screen := _game(app)
	var box := (screen.find_child("HudBar", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.bg_color.a, 1.0)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_game_screen_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _game(app)
		screen.call("show_message", "Kurz.")
		Layout.apply(app, device)
		Layout.settle_in_place(screen)
		_audit(screen, screen, device, problems)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


func test_every_window_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _game(app)
		# 12:40: längere Aktionen ließen den Termin um 14:00 verpassen → Hinweiszeilen mit Konflikt.
		app.game.time.advance(TimeSystemScript.at(1, 12, 40) - app.game.time.get_minutes())
		var openers: Array = WINDOW_OPENERS.duplicate()
		for id in app.game.locations.get_catalog().get_ids():
			openers.append("MapPin_%s" % id)
		for opener in openers:
			_press(app, opener)
			Layout.apply(app, device)
			var window: Control = null
			for child in screen.get_children():
				if String(child.name).begins_with("Window_"):
					window = child
			if window == null:
				problems.append("%s: kein Fenster für %s" % [device, opener])
				continue
			Layout.settle_in_place(window)
			_audit(window, screen, "%s / %s" % [device, window.name], problems)
			# Ortsfenster mit Reitern: jeden Reiter prüfen.
			var tabs := window.find_child("LocationTabs", true, false) as Control
			if tabs != null and tabs.visible:
				for tab_button in tabs.get_children():
					(tab_button as Button).pressed.emit()
					Layout.settle_in_place(window)
					_audit(window, screen, "%s / %s / %s" % [device, window.name, tab_button.name], problems)
		# Ereignis-Fenster (Tag 1, 20:00)
		app.game.time.advance(TimeSystemScript.at(1, 20) - app.game.time.get_minutes())
		screen.call("_refresh")
		Layout.apply(app, device)
		var event := screen.find_child("Window_event", false, false) as Control
		assert_true(event != null, "%s: kein Ereignis-Fenster" % device)
		if event != null:
			Layout.settle_in_place(event)
			_audit(event, screen, "%s / Window_event" % device, problems)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


## G5.1: Einstellungsseite mit den Geräte-Schaltern – Tippflächen, Schrift, nichts abgeschnitten.
func test_settings_screen_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		app.settings_path = "user://test_touch_fonts_settings.cfg"
		_press(app, "SettingsButton")
		Layout.apply(app, device)
		var page := app.find_child("SettingVibration", true, false).get_parent() as Control
		Layout.settle_in_place(page)
		assert_true(page.find_child("SettingCalendarAutoOpen", false, false) != null, "Schalter Kalender fehlt")
		_audit(page, page, "%s / Einstellungen" % device, problems)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


## G5.1b: Ladebildschirm (normal und mit Fehlermeldung) – Schrift, nichts abgeschnitten, alles in der Safe Area.
func test_loading_screen_layout() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		for broken in [false, true]:
			var screen := (load("res://scenes/boot/loading.tscn") as PackedScene).instantiate() as Control
			screen.set("animate", false)
			(Engine.get_main_loop() as SceneTree).root.add_child(screen)
			var margins: Array[float] = []
			for value in Layout.DEVICES[device]["margins"]:
				margins.append(float(value))
			screen.size = Layout.DEVICES[device]["size"]
			screen.call("set_safe_margins", margins)
			if broken:
				screen.set("app_scene_path", "res://gibt_es_nicht.tscn")
				screen.call("run_to_end", 3000)
			else:
				screen.call("advance")  # erster Schritt: Statustext steht
			Layout.settle_in_place(screen)
			var where := "%s / Ladebildschirm%s" % [device, " (Fehler)" if broken else ""]
			_audit(screen, screen, where, problems)
			var safe := Layout.safe_rect(device)
			for node in screen.find_children("*", "Label", false, false):
				var label := node as Label
				if label.visible and not label.text.is_empty() and not safe.grow(0.5).encloses(Layout.rect_of(label)):
					problems.append("%s: „%s“ außerhalb der Safe Area %s" % [where, label.text, Layout.rect_of(label)])
			screen.free()
	_report(problems)


## G5.4: Konflikt-Popup – Tippflächen, Schrift, nichts abgeschnitten, Panel in der Safe Area.
func test_conflict_popup_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _game(app)  # im Büro, Firma gegründet
		app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
		_press(app, "HereButton")
		_press(app, "StartButton_plan_week")
		var popup := screen.find_child("ConflictPopup", false, false) as Control
		if popup == null:
			_press(app, "WindowCloseButton")
			problems.append("%s: kein Popup" % device)
			app.free()
			continue
		Layout.apply(app, device)
		Layout.settle_in_place(popup)
		_audit(popup, screen, "%s / Konflikt-Popup" % device, problems)
		var panel := Layout.rect_of(popup.find_child("PopupPanel", false, false) as Control)
		if not Layout.safe_rect(device).grow(0.5).encloses(panel):
			problems.append("%s: Popup ragt aus der Safe Area: %s" % [device, panel])
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


## G5.5: Um 12:40 – Kalender aus der Ferne mit gesperrtem „Warten bis 14:00“ und Grund, dann im Studio Kalender und
## Ortsfenster mit freiem „Warten bis 14:00“: Tippflächen, Schrift, Button-Texte passen, Fenster in der Safe Area.
func test_wait_buttons_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		_press(app, "NewGameButton")
		var screen := app.find_child("CityMap", true, false).get_parent() as Control
		app.game.time.advance(TimeSystemScript.at(1, 12, 40) - app.game.time.get_minutes())
		for step in [["AppointmentsButton", "WaitButton_camera_meeting", true], ["MapPin_studio", "", false],
				["TravelButton", "", false], ["MapPin_studio", "WaitButton", false],
				["AppointmentsButton", "WaitButton_camera_meeting", false]]:
			_press(app, step[0])
			if step[1].is_empty():
				continue
			Layout.apply(app, device)
			var window: Control = null
			for child in screen.get_children():
				if String(child.name).begins_with("Window_"):
					window = child
			Layout.settle_in_place(window)
			var where := "%s / %s / %s" % [device, window.name, step[1]]
			_audit(window, screen, where, problems)
			var wait := window.find_child(step[1], true, false) as Button
			if wait == null or not wait.is_visible_in_tree() or wait.disabled != step[2]:
				problems.append("%s: Warten-Button fehlt oder falscher Zustand" % where)
				continue
			var text_width := wait.get_theme_font("font").get_string_size(wait.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					wait.get_theme_font_size("font_size")).x
			if text_width > wait.size.x + 0.5:
				problems.append("%s: „%s“ abgeschnitten" % [where, wait.text])
			if not Layout.safe_rect(device).grow_side(SIDE_BOTTOM, Layout.PADDING - 8.0).grow(0.5) \
					.encloses(Layout.rect_of(window)):
				problems.append("%s: Fenster ragt aus der Safe Area: %s" % [where, Layout.rect_of(window)])
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


## G5.6: Erinnerungsfenster – zu Hause (Hinfahren, „zu spät“) und im Studio (Warten): Tippflächen, Schrift, nichts
## abgeschnitten (auch Button-Texte), kleines Fenster ganz in der Safe Area.
func test_reminder_window_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		for on_site in [false, true]:
			var app := _app()
			_press(app, "NewGameButton")
			var screen := app.find_child("CityMap", true, false).get_parent() as Control
			if on_site:
				app.game.locations.travel("studio")
			app.game.time.advance(TimeSystemScript.at(1, 13, 45) - app.game.time.get_minutes())
			screen.call("_refresh")
			Layout.apply(app, device)
			var window := screen.find_child("Window_reminder", false, false) as Control
			var where := "%s / Erinnerung %s" % [device, "Studio" if on_site else "Wohnung"]
			if window == null:
				problems.append("%s: kein Fenster" % where)
				app.free()
				continue
			Layout.settle_in_place(window)
			_audit(window, screen, where, problems)
			for node in window.find_children("*", "Button", true, false):
				var button := node as Button
				if button.text.is_empty() or not button.is_visible_in_tree():
					continue
				var width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						button.get_theme_font_size("font_size")).x
				if width > button.size.x + 0.5:
					problems.append("%s: „%s“ abgeschnitten" % [where, button.text])
			for node in window.find_children("*", "Label", true, false):
				var label := node as Label
				if label.is_visible_in_tree() and label.autowrap_mode != TextServer.AUTOWRAP_OFF \
						and label.get_line_count() > label.get_visible_line_count():
					problems.append("%s: „%s“ nicht ganz sichtbar" % [where, label.text])
			if not Layout.safe_rect(device).grow(0.5).encloses(Layout.rect_of(window)):
				problems.append("%s: Fenster ragt aus der Safe Area: %s" % [where, Layout.rect_of(window)])
			var scroll := window.find_child("WindowScroll", true, false) as ScrollContainer
			var content := window.find_child("ReminderContent", true, false) as Control
			if content.get_combined_minimum_size().y > scroll.size.y + 0.5:
				problems.append("%s: Inhalt braucht %d px, sichtbar %d" % [where, content.get_combined_minimum_size().y,
						scroll.size.y])
			app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)


## G5.7: Studio-Fenster von der Wohnung aus um 10:00 – Kombi-Kacheln („Hinfahren und starten“ mit Auto), Sperrgründe
## und „Hinfahren“ mit Auto: Tippflächen, Schrift, Zeitzeilen und Button-Texte nicht abgeschnitten (Button-Text in
## einer Zeile samt Symbol), auch in jedem Reiter des „Grenzfalls“.
func test_trip_tiles_touch_and_fonts() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		var app := _app()
		_press(app, "NewGameButton")
		var screen := app.find_child("CityMap", true, false).get_parent() as Control
		app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
		_press(app, "MapPin_studio")
		Layout.apply(app, device)
		var window := screen.find_child("Window_location", false, false) as Control
		var pages: Array = [null]
		var tabs := window.find_child("LocationTabs", true, false) as Control
		if tabs != null and tabs.visible:
			pages = tabs.get_children()
		for page in pages:
			if page != null:
				(page as Button).pressed.emit()
			Layout.settle_in_place(window)
			var where := "%s%s" % [device, "" if page == null else " / %s" % page.name]
			_audit(window, screen, where, problems)
			for node in window.find_children("*", "Button", true, false):
				var button := node as Button
				if button.text.is_empty() or not button.is_visible_in_tree():
					continue
				var font := button.get_theme_font("font")
				var font_size := button.get_theme_font_size("font_size")
				var needed := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if button.icon != null:
					needed += button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
				var box := button.get_theme_stylebox("normal")
				var room := button.size.x - box.get_content_margin(SIDE_LEFT) - box.get_content_margin(SIDE_RIGHT)
				if not button.disabled and needed > room + 0.5:
					problems.append("%s: „%s“ passt nicht in eine Zeile (%d > %d px)" % [where, button.text, needed, room])
		var travel := window.find_child("TravelButton", true, false) as Button
		if travel == null or not travel.is_visible_in_tree() or travel.icon == null:
			problems.append("%s: „Hinfahren“ ohne Auto" % device)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_report(problems)
