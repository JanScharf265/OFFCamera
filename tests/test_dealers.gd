extends "res://tests/base_test.gd"

## Ticket U.11: Crew 2 – Dealer verkaufen täglich (Unterwelt-Abrechnung im DayCycle, eine Buchung aufs Schwarzgeld),
## Können (mehr Einheiten, weniger Hitze), Gier (zweigt ab), Loyalität (Lohn pünktlich +, unbezahlt −); Befördern;
## Migration v24 → v25; Anzeige im Fenster „Crew“.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")

const SAVE_PATH := "user://test_dealers_save.json"


## Organisation, Kapitel „Erster Deal“ erledigt, `stock` Gras im Bestand, Tag 1 10:00 – Crew möglich.
func _ready_game(stock: int = 40) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	var data := game.supply.to_dict()
	data["stock"] = {"weed": 5}
	game.supply.restore(data)
	game.missions.update_availability()
	game.locations.travel("garage")
	assert_eq(game.sites.acquire("garage_san_pedro"), "")
	game.locations.travel("cafe_harbor")
	assert_eq(game.sales.sell("harbor_after_hours", "weed", 5), "")
	data = game.supply.to_dict()
	data["stock"] = {"weed": stock}
	game.supply.restore(data)
	return game


## Setzt ein Mitglied direkt (feste Werte statt Bewerber).
func _add(game: GameStateScript, id: String, skill: int, greed: int, loyalty: int = 50, wage: int = 4000) -> void:
	var data := game.crew.to_dict()
	data["members"].append({"id": id, "name": "N %s" % id, "role": "dealer", "skill": skill, "loyalty": loyalty,
			"greed": greed, "wage_cents": wage, "hired_day": game.time.get_day(), "rank": 1, "district": ""})
	assert_eq(game.crew.restore(data), "")


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_real_rules_load() -> void:
	var catalog := CrewSystemScript.Catalog.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq([catalog.dealing["role"], catalog.dealing["base_units"], catalog.promotion["max_rank"]], ["dealer", 2, 3])


func test_bad_rules_are_rejected() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CrewSystemScript.DEFAULT_PATH))
	var catalog := CrewSystemScript.Catalog.new()
	assert_true(catalog.load_data(good), "; ".join(catalog.errors))
	for change in [{"dealing": {"role": "dealer"}}, {"dealing": "x"}, {"promotion": {}}]:
		var bad := good.duplicate(true)
		bad.merge(change, true)
		assert_eq(catalog.load_data(bad), false, "angenommen: %s" % change)
	var unknown_role := good.duplicate(true)
	unknown_role["dealing"]["role"] = "boss"
	assert_eq(catalog.load_data(unknown_role), false, "unbekannte Rolle")


func test_values_follow_skill_and_greed() -> void:
	var game := _ready_game()
	var low := {"id": "a", "skill": 20, "greed": 20, "role": "dealer"}
	var high := {"id": "b", "skill": 80, "greed": 80, "role": "dealer"}
	assert_eq([game.crew.dealer_units(low), game.crew.dealer_units(high)], [3, 6])
	assert_eq([game.crew.skim_percent(low), game.crew.skim_percent(high)], [4, 16])
	assert_eq([game.crew.heat_percent(low), game.crew.heat_percent(high)], [90, 60])


func test_dealer_sells_at_next_morning() -> void:
	var game := _ready_game()
	_add(game, "d1", 40, 50)
	var member := game.crew.get_member("d1")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var heat := game.organisation.get_value("heat")
	_next_morning(game)
	var entries := game.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY)
	assert_eq(entries.size(), 1, "eine Abrechnung je Tag")
	var units := 40 - game.supply.get_stock("weed")
	assert_true(units == 4 or units == 5, "Einheiten %d" % units)
	var gross := units * 7000
	assert_eq(entries[0].amount_cents, gross - gross * 10 / 100, "10 % abgezweigt (Gier 50)")
	assert_eq(entries[0].account, LedgerSystemScript.BLACK)
	assert_eq(game.organisation.get_value("heat"), heat + units * 80 / 100, "Hitze 80 % (Können 40)")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK),
			black + entries[0].amount_cents - member["wage_cents"] - 2000, "Abrechnung – Lohn – Garage")
	assert_true(" ".join(game.crew.take_notices()).contains("Abrechnung: Deine Dealer haben %d Einheiten verkauft" % units))


