extends "res://tests/base_test.gd"

## Ticket U.14: Rivalen – drei erfundene Banden als Daten (Stärke, Aggression, Revier); Druck auf den Einfluss je nach
## Beziehung und Stärke; „Ärger“-Ereignisse im EventSystem (Seed, höchstens eins je Tag, nur mit Einfluss im Revier);
## Antworten dagegenhalten / verhandeln / zurückziehen; Waffenstillstand im Fenster „Rivalen“; Ablauf; Speichern/Laden;
## Migration v26 → v27.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const RivalSystemScript := preload("res://scripts/systems/rival_system.gd")

const SAVE_PATH := "user://test_rivals_save.json"


## Organisation, „Der erste Dealer“ erledigt (Rivalen sichtbar), Respekt 30, 2.000 € Schwarzgeld – Tag 1, 10:00.
func _ready_game(seed: int = Helpers.TEST_SEED) -> GameStateScript:
	var game := Helpers.new_game(null, seed)
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.organisation.change({"respect": 30})
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	var missions := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer"]:
		missions["completed"][id] = 0
	missions["active"] = []
	assert_eq(game.missions.restore(missions), "")
	game.ledger.post(200000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _set_influence(game: GameStateScript, district: String, value: int) -> void:
	var data := game.territory.to_dict()
	data["influence"][district] = value
	assert_eq(game.territory.restore(data), "")


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


## Springt Tag für Tag, bis ein „Ärger“ der Bande offen ist (höchstens 60 Tage). Rückgabe: Instanz-ID oder "".
func _wait_for_clash(game: GameStateScript, gang: String, district: String) -> String:
	for i in 60:
		_set_influence(game, district, 50)
		_next_morning(game)
		while game.events.has_pending():
			var id: String = game.events.get_next_pending_id()
			if id.begins_with("rival_clash_%s" % gang):
				return id
			game.events.resolve(id, game.events.get_definition_for(id).options[-1].id)
	return ""


func test_real_rivals_load() -> void:
	var catalog := RivalSystemScript.Catalog.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_all().map(func(g) -> String: return g.id), ["halcones", "marea", "grises"])
	assert_eq(catalog.get_for_district("altstadt").id, "grises")
	assert_eq(Helpers.game_data().errors, PackedStringArray())


func test_bad_rivals_are_rejected() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RivalSystemScript.DEFAULT_PATH))
	var catalog := RivalSystemScript.Catalog.new()
	assert_true(catalog.load_data(good), "; ".join(catalog.errors))
	var twice := good.duplicate(true)
	twice["gangs"][1]["districts"] = ["puerto_banus"]
	assert_eq(catalog.load_data(twice), false, "Gebiet doppelt vergeben")
	for change in [{"truce_days": -1}, {"gangs": []}, {"extra": 1}]:
		var bad := good.duplicate(true)
		bad.merge(change, true)
		assert_eq(catalog.load_data(bad), false, "angenommen: %s" % change)
	var data := Helpers.game_data()
	var unknown := good.duplicate(true)
	unknown["gangs"][0]["clash_event"] = "first_brand_request"
	assert_true(data.rivals.load_data(unknown))
	assert_true(not data.check_references().is_empty(), "Ereignis nicht „scripted“")


func test_pressure_follows_relation_and_strength() -> void:
	var game := _ready_game()
	assert_eq(game.territory.rival_pressure("puerto_banus"), 2, "neutral, Stärke 50")
	assert_eq(game.rivals.offer_truce("halcones"), "")
	assert_eq(game.territory.rival_pressure("puerto_banus"), 0, "Waffenstillstand")
	assert_eq(game.territory.rival_pressure("san_pedro"), 2, "andere Bande unberührt")


func test_truce_costs_and_expires() -> void:
	var game := _ready_game()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_eq(game.rivals.truce_cost("halcones"), 40000)
	assert_eq(game.rivals.offer_truce("halcones"), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 40000)
	assert_eq([game.rivals.get_relation("halcones"), game.rivals.get_until_day("halcones")], ["truce", 8])
	assert_eq(game.rivals.check_truce("halcones"), "Waffenstillstand bis Tag 8.")
	game.time.advance(TimeSystemScript.at(9, 8) - game.time.get_minutes())
	assert_eq(game.rivals.get_relation("halcones"), "neutral")
	assert_true(" ".join(game.rivals.take_notices()).contains("Waffenstillstand mit Los Halcones ist abgelaufen"))


