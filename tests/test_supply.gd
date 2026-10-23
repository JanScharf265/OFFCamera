extends "res://tests/base_test.gd"

## Ticket U.6: Lieferant und Bestand – erst nach „Treffen am Hafen“ erreichbar; Vorkasse als Buchung (Schwarzgeld, wenn
## es reicht, sonst Privatkonto); Lieferung beim Tageswechsel, kann platzen (Seed, deterministisch), jeder Tag einmal;
## Bestand; Auftrag „Die erste Ware“; Speichern/Laden; Migration v19 → v20; Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SupplierCatalogScript := preload("res://scripts/systems/supplier_catalog.gd")

const SAVE_PATH := "user://test_supply_save.json"
const RUBIO := "el_rubio"


## Organisation gegründet und „Treffen am Hafen“ erledigt (10:00 im offenen Café).
func _ready_game(p_seed: int = Helpers.TEST_SEED) -> GameStateScript:
	var game := Helpers.new_game(null, p_seed)
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	assert_eq(game.missions.is_completed("first_deal_meeting"), true)
	return game


func _next_day(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_real_suppliers_load() -> void:
	var catalog := SupplierCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var rubio = catalog.get_definition(RUBIO)
	assert_eq(rubio.name, "El Rubio")
	assert_eq(rubio.failure_percent, 15)
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_suppliers_are_rejected() -> void:
	var good := {"id": "s_a", "name": "S", "description": "D.", "products": ["weed"], "min_units": 1, "max_units": 5,
			"delivery_days": 1, "failure_percent": 10, "unlocked_by_mission": "first_deal_meeting"}
	var catalog := SupplierCatalogScript.new()
	assert_true(catalog.load_data([good]))
	for change in [{"products": []}, {"min_units": 0}, {"max_units": 0}, {"delivery_days": 0}, {"failure_percent": 101},
			{"extra": 1}, {"products": ["weed", "weed"]}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(catalog.load_data([bad]), false, "angenommen: %s" % change)
	var data := Helpers.game_data()
	var unknown := good.duplicate()
	unknown["products"] = ["gold"]
	assert_true(data.suppliers.load_data([unknown]))
	assert_true(not data.check_references().is_empty(), "unbekanntes Produkt nicht gemeldet")


func test_locked_until_meeting() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	assert_eq(game.supply.is_unlocked(RUBIO), false)
	assert_eq(game.supply.check_order(RUBIO, "weed", 1), "Diesen Lieferanten kennst du noch nicht.")


func test_order_pays_in_advance_and_delivers_next_morning() -> void:
	var game := _ready_game()
	var private := game.ledger.get_balance()
	assert_eq(game.supply.check_order(RUBIO, "weed", 0), "Menge 1–20 Einheiten.")
	assert_eq(game.supply.check_order(RUBIO, "weed", 21), "Menge 1–20 Einheiten.")
	assert_eq(game.supply.payment_account(20000), LedgerSystemScript.PRIVATE, "kein Schwarzgeld → Privatkonto")
	assert_eq(game.supply.order(RUBIO, "weed", 5), "")
	assert_eq(game.ledger.get_balance(), private - 20000, "5 × 40 € Vorkasse")
	var entry = game.ledger.get_entries()[-1]
	assert_eq([entry.category, entry.source, entry.account], ["underworld_purchase", "supply", "private"])
	assert_eq(game.supply.get_stock("weed"), 0, "noch nicht da")
	assert_eq(game.supply.get_pending_orders().size(), 1)
	_next_day(game)
	var delivered: bool = game.supply.get_stock("weed") == 5
	var failed: bool = game.supply.get_stock("weed") == 0
	assert_true(delivered or failed)
	assert_eq(game.supply.get_pending_orders().size(), 0)
	var notices := Array(game.supply.take_notices())
	assert_eq(notices.size(), 1)
	if delivered:
		assert_eq(notices[0], "Lieferung von El Rubio: 5 × Gras ist da.")
		assert_eq(game.missions.is_completed("first_deal_goods"), true, "„Die erste Ware“ erledigt")
	else:
		assert_eq(notices[0], "Lieferung geplatzt: El Rubio meldet sich nicht – 200,00 € sind weg.")


func test_black_money_pays_when_enough() -> void:
	var game := _ready_game()
	game.ledger.post(100000, "test", "Test", "test", "", "", false, LedgerSystemScript.BLACK)
	var private := game.ledger.get_balance()
	assert_eq(game.supply.order(RUBIO, "coke", 2), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), 100000 - 40000)
	assert_eq(game.ledger.get_balance(), private, "Privatkonto unberührt")


func test_not_enough_money() -> void:
	var game := _ready_game()
	assert_eq(game.supply.check_order(RUBIO, "coke", 20), "Nicht genug Geld (Vorkasse 4.000,00 €).")
	var entries := game.ledger.get_entries().size()
	assert_eq(game.supply.order(RUBIO, "coke", 20), "Nicht genug Geld (Vorkasse 4.000,00 €).")
	assert_eq(game.ledger.get_entries().size(), entries)


## Seed entscheidet: gleiche Seeds → gleicher Ausgang; über viele Seeds platzen ungefähr 15 %.
func test_failure_is_deterministic_and_about_fifteen_percent() -> void:
	var failures := 0
	var runs := 60
	for i in runs:
		var outcome := []
		for repeat in 2:
			var game := _ready_game(1000 + i)
			game.supply.order(RUBIO, "weed", 1)
			_next_day(game)
			outcome.append(game.supply.get_stock("weed"))
		assert_eq(outcome[0], outcome[1], "Seed %d nicht deterministisch" % (1000 + i))
		if outcome[0] == 0:
			failures += 1
	assert_true(failures >= 2 and failures <= 20, "geplatzt: %d von %d" % [failures, runs])


func test_each_day_once_and_survives_load() -> void:
	var game := _ready_game()
	game.supply.order(RUBIO, "hash", 3)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.supply.get_pending_orders().size(), 1, "Bestellung nach dem Laden noch unterwegs")
		_next_day(loaded)
		_next_day(game)
		assert_eq(loaded.supply.get_stock("hash"), game.supply.get_stock("hash"), "gleicher Ausgang nach dem Laden")
		var stock: int = loaded.supply.get_stock("hash")
		loaded.supply.on_day_changed(loaded.time.get_day())  # derselbe Tag noch einmal
		assert_eq(loaded.supply.get_stock("hash"), stock)
		var copy := Helpers.new_game()
		assert_eq(copy.restore(loaded.to_dict()), "")
		assert_eq(copy.supply.to_dict(), loaded.supply.to_dict())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_restore_rejects_bad_data_without_change() -> void:
	var game := _ready_game()
	game.supply.order(RUBIO, "weed", 1)
	var good := game.supply.to_dict()
	for change in [{"stock": {"weed": -1}}, {"orders": "x"}, {"next_number": 1}, {"last_processed_day": -1}]:
		var bad := good.duplicate(true)
		bad.merge(change, true)
		assert_true(not game.supply.restore(bad).is_empty(), "angenommen: %s" % change)
	assert_eq(game.supply.to_dict(), good)


