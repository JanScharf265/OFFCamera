extends "res://tests/base_test.gd"

## Ticket U.17: Schwarzgeld ausgeben – Schalter (gespeichert), Aktivitäten und Ausrüstung zahlen dann aus Schwarzgeld,
## wenn es reicht und das Tageslimit es erlaubt; sonst privat. Hitze je Zahlung; Miete/Fristen/Firma nie. Regeln als
## Daten; Speichern/Laden; Migration v29 → v30; Schalter im Organisations-Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const BlackSpendingSystemScript := preload("res://scripts/systems/black_spending_system.gd")

const SAVE_PATH := "user://test_black_spending_save.json"


## Organisation, 1.000 € Schwarzgeld, 10:00 im Café, Schalter an.
func _ready_game(enabled: bool = true) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	game.ledger.post(100000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	game.black_spending.set_enabled(enabled)
	return game


func test_rules_load() -> void:
	var rules := BlackSpendingSystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq([rules.get_value("daily_limit_cents"), rules.get_value("heat_per_100_euro"), rules.get_value("min_heat")],
			[30000, 2, 1])
	assert_eq(rules.load_data({"daily_limit_cents": 1}), false)
	assert_eq(rules.load_data({"daily_limit_cents": 1, "heat_per_100_euro": 1, "min_heat": 1, "x": 1}), false)


func test_off_pays_private() -> void:
	var game := _ready_game(false)
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var private := game.ledger.get_balance()
	assert_eq(game.activities.start("eat_out"), "")
	assert_eq([game.ledger.get_balance(LedgerSystemScript.BLACK), game.ledger.get_balance()], [black, private - 1500])


func test_on_pays_black_with_heat() -> void:
	var game := _ready_game()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var private := game.ledger.get_balance()
	var heat := game.organisation.get_value("heat")
	assert_eq(game.activities.start("eat_out"), "")
	assert_eq([game.ledger.get_balance(LedgerSystemScript.BLACK), game.ledger.get_balance()], [black - 1500, private])
	assert_eq(game.organisation.get_value("heat"), heat + 1, "mindestens +1")
	assert_true(" ".join(game.black_spending.take_notices()).contains("Bezahlt mit Schwarzgeld: Essen gehen 15,00 €"))


func test_equipment_and_daily_limit() -> void:
	var game := _ready_game()
	game.locations.travel("studio")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var heat := game.organisation.get_value("heat")
	assert_eq(game.equipment.buy("camera"), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 12000)
	assert_eq(game.organisation.get_value("heat"), heat + 2, "120 € → 2")
	assert_eq(game.black_spending.remaining_today(), 18000)
	var private := game.ledger.get_balance()
	assert_eq(game.equipment.buy("microphone"), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 12000 - 8000, "80 € passen noch ins Limit")
	assert_eq(game.equipment.buy("lighting"), "")
	assert_eq(game.black_spending.remaining_today(), 5000, "noch 50 €")
	game.ledger.post(50000, "test", "Privat", "test", "p")
	private = game.ledger.get_balance()
	assert_eq(game.equipment.buy("camera"), "", "Stufe 2 (450 €)")
	assert_eq(game.ledger.get_balance(), private - 45000, "über dem Limit: privat")


func test_not_enough_black_pays_private() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	game.black_spending.set_enabled(true)
	var private := game.ledger.get_balance()
	assert_eq(game.activities.start("coffee"), "")
	assert_eq(game.ledger.get_balance(), private - 350)


func test_rent_never_black() -> void:
	var game := _ready_game()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	game.time.advance(TimeSystemScript.at(8, 9) - game.time.get_minutes())
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black, "Miete & Co. nicht aus Schwarzgeld")


func test_saved_and_migrated() -> void:
	var game := _ready_game()
	game.activities.start("eat_out")
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.black_spending.to_dict(), game.black_spending.to_dict())
		assert_eq(loaded.black_spending.is_enabled(), true)
	assert_true(not game.black_spending.restore({"enabled": "ja", "day": 1, "spent_today_cents": 0}).is_empty())
	var old := {}
	assert_eq(SaveSystemScript._run_migration(29, old), "")
	assert_eq(old["black_spending"]["enabled"], false)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_toggle() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_black_spending_settings.cfg"
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	var toggle := app.find_child("BlackSpendingToggle", true, false) as Button
	assert_eq(toggle.text, "Mit Schwarzgeld bezahlen: Aus")
	toggle.pressed.emit()
	assert_eq(app.game.black_spending.is_enabled(), true)
	assert_eq((app.find_child("BlackSpendingToggle", true, false) as Button).text, "Mit Schwarzgeld bezahlen: An")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_black_spending_settings.cfg"))


## U.25: Kachel zeigt „· bar“, wenn die Ausgabe aus Schwarzgeld käme.
func test_ui_tile_marks_cash() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_black_spending_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	app.game.ledger.post(100000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	(app.find_child("MapPin_cafe_harbor", true, false) as Button).pressed.emit()
	var texts := func() -> String:
		var parts := []
		for label in app.find_child("TileEffects_eat_out", true, false).find_children("*", "Label", true, false):
			parts.append(label.text)
		return " ".join(parts)
	assert_true(not texts.call().contains("bar"), "aus: kein Hinweis")
	app.game.black_spending.set_enabled(true)
	screen.call("_refresh")
	assert_true(texts.call().contains("-15,00 € · bar"), "an: %s" % texts.call())
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_black_spending_settings.cfg"))
