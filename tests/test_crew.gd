extends "res://tests/base_test.gd"

## Ticket U.10: Crew 1 – Rollen als Daten; Bewerber je Tag aus Seed und Tag (deterministisch, auch nach dem Laden);
## einstellen/feuern; Löhne im Tageswechsel (Schwarzgeld, ersatzweise privat, sonst Frist); Auftrag „Der erste
## Dealer“; Speichern/Laden; Migration v23 → v24; Fenster „Crew“.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")

const SAVE_PATH := "user://test_crew_save.json"


## Organisation gegründet, Kapitel „Erster Deal“ bis „Der erste Verkauf“ erledigt – Tag 1, 10:00 im Café.
func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	var data := game.supply.to_dict()
	data["stock"] = {"weed": 10}
	game.supply.restore(data)
	game.missions.update_availability()
	game.locations.travel("garage")
	assert_eq(game.sites.acquire("garage_san_pedro"), "")
	game.locations.travel("cafe_harbor")
	assert_eq(game.sales.sell("harbor_after_hours", "weed", 5), "")
	assert_eq(game.missions.is_completed("first_deal_sale"), true)
	return game


## Erster Bewerber mit dieser Rolle in den nächsten Tagen (springt dafür vor).
func _applicant_with_role(game: GameStateScript, role: String) -> Dictionary:
	for i in 20:
		for applicant in game.crew.get_applicants():
			if applicant["role"] == role:
				return applicant
		game.time.advance(TimeSystemScript.MINUTES_PER_DAY)
	return {}


func test_real_crew_data_loads() -> void:
	var catalog := CrewSystemScript.Catalog.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_roles().map(func(role) -> String: return role.id), ["dealer", "runner", "driver", "guard"])
	assert_eq([catalog.unlocked_by_mission, catalog.max_members, catalog.applicants_per_day], ["first_deal_sale", 6, 3])
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_crew_data_is_rejected() -> void:
	var good := {"unlocked_by_mission": "first_deal_sale", "max_members": 1, "applicants_per_day": 1,
			"first_names": ["A"], "last_initials": ["B."],
			"dealing": {"role": "r", "base_units": 1, "skill_per_extra_unit": 1, "skim_percent_per_10_greed": 0,
			"heat_skill_percent": 0, "loyalty_paid": 0, "loyalty_unpaid": 0},
			"promotion": {"max_rank": 1, "min_days": 0, "cost_wage_days": 0, "skill_bonus": 0, "loyalty_bonus": 0,
			"wage_percent": 100}, "risks": JSON.parse_string(FileAccess.get_file_as_string(CrewSystemScript.DEFAULT_PATH))["risks"],
			"roles": [{"id": "r", "display_name": "R",
			"description": "D.", "wage_min_cents": 1, "wage_max_cents": 2, "order": 1, "offered": true}]}
	var catalog := CrewSystemScript.Catalog.new()
	assert_true(catalog.load_data(good), "; ".join(catalog.errors))
	for change in [{"max_members": 0}, {"first_names": []}, {"roles": []}, {"extra": 1}, {"last_initials": [5]},
			{"roles": [{"id": "r", "display_name": "R", "description": "D.", "wage_min_cents": 5, "wage_max_cents": 2,
			"order": 1, "offered": true}]},
			{"roles": [{"id": "r", "display_name": "R", "description": "D.", "wage_min_cents": 1, "wage_max_cents": 2,
			"order": 1, "offered": false}]},
			{"roles": [{"id": "r", "display_name": "R", "description": "D.", "wage_min_cents": 1, "wage_max_cents": 2,
			"order": 1}]}]:
		var bad := good.duplicate(true)
		bad.merge(change, true)
		assert_eq(catalog.load_data(bad), false, "angenommen: %s" % change)
	var data := Helpers.game_data()
	var unknown := good.duplicate(true)
	unknown["unlocked_by_mission"] = "nope"
	assert_true(data.crew.load_data(unknown))
	assert_true(not data.check_references().is_empty())