func test_no_clash_without_influence() -> void:
	var game := _ready_game()
	for i in 30:
		_next_morning(game)
	for id in game.events.to_dict()["triggered"]:
		assert_true(not String(id).begins_with("rival_clash_"), "Ärger ohne Einfluss: %s" % id)


func test_clash_and_fight() -> void:
	var game := _ready_game()
	var instance := _wait_for_clash(game, "halcones", "puerto_banus")
	assert_true(not instance.is_empty(), "kein Ärger mit Los Halcones in 60 Tagen")
	if instance.is_empty():
		return
	var respect := game.organisation.get_value("respect")
	assert_eq(game.events.resolve(instance, "fight"), "")
	assert_eq(game.rivals.get_strength("halcones"), 40)
	assert_eq(game.rivals.get_relation("halcones"), "conflict")
	assert_eq(game.organisation.get_value("respect"), respect + 5)
	assert_eq(game.territory.rival_pressure("puerto_banus"), 2, "Konflikt 150 % × Stärke 40/50 = 120 % von 2")


func test_clash_retreat_and_negotiate() -> void:
	var game := _ready_game()
	var instance := _wait_for_clash(game, "halcones", "puerto_banus")
	assert_true(not instance.is_empty())
	if instance.is_empty():
		return
	var influence := game.territory.get_influence("puerto_banus")
	assert_eq(game.events.resolve(instance, "retreat"), "")
	assert_eq(game.territory.get_influence("puerto_banus"), influence - 20)
	var second := _wait_for_clash(game, "halcones", "puerto_banus")
	assert_true(not second.is_empty())
	if second.is_empty():
		return
	assert_eq(game.events.resolve(second, "negotiate"), "")
	assert_eq(game.rivals.get_relation("halcones"), "truce")


func test_clashes_deterministic_and_saved() -> void:
	var a := _ready_game()
	var b := _ready_game()
	assert_eq(_wait_for_clash(a, "halcones", "puerto_banus"), _wait_for_clash(b, "halcones", "puerto_banus"))
	assert_eq(SaveSystemScript.save(a, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.rivals.to_dict(), a.rivals.to_dict())
		var pending := loaded.events.get_next_pending_id()
		assert_true(pending.begins_with("rival_clash_halcones"))
		assert_eq(loaded.events.resolve(pending, "fight"), "")
		assert_eq(loaded.rivals.get_strength("halcones"), 40, "Antwort wirkt auch nach dem Laden")
	for bad in [{}, {"gangs": {"x": {"strength": 1}}, "clashes": {}, "last_processed_day": 1},
			{"gangs": {}, "clashes": {"i": {"gang": 1}}, "last_processed_day": 1}, {"gangs": {}, "clashes": {}}]:
		assert_true(not a.rivals.restore(bad).is_empty(), "angenommen: %s" % bad)
	assert_eq(SaveSystemScript._run_migration(26, {"time": {"minutes": 3000}}), "")
	assert_true(not SaveSystemScript._run_migration(26, {}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_rivals_window_and_district_line() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_rivals_settings.cfg"
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true(app.find_child("RivalsButton", true, false) == null, "Rivalen vor dem ersten Dealer")
	screen.call("_close_window")
	var missions: Dictionary = app.game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale", "crew_first_dealer"]:
		missions["completed"][id] = 0
	missions["active"] = []
	app.game.missions.restore(missions)
	app.game.ledger.post(100000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	(app.find_child("RivalsButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("RivalValues_halcones", true, false) as Label).text,
			"Stärke 50 · Aggression 60 · Revier: Puerto Banús")
	var truce := app.find_child("RivalTruceButton_halcones", true, false) as Button
	assert_eq([truce.disabled, truce.text], [false, "Waffenstillstand · 400,00 €"])
	truce.pressed.emit()
	assert_eq((app.find_child("RivalStatus_halcones", true, false) as Label).text, "Waffenstillstand bis Tag 8")
	screen.call("_close_window")
	screen.call("set_underworld_view", true)
	(app.find_child("DistrictLabel_puerto_banus", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("DistrictRival", true, false) as Label).text,
			"Revier von Los Halcones · Stärke 50 · Waffenstillstand")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_rivals_settings.cfg"))