func test_migration_19_to_20() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v19.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v19 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.supply.total_stock(), 0)
		assert_eq(game.supply.get_pending_orders().size(), 0)
	assert_true(not SaveSystemScript._run_migration(19, {"time": "x"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


# --- Spielansicht ---------------------------------------------------------------------

func test_ui_order_from_organisation_window() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true(app.find_child("SupplierButton_el_rubio", true, false) == null, "vor dem Treffen erreichbar")
	assert_true(app.find_child("StockEmpty", true, false) != null)
	(app.find_child("WindowCloseButton", true, false) as Button).pressed.emit()
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	screen.call("_refresh")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	(app.find_child("SupplierButton_el_rubio", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("WindowTitle", true, false) as Label).text, "Lieferant · El Rubio")
	assert_eq((app.find_child("SupplierUnits_weed", true, false) as Label).text, "5")
	(app.find_child("SupplierMore_weed", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("SupplierUnits_weed", true, false) as Label).text, "6")
	assert_eq((app.find_child("SupplierOrderButton_weed", true, false) as Button).text, "Bestellen · 240,00 €")
	assert_eq((app.find_child("SupplierNote_weed", true, false) as Label).text, "Bezahlt aus: Privatkonto")
	var balance: int = app.game.ledger.get_balance()
	(app.find_child("SupplierOrderButton_weed", true, false) as Button).pressed.emit()
	assert_eq(app.game.ledger.get_balance(), balance - 24000)
	assert_true((app.find_child("FeedbackLabel", true, false) as Label).text.begins_with(
			"Bestellt: 6 × Gras (-240,00 €, Vorkasse)"))
	(app.find_child("WindowCloseButton", true, false) as Button).pressed.emit()
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true(app.find_child("PendingOrder_order_0001", true, false) != null, "Lieferung unterwegs fehlt")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Selbstprüfung U.6: Nach „Bestellen“ zeigt das Fenster „unterwegs“, und die Rückmeldung liegt über dem Fenster.
func test_ui_order_feedback_visible() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent() as Control
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	screen.call("open_supplier", RUBIO)
	(app.find_child("SupplierOrderButton_weed", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("SupplierStock_weed", true, false) as Label).text, "Bestand 0 · unterwegs 5")
	var toast := app.find_child("Toast", true, false) as Control
	var window := screen.find_child("Window_supplier", false, false) as Control
	assert_true(toast.visible and toast.get_index() > window.get_index(), "Rückmeldung unter dem Fenster")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
