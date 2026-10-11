extends "res://tests/base_test.gd"

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


func test_new_game_starts_day_1_monday_midnight() -> void:
	var time := TimeSystemScript.new()
	assert_eq(time.get_minutes(), 0)
	assert_eq(time.get_day(), 1)
	assert_eq(time.format_clock(), "00:00")
	assert_eq(time.format_date(), "Tag 1 · Mo")


func test_at_builds_start_time() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 8, 5))
	assert_eq(time.get_minutes(), 8 * 60 + 5)
	assert_eq(time.format_clock(), "08:05")


func test_advance_changes_time_exactly() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 18))
	assert_true(time.advance(120))
	assert_eq(time.get_minutes(), TimeSystemScript.at(1, 20))
	assert_eq(time.format_clock(), "20:00")


func test_advance_emits_time_advanced_once_with_range() -> void:
	var time := TimeSystemScript.new(100)
	var calls := []
	var on_advanced := func(from: int, to: int) -> void: calls.append([from, to])
	time.time_advanced.connect(on_advanced)
	time.advance(30)
	assert_eq(calls, [[100, 130]])
	time.time_advanced.disconnect(on_advanced)


func test_no_day_change_within_same_day() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 8))
	var days := []
	var on_day := func(day: int) -> void: days.append(day)
	time.day_changed.connect(on_day)
	time.advance(15 * 60 + 59)  # bis 23:59
	assert_eq(days, [])
	assert_eq(time.get_day(), 1)
	time.day_changed.disconnect(on_day)


func test_day_change_exactly_at_midnight() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 23))
	var days := []
	var on_day := func(day: int) -> void: days.append(day)
	time.day_changed.connect(on_day)
	time.advance(60)
	assert_eq(days, [2])
	assert_eq(time.format_date(), "Tag 2 · Di")
	assert_eq(time.format_clock(), "00:00")
	time.day_changed.disconnect(on_day)


func test_day_change_across_midnight() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 22))
	var days := []
	var on_day := func(day: int) -> void: days.append(day)
	time.day_changed.connect(on_day)
	time.advance(180)
	assert_eq(days, [2])
	assert_eq(time.format_clock(), "01:00")
	time.day_changed.disconnect(on_day)


func test_multi_day_advance_emits_each_day_once_in_order() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 12))
	var days := []
	var on_day := func(day: int) -> void: days.append(day)
	time.day_changed.connect(on_day)
	time.advance(3 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(days, [2, 3, 4])
	assert_eq(time.get_day(), 4)
	time.day_changed.disconnect(on_day)


func test_day_changed_fires_before_time_advanced_with_new_time_set() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 23, 30))
	var events := []
	var on_day := func(day: int) -> void: events.append("day %d @ %d" % [day, time.get_minutes()])
	var on_advanced := func(_from: int, _to: int) -> void: events.append("advanced")
	time.day_changed.connect(on_day)
	time.time_advanced.connect(on_advanced)
	time.advance(60)
	assert_eq(events, ["day 2 @ %d" % TimeSystemScript.at(2, 0, 30), "advanced"])
	time.day_changed.disconnect(on_day)
	time.time_advanced.disconnect(on_advanced)


func test_zero_and_negative_duration_are_rejected_without_change() -> void:
	var time := TimeSystemScript.new(500)
	var calls := []
	var on_advanced := func(from: int, to: int) -> void: calls.append([from, to])
	time.time_advanced.connect(on_advanced)
	expect_error_output()
	assert_eq(time.advance(0), false)
	expect_error_output()
	assert_eq(time.advance(-30), false)
	assert_eq(time.get_minutes(), 500)
	assert_eq(calls, [])
	time.time_advanced.disconnect(on_advanced)


func test_advance_from_signal_handler_is_rejected() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 23))
	var nested_results := []
	var days := []
	var on_day := func(day: int) -> void:
		days.append(day)
		nested_results.append(time.advance(10))
	time.day_changed.connect(on_day)
	expect_error_output()
	assert_true(time.advance(120))
	assert_eq(nested_results, [false])
	assert_eq(days, [2])
	assert_eq(time.get_minutes(), TimeSystemScript.at(2, 1))
	time.day_changed.disconnect(on_day)


func test_weekday_wraps_after_sunday() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(7, 10))
	assert_eq(time.format_date(), "Tag 7 · So")
	time.advance(TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(time.format_date(), "Tag 8 · Mo")
