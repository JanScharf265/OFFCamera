extends "res://tests/base_test.gd"

## Ticket U.12: Gebiete als Daten (DistrictCatalog) und Unterwelt-Ansicht der Karte (Variante B, GD 080): Schalter
## erst nach El Capitán, Wechsel kostet keine Spielzeit und ändert keinen Spielwert, Gebiete nur in der
## Unterwelt-Ansicht, Streamer-Orte weiter antippbar, Ansicht in den Geräte-Einstellungen gespeichert; Layout auf
## iPhone 13/14 und 15/16 Pro Max.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const Layout := preload("res://tests/layout_helper.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")
const DistrictCatalogScript := preload("res://scripts/systems/district_catalog.gd")

const SAVE_PATH := "user://test_view_save.json"
const SETTINGS_PATH := "user://test_view_settings.cfg"


func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	_screen(app).set("show_tutorials", false)
	return app


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent()


func _cleanup(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func test_real_districts_load() -> void:
	var catalog := DistrictCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_all().map(func(d) -> String: return d.id),
			["san_pedro", "altstadt", "nueva_andalucia", "puerto_banus"])
	assert_eq(catalog.get_at(Vector2i(1, 6)).id, "san_pedro", "Garage liegt in San Pedro")
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_districts_are_rejected() -> void:
	var good := {"id": "a", "display_name": "A", "description": "D.", "area": [0, 0, 1, 1], "label_cell": [0, 0],
			"color": "#ff0000",
			"demand": 1, "police": 1, "rivals": 1}
	var catalog := DistrictCatalogScript.new()
	assert_true(catalog.load_data([good]), "; ".join(catalog.errors))
	for change in [{"label_cell": [5, 5]}, {"label_cell": [0]}, {"area": [0, 0, 20, 1]}, {"area": [2, 0, 1, 1]}, {"area": [0, 0]}, {"color": "nope"},
			{"demand": 101}, {"police": -1}, {"extra": 1}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(catalog.load_data([bad]), false, "angenommen: %s" % change)
	var overlap := good.duplicate()
	overlap["id"] = "b"
	overlap["area"] = [1, 1, 2, 2]
	overlap["label_cell"] = [2, 2]
	assert_eq(catalog.load_data([good, overlap]), false, "Überschneidung")


func test_toggle_only_after_el_capitan() -> void:
	var app := _app()
	var screen := _screen(app)
	assert_eq((app.find_child("ViewToggleButton", true, false) as Control).visible, false, "Schalter vor El Capitán")
	screen.call("on_organisation_name_submitted", "Los Lobos")
	assert_eq((app.find_child("ViewToggleButton", true, false) as Control).visible, true)
	assert_eq((app.find_child("ViewToggleButtonDay", true, false) as Control).visible, false)
	_cleanup(app)


func test_toggle_is_only_optics_and_is_remembered() -> void:
	var app := _app()
	var screen := _screen(app)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	var map := app.find_child("CityMap", true, false)
	var before: Dictionary = app.game.to_dict()
	(app.find_child("ViewToggleButton", true, false) as Button).pressed.emit()
	assert_eq(map.call("is_underworld_view"), true)
	var after: Dictionary = app.game.to_dict()
	# Nur die Tutorial-Buchführung (Auslöser „Unterwelt-Ansicht gesehen“) darf sich ändern.
	before.erase("tutorials")
	after.erase("tutorials")
	assert_eq(after, before, "Wechsel ändert keinen Spielwert und keine Spielzeit")
	assert_eq(SettingsScript.load_from(SETTINGS_PATH).get_flag(SettingsScript.UNDERWORLD_VIEW), true, "gespeichert")
	assert_eq((app.find_child("DistrictLabel_puerto_banus", true, false) as Control).visible, true)
	# Streamer-Orte bleiben antippbar
	(app.find_child("MapPin_studio", true, false) as Button).pressed.emit()
	assert_eq(screen.get("_window_kind"), "location", "Studio lässt sich in der Unterwelt-Ansicht öffnen")
	screen.call("_close_window")
	(app.find_child("ViewToggleButtonDay", true, false) as Button).pressed.emit()
	assert_eq(map.call("is_underworld_view"), false)
	assert_eq((app.find_child("DistrictLabel_puerto_banus", true, false) as Control).visible, false, "Gebiete nur nachts")
	assert_eq(SettingsScript.load_from(SETTINGS_PATH).get_flag(SettingsScript.UNDERWORLD_VIEW), false)
	_cleanup(app)


func test_view_restored_from_settings() -> void:
	var settings = SettingsScript.load_from(SETTINGS_PATH)
	assert_eq(settings.set_flag(SettingsScript.UNDERWORLD_VIEW, true), "")
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var map := app.find_child("CityMap", true, false)
	assert_eq(map.call("is_underworld_view"), false, "vor El Capitán immer Tag")
	_screen(app).call("on_organisation_name_submitted", "Los Lobos")
	assert_eq(map.call("is_underworld_view"), true, "gespeicherte Ansicht")
	_cleanup(app)


## Seit U.13 öffnet der Tipp das Fenster des Gebiets.
func test_district_tap_shows_values() -> void:
	var app := _app()
	var screen := _screen(app)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	screen.call("set_underworld_view", true)
	(app.find_child("DistrictLabel_puerto_banus", true, false) as Button).pressed.emit()
	assert_eq(screen.get("_window_kind"), "district")
	assert_eq((app.find_child("DistrictValues", true, false) as Label).text, "Nachfrage 80 · Polizei 60 · Rivalen 50")
	_cleanup(app)


func test_underworld_locations_highlighted() -> void:
	var game := Helpers.new_game()
	assert_eq(game.underworld_location_ids(), PackedStringArray())
	game.organisation.found("Los Lobos")
	var data := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash"]:
		data["completed"][id] = 0
	data["active"] = []
	assert_eq(game.missions.restore(data), "")
	assert_eq(game.underworld_location_ids(), PackedStringArray(["garage", "cafe_harbor"]))


func test_toggle_fits_every_device() -> void:
	for device in Layout.DEVICES:
		var app := _app()
		var screen := _screen(app)
		screen.call("on_organisation_name_submitted", "Los Lobos")
		Layout.apply(app, device)
		Layout.sort_containers(screen)
		var safe := Layout.safe_rect(device)
		var toggle := Layout.screen_rect(app.find_child("ViewToggleButton", true, false) as Control, screen)
		assert_true(toggle.size.x >= UiStyle.TOUCH_SIZE - 0.5 and toggle.size.y >= UiStyle.TOUCH_SIZE - 0.5,
				"%s: Tippfläche %s" % [device, toggle.size])
		assert_true(safe.grow(0.5).encloses(toggle), "%s: Schalter außerhalb der Safe Area" % device)
		assert_true(toggle.position.x > safe.position.x + safe.size.x / 2.0, "%s: Schalter nicht rechts" % device)
		for group in ["LifeGroup", "BusinessGroup"]:
			var rect := Layout.screen_rect(app.find_child(group, true, false) as Control, screen)
			assert_true(not rect.intersects(toggle), "%s: Schalter überdeckt %s" % [device, group])
		screen.call("show_message", "Eine lange Rückmeldung, die über mehrere Zeilen geht und nicht unter dem Schalter liegen darf, damit man ihn immer antippen kann.")
		screen.call("_layout")
		var toast := Layout.screen_rect(app.find_child("Toast", true, false) as Control, screen)
		assert_true(not toast.intersects(toggle), "%s: Rückmeldung überdeckt den Schalter" % device)
		_cleanup(app)
