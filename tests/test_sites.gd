extends "res://tests/base_test.gd"

## Ticket U.8: Standorte der Unterwelt – Katalog (Felder nach Leitfaden 9.3); die Garage ist bis „Die erste Ware“
## unbekannt (nicht auf der Karte, nicht anfahrbar); Anmieten vor Ort (Startkosten, Spielzeit); laufende Kosten am
## Tageswechsel (Schwarzgeld, ersatzweise privat, sonst Frist); Kapazität begrenzt Bestellungen; Auftrag „Ein sicherer
## Ort“; Speichern/Laden; Migration v21 → v22.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SiteCatalogScript := preload("res://scripts/systems/site_catalog.gd")

const SAVE_PATH := "user://test_sites_save.json"
const GARAGE := "garage_san_pedro"


## Organisation, „Treffen am Hafen“ und „Die erste Ware“ erledigt (5 Gras im Bestand), 10:00 im Café.
func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	var data := game.supply.to_dict()
	data["stock"] = {"weed": 5}
	game.supply.restore(data)
	game.missions.update_availability()
	assert_eq(game.missions.is_completed("first_deal_goods"), true)
	return game


func test_real_sites_load() -> void:
	var catalog := SiteCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var garage = catalog.get_definition(GARAGE)
	assert_eq([garage.type, garage.location, garage.capacity_units, garage.start_cost_cents,
			garage.running_cost_per_day_cents], ["stash", "garage", 100, 30000, 2000])
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_sites_are_rejected() -> void:
	var good := {"id": "s_a", "display_name": "S", "type": "stash", "location": "garage", "description": "D.",
			"unlocked_by_mission": "first_deal_goods", "start_cost_cents": 1, "running_cost_per_day_cents": 1,
			"setup_minutes": 0, "capacity_units": 1, "staff_slots": 0, "productivity_per_day": 0, "risk": 5,
			"activities": [], "requires": [], "product": "", "sale_units_per_day": 0, "laundering_limit_cents": 0,
			"supplier_discount_percent": 0, "max_level": 1, "upgrade_cost_cents": 0, "upgrade_percent": 0}
	var catalog := SiteCatalogScript.new()
	assert_true(catalog.load_data([good]), "; ".join(catalog.errors))
	for change in [{"type": "castle"}, {"risk": 101}, {"capacity_units": -1}, {"extra": 1}, {"requires": "x"}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(catalog.load_data([bad]), false, "angenommen: %s" % change)
	var data := Helpers.game_data()
	var unknown := good.duplicate()
	unknown["location"] = "moon"
	assert_true(data.sites.load_data([unknown]))
	assert_true(not data.check_references().is_empty())


func test_garage_unknown_until_goods() -> void:
	var game := Helpers.new_game()
	assert_eq(game.locations.is_known("garage"), false)
	assert_eq(game.locations.check_travel("garage"), "Diesen Ort kennst du noch nicht.")
	assert_eq(game.sites.check_acquire(GARAGE), "Diesen Standort kennst du noch nicht.")
	var ready := _ready_game()
	assert_eq(ready.locations.is_known("garage"), true)
	assert_eq(ready.missions.is_active("first_deal_stash"), true, "Auftrag „Ein sicherer Ort“")


func test_acquire_on_site_costs_and_takes_time() -> void:
	var game := _ready_game()
	assert_eq(game.sites.check_acquire(GARAGE), "Nur vor Ort möglich: Garage in San Pedro.")
	assert_eq(game.locations.travel("garage"), "")
	var private := game.ledger.get_balance()
	var minutes := game.time.get_minutes()
	var respect := game.organisation.get_value("respect")
	assert_eq(game.sites.acquire(GARAGE), "")
	assert_eq(game.ledger.get_balance(), private - 30000, "Startkosten vom Privatkonto (kein Schwarzgeld)")
	assert_eq(game.time.get_minutes(), minutes + 30)
	assert_eq(game.sites.is_owned(GARAGE), true)
	assert_eq(game.sites.capacity(), 120)
	assert_eq(game.missions.is_completed("first_deal_stash"), true)
	assert_eq(game.organisation.get_value("respect"), respect + 5)
	assert_eq(game.sites.acquire(GARAGE), "Gehört schon dir.")


func test_running_costs_each_day_once() -> void:
	var game := _ready_game()
	game.locations.travel("garage")
	game.sites.acquire(GARAGE)
	game.ledger.post(5000, "test", "Test", "test", "", "", false, LedgerSystemScript.BLACK)
	game.time.advance(TimeSystemScript.at(3, 8) - game.time.get_minutes())  # Tag 2 und 3
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), 5000 - 2 * 2000, "zweimal 20 € Schwarzgeld")
	var copy := Helpers.new_game()
	assert_eq(copy.restore(game.to_dict()), "")
	copy.sites.on_day_changed(3)
	assert_eq(copy.ledger.get_balance(LedgerSystemScript.BLACK), 1000, "nach dem Laden nicht noch einmal")