func test_sales_are_deterministic_and_once_per_day() -> void:
	var a := _ready_game()
	var b := _ready_game()
	_add(a, "d1", 50, 30)
	_add(b, "d1", 50, 30)
	for i in 3:
		_next_morning(a)
		_next_morning(b)
	assert_eq(a.supply.get_stock("weed"), b.supply.get_stock("weed"))
	assert_eq(a.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY).size(), 3)
	a.crew.on_day_changed(a.time.get_day())
	assert_eq(a.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY).size(), 3, "nicht doppelt")


func test_no_stock_no_sale() -> void:
	var game := _ready_game(0)
	_add(game, "d1", 50, 30)
	_next_morning(game)
	assert_eq(game.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY).size(), 0)
	assert_true(" ".join(game.crew.take_notices()).contains("keine Ware"))


func test_stock_limits_sales() -> void:
	var game := _ready_game(2)
	_add(game, "d1", 80, 0)
	_next_morning(game)
	assert_eq(game.supply.get_stock("weed"), 0)
	assert_eq(game.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY)[0].amount_cents, 2 * 7000)


func test_hired_today_sells_from_tomorrow() -> void:
	var game := _ready_game()
	var applicant: Dictionary = game.crew.get_applicants()[0]
	assert_eq(game.crew.hire(applicant["id"]), "")
	_next_morning(game)
	assert_eq(game.ledger.get_entries_by_category(CrewSystemScript.SALES_CATEGORY).size(), 1,
			"am Einstellungstag verkauft er schon (abgerechnet am nächsten Morgen)")


func test_loyalty_follows_wages() -> void:
	var game := _ready_game(0)
	_add(game, "d1", 50, 30, 50)
	_next_morning(game)
	assert_eq(game.crew.get_member("d1")["loyalty"], 51, "Lohn bezahlt")
	_add(game, "rich", 50, 30, 50, 100000000)
	_next_morning(game)
	assert_eq(game.crew.get_member("d1")["loyalty"], 41, "Lohn nicht bezahlt")


func test_promote() -> void:
	var game := _ready_game()
	_add(game, "d1", 50, 30, 50, 4000)
	assert_eq(game.crew.check_promote("d1"), "Erst nach 3 Tagen (noch 3).")
	for i in 3:
		_next_morning(game)
	var before := game.crew.get_member("d1")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_eq(game.crew.check_promote("d1"), "")
	assert_eq(game.crew.promote("d1"), "")
	var after := game.crew.get_member("d1")
	assert_eq([after["rank"], after["skill"], after["loyalty"], after["wage_cents"]],
			[2, before["skill"] + 10, before["loyalty"] + 10, 5000])
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 5 * 4000)
	var data := game.crew.to_dict()
	data["members"][0]["rank"] = 3
	game.crew.restore(data)
	assert_eq(game.crew.check_promote("d1"), "Höchster Rang erreicht.")


func test_crew_with_rank_survives_save_and_migration() -> void:
	var game := _ready_game()
	_add(game, "d1", 50, 30)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.crew.get_members(), game.crew.get_members())
	var old := {"crew": {"members": [{"id": "x", "name": "N", "role": "dealer", "skill": 1, "loyalty": 1, "greed": 1,
			"wage_cents": 1, "hired_day": 1}], "gone_today": [], "last_processed_day": 1}}
	assert_eq(SaveSystemScript._run_migration(24, old), "")
	assert_eq(old["crew"]["members"][0]["rank"], 1)
	assert_true(not SaveSystemScript._run_migration(24, {}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_dealer_card_and_promote() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	var missions: Dictionary = app.game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
		missions["completed"][id] = 0
	missions["active"] = []
	assert_eq(app.game.missions.restore(missions), "")
	_add(app.game, "d1", 40, 50, 50, 4000)
	var data: Dictionary = app.game.crew.to_dict()
	data["members"][0]["hired_day"] = 0
	data["last_processed_day"] = app.game.time.get_day()
	app.game.crew.restore(data)
	var ledger_black := LedgerSystemScript.BLACK
	app.game.ledger.post(100000, "test", "Start", "test", "t", "", false, ledger_black)
	app.game.time.advance(TimeSystemScript.at(3, 10) - app.game.time.get_minutes())
	screen.call("_refresh")
	screen.call("open_crew")
	var info := app.find_child("CrewDealerInfo_d1", true, false) as Label
	assert_true(info != null, "Dealer-Zeile fehlt")
	if info != null:
		assert_eq(info.text, "Verkauft 4–5 Einheiten am Tag · zweigt 10 % ab · Hitze 80 %")
	var promote := app.find_child("CrewPromoteButton_d1", true, false) as Button
	assert_eq([promote.disabled, promote.text], [false, "Befördern · 200,00 €"])
	promote.pressed.emit()
	assert_eq(app.game.crew.get_member("d1")["rank"], 2)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
