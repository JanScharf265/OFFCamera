extends "res://tests/base_test.gd"

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


## Neues Spiel (Tag 1, 08:00) mit den angegebenen Ereignissen und ohne Termine
## (verpasste Termine würden sonst die Stimmung ändern).
func _new_game(events: Array) -> GameStateScript:
	var data := Helpers.game_data()
	data.appointments.load_data([])
	assert_true(data.events.load_data(events), "Testdaten ungültig: %s" % "; ".join(data.events.errors))
	return GameStateScript.new(data)


func _event(id: String, hour: int, priority: int = 0, options: Array = []) -> Dictionary:
	if options.is_empty():
		options = [
			{"id": "accept", "label": "Ja", "money_cents": 3000, "category": "creator", "effects": {"mood": 5}},
			{"id": "pay", "label": "Zahlen", "money_cents": -100000, "category": "misc"},
			{"id": "decline", "label": "Nein"},
		]
	return {"id": id, "title": "T", "text": "X", "priority": priority,
			"trigger": {"day": 1, "hour": hour}, "options": options}


func test_event_is_not_triggered_before_due_time() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(11 * 60 + 59)  # 08:00 -> 19:59
	assert_eq(game.events.has_pending(), false)
	assert_eq(game.events.is_triggered("evt"), false)


func test_event_is_triggered_when_time_reaches_due_time_exactly() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)  # -> 20:00
	assert_eq(game.events.has_pending(), true)
	assert_eq(game.events.get_next_pending().id, "evt")


func test_event_is_triggered_when_time_jumps_past_due_time() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(2 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(game.events.is_triggered("evt"), true)


func test_event_at_start_time_is_not_triggered() -> void:
	var game := _new_game([_event("evt", 8)])  # Spielstart ist 08:00, Intervall ist (von, bis]
	game.time.advance(60)
	assert_eq(game.events.is_triggered("evt"), false)


func test_event_triggers_only_once() -> void:
	var game := _new_game([_event("evt", 20)])
	var triggered := []
	var on_triggered := func(id: String) -> void: triggered.append(id)
	game.events.event_triggered.connect(on_triggered)
	game.time.advance(12 * 60)
	game.events.resolve("evt", "decline")
	game.time.advance(TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(triggered, ["evt"])
	assert_eq(game.events.has_pending(), false)
	game.events.event_triggered.disconnect(on_triggered)


func test_simultaneous_events_are_ordered_by_time_then_priority_then_id() -> void:
	var game := _new_game([_event("late", 12), _event("b_low", 10), _event("a_low", 10), _event("high", 10, 5)])
	var triggered := []
	var on_triggered := func(id: String) -> void: triggered.append(id)
	game.events.event_triggered.connect(on_triggered)
	game.time.advance(6 * 60)  # 08:00 -> 14:00
	assert_eq(triggered, ["high", "a_low", "b_low", "late"])
	game.events.event_triggered.disconnect(on_triggered)


func test_resolve_applies_money_and_stats_once() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)
	assert_eq(game.events.resolve("evt", "accept"), "")
	assert_eq(game.ledger.get_balance(), 53000)
	assert_eq(game.stats.mood, 65)
	var entry := game.ledger.get_entries()[0]
	assert_eq(entry.source, "event")
	assert_eq(entry.reference, "evt")
	assert_eq(entry.time_minutes, TimeSystemScript.at(1, 20))
	assert_eq(game.events.is_resolved("evt"), true)
	assert_eq(game.events.has_pending(), false)


func test_resolving_twice_is_rejected_without_double_booking() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)
	game.events.resolve("evt", "accept")
	assert_eq(game.events.resolve("evt", "accept"), "Dieses Ereignis ist nicht offen.")
	assert_eq(game.ledger.get_balance(), 53000)
	assert_eq(game.ledger.get_entries().size(), 1)


func test_unknown_option_keeps_event_open() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)
	assert_eq(game.events.resolve("evt", "maybe"), "Unbekannte Auswahl: maybe")
	assert_eq(game.events.has_pending(), true)


func test_unaffordable_option_is_rejected_and_event_stays_open() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)
	assert_eq(game.events.resolve("evt", "pay"), "Nicht genug Geld (kostet 1.000,00 €).")
	assert_eq(game.ledger.get_balance(), 50000)
	assert_eq(game.events.has_pending(), true)


func test_option_without_effects_changes_nothing() -> void:
	var game := _new_game([_event("evt", 20)])
	game.time.advance(12 * 60)
	assert_eq(game.events.resolve("evt", "decline"), "")
	assert_eq(game.ledger.get_entries().size(), 0)
	assert_eq(game.stats.mood, 60)


func test_event_due_during_activity_is_triggered() -> void:
	var game := _new_game([_event("evt", 9)])
	assert_eq(game.activities.start("sleep"), "")  # 08:00 -> 16:00
	assert_eq(game.events.get_next_pending().id, "evt")


func test_game_without_event_catalog_has_no_events() -> void:
	var data := Helpers.game_data()
	data.events.load_data([])
	var game := GameStateScript.new(data)
	game.time.advance(3 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(game.events.has_pending(), false)
