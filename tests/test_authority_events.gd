extends "res://tests/base_test.gd"

## Behördenereignisse (Ticket 5.4): neue Bedingungen (offene Fristen, Unternehmen, Vorwochen-Gewinn),
## Optionen mit Konto, Spielzeit und Unternehmenswirkung, festes Ereignis nach 3 überfälligen Fristen.
## Alles fiktive, abstrakte Spielwerte.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")


## Spiel mit echten Ereignisdaten oder eigenen; ohne Termine.
func _game(events: Array = []) -> GameStateScript:
	var data := Helpers.game_data()
	data.appointments.load_data([])
	if not events.is_empty():
		assert_true(data.events.load_data(events), "Testdaten ungültig: %s" % "; ".join(data.events.errors))
	return GameStateScript.new(data, Helpers.TEST_SEED)


func _event(id: String, conditions: Dictionary, options: Array = []) -> Dictionary:
	if options.is_empty():
		options = [{"id": "ok", "label": "Ok"}]
	return {"id": id, "title": "Titel %s" % id, "text": "X",
			"trigger": {"random": {"chance_percent": 100, "conditions": conditions}}, "options": options}


func _to_morning(game: GameStateScript, day: int) -> void:
	game.time.advance(TimeSystemScript.at(day, 8) - game.time.get_minutes())


func _resolve_all(game: GameStateScript) -> void:
	while game.events.has_pending():
		var instance := game.events.get_next_pending_id()
		game.events.resolve(instance, game.events.get_definition_for(instance).options[-1].id)


func test_catalog_requires_a_free_option() -> void:
	var catalog := EventCatalogScript.new()
	var paid_only := _event("x", {}, [{"id": "pay", "label": "Zahlen", "money_cents": -100, "category": "fee"}])
	assert_eq(catalog.load_data([paid_only]), false)
	assert_true("mindestens eine Option ohne Kosten" in "; ".join(catalog.errors), "; ".join(catalog.errors))


func test_catalog_checks_new_option_fields() -> void:
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([_event("x", {}, [{"id": "a", "label": "A", "account": "offshore"}])]), false)
	assert_eq(catalog.load_data([_event("x", {}, [{"id": "a", "label": "A", "minutes": -5}])]), false)
	assert_eq(catalog.load_data([_event("x", {}, [{"id": "a", "label": "A", "company": {"profit": 3}}])]), false)
	assert_eq(catalog.load_data([_event("x", {"min_open_obligations": 1, "company_founded": 1})]), true)


func test_company_condition() -> void:
	var game := _game([_event("needs_company", {"company_founded": 1}), _event("without_company", {"company_founded": 0})])
	_to_morning(game, 2)
	assert_eq(game.events.get_triggered_ids(), PackedStringArray(["without_company@2"]))
	_resolve_all(game)
	game.locations.travel("office")
	game.company.found("merch_label")
	_to_morning(game, 3)
	assert_true(game.events.is_triggered("needs_company@3"), "Bedingung Unternehmen ignoriert")


func test_open_obligations_condition() -> void:
	var game := _game([_event("overdue", {"min_open_obligations": 1})])
	game.ledger.post(-49000, "test", "Ausgabe für Test", "test")  # 10 € – Mieten bleiben offen
	_to_morning(game, 7)
	assert_true(game.events.get_triggered_ids().is_empty(), "ohne offene Fristen ausgelöst")
	_to_morning(game, 8)  # Fristen vor Ereignissen (DayCycle) -> am selben Tageswechsel sichtbar
	assert_true(game.events.is_triggered("overdue@8"), "offene Fristen nicht erkannt")


func test_enforcement_notice_comes_surely_after_three_open_obligations() -> void:
	var game := _game()  # echte Daten
	game.ledger.post(-49000, "test", "Ausgabe für Test", "test")  # 10 €
	_to_morning(game, 8)  # 2 offene Mieten
	_resolve_all(game)
	assert_true(not game.events.is_triggered("enforcement_notice@8"), "schon bei 2 offenen Fristen")
	_to_morning(game, 14)
	_resolve_all(game)  # andere Zufallsereignisse der Woche entscheiden
	_to_morning(game, 15)  # 4 offene Mieten
	assert_eq(game.obligations.count_open(), 4)
	assert_true(game.events.is_triggered("enforcement_notice@15"), "festes Ereignis fehlt")
	assert_eq(game.events.get_next_pending_id(), "enforcement_notice@15")  # höchste Priorität


