extends "res://tests/base_test.gd"

## Ticket G5.8: rote Zählerpunkte mit Zahl (Kalender: Termine heute, die noch kommen; Fristen: fällige/überfällige
## offene) aus den Systemen, „9+“ ab 10, aktualisiert nach Aktion und Laden; Balken für Energie und Stimmung färben
## sich unter 40 gelb und unter 20 rot.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const DayPlanScript := preload("res://scripts/core/day_plan.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const RoundButtonScript := preload("res://scripts/ui/round_button.gd")
const HudBarScript := preload("res://scripts/ui/hud_bar.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_badges_save.json"


## Echte Daten plus `extra` Test-Termine heute ab 15:00 zu Hause (nur in den Testdaten).
func _data_with_extra(extra: int):
	var data := Helpers.game_data()
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/appointments/appointments.json"))
	for i in extra:
		list.append({"id": "extra_%02d" % i, "title": "Test %d" % i, "location": "home",
				"start": {"day": 1, "hour": 15 + i / 2, "minute": (i % 2) * 30}, "duration_minutes": 15,
				"missed_effects": {"mood": -1}})
	assert_true(data.appointments.load_data(list), "; ".join(data.appointments.errors))
	return data


func _app(data = null) -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	if data != null:
		app.preloaded_data = data
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _badge_text(app: Node, button_name: String) -> String:
	var button := app.find_child(button_name, true, false)
	var badge := button.find_child("Badge", true, false) as Control
	return (badge.find_child("BadgeLabel", true, false) as Label).text if badge.visible else ""


# --- Zählungen aus den Systemen -----------------------------------------------------------

func test_calendar_count_zero_one_many() -> void:
	var game := Helpers.new_game()
	assert_eq(DayPlanScript.count_upcoming_today(game), 1, "Treffen um 14:00")
	game.time.advance(TimeSystemScript.at(1, 14, 30) - game.time.get_minutes())
	assert_eq(DayPlanScript.count_upcoming_today(game), 0, "verpasst zählt nicht")
	var busy := Helpers.new_game(_data_with_extra(3))
	assert_eq(DayPlanScript.count_upcoming_today(busy), 4)
	busy.time.advance(TimeSystemScript.at(1, 15, 10) - busy.time.get_minutes())
	assert_eq(DayPlanScript.count_upcoming_today(busy), 2, "14:00 und 15:00 vorbei")


func test_badge_texts_and_nine_plus() -> void:
	var button := RoundButtonScript.new("Test", "res://assets/icons/calendar.svg")
	(Engine.get_main_loop() as SceneTree).root.add_child(button)
	var badge := button.find_child("Badge", true, false) as Control
	var label := button.find_child("BadgeLabel", true, false) as Label
	for pair in [[0, false, ""], [1, true, "1"], [9, true, "9"], [10, true, "9+"], [37, true, "9+"]]:
		button.set_badge(pair[0])
		assert_eq(badge.visible, pair[1], "Punkt bei %d" % pair[0])
		if pair[1]:
			assert_eq(label.text, pair[2])
			assert_eq(button.get_badge(), pair[0])
			assert_true(label.get_theme_font_size("font_size") >= UiStyle.MINI_FONT_SIZE)
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					label.get_theme_font_size("font_size")).x
			assert_true(width <= badge.size.x, "„%s“ passt nicht in den Punkt" % label.text)
	# Der Punkt verdeckt das Symbol nicht.
	button.size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE + 24)
	for count in [1, 10]:
		button.set_badge(count)
		var icon := button.find_child("Icon", true, false) as Control
		assert_true(not badge.get_global_rect().intersects(icon.get_global_rect()),
				"Punkt (%s) über dem Symbol %s" % [badge.get_global_rect(), icon.get_global_rect()])
	button.free()


