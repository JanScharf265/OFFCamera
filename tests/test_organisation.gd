extends "res://tests/base_test.gd"

## Ticket U.2: Organisation – Name, Respekt, Hitze, Stabilität (0–100); vor der Gründung unsichtbar und unveränderlich;
## Hitze sinkt jeden Tag (GD 086) (DayCycle, jeder Tag einmal, auch nach Laden); Regeln aus den Daten; Migration v16 → v17.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const OrganisationRulesScript := preload("res://scripts/systems/organisation_rules.gd")
const OrganisationSystemScript := preload("res://scripts/systems/organisation_system.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const HudBarScript := preload("res://scripts/ui/hud_bar.gd")

const SAVE_PATH := "user://test_organisation_save.json"


func _to_day(game: GameStateScript, day: int) -> void:
	game.time.advance(TimeSystemScript.at(day, 8) - game.time.get_minutes())


func test_real_rules_load() -> void:
	var rules := OrganisationRulesScript.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq(rules.start, {"respect": 0, "heat": 0, "stability": 50})
	assert_eq(rules.heat_decay_per_day, 3)


func test_bad_rules_are_rejected() -> void:
	var good := {"start": {"respect": 0, "heat": 0, "stability": 50}, "heat_decay_per_day": 3,
			"name_min_length": 2, "name_max_length": 24,
			"intro": {"event": "underworld_intro", "first_day": 2, "retry_days": 2, "accept_option": "listen"}}
	var rules := OrganisationRulesScript.new()
	assert_true(rules.load_data(good), "; ".join(rules.errors))
	for change in [{"start": {"respect": 0, "heat": 101, "stability": 50}}, {"start": {"respect": 0, "heat": 0}},
			{"start": {"respect": 0, "heat": 0, "stability": 50, "fear": 1}}, {"heat_decay_per_day": -1},
			{"name_min_length": 5, "name_max_length": 3}, {"name_max_length": 99}]:
		var data := good.duplicate(true)
		data.merge(change, true)
		assert_eq(rules.load_data(data), false, "angenommen: %s" % change)
	assert_eq(rules.load_data([]), false)


func test_nothing_before_founding() -> void:
	var game := Helpers.new_game()
	assert_eq(game.organisation.is_founded(), false)
	assert_eq(game.organisation.change({"heat": 10}), false)
	assert_eq(game.organisation.get_value("heat"), 0)
	_to_day(game, 3)
	assert_eq(game.organisation.get_value("heat"), 0)


func test_found_with_name_rules() -> void:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found(" "), "Der Name ist zu kurz (mindestens 2 Zeichen).")
	assert_eq(game.organisation.found("x".repeat(25)), "Der Name ist zu lang (höchstens 24 Zeichen).")
	var names := []
	game.organisation.founded.connect(func(n: String) -> void: names.append(n))
	assert_eq(game.organisation.found("  Los Testigos "), "")
	assert_eq(game.organisation.get_name(), "Los Testigos")
	assert_eq(names, ["Los Testigos"])
	assert_eq(game.organisation.found("Noch eine"), "Die Organisation gibt es schon.")
	assert_eq([game.organisation.get_value("respect"), game.organisation.get_value("heat"),
			game.organisation.get_value("stability")], [0, 0, 50])
	assert_eq(game.tutorials.was_reported("first_organisation_founded"), true)


func test_values_are_clamped() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Testigos")
	game.organisation.change({"heat": 250, "respect": -5, "stability": 70})
	assert_eq(game.organisation.get_value("heat"), 100)
	assert_eq(game.organisation.get_value("respect"), 0)
	assert_eq(game.organisation.get_value("stability"), 100)
	print("          (die folgende ERROR-Meldung ist erwartet)")
	assert_eq(game.organisation.change({"fear": 3}), false)


## GD 086: Hitze sinkt an jedem Tag um 3 – auch nach einem Tag mit neuer Hitze.
func test_heat_cools_every_day() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Testigos")
	game.organisation.change({"heat": 20})  # Tag 1
	_to_day(game, 2)
	assert_eq(game.organisation.get_value("heat"), 17, "auch nach einem Tag mit Hitze: -3")
	game.organisation.change({"heat": 5})  # Tag 2 → 22
	_to_day(game, 3)
	assert_eq(game.organisation.get_value("heat"), 19)
	_to_day(game, 12)  # 9 Tage auf einmal: 19 - 9 × 3 → 0, nicht darunter
	assert_eq(game.organisation.get_value("heat"), 0)


func test_each_day_once_even_after_load() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Testigos")
	game.organisation.change({"heat": 30})
	_to_day(game, 3)  # 30 → 27 → 24
	assert_eq(game.organisation.get_value("heat"), 24)
	var copy := Helpers.new_game()
	assert_eq(copy.restore(game.to_dict()), "")
	copy.organisation.on_day_changed(3)  # derselbe Tag noch einmal: nichts
	assert_eq(copy.organisation.get_value("heat"), 24)
	assert_eq(copy.organisation.get_name(), "Los Testigos")
	assert_eq(copy.organisation.to_dict(), game.organisation.to_dict())


func test_restore_rejects_bad_values_without_change() -> void:
	var game := Helpers.new_game()
	var good := game.organisation.to_dict()
	for change in [{"heat": 101}, {"founded": "ja"}, {"founded": true, "name": " "}, {"last_processed_day": -1}]:
		var data := good.duplicate()
		data.merge(change, true)
		assert_true(not game.organisation.restore(data).is_empty(), "angenommen: %s" % change)
	assert_eq(game.organisation.to_dict(), good)


func test_migration_16_to_17() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v16.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v16 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.organisation.is_founded(), false)
		assert_eq(game.organisation.get_value("stability"), 50)
		assert_eq(game.organisation.to_dict()["last_processed_day"], game.time.get_day())
	assert_true(not SaveSystemScript._run_migration(16, {"time": "kaputt"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_hud_heat_visible_after_founding_with_colors() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	var block := app.find_child("HeatBlock", true, false) as Control
	assert_eq(block.visible, false, "vor der Gründung sichtbar")
	app.game.organisation.found("Los Testigos")
	screen.call("_refresh")
	assert_eq(block.visible, true)
	for pair in [[0, HudBarScript.heat_color(0)], [29, UiStyle_TEXT()], [30, HudBarScript.LOW_COLOR],
			[59, HudBarScript.LOW_COLOR], [60, HudBarScript.CRITICAL_COLOR]]:
		app.game.organisation.change({"heat": pair[0] - app.game.organisation.get_value("heat")})
		screen.call("_refresh")
		assert_eq((app.find_child("HeatValue", true, false) as Label).text, str(pair[0]))
		assert_eq((block.get_child(0) as Control).modulate, pair[1], "Farbe bei %d" % pair[0])
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


static func UiStyle_TEXT() -> Color:
	return preload("res://scripts/ui/ui_style.gd").TEXT