func test_no_crew_before_first_sale() -> void:
	var game := Helpers.new_game()
	assert_eq(game.crew.is_available(), false)
	assert_eq(game.crew.get_applicants(), [])
	var ready := _ready_game()
	assert_eq(ready.crew.is_available(), true)
	assert_eq(ready.crew.get_applicants().size(), 3)
	assert_eq(ready.missions.is_active("crew_first_dealer"), true, "Auftrag „Der erste Dealer“")


func test_applicants_are_deterministic_and_change_daily() -> void:
	var game := _ready_game()
	var other := _ready_game()
	assert_eq(game.crew.get_applicants(), other.crew.get_applicants(), "gleicher Seed, gleiche Bewerber")
	var today: Array = game.crew.get_applicants()
	for applicant in today:
		for key in CrewSystemScript.VALUE_KEYS:
			assert_true(applicant[key] >= 20 and applicant[key] <= 80, "%s außerhalb" % key)
		var role = game.crew.get_catalog().get_role(applicant["role"])
		assert_true(applicant["wage_cents"] >= role.wage_min_cents and applicant["wage_cents"] <= role.wage_max_cents)
	game.time.advance(TimeSystemScript.MINUTES_PER_DAY)
	assert_true(game.crew.get_applicants() != today, "neuer Tag, neue Bewerber")


## GD nach U.10: vorerst nur Dealer als Bewerber; Läufer, Fahrer, Schutz bleiben in den Daten, kommen aber nicht.
func test_only_dealers_are_offered() -> void:
	var game := _ready_game()
	assert_eq(game.crew.get_catalog().get_offered_roles().map(func(role) -> String: return role.id), ["dealer"])
	assert_eq(game.crew.get_catalog().has_role("guard"), true, "Rolle bleibt in den Daten")
	for i in 30:
		for applicant in game.crew.get_applicants():
			assert_eq(applicant["role"], "dealer", "Tag %d" % game.time.get_day())
		game.time.advance(TimeSystemScript.MINUTES_PER_DAY)


func test_hire_and_fire() -> void:
	var game := _ready_game()
	var applicant: Dictionary = game.crew.get_applicants()[0]
	var private := game.ledger.get_balance()
	assert_eq(game.crew.hire(applicant["id"]), "")
	assert_eq(game.ledger.get_balance(), private, "Einstellen kostet nichts sofort")
	assert_eq(game.crew.get_members().size(), 1)
	assert_eq(game.crew.get_applicants().size(), 2, "eingestellt = kein Bewerber mehr")
	assert_eq(game.crew.hire(applicant["id"]), "Diesen Bewerber gibt es heute nicht.")
	assert_eq(game.crew.fire(applicant["id"]), "")
	assert_eq(game.crew.get_members().size(), 0)
	assert_eq(game.crew.get_applicants().size(), 2, "gefeuert = heute nicht wieder Bewerber")
	assert_eq(game.crew.fire("x"), "Dieses Mitglied gibt es nicht.")


func test_crew_limit() -> void:
	var game := _ready_game()
	var data := game.crew.to_dict()
	for i in 6:
		data["members"].append({"id": "m%d" % i, "name": "N", "role": "runner", "skill": 50, "loyalty": 50, "greed": 50,
				"wage_cents": 100, "hired_day": 1, "rank": 1, "district": ""})
	assert_eq(game.crew.restore(data), "")
	assert_eq(game.crew.check_hire(game.crew.get_applicants()[0]["id"]), "Crew ist voll (6).")


func test_wages_paid_at_day_change() -> void:
	var game := _ready_game()
	var applicant: Dictionary = game.crew.get_applicants()[0]
	game.crew.hire(applicant["id"])
	var stock := game.supply.to_dict()
	stock["stock"] = {}
	game.supply.restore(stock)  # ohne Ware keine Abrechnung (U.11) – nur der Lohn
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	game.time.advance(TimeSystemScript.at(2, 10) - game.time.get_minutes())
	var entries := game.ledger.get_entries_by_category(CrewSystemScript.CATEGORY)
	assert_eq(entries.size(), 1, "eine Lohnbuchung je Tag")
	assert_eq(entries[0].amount_cents, -int(applicant["wage_cents"]))
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - int(applicant["wage_cents"]) - 2000,
			"aus dem Schwarzgeld (350 € vom Verkauf; dazu 20 € Miete für die Garage)")


