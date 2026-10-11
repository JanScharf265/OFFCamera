extends "res://tests/base_test.gd"

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")


func _new_game() -> GameStateScript:
	return Helpers.new_game()


## Neues Spiel, bereits an `location_id` (Fahrzeit vergeht dabei).
func _game_at(location_id: String) -> GameStateScript:
	var game := _new_game()
	if location_id != game.locations.get_current():
		assert_eq(game.locations.travel(location_id), "", "Fahrt nach %s" % location_id)
	return game


func test_new_game_has_start_values() -> void:
	var game := _new_game()
	assert_eq(game.time.format_date(), "Tag 1 · Mo")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.ledger.get_balance(), 50000)
	assert_eq(game.stats.energy, 80)
	assert_eq(game.stats.mood, 60)
	assert_eq(game.locations.get_current(), "home")


## Seit Phase 3 hat keine echte Aktivität eine Einnahme mehr (Streams sind Content);
## das ActivitySystem unterstützt sie aber weiter – geprüft mit Testdaten.
func test_income_is_in_ledger_with_reference_and_start_time() -> void:
	var data := Helpers.game_data()
	data.activities.load_data([{"id": "side_job", "display_name": "Nebenjob", "location": "office",
			"duration_minutes": 60, "money_cents": 2500, "category": "work", "effects": {"energy": -10}}])
	var game := GameStateScript.new(data)
	game.locations.travel("office")  # 08:00 -> 08:20
	assert_eq(game.activities.start("side_job"), "")
	var entries := game.ledger.get_entries()
	assert_eq(entries.size(), 1)
	if entries.size() != 1:
		return
	assert_eq(entries[0].amount_cents, 2500)
	assert_eq(entries[0].category, "work")
	assert_eq(entries[0].source, "activity")
	assert_eq(entries[0].reference, "side_job")
	assert_eq(entries[0].time_minutes, TimeSystemScript.at(1, 8, 20))
	assert_eq(game.stats.energy, 70)


func test_expense_is_in_ledger() -> void:
	var game := _game_at("cafe_harbor")
	assert_eq(game.activities.start("eat_out"), "")
	assert_eq(game.ledger.get_balance(), 48500)
	assert_eq(game.ledger.get_entries_by_category("food").size(), 1)


func test_activity_without_money_creates_no_entry() -> void:
	var game := _new_game()
	assert_eq(game.activities.start("rest"), "")
	assert_eq(game.ledger.get_entries().size(), 0)
	assert_eq(game.time.format_clock(), "09:00")


func test_energy_is_capped_at_100() -> void:
	var game := _new_game()
	game.activities.start("rest")  # 80 -> 95
	game.activities.start("rest")  # 95 -> 100
	assert_eq(game.stats.energy, 100)


func test_sleep_takes_8_hours_and_gives_60_energy() -> void:
	var game := _new_game()
	game.stats.apply({"energy": -70})  # 80 -> 10
	assert_eq(game.activities.start("sleep"), "")
	assert_eq(game.time.format_clock(), "16:00")
	assert_eq(game.stats.energy, 70)


func test_coffee_costs_money_at_the_harbor() -> void:
	var game := _game_at("cafe_harbor")  # 08:20
	assert_eq(game.activities.start("coffee"), "")
	assert_eq(game.time.format_clock(), "08:50")
	assert_eq(game.ledger.get_balance(), 50000 - 350)
	assert_eq(game.stats.energy, 90)


func test_training_and_week_planning() -> void:
	var game := _game_at("gym")  # 08:15
	assert_eq(game.activities.start("training"), "")
	assert_eq(game.time.format_clock(), "09:45")
	assert_eq(game.stats.energy, 65)
	assert_eq(game.stats.mood, 70)
	assert_eq(game.locations.travel("office"), "")  # 25 min -> 10:10
	assert_eq(game.activities.start("plan_week"), "")
	assert_eq(game.time.format_clock(), "11:10")


