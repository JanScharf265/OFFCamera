extends "res://tests/base_test.gd"

## Ticket U.16: Waschen über die Tarnfirma als reine Spielmechanik – Regeln als Daten (Gebühr %, Tageslimit, Schritte,
## Hitze); zwei Buchungen (Schwarzgeld − Betrag, Firmenkonto + Betrag − Gebühr); Limit je Tag; nur mit Organisation
## und Unternehmen; keine Spielzeit; Speichern/Laden; Migration v28 → v29; Abschnitt im Organisations-Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LaunderingSystemScript := preload("res://scripts/systems/laundering_system.gd")

const SAVE_PATH := "user://test_laundering_save.json"


## Organisation und Merch-Label gegründet, 2.000 € Schwarzgeld – Tag 1.
func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.locations.travel("office")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	assert_eq(game.company.found("merch_label"), "")
	game.ledger.post(200000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func test_real_rules_load() -> void:
	var rules := LaunderingSystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq([rules.get_value("fee_percent"), rules.get_value("daily_limit_cents"), rules.get_value("step_cents")],
			[15, 100000, 10000])
	for bad in [{"fee_percent": 101, "daily_limit_cents": 1, "step_cents": 1, "heat_per_1000_euro": 0},
			{"fee_percent": 1, "daily_limit_cents": 1, "step_cents": 2, "heat_per_1000_euro": 0},
			{"fee_percent": 1, "daily_limit_cents": 1, "step_cents": 1}, "x"]:
		assert_eq(rules.load_data(bad), false, "angenommen: %s" % [bad])


func test_needs_organisation_and_company() -> void:
	var game := Helpers.new_game()
	assert_eq(game.laundering.is_available(), false)
	assert_eq(game.laundering.check(10000), "Erst eine Organisation gründen.")
	game.organisation.found("Los Lobos")
	assert_eq(game.laundering.check(10000), "Dafür braucht es ein Unternehmen.")


func test_launder_books_both_accounts_and_heat() -> void:
	var game := _ready_game()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var company := game.ledger.get_balance(LedgerSystemScript.COMPANY)
	var heat := game.organisation.get_value("heat")
	var minutes := game.time.get_minutes()
	assert_eq(game.laundering.launder(50000), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 50000)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.COMPANY), company + 42500, "15 % Gebühr")
	assert_eq(game.organisation.get_value("heat"), heat + 2, "5 je 1.000 € → 500 € = 2")
	assert_eq(game.time.get_minutes(), minutes, "keine Spielzeit")
	assert_eq(game.ledger.get_entries_by_category(LaunderingSystemScript.CATEGORY_OUT).size(), 1)
	assert_eq(game.ledger.get_entries_by_category(LaunderingSystemScript.CATEGORY_IN).size(), 1)


func test_daily_limit_and_steps() -> void:
	var game := _ready_game()
	assert_eq(game.laundering.check(15000), "Betrag in Schritten von 100,00 €.")
	assert_eq(game.laundering.launder(80000), "")
	assert_eq(game.laundering.check(30000), "Heute noch 200,00 € möglich.")
	assert_eq(game.laundering.launder(20000), "")
	assert_eq(game.laundering.check(10000), "Für heute ist das Limit erreicht.")
	game.time.advance(TimeSystemScript.at(2, 9) - game.time.get_minutes())
	assert_eq(game.laundering.remaining_today(), 100000, "neuer Tag, neues Limit")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), 100000)
	assert_eq(game.laundering.check(100000), "")


func test_not_enough_black_money() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	game.locations.travel("office")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	assert_eq(game.company.found("merch_label"), "")
	assert_eq(game.laundering.check(10000), "Nicht genug Schwarzgeld (0,00 €).")


func test_survives_save_and_migration() -> void:
	var game := _ready_game()
	game.laundering.launder(30000)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.laundering.to_dict(), game.laundering.to_dict())
		assert_eq(loaded.laundering.remaining_today(), 70000)
		assert_eq(loaded.laundering.launder(10000), "", "kein doppelter Buchungsschlüssel nach dem Laden")
	assert_true(not game.laundering.restore({"day": 1}).is_empty())
	var old := {}
	assert_eq(SaveSystemScript._run_migration(28, old), "")
	assert_eq(old["laundering"]["total_cents"], 0)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_section_in_organisation_window() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_laundering_settings.cfg"
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true(app.find_child("LaunderButton", true, false) == null, "Waschen ohne Firma")
	screen.call("_close_window")
	app.game.locations.travel("office")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	assert_eq(app.game.company.found("merch_label"), "")
	app.game.ledger.post(200000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("LaunderAmount", true, false) as Label).text, "500,00 €")
	var button := app.find_child("LaunderButton", true, false) as Button
	assert_eq([button.disabled, button.text], [false, "Waschen · 425,00 € aufs Firmenkonto"])
	(app.find_child("LaunderMore", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("LaunderAmount", true, false) as Label).text, "600,00 €")
	(app.find_child("LaunderButton", true, false) as Button).pressed.emit()
	assert_eq(app.game.laundering.get_total(), 60000)
	assert_eq((app.find_child("LaunderTerms", true, false) as Label).text,
			"Gebühr 15 % · heute noch 400,00 € möglich · Hitze +5 je 1.000 €")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_laundering_settings.cfg"))