func test_enforcement_effects_are_abstract_values_only() -> void:
	var game := _game()
	game.ledger.post(-49000, "test", "Ausgabe für Test", "test")
	_to_morning(game, 8)
	_resolve_all(game)
	_to_morning(game, 15)
	var mood := game.stats.mood
	var balance := game.ledger.get_balance()
	assert_eq(game.events.resolve("enforcement_notice@15", "acknowledge"), "")
	assert_eq(game.stats.mood, mood - 10)
	assert_eq(game.ledger.get_balance(), balance)  # kein Geld bewegt


func test_option_with_time_advances_clock_after_closing_event() -> void:
	var options := [{"id": "meeting", "label": "Termin", "minutes": 120, "company": {"reputation": 3}},
			{"id": "skip", "label": "Nein"}]
	var game := _game([_event("audit", {"company_founded": 1}, options)])
	game.locations.travel("office")
	game.company.found("merch_label")  # 09:20, Ruf 50
	_to_morning(game, 2)
	assert_eq(game.events.resolve("audit@2", "meeting"), "")
	assert_eq(game.time.format_clock(), "10:00")
	assert_eq(game.events.is_resolved("audit@2"), true)
	assert_true(game.company.reputation > 50 - 5, "Unternehmenswirkung fehlt")
	var reasons := PackedStringArray()
	for change in game.company.get_history():
		reasons.append(change.reason)
	assert_true("Titel audit: Termin" in reasons, "Begründung im Unternehmens-Protokoll fehlt")


func test_company_account_option() -> void:
	var options := [{"id": "pay", "label": "Zahlen", "money_cents": -4000, "category": "levy", "account": "company"},
			{"id": "skip", "label": "Nein"}]
	var game := _game([_event("claim", {"company_founded": 1}, options)])
	game.locations.travel("office")
	game.company.found("merch_label")  # Firmenkonto 200 €
	_to_morning(game, 2)
	var private_before := game.ledger.get_balance("private")
	var company_before := game.ledger.get_balance("company")
	assert_eq(game.events.resolve("claim@2", "pay"), "")
	assert_eq(game.ledger.get_balance("company"), company_before - 4000)
	assert_eq(game.ledger.get_balance("private"), private_before)
	assert_eq(game.ledger.get_entries_by_category("levy")[0].account, "company")


func test_company_account_option_needs_money_on_company_account() -> void:
	var options := [{"id": "pay", "label": "Zahlen", "money_cents": -40000, "category": "levy", "account": "company"},
			{"id": "skip", "label": "Nein"}]
	var game := _game([_event("claim", {"company_founded": 1}, options)])
	game.locations.travel("office")
	game.company.found("merch_label")
	_to_morning(game, 2)
	assert_eq(game.events.resolve("claim@2", "pay"), "Nicht genug Geld auf dem Firmenkonto (kostet 400,00 €).")
	assert_eq(game.events.resolve("claim@2", "skip"), "")


func test_last_week_profit_condition() -> void:
	var game := _game([_event("rich", {"company_founded": 1, "min_last_week_profit_cents": 5000})])
	game.locations.travel("office")
	game.company.found("merch_label")
	_to_morning(game, 9)  # Woche 1 ohne Pflege: Verlust
	assert_true(game.events.get_triggered_ids().is_empty(), "ohne Gewinn ausgelöst")
	game.ledger.post(100000, "sales", "Großauftrag", "test", "", "", false, "company")  # Gewinn in Woche 2
	_to_morning(game, 15)
	assert_true(game.events.is_triggered("rich@15"), "Gewinnbedingung nicht erkannt")


func test_option_summary_shows_time_company_and_account() -> void:
	var catalog := EventCatalogScript.new()
	catalog.load_file()
	var ActivityText := load("res://scripts/ui/activity_text.gd")
	var claim := catalog.get_definition("back_claim")
	assert_eq(ActivityText.event_option_summary(claim.get_option("pay"), {}), "Ruf (Firma) +1 · -40,00 € (Firmenkonto)")
	assert_eq(ActivityText.event_option_summary(claim.get_option("object"), {}), "1 h 30 min · Stimmung -3")
