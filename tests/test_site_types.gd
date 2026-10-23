extends "res://tests/base_test.gd"

## Ticket U.18: weitere Standorte (Lager, Verkaufspunkt, Club, Produktion, Liegeplatz) mit Wirkung und Ausbaustufen;
## neue Orte Club und Finca erst nach „Ein Stück Stadt“; Speichern/Laden; Migration v30 → v31.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SiteSystemScript := preload("res://scripts/systems/site_system.gd")

const SAVE_PATH := "user://test_site_types_save.json"


## Organisation, Aufträge bis „Ein Stück Stadt“ erledigt, 10.000 € Schwarzgeld – Tag 1, 10:00.
func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	var missions := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer",
			"territory_first"]:
		missions["completed"][id] = 0
	missions["active"] = []
	assert_eq(game.missions.restore(missions), "")
	game.ledger.post(1000000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _own(game: GameStateScript, site_id: String, level: int = 1) -> void:
	var data := game.sites.to_dict()
	data["owned"][site_id] = 0
	if level > 1:
		data["levels"][site_id] = level
	assert_eq(game.sites.restore(data), "")


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_real_sites_load() -> void:
	var data := Helpers.game_data()
	assert_eq(data.errors, PackedStringArray())
	assert_eq(data.sites.get_all().map(func(s) -> String: return s.type),
			["stash", "storage", "sales_point", "club", "production", "berth"])


func test_new_locations_only_after_territory() -> void:
	var game := Helpers.new_game()
	assert_eq([game.locations.is_known("club"), game.locations.is_known("finca")], [false, false])
	var ready := _ready_game()
	assert_eq([ready.locations.is_known("club"), ready.locations.is_known("finca")], [true, true])


func test_storage_adds_capacity_and_needs_stash() -> void:
	var game := _ready_game()
	game.locations.travel("garage")
	assert_eq(game.sites.check_acquire("storage_san_pedro"), "Erst „Versteck: Garage“ anmieten.")
	_own(game, "garage_san_pedro")
	assert_eq(game.sites.acquire("storage_san_pedro"), "")
	assert_eq(game.sites.capacity(), 20 + 100 + 300)


func test_production_fills_stock_within_capacity() -> void:
	var game := _ready_game()
	_own(game, "finca_hinterland")
	_next_morning(game)
	assert_eq(game.supply.get_stock("weed"), 5)
	var data := game.supply.to_dict()
	data["stock"] = {"weed": 18}
	game.supply.restore(data)
	_next_morning(game)
	assert_eq(game.supply.get_stock("weed"), 20, "nur bis Platz 20")
	assert_true(" ".join(game.sites.take_notices()).contains("Gewächshäuser: 2 × Gras produziert"))


func test_sales_point_sells_daily() -> void:
	var game := _ready_game()
	_own(game, "backroom_store")
	var data := game.supply.to_dict()
	data["stock"] = {"weed": 10}
	game.supply.restore(data)
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var heat := game.organisation.get_value("heat")
	_next_morning(game)
	assert_eq(game.supply.get_stock("weed"), 6)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black + 4 * 7000 - 3000, "Verkauf − Miete")
	assert_eq(game.organisation.get_value("heat"), maxi(0, heat - 3) + 4, "erst Abkühlung (DayCycle), dann Hitze 4")


func test_club_raises_laundering_limit() -> void:
	var game := _ready_game()
	assert_eq(game.laundering.daily_limit(), 100000)
	_own(game, "club_medusa")
	assert_eq(game.laundering.daily_limit(), 200000)
	_own(game, "club_medusa", 2)
	assert_eq(game.laundering.daily_limit(), 250000, "Stufe 2: +50 %")


func test_berth_discount() -> void:
	var game := _ready_game()
	assert_eq(game.supply.order_cost("weed", 10), 40000)
	_own(game, "berth_14")
	assert_eq(game.supply.order_cost("weed", 10), 36000)
	_own(game, "berth_14", 2)
	assert_eq(game.supply.order_cost("weed", 10), 32000, "Stufe 2: 20 %")


func test_upgrade_levels_costs_and_running() -> void:
	var game := _ready_game()
	game.locations.travel("garage")
	assert_eq(game.sites.check_upgrade("garage_san_pedro"), "Erst anmieten.")
	assert_eq(game.sites.acquire("garage_san_pedro"), "")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var minutes := game.time.get_minutes()
	assert_eq(game.sites.upgrade("garage_san_pedro"), "")
	assert_eq(game.sites.get_level("garage_san_pedro"), 2)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 25000)
	assert_eq(game.time.get_minutes(), minutes + 30)
	assert_eq(game.sites.effects("garage_san_pedro")["capacity"], 150)
	assert_eq(game.sites.effects("garage_san_pedro")["running"], 3000)
	assert_eq(game.sites.upgrade_cost("garage_san_pedro"), 50000)
	assert_eq(game.sites.upgrade("garage_san_pedro"), "")
	assert_eq(game.sites.check_upgrade("garage_san_pedro"), "Voll ausgebaut (Stufe 3).")


func test_levels_saved_and_migrated() -> void:
	var game := _ready_game()
	_own(game, "garage_san_pedro", 2)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.sites.get_level("garage_san_pedro"), 2)
	var bad := game.sites.to_dict()
	bad["levels"] = {"x": 0}
	assert_true(not game.sites.restore(bad).is_empty())
	var old := {"sites": {"owned": {}, "last_processed_day": 1}}
	assert_eq(SaveSystemScript._run_migration(30, old), "")
	assert_eq(old["sites"]["levels"], {})
	SaveSystemScript.delete_save(SAVE_PATH)
