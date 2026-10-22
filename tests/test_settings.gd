extends "res://tests/base_test.gd"

## Ticket G5.1: Geräte-Einstellungen in user://…/settings.cfg – Standardwerte, Speichern/Laden, kaputte und
## fehlende Datei, unbekannte Schlüssel, Schalter in der Einstellungsseite, „Spielstand löschen“ lässt sie stehen.

const SettingsScript := preload("res://scripts/core/settings.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const Helpers := preload("res://tests/helpers.gd")

const PATH := "user://test_settings.cfg"
const SAVE_PATH := "user://test_settings_save.json"


func _remove() -> void:
	for p in [PATH, PATH + SettingsScript.TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_defaults_are_on() -> void:
	_remove()
	var settings = SettingsScript.load_from(PATH)
	assert_eq(settings.get_flag(SettingsScript.CALENDAR_AUTO_OPEN), true)
	assert_eq(settings.get_flag(SettingsScript.VIBRATION), true)
	assert_eq(settings.load_problem, "")
	assert_eq(FileAccess.file_exists(PATH), false, "Laden allein schreibt nichts")


func test_save_and_load() -> void:
	_remove()
	var settings = SettingsScript.load_from(PATH)
	assert_eq(settings.set_flag(SettingsScript.VIBRATION, false), "")
	assert_eq(FileAccess.file_exists(PATH + SettingsScript.TMP_SUFFIX), false)
	var again = SettingsScript.load_from(PATH)
	assert_eq(again.get_flag(SettingsScript.VIBRATION), false)
	assert_eq(again.get_flag(SettingsScript.CALENDAR_AUTO_OPEN), true)
	assert_true(not settings.set_flag("gibt_es_nicht", true).is_empty(), "unbekannter Schlüssel angenommen")
	_remove()


func test_broken_file_gives_defaults_and_is_replaced_on_save() -> void:
	_remove()
	_write("[device\nvibration = kaputt ((((")
	var settings = SettingsScript.load_from(PATH)
	assert_eq(settings.get_flag(SettingsScript.VIBRATION), true)
	assert_true(not settings.load_problem.is_empty(), "Problem nicht gemeldet")
	assert_eq(FileAccess.get_file_as_string(PATH), "[device\nvibration = kaputt ((((", "kaputte Datei angefasst")
	assert_eq(settings.set_flag(SettingsScript.CALENDAR_AUTO_OPEN, false), "")
	var again = SettingsScript.load_from(PATH)
	assert_eq(again.load_problem, "")
	assert_eq(again.get_flag(SettingsScript.CALENDAR_AUTO_OPEN), false)
	_remove()


func test_unknown_keys_and_wrong_types_are_ignored() -> void:
	_remove()
	_write("[device]\nvibration=false\ncalendar_auto_open=\"ja\"\nunbekannt=42\n[anderes]\nx=1\n")
	var settings = SettingsScript.load_from(PATH)
	assert_eq(settings.load_problem, "")
	assert_eq(settings.get_flag(SettingsScript.VIBRATION), false)
	assert_eq(settings.get_flag(SettingsScript.CALENDAR_AUTO_OPEN), true, "falscher Typ → Standardwert")
	_remove()


func _app() -> AppScript:
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func test_toggles_in_settings_screen_change_values() -> void:
	_remove()
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := _app()
	(app.find_child("SettingsButton", true, false) as Button).pressed.emit()
	var calendar := app.find_child("SettingCalendarAutoOpen", true, false) as CheckButton
	var vibration := app.find_child("SettingVibration", true, false) as CheckButton
	assert_true(calendar != null and vibration != null, "Schalter fehlen")
	if calendar == null or vibration == null:
		app.free()
		return
	assert_eq(calendar.button_pressed, true)
	assert_eq(vibration.button_pressed, true)
	vibration.button_pressed = false  # wie ein Tipp: löst toggled aus
	assert_eq(app.settings.get_flag(SettingsScript.VIBRATION), false)
	assert_eq(SettingsScript.load_from(PATH).get_flag(SettingsScript.VIBRATION), false, "nicht gespeichert")
	app.free()
	# Neustart: Wert bleibt
	var restarted := _app()
	(restarted.find_child("SettingsButton", true, false) as Button).pressed.emit()
	assert_eq((restarted.find_child("SettingVibration", true, false) as CheckButton).button_pressed, false)
	restarted.free()
	_remove()


func test_deleting_the_save_keeps_device_settings() -> void:
	_remove()
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := _app()
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	app.settings.set_flag(SettingsScript.CALENDAR_AUTO_OPEN, false)
	(app.find_child("MenuButton", true, false) as Button).pressed.emit()
	(app.find_child("SettingsButton", true, false) as Button).pressed.emit()
	(app.find_child("DeleteSaveButton", true, false) as Button).pressed.emit()
	(app.find_child("DeleteSaveButton", true, false) as Button).pressed.emit()
	assert_eq(SaveSystemScript.has_save(SAVE_PATH), false)
	assert_eq(SettingsScript.load_from(PATH).get_flag(SettingsScript.CALENDAR_AUTO_OPEN), false)
	assert_eq((app.find_child("SettingCalendarAutoOpen", true, false) as CheckButton).button_pressed, false)
	app.free()
	_remove()