func test_activity_elsewhere_is_rejected_without_any_change() -> void:
	var game := _new_game()
	assert_eq(game.activities.check("training"), "Nur vor Ort möglich: Fitnessstudio.")
	assert_eq(game.activities.start("training"), "Nur vor Ort möglich: Fitnessstudio.")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.ledger.get_entries().size(), 0)


func test_closed_location_blocks_activity() -> void:
	var game := _game_at("office")  # 08:20, Büro 08–18
	game.time.advance(TimeSystemScript.at(1, 18) - game.time.get_minutes())  # 18:00
	assert_eq(game.activities.start("plan_week"), "Büro ist geschlossen (geöffnet 08:00–18:00).")
	assert_eq(game.time.format_clock(), "18:00")


func test_activity_must_end_before_closing() -> void:
	var game := _game_at("office")
	game.time.advance(TimeSystemScript.at(1, 17, 30) - game.time.get_minutes())  # 17:30
	assert_eq(game.activities.check("plan_week"), "Büro schließt vorher (geöffnet 08:00–18:00).")
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())  # nächster Morgen
	assert_eq(game.activities.check("plan_week"), "")


func test_too_little_energy_is_rejected_without_any_change() -> void:
	var game := _game_at("gym")  # 08:15
	game.stats.apply({"energy": -70})  # 80 -> 10
	var reason := game.activities.start("training")
	assert_eq(reason, "Zu wenig Energie (benötigt 15).")
	assert_eq(game.time.format_clock(), "08:15")
	assert_eq(game.stats.energy, 10)
	assert_eq(game.ledger.get_entries().size(), 0)


func test_not_enough_money_is_rejected_without_any_change() -> void:
	var game := _game_at("cafe_harbor")
	game.ledger.post(-49000, "test", "Ausgabe für Test", "test")  # 500 € -> 10 €
	var reason := game.activities.start("eat_out")
	assert_eq(reason, "Nicht genug Geld (kostet 15,00 €).")
	assert_eq(game.time.format_clock(), "08:20")
	assert_eq(game.stats.energy, 80)
	assert_eq(game.ledger.get_balance(), 1000)


func test_unknown_activity_is_rejected() -> void:
	var game := _new_game()
	assert_eq(game.activities.start("fly"), "Unbekannte Aktivität: fly")
	assert_eq(game.time.format_clock(), "08:00")


func test_check_does_not_change_anything() -> void:
	var game := _game_at("cafe_harbor")
	assert_eq(game.activities.check("eat_out"), "")
	assert_eq(game.ledger.get_balance(), 50000)
	assert_eq(game.time.format_clock(), "08:20")


func test_activity_completed_fires_once() -> void:
	var game := _new_game()
	var completed := []
	var on_completed := func(id: String) -> void: completed.append(id)
	game.activities.activity_completed.connect(on_completed)
	game.activities.start("rest")
	game.activities.start("fly")
	assert_eq(completed, ["rest"])
	game.activities.activity_completed.disconnect(on_completed)


func test_activity_started_during_time_advance_is_rejected() -> void:
	var game := _new_game()
	var nested := []
	var on_advanced := func(_from: int, _to: int) -> void: nested.append(game.activities.start("rest"))
	game.time.time_advanced.connect(on_advanced)
	game.activities.start("rest")
	assert_eq(nested, ["Gerade läuft bereits ein Zeitfortschritt."])
	assert_eq(game.time.format_clock(), "09:00")
	game.time.time_advanced.disconnect(on_advanced)


func test_player_stats_are_clamped() -> void:
	var stats := PlayerStatsScript.new(150, -10)
	assert_eq(stats.energy, 100)
	assert_eq(stats.mood, 0)
	stats.apply({"energy": -500, "mood": 500})
	assert_eq(stats.energy, 0)
	assert_eq(stats.mood, 100)