func test_game_screen_badges_and_nine_plus() -> void:
	var app := _app(_data_with_extra(12))
	_press(app, "NewGameButton")
	assert_eq(_badge_text(app, "AppointmentsButton"), "9+", "13 Termine")
	assert_eq(_badge_text(app, "ObligationsButton"), "", "keine Fristen offen")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_badge_updates_after_action_and_after_loading() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	assert_eq(_badge_text(app, "AppointmentsButton"), "1")
	app.game.time.advance(TimeSystemScript.at(1, 13, 30) - app.game.time.get_minutes())
	_press(app, "HereButton")
	_press(app, "StartButton_rest")  # bis 14:30 → Treffen verpasst
	_press(app, "ConflictConfirmButton")
	assert_eq(app.game.time.format_clock(), "14:30")
	assert_eq(_badge_text(app, "AppointmentsButton"), "", "nach der Aktion kein Punkt mehr")
	app.free()
	# Laden: Spielstand von 10:00 (Termin kommt noch) → Punkt sofort da.
	var game := Helpers.new_game()
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var again := AppScript.new()
	again.save_path = SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(again)
	_press(again, "ContinueButton")
	assert_eq(_badge_text(again, "AppointmentsButton"), "1", "nach dem Laden")
	again.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_obligations_badge_counts_open() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	app.game.ledger.post(-45000, "test", "Ausgabe für Test", "test")
	app.game.time.advance(TimeSystemScript.at(8, 9) - app.game.time.get_minutes())  # Montag: Miete fällig, offen
	while app.game.events.has_pending():
		var instance: String = app.game.events.get_next_pending_id()
		app.game.events.resolve(instance, app.game.events.get_definition_for(instance).options[-1].id)
	app.find_child("CityMap", true, false).get_parent().call("_refresh")
	var expected := app.game.obligations.count_open()
	assert_true(expected >= 1, "keine offene Frist")
	assert_eq(_badge_text(app, "ObligationsButton"), str(expected))
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Balkenfarben ---------------------------------------------------------------------

func test_level_boundaries() -> void:
	assert_eq(PlayerStatsScript.level_of(40), PlayerStatsScript.LEVEL_OK)
	assert_eq(PlayerStatsScript.level_of(39), PlayerStatsScript.LEVEL_LOW)
	assert_eq(PlayerStatsScript.level_of(20), PlayerStatsScript.LEVEL_LOW)
	assert_eq(PlayerStatsScript.level_of(19), PlayerStatsScript.LEVEL_CRITICAL)
	assert_eq(PlayerStatsScript.level_of(0), PlayerStatsScript.LEVEL_CRITICAL)


func test_hud_bar_colors_at_boundaries() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	var screen := app.find_child("CityMap", true, false).get_parent()
	for key in ["energy", "mood"]:
		var bar := app.find_child("StatBar_%s" % key, true, false) as ProgressBar
		for pair in [[40, HudBarScript.STAT_COLORS[key]], [39, HudBarScript.LOW_COLOR], [20, HudBarScript.LOW_COLOR],
				[19, HudBarScript.CRITICAL_COLOR]]:
			app.game.stats.set(key, pair[0])
			screen.call("_refresh")
			assert_eq((bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color, pair[1], "%s %d" % [key, pair[0]])
			assert_eq((app.find_child("StatValue_%s" % key, true, false) as Label).text, str(pair[0]), "Zahl sichtbar")
	# Normalfarben selbst sind weder gelb noch rot.
	for key in HudBarScript.STAT_COLORS:
		assert_true(HudBarScript.STAT_COLORS[key] != HudBarScript.LOW_COLOR, key)
		assert_true(HudBarScript.STAT_COLORS[key] != HudBarScript.CRITICAL_COLOR, key)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_bar_color_updates_after_action() -> void:
	var app := _app()
	_press(app, "NewGameButton")
	app.game.stats.energy = 45
	_press(app, "MapPin_gym")
	_press(app, "StartButton_training")  # Hinfahren und starten: Energie -15 → 30
	var bar := app.find_child("StatBar_energy", true, false) as ProgressBar
	assert_eq(app.game.stats.energy, 30)
	assert_eq((bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color, HudBarScript.LOW_COLOR)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
