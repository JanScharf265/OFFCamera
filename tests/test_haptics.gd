extends "res://tests/base_test.gd"

## Ticket G5.9: Vibration – Schalter aus → nie; Geld ab 100 € (99 € nein); Konflikt, Erinnerung, Ereignis lösen aus;
## mehrere Auslöser einer Aktion → einmal; Laden vibriert nicht. Ohne Gerät geprüft über Zähler und Gründe
## (am Mac und hier ist nichts zu spüren – Wirkung nur auf dem iPhone).

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const HapticsScript := preload("res://scripts/core/haptics.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

const SAVE_PATH := "user://test_haptics_save.json"
const SETTINGS_PATH := "user://test_haptics_settings.cfg"


func _remove_settings() -> void:
	for p in [SETTINGS_PATH, SETTINGS_PATH + SettingsScript.TMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Dienst mit Test-Uhr (clock["now"]) und stiller Ausgabe; zählt die Ausgaben in outputs.
func _haptics(settings, clock: Dictionary, outputs: Array) -> HapticsScript:
	var haptics := HapticsScript.new(settings)
	haptics.clock = func() -> int: return clock["now"]
	haptics.output = func(duration: int) -> void: outputs.append(duration)
	return haptics


func test_switch_off_never_vibrates() -> void:
	_remove_settings()
	var settings = SettingsScript.load_from(SETTINGS_PATH)
	var clock := {"now": 0}
	var outputs := []
	var haptics := _haptics(settings, clock, outputs)
	assert_eq(haptics.warn(HapticsScript.REASON_EVENT), true, "Standard: an")
	settings.set_flag(SettingsScript.VIBRATION, false)
	for reason in [HapticsScript.REASON_CONFLICT, HapticsScript.REASON_MONEY, HapticsScript.REASON_REMINDER]:
		clock["now"] += 10000
		assert_eq(haptics.warn(reason), false, reason)
	var game := Helpers.new_game()
	haptics.attach(game)
	clock["now"] += 10000
	game.ledger.post(-30000, "test", "Groß", "test")
	assert_eq(haptics.count, 1, "nur die erste (Schalter noch an)")
	assert_eq(outputs, [HapticsScript.DURATION_MSEC])
	assert_true(HapticsScript.DURATION_MSEC >= 40 and HapticsScript.DURATION_MSEC <= 80)
	_remove_settings()


func test_money_threshold() -> void:
	var clock := {"now": 0}
	var outputs := []
	var haptics := _haptics(null, clock, outputs)
	var game := Helpers.new_game()
	haptics.attach(game)
	game.ledger.post(-9999, "test", "99,99 €", "test")
	assert_eq(haptics.count, 0, "99,99 € nicht")
	clock["now"] += 10000
	game.ledger.post(-10000, "test", "100 €", "test")
	assert_eq(haptics.count, 1, "100 € Ausgabe")
	clock["now"] += 10000
	game.ledger.post(10000, "test", "100 € Einnahme", "test")
	assert_eq(haptics.count, 2, "100 € Einnahme")
	clock["now"] += 10000
	game.ledger.post(9900, "test", "99 €", "test")
	assert_eq(haptics.count, 2, "99 € nicht")
	# Umbuchungen zwischen den eigenen Konten sind keine Ein- oder Ausgaben.
	clock["now"] += 10000
	assert_true(not game.ledger.transfer(20000, LedgerSystemScript.PRIVATE, LedgerSystemScript.COMPANY, "Einlage", "test",
			"haptics:1").is_empty())
	assert_eq(haptics.count, 2, "Umbuchung zählt nicht")
	assert_eq(haptics.history, PackedStringArray(["money", "money"]))
	haptics.detach()
	clock["now"] += 10000
	game.ledger.post(-50000, "test", "nach dem Lösen", "test")
	assert_eq(haptics.count, 2, "nach detach() still")


func test_several_triggers_vibrate_once() -> void:
	var clock := {"now": 1000}
	var outputs := []
	var haptics := _haptics(null, clock, outputs)
	var game := Helpers.new_game()
	haptics.attach(game)
	# Ein Sprung über 14:00 (Termin verpasst) und 20:00 (Ereignis) – eine Aktion, eine Vibration.
	game.time.advance(TimeSystemScript.at(1, 21) - game.time.get_minutes())
	assert_eq(game.appointments.is_missed("camera_meeting"), true)
	assert_eq(game.events.has_pending(), true)
	assert_eq(haptics.count, 1)
	assert_eq(haptics.history, PackedStringArray(["missed"]))
	# Nach der Sperre wieder.
	clock["now"] += HapticsScript.LOCK_MSEC
	assert_eq(haptics.warn(HapticsScript.REASON_REMINDER), true)
	assert_eq(outputs.size(), 2)


func test_event_and_obligation_signals_trigger() -> void:
	var clock := {"now": 0}
	var haptics := _haptics(null, clock, [])
	var game := Helpers.new_game()
	haptics.attach(game)
	game.time.advance(TimeSystemScript.at(1, 15) - game.time.get_minutes())  # Termin verpasst
	clock["now"] += 10000
	game.time.advance(TimeSystemScript.at(1, 21) - game.time.get_minutes())  # Ereignis 20:00
	assert_eq(haptics.history, PackedStringArray(["missed", "event"]))
	game.events.resolve(game.events.get_next_pending_id(), "decline")
	clock["now"] += 10000
	game.ledger.post(-45000, "test", "Ausgabe für Test", "test")  # selbst ≥ 100 € → vibriert
	clock["now"] += 10000
	game.time.advance(TimeSystemScript.at(8, 9) - game.time.get_minutes())  # Montag: Miete fällig, offen
	assert_true("obligation" in haptics.history, str(haptics.history))


# --- Spielansicht ---------------------------------------------------------------------

func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = SETTINGS_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.haptics.output = func(_duration: int) -> void: pass
	return app


func _done(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func test_conflict_popup_vibrates_and_confirm_adds_nothing() -> void:
	var app := _app()
	var clock := {"now": 0}
	app.haptics.clock = func() -> int: return clock["now"]
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 25) - app.game.time.get_minutes())
	clock["now"] += 10000
	_press(app, "HereButton")
	_press(app, "StartButton_rest")
	assert_eq(app.haptics.history, PackedStringArray(["conflict"]))
	_press(app, "ConflictConfirmButton")  # verpasst den Termin – gleiche Aktion, keine zweite Vibration
	assert_eq(app.game.appointments.is_missed("camera_meeting"), true)
	assert_eq(app.haptics.count, 1)
	_done(app)


func test_reminder_vibrates() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	app.find_child("CityMap", true, false).get_parent().call("_refresh")
	assert_true(app.find_child("Window_reminder", true, false) != null, "keine Erinnerung")
	assert_eq(app.haptics.history, PackedStringArray(["reminder"]))
	_done(app)


func test_switch_off_in_app_never_vibrates() -> void:
	var app := _app()
	app.settings.set_flag(SettingsScript.VIBRATION, false)
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	app.find_child("CityMap", true, false).get_parent().call("_refresh")
	assert_eq(app.haptics.count, 0)
	_done(app)


## Ein Stand um 21:00 mit offenem Ereignis und eine fällige Erinnerung (13:35, nicht erinnert): Beim Laden öffnen
## sich die Fenster, aber es vibriert nicht.
func test_loading_does_not_vibrate() -> void:
	for minutes in [TimeSystemScript.at(1, 21), TimeSystemScript.at(1, 13, 35)]:
		var game := Helpers.new_game()
		game.time.advance(minutes - game.time.get_minutes())
		assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
		_remove_settings()
		var app := AppScript.new()
		app.save_path = SAVE_PATH
		app.settings_path = SETTINGS_PATH
		(Engine.get_main_loop() as SceneTree).root.add_child(app)
		app.haptics.output = func(_duration: int) -> void: pass
		_press(app, "ContinueButton")
		var screen := app.find_child("CityMap", true, false).get_parent()
		var opened := screen.find_child("Window_event", false, false) != null \
				or screen.find_child("Window_reminder", false, false) != null
		assert_true(opened, "kein Fenster nach dem Laden (%d)" % minutes)
		assert_eq(app.haptics.count, 0, "Laden vibriert (%d)" % minutes)
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	_remove_settings()