func test_unpaid_running_costs_become_obligation() -> void:
	var game := _ready_game()
	game.locations.travel("garage")
	game.sites.acquire(GARAGE)
	game.ledger.post(-game.ledger.get_balance(), "test", "Test: alles weg", "test")
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
	var instance: Dictionary = game.obligations.get_instance("site_%s@2" % GARAGE)
	assert_eq(instance["status"], "open")
	assert_eq(instance["amount_cents"], 2000)


func test_capacity_limits_orders() -> void:
	var game := _ready_game()  # 5 im Bestand, Grundplatz 20
	game.ledger.post(200000, "test", "Test: Geld genug", "test")
	assert_eq(game.supply.check_order("el_rubio", "weed", 15), "")
	assert_eq(game.supply.check_order("el_rubio", "weed", 16), "Kein Platz: noch 15 Einheiten frei (Bestand + unterwegs).")
	game.supply.order("el_rubio", "weed", 10)
	assert_eq(game.supply.check_order("el_rubio", "weed", 6), "Kein Platz: noch 5 Einheiten frei (Bestand + unterwegs).")
	game.locations.travel("garage")
	game.sites.acquire(GARAGE)
	assert_eq(game.supply.check_space(105), "")


func test_sites_survive_save_and_load() -> void:
	var game := _ready_game()
	game.locations.travel("garage")
	game.sites.acquire(GARAGE)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.sites.is_owned(GARAGE), true)
		assert_eq(loaded.sites.capacity(), 120)
	for bad in [{"owned": "x", "last_processed_day": 1}, {"owned": {"a": -1}, "last_processed_day": 1}, {"owned": {}}]:
		assert_true(not game.sites.restore(bad).is_empty(), "angenommen: %s" % bad)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_migration_21_to_22() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v21.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v21 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.sites.get_owned().size(), 0)
		assert_eq(game.sites.capacity(), 20)
	assert_true(not SaveSystemScript._run_migration(21, {"time": "x"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_map_hides_garage_then_card_rents() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	assert_eq((app.find_child("MapPin_garage", true, false) as Control).visible, false, "Garage vorab auf der Karte")
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	var data: Dictionary = app.game.supply.to_dict()
	data["stock"] = {"weed": 5}
	app.game.supply.restore(data)
	app.game.missions.update_availability()
	screen.call("_refresh")
	assert_eq((app.find_child("MapPin_garage", true, false) as Control).visible, true, "Garage nach „Die erste Ware“")
	(app.find_child("MapPin_garage", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("SiteButton_%s" % GARAGE, true, false) as Button).text, "Nur vor Ort möglich: Garage in San Pedro.")
	(app.find_child("TravelButton", true, false) as Button).pressed.emit()
	var button := app.find_child("SiteButton_%s" % GARAGE, true, false) as Button
	assert_eq([button.disabled, button.text], [false, "Anmieten"])
	button.pressed.emit()
	assert_eq(app.game.sites.is_owned(GARAGE), true)
	# Seit U.18: eigener Standort zeigt „Ausbauen“ (Stufe 1 von 3) und seine Wirkung.
	assert_eq(button.visible, true)
	assert_true(button.text.begins_with("Ausbauen · 250,00 €") or button.disabled, button.text)
	assert_eq((app.find_child("SiteInfo_%s" % GARAGE, true, false) as Label).text, "Versteck · Platz +100")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_capacity_line() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	app.game.supply.order("el_rubio", "weed", 3)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("StockCapacity", true, false) as Label).text, "Platz für Ware: 3 von 20 belegt (davon unterwegs 3)")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
