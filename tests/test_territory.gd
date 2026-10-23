extends "res://tests/base_test.gd"

## Ticket U.13: Gebiete übernehmen, halten, verlieren – Regeln als Daten; Dealer einem Gebiet zuteilen; Einfluss aus
## der Abrechnung, Druck der Rivalen je Tag; Beanspruchen (Buchung, Respekt); Verlust unter der Grenze (Respekt,
## Stabilität); eigene Gebiete +1 Einheit je Dealer; Auftrag „Ein Stück Stadt“; Speichern/Laden; Migration v25 → v26;
## Gebietsfenster und Zuteilung in der Crew.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")
const TerritorySystemScript := preload("res://scripts/systems/territory_system.gd")

const SAVE_PATH := "user://test_territory_save.json"


## Organisation gegründet, „Der erste Dealer“ erledigt, viel Ware, 2.000 € Schwarzgeld – Tag 1, 10:00.
func _ready_game(stock: int = 200) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	var missions := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer"]:
		missions["completed"][id] = 0
	missions["active"] = []
	assert_eq(game.missions.restore(missions), "")
	game.missions.update_availability()
	var supply := game.supply.to_dict()
	supply["stock"] = {"weed": stock}
	game.supply.restore(supply)
	game.ledger.post(200000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _add_dealer(game: GameStateScript, id: String, skill: int, district: String) -> void:
	var data := game.crew.to_dict()
	data["members"].append({"id": id, "name": "N %s" % id, "role": "dealer", "skill": skill, "loyalty": 50, "greed": 0,
			"wage_cents": 100, "hired_day": game.time.get_day(), "rank": 1, "district": district})
	assert_eq(game.crew.restore(data), "")


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func _set_influence(game: GameStateScript, district: String, value: int, controlled: bool = false) -> void:
	var data := game.territory.to_dict()
	data["influence"][district] = value
	if controlled:
		data["controlled"][district] = game.time.get_day()
	assert_eq(game.territory.restore(data), "")


func test_real_rules_load() -> void:
	var rules := TerritorySystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq([rules.get_value("claim_min_influence"), rules.get_value("lose_below"), rules.get_value("claim_cost_cents")],
			[60, 30, 50000])
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_rules_are_rejected() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TerritorySystemScript.DEFAULT_PATH))
	var rules := TerritorySystemScript.Rules.new()
	assert_true(rules.load_data(good), "; ".join(rules.errors))
	for change in [{"rival_divisor": 0}, {"lose_below": 70}, {"claim_min_influence": 101}, {"extra": 1},
			{"claim_cost_cents": -1}, {"influence_base": "x"}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(rules.load_data(bad), false, "angenommen: %s" % change)


func test_assign_only_dealers_to_known_districts() -> void:
	var game := _ready_game()
	_add_dealer(game, "d1", 40, "")
	assert_eq(game.crew.assign("d1", "san_pedro"), "")
	assert_eq(game.crew.count_in_district("san_pedro"), 1)
	assert_eq(game.crew.assign("d1", "moon"), "Unbekanntes Gebiet: moon")
	assert_eq(game.crew.assign("x", "san_pedro"), "Dieses Mitglied gibt es nicht.")
	assert_eq(game.crew.assign("d1", ""), "")
	assert_eq(game.crew.count_in_district("san_pedro"), 0)


func test_dealer_brings_influence_rivals_press() -> void:
	var game := _ready_game()
	_add_dealer(game, "d1", 40, "san_pedro")
	_add_dealer(game, "d2", 40, "")
	_next_morning(game)
	# Können 40 → 2 + 2 = 4 Einfluss; Rivalen 40 → −2
	assert_eq(game.territory.get_influence("san_pedro"), 2)
	for district in ["altstadt", "nueva_andalucia", "puerto_banus"]:
		assert_eq(game.territory.get_influence(district), 0, "ohne Dealer kein Einfluss in %s" % district)


func test_no_sale_no_influence() -> void:
	var game := _ready_game(0)
	_add_dealer(game, "d1", 80, "san_pedro")
	_next_morning(game)
	assert_eq(game.territory.get_influence("san_pedro"), 0)


func test_claim() -> void:
	var game := _ready_game()
	_set_influence(game, "san_pedro", 59)
	assert_eq(game.territory.check_claim("san_pedro"), "Erst 60 Einfluss (jetzt 59).")
	_set_influence(game, "san_pedro", 60)
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var respect := game.organisation.get_value("respect")
	assert_eq(game.territory.claim("san_pedro"), "")
	assert_eq(game.territory.is_controlled("san_pedro"), true)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 50000)
	assert_eq(game.organisation.get_value("respect"), respect + 5 + 10, "Beanspruchen +5, Auftrag „Ein Stück Stadt“ +10")
	assert_eq(game.territory.check_claim("san_pedro"), "Gehört schon dir.")
	assert_eq(game.missions.is_completed("territory_first"), true, "Auftrag „Ein Stück Stadt“")


