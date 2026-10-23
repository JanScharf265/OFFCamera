extends "res://tests/base_test.gd"

## GD 086: Im Ereignisfenster sind alle Antwort-Buttons ohne Scrollen sichtbar – für jedes Ereignis aus den Daten,
## auf iPhone 13/14 und 15/16 Pro Max; Tippfläche mindestens 84 px.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const Layout := preload("res://tests/layout_helper.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const SAVE_PATH := "user://test_event_layout_save.json"


func test_all_event_buttons_visible_without_scrolling() -> void:
	var problems := PackedStringArray()
	for device in Layout.DEVICES:
		SaveSystemScript.delete_save(SAVE_PATH)
		var app := AppScript.new()
		app.save_path = SAVE_PATH
		app.new_game_seed = Helpers.TEST_SEED
		(Engine.get_main_loop() as SceneTree).root.add_child(app)
		(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
		var screen := app.find_child("CityMap", true, false).get_parent() as Control
		screen.set("show_tutorials", false)
		Layout.apply(app, device)
		for definition in app.game.data.events.get_all():
			# Ereignis direkt öffnen (ohne Auslöser) – nur Darstellung
			app.game.events.call("_trigger", definition.id)
			screen.call("_refresh")
			var window := screen.find_child("Window_event", false, false) as Control
			if window == null:
				problems.append("%s / %s: kein Fenster" % [definition.id, device])
				continue
			Layout.settle_in_place(window)
			screen.call("_layout")
			Layout.settle_in_place(window)
			var scroll := window.find_child("WindowScroll", true, false) as Control
			var visible := Layout.screen_rect(scroll, screen)
			for option in definition.options:
				var button := window.find_child("EventOption_%s" % option.id, true, false) as Control
				var rect := Layout.screen_rect(button, screen)
				if rect.end.y > visible.end.y + 0.5 or rect.position.y < visible.position.y - 0.5:
					problems.append("%s / %s: „%s“ unter dem sichtbaren Bereich (%s, sichtbar bis %.0f)" % [
							definition.id, device, option.label, rect, visible.end.y])
				if rect.size.y < UiStyle.TOUCH_SIZE - 0.5:
					problems.append("%s / %s: „%s“ zu niedrig (%.0f px)" % [definition.id, device, option.label, rect.size.y])
			var events_data: Dictionary = app.game.events.to_dict()
			events_data["pending"] = []
			app.game.events.restore(events_data)
			screen.call("_close_window")
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	assert_true(problems.is_empty(), "%d Probleme:\n%s" % [problems.size(), "\n".join(problems)])
