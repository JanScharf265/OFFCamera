extends "res://tests/base_test.gd"

## Ticket U.9: Verkaufen als Aktion – Katalog der Verkaufsorte; verfügbar erst nach „Ein sicherer Ort“; Verkauf vor
## Ort nimmt Bestand, bucht Schwarzgeld, bringt Hitze, kostet Spielzeit; Auftrag „Der erste Verkauf“ schließt das
## Kapitel „Erster Deal“; Speichern/Laden; Migration v22 → v23; Kachel und Verkaufsfenster.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SaleSystemScript := preload("res://scripts/systems/sale_system.gd")

const SAVE_PATH := "user://test_sales_save.json"
const SPOT := "harbor_after_hours"


## Organisation, erste Ware (12 Gras) und Versteck – 10:00 im Café am Hafen.
func _ready_game(stock: int = 12) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	var data := game.supply.to_dict()
	data["stock"] = {"weed": stock}
	game.supply.restore(data)
	game.missions.update_availability()
	game.locations.travel("garage")
	assert_eq(game.sites.acquire("garage_san_pedro"), "")
	assert_eq(game.missions.is_completed("first_deal_stash"), true)
	game.locations.travel("cafe_harbor")
	return game


func test_real_spots_load() -> void:
	var catalog := SaleSystemScript.Catalog.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var spot = catalog.get_definition(SPOT)
	assert_eq([spot.location, spot.minutes, spot.max_units, spot.price_percent, spot.heat_percent],
			["cafe_harbor", 60, 10, 100, 100])
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_spots_are_rejected() -> void:
	var good := {"id": "s", "display_name": "S", "location": "cafe_harbor", "description": "D.",
			"unlocked_by_mission": "first_deal_stash", "minutes": 1, "max_units": 1, "price_percent": 1, "heat_percent": 0}
	var catalog := SaleSystemScript.Catalog.new()
	assert_true(catalog.load_data([good]), "; ".join(catalog.errors))
	for change in [{"minutes": 0}, {"max_units": 0}, {"heat_percent": -1}, {"extra": 1}, {"location": 5}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(catalog.load_data([bad]), false, "angenommen: %s" % change)
	assert_eq(catalog.load_data([good, good]), false, "doppelte ID")
	var data := Helpers.game_data()
	var unknown := good.duplicate()
	unknown["unlocked_by_mission"] = "nope"
	assert_true(data.sale_spots.load_data([unknown]))
	assert_true(not data.check_references().is_empty())


func test_not_available_before_stash() -> void:
	var game := Helpers.new_game()
	assert_eq(game.sales.is_available(SPOT), false)
	assert_eq(game.sales.check_sale(SPOT, "weed", 1), "Hier verkaufst du noch nichts.")
	assert_eq(game.missions.is_active("first_deal_sale"), false)
	var ready := _ready_game()
	assert_eq(ready.sales.is_available(SPOT), true)
	assert_eq(ready.missions.is_active("first_deal_sale"), true, "Auftrag „Der erste Verkauf“")


func test_sell_books_black_money_heat_and_time() -> void:
	var game := _ready_game()
	var private := game.ledger.get_balance()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var heat := game.organisation.get_value("heat")
	var minutes := game.time.get_minutes()
	assert_eq(game.sales.sell(SPOT, "weed", 4), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black + 4 * 7000)
	assert_eq(game.ledger.get_balance(), private, "Privatkonto unberührt")
	assert_eq(game.organisation.get_value("heat"), heat + 4)
	assert_eq(game.time.get_minutes(), minutes + 60)
	assert_eq(game.supply.get_stock("weed"), 8)
	assert_eq(game.sales.get_sold_units(), 4)
	var entries := game.ledger.get_entries_by_category(SaleSystemScript.CATEGORY)
	assert_eq(entries.size(), 1, "genau eine Buchung")
	assert_eq(entries[0].account, LedgerSystemScript.BLACK)


func test_sale_reasons() -> void:
	var game := _ready_game(3)
	assert_eq(game.sales.check_sale(SPOT, "weed", 4), "Nicht genug im Bestand (3).")
	assert_eq(game.sales.check_sale(SPOT, "weed", 0), "Je Verkauf 1–10 Einheiten.")
	assert_eq(game.sales.check_sale(SPOT, "weed", 11), "Je Verkauf 1–10 Einheiten.")
	assert_eq(game.sales.check_sale(SPOT, "hash", 1), "Nicht genug im Bestand (0).")
	game.locations.travel("garage")
	assert_eq(game.sales.check_sale(SPOT, "weed", 1), "Nur vor Ort möglich: Café am Hafen.")
	assert_eq(game.sales.check_open(SPOT), "Nur vor Ort möglich: Café am Hafen.")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_true(not game.sales.sell(SPOT, "weed", 1).is_empty())
	assert_eq([game.ledger.get_balance(LedgerSystemScript.BLACK), game.supply.get_stock("weed")], [black, 3],
			"abgelehnter Verkauf ändert nichts")


func test_first_sale_mission_completes_chapter() -> void:
	var game := _ready_game()
	var respect := game.organisation.get_value("respect")
	assert_eq(game.sales.sell(SPOT, "weed", 3), "")
	assert_eq(game.missions.is_completed("first_deal_sale"), false)
	assert_eq(game.sales.sell(SPOT, "weed", 2), "")
	assert_eq(game.missions.is_completed("first_deal_sale"), true)
	assert_eq(game.organisation.get_value("respect"), respect + 10)


func test_first_black_money_reported() -> void:
	var game := _ready_game()
	assert_eq(game.sales.sell(SPOT, "weed", 1), "")
	assert_eq(game.tutorials.was_reported("first_black_money"), true)


func test_sales_survive_save_and_load() -> void:
	var game := _ready_game()
	game.sales.sell(SPOT, "weed", 3)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.sales.get_sold_units(), 3)
		assert_eq(loaded.supply.get_stock("weed"), 9)
	for bad in [{}, {"sold_units": -1}, {"sold_units": "x"}, {"sold_units": 1.5}]:
		assert_true(not game.sales.restore(bad).is_empty(), "angenommen: %s" % bad)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_migration_22_to_23() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v22.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v22 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.sales.get_sold_units(), 0)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_tile_opens_sale_window_and_sells() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	(app.find_child("MapPin_cafe_harbor", true, false) as Button).pressed.emit()
	assert_true(app.find_child("SaleSpotButton_%s" % SPOT, true, false) == null, "Verkaufen vor dem Versteck sichtbar")
	screen.call("_close_window")
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	var data: Dictionary = app.game.supply.to_dict()
	data["stock"] = {"weed": 6}
	app.game.supply.restore(data)
	app.game.missions.update_availability()
	app.game.locations.travel("garage")
	app.game.sites.acquire("garage_san_pedro")
	app.game.locations.travel("cafe_harbor")
	screen.call("_refresh")
	(app.find_child("MapPin_cafe_harbor", true, false) as Button).pressed.emit()
	var tile_button := app.find_child("SaleSpotButton_%s" % SPOT, true, false) as Button
	assert_true(tile_button != null, "Kachel „Ware verkaufen“ fehlt")
	if tile_button != null:
		assert_eq([tile_button.disabled, tile_button.text], [false, "Ware verkaufen"])
		tile_button.pressed.emit()
		var sell := app.find_child("SaleButton_weed", true, false) as Button
		assert_true(sell != null, "Verkaufsfenster fehlt")
		if sell != null:
			assert_eq(sell.text, "Verkaufen · +350,00 €")
			(app.find_child("SaleMore_weed", true, false) as Button).pressed.emit()
			assert_eq((app.find_child("SaleUnits_weed", true, false) as Label).text, "6")
			assert_eq((app.find_child("SaleMore_weed", true, false) as Button).disabled, true, "mehr als Bestand")
			(app.find_child("SaleButton_weed", true, false) as Button).pressed.emit()
			assert_eq(app.game.supply.get_stock("weed"), 0)
			assert_eq(app.game.ledger.get_balance(LedgerSystemScript.BLACK), 6 * 7000)
			assert_true(app.find_child("SaleEmpty", true, false) != null, "Hinweis ohne Ware")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
