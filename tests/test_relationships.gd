extends "res://tests/base_test.gd"

## Ticket U.23: Beziehungen – Kontakte als Daten (Hafen-Kontakt, Partnerschaft, käuflicher Beamter) mit Vertrauen und
## Wissen; Aktion mit Spielzeit, Buchung, Wirkung und Wartezeit; Vertrauen sinkt ohne Kontakt; Ereignisse bei
## passenden Werten (Optionsfeld „contact“); Speichern/Laden; Migration v34 → v35; Fenster „Kontakte“.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const RelationshipSystemScript := preload("res://scripts/systems/relationship_system.gd")

const SAVE_PATH := "user://test_relationships_save.json"


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
	game.ledger.post(500000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _put(game: GameStateScript, id: String, trust: int, knowledge: int) -> void:
	var data := game.relationships.to_dict()
	data["contacts"][id] = {"trust": trust, "knowledge": knowledge, "last_action_day": game.time.get_day(),
			"last_event_day": -100}
	assert_eq(game.relationships.restore(data), "")


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_catalog_loads() -> void:
	var catalog := RelationshipSystemScript.Catalog.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_all().map(func(c) -> String: return c.id), ["capitan", "partner", "officer"])
	assert_eq(Helpers.game_data().errors, PackedStringArray())
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RelationshipSystemScript.DEFAULT_PATH))
	var bad := good.duplicate(true)
	bad["contacts"][0]["action"]["cooldown_days"] = 0
	assert_eq(RelationshipSystemScript.Catalog.new().load_data(bad), false)
	bad = good.duplicate(true)
	bad["contacts"][0]["start_trust"] = 101
	assert_eq(RelationshipSystemScript.Catalog.new().load_data(bad), false)


func test_known_contacts_follow_missions() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	assert_eq(game.relationships.get_known().map(func(c) -> String: return c.id), ["partner"])
	var ready := _ready_game()
	assert_eq(ready.relationships.get_known().map(func(c) -> String: return c.id), ["capitan", "partner", "officer"])


func test_partner_evening() -> void:
	var game := _ready_game()
	var private := game.ledger.get_balance()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var mood := game.stats.mood
	var minutes := game.time.get_minutes()
	assert_eq(game.relationships.act("partner"), "")
	assert_eq(game.relationships.get_trust("partner"), 78)
	assert_eq(game.time.get_minutes(), minutes + 180)
	assert_eq(game.stats.mood, mini(100, mood + 12))
	assert_eq(game.ledger.get_balance() + game.ledger.get_balance(LedgerSystemScript.BLACK), private + black - 6000)
	assert_eq(game.relationships.check_action("partner"), "Erst wieder in 1 Tag.")


func test_officer_lowers_file_and_heat() -> void:
	var game := _ready_game()
	game.organisation.change({"heat": 50})
	var police := game.police.to_dict()
	police.merge({"level": 2, "case": "MB-1", "progress": 40}, true)
	game.police.restore(police)
	assert_eq(game.relationships.act("officer"), "")
	assert_eq(game.police.get_progress(), 30)
	assert_eq(game.organisation.get_value("heat"), 45)
	assert_eq(game.relationships.get_knowledge("officer"), 20)


func test_trust_decays_without_contact() -> void:
	var game := _ready_game()
	var trust := game.relationships.get_trust("partner")
	for i in 3:
		_next_morning(game)
		while game.events.has_pending():
			var id: String = game.events.get_next_pending_id()
			game.events.resolve(id, game.events.get_definition_for(id).options[0].id)
	assert_eq(game.relationships.get_trust("partner"), trust - 1, "alle 3 Tage −1")


func test_partner_questions_event() -> void:
	var game := _ready_game()
	_put(game, "partner", 50, 45)
	_next_morning(game)
	var instance := ""
	for id in game.events.to_dict()["pending"]:
		if String(id).begins_with("partner_questions"):
			instance = id
	assert_true(not instance.is_empty(), "Fragen kommen")
	assert_eq(game.events.resolve(instance, "lie"), "")
	assert_eq(game.relationships.get_trust("partner"), 35, "50 − 15")


func test_officer_demand_without_money() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	var missions := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer",
			"territory_first"]:
		missions["completed"][id] = 0
	missions["active"] = []
	game.missions.restore(missions)
	var private := game.ledger.to_dict()
	_put(game, "officer", 40, 60)
	game.ledger.post(-game.ledger.get_balance(), "test", "Leer", "test", "x")
	_next_morning(game)
	var instance := ""
	for id in game.events.to_dict()["pending"]:
		if String(id).begins_with("officer_demands"):
			instance = id
	assert_true(not instance.is_empty())
	var heat := game.organisation.get_value("heat")
	assert_eq(game.events.resolve(instance, "pay"), "")
	assert_eq(game.organisation.get_value("heat"), heat + 15, "ohne Geld: verärgert")


func test_saved_and_migrated() -> void:
	var game := _ready_game()
	game.relationships.act("capitan")
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.relationships.to_dict(), game.relationships.to_dict())
	assert_true(not game.relationships.restore({"contacts": {"x": {"trust": 200}}, "instances": {},
			"last_processed_day": 1}).is_empty())
	assert_eq(SaveSystemScript._run_migration(34, {"time": {"minutes": 3000}}), "")
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_window() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_relationships_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	(app.find_child("ContactsButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("ContactValues_partner", true, false) as Label).text, "Vertrauen 70 · Wissen 0")
	var action := app.find_child("ContactAction_partner", true, false) as Button
	assert_eq(action.text, "Einen Abend zu zweit · 3 h · 60,00 €")
	action.pressed.emit()
	assert_eq(app.game.relationships.get_trust("partner"), 78)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_relationships_settings.cfg"))
