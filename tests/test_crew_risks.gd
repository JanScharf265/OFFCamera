extends "res://tests/base_test.gd"

## Ticket U.15: Crew-Folgen als Ereignisse – Verhaftung (Hitze, Polizei im Gebiet, Können), Verrat (Gier über
## Loyalität), Spitzel (wenig Loyalität bei hoher Hitze), Abwerbung (Bande im Revier); Antworten über das Optionsfeld
## „crew“; Namen im Ereignistext; Folgen beim Feuern; höchstens ein Vorfall je Tag, deterministisch;
## Speichern/Laden; Migration v27 → v28.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")

const SAVE_PATH := "user://test_crew_risks_save.json"


func _ready_game(heat: int = 0) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.organisation.change({"respect": 30, "heat": heat})
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	var missions := game.missions.to_dict()
	for id in ["first_deal_meeting", "first_deal_goods", "first_deal_stash", "first_deal_sale"]:
		missions["completed"][id] = 0
	missions["active"] = []
	assert_eq(game.missions.restore(missions), "")
	var supply := game.supply.to_dict()
	supply["stock"] = {"weed": 100}
	game.supply.restore(supply)
	game.ledger.post(500000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _add(game: GameStateScript, id: String, values: Dictionary) -> void:
	var member := {"id": id, "name": "Toni %s" % id, "role": "dealer", "skill": 50, "loyalty": 50, "greed": 30,
			"wage_cents": 100, "hired_day": 0, "rank": 1, "district": ""}
	member.merge(values, true)
	var data := game.crew.to_dict()
	data["members"].append(member)
	assert_eq(game.crew.restore(data), "")


## Springt Tag für Tag (Ereignisse anderer Art werden beantwortet), bis ein Crew-Vorfall der Art offen ist.
func _wait_for(game: GameStateScript, kind: String, days: int = 80) -> String:
	for i in days:
		game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())
		while game.events.has_pending():
			var id: String = game.events.get_next_pending_id()
			if game.crew.get_incident(id).get("kind", "") == kind:
				return id
			game.events.resolve(id, game.events.get_definition_for(id).options[0].id \
					if not game.crew.get_incident(id).is_empty() else game.events.get_definition_for(id).options[-1].id)
	return ""


func test_risk_chances_follow_values() -> void:
	var game := _ready_game(60)
	var calm: Dictionary = game.crew.call("_risk_chances", {"id": "a", "role": "dealer", "skill": 80, "loyalty": 80,
			"greed": 20, "district": ""}, 0)
	assert_eq(calm, {"arrest": 0}, "erfahren, loyal, keine Hitze")
	var risky: Dictionary = game.crew.call("_risk_chances", {"id": "b", "role": "dealer", "skill": 20, "loyalty": 20,
			"greed": 80, "district": "puerto_banus"}, 60)
	assert_eq(risky, {"arrest": 6, "betrayal": 6, "informant": 5, "poached": 6})


func test_arrest_lawyer_or_drop() -> void:
	var game := _ready_game(100)
	_add(game, "d1", {"skill": 20, "district": "puerto_banus", "loyalty": 90, "greed": 0})
	_add(game, "d2", {"skill": 80, "loyalty": 90, "greed": 0})
	var instance := _wait_for(game, "arrest")
	assert_true(not instance.is_empty(), "keine Festnahme in 80 Tagen")
	if instance.is_empty():
		return
	var incident := game.crew.get_incident(instance)
	assert_true(game.events.get_text(instance).contains(incident["name"]), "Name im Text")
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_eq(game.events.resolve(instance, "lawyer"), "")
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 30000)
	assert_true(not game.crew.get_member(incident["member"]).is_empty(), "nach dem Anwalt wieder da")
	var second := _wait_for(game, "arrest")
	assert_true(not second.is_empty())
	if second.is_empty():
		return
	var gone: String = game.crew.get_incident(second)["member"]
	assert_eq(game.events.resolve(second, "drop"), "")
	assert_true(game.crew.get_member(gone).is_empty(), "fallen gelassen = raus")


