extends "res://tests/base_test.gd"

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")


func _new_game() -> GameStateScript:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	return GameStateScript.new(catalog)


func test_new_game_has_start_values() -> void:
	var game := _new_game()
	assert_eq(game.time.format_date(), "Tag 1 · Mo")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.ledger.get_balance(), 50000)
	assert_eq(game.stats.energy, 80)
	assert_eq(game.stats.mood, 60)


func test_stream_changes_time_stats_and_money_exactly() -> void:
	var game := _new_game()
	assert_eq(game.activities.start("stream_short"), "")
	assert_eq(game.time.format_clock(), "10:00")
	assert_eq(game.stats.energy, 60)
	assert_eq(game.stats.mood, 65)
	assert_eq(game.ledger.get_balance(), 52500)


func test_income_is_in_ledger_with_reference_and_start_time() -> void:
	var game := _new_game()
	game.activities.start("stream_short")
	var entries := game.ledger.get_entries()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].amount_cents, 2500)
	assert_eq(entries[0].category, "creator")
	assert_eq(entries[0].source, "activity")
	assert_eq(entries[0].reference, "stream_short")
	assert_eq(entries[0].time_minutes, TimeSystemScript.at(1, 8))


func test_expense_is_in_ledger() -> void:
	var game := _new_game()
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


func test_too_little_energy_is_rejected_without_any_change() -> void:
	var game := _new_game()
	game.stats.apply({"energy": -70})  # 80 -> 10
	var reason := game.activities.start("stream_short")
	assert_eq(reason, "Zu wenig Energie (benötigt 20).")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.stats.energy, 10)
	assert_eq(game.ledger.get_entries().size(), 0)


func test_not_enough_money_is_rejected_without_any_change() -> void:
	var game := _new_game()
	game.ledger.post(-49000, "test", "Ausgabe für Test", "test")  # 500 € -> 10 €
	var reason := game.activities.start("eat_out")
	assert_eq(reason, "Nicht genug Geld (kostet 15,00 €).")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.stats.energy, 80)
	assert_eq(game.ledger.get_balance(), 1000)


func test_unknown_activity_is_rejected() -> void:
	var game := _new_game()
	assert_eq(game.activities.start("fly"), "Unbekannte Aktivität: fly")
	assert_eq(game.time.format_clock(), "08:00")


func test_check_does_not_change_anything() -> void:
	var game := _new_game()
	assert_eq(game.activities.check("eat_out"), "")
	assert_eq(game.ledger.get_balance(), 50000)
	assert_eq(game.time.format_clock(), "08:00")


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
	game.activities.start("eat_out")
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
