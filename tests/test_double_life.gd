extends "res://tests/base_test.gd"

## Ticket U.22: Doppelleben – Ruf des Kanals senkt jeden Hitze-Anstieg leicht (höchstens 10 %), Bekanntheit erhöht ihn
## (höchstens 30 %); am Spielanfang unverändert; Ereignisse Paparazzi/Leak/Gerüchte/Skandal/Abwesenheit nur unter
## ihren Bedingungen (Follower, Hitze, Polizei, Haft); Anzeige im Organisations-Fenster.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const DoubleLifeSystemScript := preload("res://scripts/systems/double_life_system.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")


func _game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	return game


func test_rules_load() -> void:
	var rules := DoubleLifeSystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	var bad: Dictionary = rules.values.duplicate()
	bad["cover_reputation_per_percent"] = 0
	assert_eq(DoubleLifeSystemScript.Rules.new().load_data(bad), false)


func test_start_is_neutral() -> void:
	var game := _game()
	assert_eq(game.double_life.heat_gain_percent(), 100)
	game.organisation.change({"heat": 10})
	assert_eq(game.organisation.get_value("heat"), 10)


func test_reputation_covers_slightly() -> void:
	var game := _game()
	game.channel.reputation = 100
	assert_eq(game.double_life.cover_percent(), 10, "höchstens 10 %")
	game.organisation.change({"heat": 20})
	assert_eq(game.organisation.get_value("heat"), 18)


func test_fame_draws_attention() -> void:
	var game := _game()
	game.channel.followers = 25000
	assert_eq(game.double_life.fame_percent(), 20)
	game.organisation.change({"heat": 10})
	assert_eq(game.organisation.get_value("heat"), 12)
	game.channel.followers = 500000
	assert_eq(game.double_life.fame_percent(), 30, "höchstens 30 %")


func test_decrease_and_small_gains() -> void:
	var game := _game()
	game.organisation.change({"heat": 30})
	game.channel.reputation = 100
	game.organisation.change({"heat": -10})
	assert_eq(game.organisation.get_value("heat"), 20, "Abkühlung unverändert")
	game.organisation.change({"heat": 1})
	assert_eq(game.organisation.get_value("heat"), 21, "+1 bleibt +1")


func test_event_conditions() -> void:
	var game := _game()
	var values: Dictionary = game.events.condition_values()
	assert_eq([values["heat"], values["locked_up"]], [0, 0])
	game.organisation.change({"heat": 30})
	game.justice.arrest(game.time.get_day())
	values = game.events.condition_values()
	assert_eq([values["heat"], values["locked_up"]], [30, 1])
	for id in ["paparazzi", "leak", "rumors", "scandal", "absence"]:
		var definition = game.data.events.get_definition(id)
		assert_true(definition != null and definition.is_random, id)
	assert_eq(game.data.events.get_definition("absence").conditions.get("min_locked_up"), 1)
	assert_eq(game.data.events.get_definition("scandal").conditions.get("min_police_level"), 2)


func test_ui_line() -> void:
	SaveSystemScript.delete_save("user://test_double_life_save.json")
	var app := AppScript.new()
	app.save_path = "user://test_double_life_save.json"
	app.settings_path = "user://test_double_life_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.channel.followers = 15000
	app.game.channel.reputation = 75
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("DoubleLifeStatus", true, false) as Label).text, "Hitze-Anstieg +5 %")
	assert_true((app.find_child("DoubleLifeDetail", true, false) as Label).text.begins_with("Tarnung durch den Kanal −5 %"))
	app.free()
	SaveSystemScript.delete_save("user://test_double_life_save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_double_life_settings.cfg"))