func test_controlled_bonus_and_half_pressure() -> void:
	var game := _ready_game()
	_set_influence(game, "puerto_banus", 80, true)
	assert_eq(game.territory.rival_pressure("puerto_banus"), 1, "Rivalen 50 → 2, eigenes Gebiet halb")
	assert_eq(game.territory.unit_bonus("puerto_banus"), 1)
	_add_dealer(game, "d1", 40, "puerto_banus")
	var stock := game.supply.get_stock("weed")
	_next_morning(game)
	var sold := stock - game.supply.get_stock("weed")
	assert_true(sold == 5 or sold == 6, "4–5 + 1 Einheiten, verkauft: %d" % sold)


func test_losing_a_district() -> void:
	var game := _ready_game()
	_set_influence(game, "puerto_banus", 30, true)
	game.organisation.change({"respect": 20})
	var respect := game.organisation.get_value("respect")
	var stability := game.organisation.get_value("stability")
	_next_morning(game)
	assert_eq(game.territory.is_controlled("puerto_banus"), false, "unter 30 → verloren")
	assert_eq(game.organisation.get_value("respect"), respect - 5)
	assert_eq(game.organisation.get_value("stability"), stability - 5)
	assert_true(" ".join(game.territory.take_notices()).contains("Gebiet verloren: Puerto Banús"))


func test_once_per_day_and_deterministic() -> void:
	var game := _ready_game()
	_set_influence(game, "altstadt", 50)
	_next_morning(game)
	assert_eq(game.territory.get_influence("altstadt"), 49)
	game.territory.on_day_changed(game.time.get_day())
	assert_eq(game.territory.get_influence("altstadt"), 49, "nicht doppelt")


func test_territory_survives_save_and_migration() -> void:
	var game := _ready_game()
	_add_dealer(game, "d1", 40, "altstadt")
	_set_influence(game, "san_pedro", 70, true)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.territory.to_dict(), game.territory.to_dict())
		assert_eq(loaded.crew.get_member("d1")["district"], "altstadt")
	for bad in [{}, {"influence": {"a": 101}, "controlled": {}, "last_processed_day": 1},
			{"influence": {}, "controlled": {"a": "x"}, "last_processed_day": 1}, {"influence": {}, "controlled": {}}]:
		assert_true(not game.territory.restore(bad).is_empty(), "angenommen: %s" % bad)
	var old := {"time": {"minutes": 3000}, "crew": {"members": [{"id": "x"}], "gone_today": [], "last_processed_day": 1}}
	assert_eq(SaveSystemScript._run_migration(25, old), "")
	assert_eq([old["crew"]["members"][0]["district"], old["territory"]["last_processed_day"]], ["", 3])
	assert_true(not SaveSystemScript._run_migration(25, {"time": {"minutes": 1}}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_district_window_claim_and_crew_assign() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_territory_settings.cfg"
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.ledger.post(200000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	_add_dealer(app.game, "d1", 40, "")
	var missions: Dictionary = app.game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
		missions["completed"][id] = 0
	missions["active"] = []
	app.game.missions.restore(missions)
	screen.call("open_crew")
	var assign := app.find_child("CrewDistrictButton_d1", true, false) as Button
	assert_eq(assign.text, "Gebiet: keins")
	assign.pressed.emit()
	assert_eq(app.game.crew.get_member("d1")["district"], "san_pedro")
	assert_eq((app.find_child("CrewDistrictButton_d1", true, false) as Button).text, "Gebiet: San Pedro")
	screen.call("_close_window")
	_set_influence(app.game, "san_pedro", 65)
	screen.call("set_underworld_view", true)
	(app.find_child("DistrictLabel_san_pedro", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("DistrictInfluence", true, false) as Label).text,
			"Dein Einfluss: 65 von 100 · Dealer hier: 1 · Rivalen drücken −2 am Tag")
	var claim := app.find_child("DistrictClaimButton", true, false) as Button
	assert_eq([claim.disabled, claim.text], [false, "Beanspruchen · 500,00 €"])
	claim.pressed.emit()
	assert_eq(app.game.territory.is_controlled("san_pedro"), true)
	assert_eq((app.find_child("DistrictLabel_san_pedro", true, false) as Button).text, "San Pedro · deins")
	assert_eq((app.find_child("DistrictStatus", true, false) as Label).text, "Gehört dir seit Tag 1.")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_territory_settings.cfg"))
