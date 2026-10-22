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