func test_unpaid_wages_become_obligation() -> void:
	var game := _ready_game()
	var data := game.crew.to_dict()
	data["members"].append({"id": "m", "name": "N", "role": "guard", "skill": 50, "loyalty": 50, "greed": 50,
			"wage_cents": 10000000, "hired_day": 1, "rank": 1, "district": ""})
	assert_eq(game.crew.restore(data), "")
	game.time.advance(TimeSystemScript.at(2, 10) - game.time.get_minutes())
	assert_eq(game.ledger.get_entries_by_category(CrewSystemScript.CATEGORY).size(), 0)
	assert_true(" ".join(game.crew.take_notices()).contains("offen unter „Fristen“"))


func test_first_dealer_mission() -> void:
	var game := _ready_game()
	var respect := game.organisation.get_value("respect")
	var dealer := _applicant_with_role(game, "dealer")
	assert_true(not dealer.is_empty(), "kein Dealer in 20 Tagen")
	assert_eq(game.crew.hire(dealer["id"]), "")
	assert_eq(game.missions.is_completed("crew_first_dealer"), true)
	assert_eq(game.organisation.get_value("respect"), respect + 5)


func test_crew_survives_save_and_load() -> void:
	var game := _ready_game()
	var applicants: Array = game.crew.get_applicants()
	game.crew.hire(applicants[0]["id"])
	game.crew.hire(applicants[1]["id"])
	game.crew.fire(applicants[1]["id"])
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.crew.get_members(), game.crew.get_members())
		assert_eq(loaded.crew.get_applicants(), game.crew.get_applicants(), "gleiche Bewerber nach dem Laden")
	for bad in [{}, {"members": "x", "gone_today": [], "last_processed_day": 1},
			{"members": [{"id": "a"}], "gone_today": [], "last_processed_day": 1},
			{"members": [], "gone_today": [1], "last_processed_day": 1}, {"members": [], "gone_today": []}]:
		assert_true(not game.crew.restore(bad).is_empty(), "angenommen: %s" % bad)
	SaveSystemScript.delete_save(SAVE_PATH)


func test_migration_23_to_24() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v23.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game: GameStateScript = result["game"]
	assert_true(game != null, "v23 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.crew.get_members(), [])
	assert_true(not SaveSystemScript._run_migration(23, {"time": "x"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_crew_window_hire_and_fire() -> void:
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
	assert_true(app.find_child("CrewButton", true, false) == null, "Crew vor dem ersten Verkauf")
	var data: Dictionary = app.game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
		data["completed"][id] = 0
	data["active"] = []
	assert_eq(app.game.missions.restore(data), "")
	app.game.missions.update_availability()
	screen.call("_close_window")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	var crew_button := app.find_child("CrewButton", true, false) as Button
	assert_true(crew_button != null, "Button „Crew“ fehlt")
	if crew_button != null:
		assert_eq(crew_button.text, "Crew (0)")
		crew_button.pressed.emit()
		var first: Dictionary = app.game.crew.get_applicants()[0]
		var hire := app.find_child("CrewHireButton_%s" % first["id"], true, false) as Button
		assert_eq([hire.disabled, hire.text], [false, "Einstellen"])
		hire.pressed.emit()
		assert_eq(app.game.crew.get_members().size(), 1)
		assert_true(app.find_child("CrewFireButton_%s" % first["id"], true, false) != null, "Mitglied fehlt")
		(app.find_child("CrewFireButton_%s" % first["id"], true, false) as Button).pressed.emit()
		assert_eq(app.game.crew.get_members().size(), 0)
		assert_true(app.find_child("CrewEmpty", true, false) != null)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