func test_betrayal_takes_stock() -> void:
	var game := _ready_game()
	_add(game, "d1", {"loyalty": 10, "greed": 80, "role": "dealer"})
	var instance := _wait_for(game, "betrayal")
	assert_true(not instance.is_empty(), "kein Verrat in 80 Tagen")
	if instance.is_empty():
		return
	var stock := game.supply.get_stock("weed")
	assert_eq(game.events.resolve(instance, "let_go"), "")
	assert_eq(game.supply.get_stock("weed"), stock - 10)
	assert_true(game.crew.get_member("d1").is_empty())


func test_poach_raise() -> void:
	var game := _ready_game()
	_add(game, "d1", {"loyalty": 20, "greed": 0, "skill": 80, "district": "puerto_banus", "wage_cents": 4000})
	var instance := _wait_for(game, "poached")
	assert_true(not instance.is_empty(), "keine Abwerbung in 80 Tagen")
	if instance.is_empty():
		return
	assert_true(game.events.get_text(instance).begins_with("Los Halcones haben Toni d1 ein Angebot gemacht"))
	assert_eq(game.events.resolve(instance, "raise"), "")
	assert_eq(game.crew.get_member("d1")["wage_cents"], 5000)


func test_at_most_one_incident_per_day_and_deterministic() -> void:
	var a := _ready_game(100)
	var b := _ready_game(100)
	for game in [a, b]:
		for i in 4:
			_add(game, "d%d" % i, {"skill": 20, "loyalty": 10, "greed": 90, "district": "puerto_banus"})
	for i in 10:
		for game in [a, b]:
			game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())
	var per_day := {}
	for id in a.crew.to_dict()["incidents"]:
		var day := String(id).get_slice("@", 1)
		assert_true(not per_day.has(day), "zwei Vorfälle an Tag %s" % day)
		per_day[day] = true
	assert_eq(a.crew.to_dict()["incidents"], b.crew.to_dict()["incidents"], "gleicher Seed, gleiche Vorfälle")


func test_no_incidents_for_new_members() -> void:
	var game := _ready_game(100)
	_add(game, "d1", {"skill": 0, "loyalty": 0, "greed": 100, "district": "puerto_banus", "hired_day": 1})
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
	assert_eq(game.crew.to_dict()["incidents"], {}, "erst nach 2 Tagen")


func test_firing_consequences() -> void:
	var game := _ready_game()
	_add(game, "calm", {"loyalty": 60})
	_add(game, "angry", {"loyalty": 10})
	var stability := game.organisation.get_value("stability")
	var heat := game.organisation.get_value("heat")
	assert_eq(game.crew.fire("calm"), "")
	assert_eq([game.organisation.get_value("stability"), game.organisation.get_value("heat")], [stability - 2, heat])
	assert_eq(game.crew.fire("angry"), "")
	assert_eq([game.organisation.get_value("stability"), game.organisation.get_value("heat")], [stability - 4, heat + 5])
	assert_true(" ".join(game.crew.take_notices()).contains("Toni angry ist sauer und redet"))


func test_incidents_survive_save_and_migration() -> void:
	var game := _ready_game(100)
	_add(game, "d1", {"skill": 20, "loyalty": 90, "greed": 0, "district": "puerto_banus"})
	var instance := _wait_for(game, "arrest")
	assert_true(not instance.is_empty())
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null and not instance.is_empty():
		assert_true(loaded.events.get_text(instance).contains("Toni d1"), "Name nach dem Laden")
		assert_eq(loaded.events.resolve(instance, "drop"), "")
		assert_true(loaded.crew.get_member("d1").is_empty())
	var bad := game.crew.to_dict()
	bad["incidents"] = {"x": {"kind": "party"}}
	assert_true(not game.crew.restore(bad).is_empty())
	var old := {"crew": {"members": []}}
	assert_eq(SaveSystemScript._run_migration(27, old), "")
	assert_eq(old["crew"]["incidents"], {})
	SaveSystemScript.delete_save(SAVE_PATH)
