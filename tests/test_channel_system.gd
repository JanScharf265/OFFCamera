extends "res://tests/base_test.gd"

## Kanalprofil (Ticket 3.1): Grenzen, Wachstumsbremse, Protokoll mit Begründung, Speichern.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const Helpers := preload("res://tests/helpers.gd")


func _channel(followers: int = 0, community: int = 50, reputation: int = 50) -> ChannelSystemScript:
	return ChannelSystemScript.new(TimeSystemScript.new(TimeSystemScript.at(1, 8)), followers, community, reputation)


func test_new_game_starts_with_channel_values() -> void:
	var game := Helpers.new_game()
	assert_eq(game.channel.followers, 120)
	assert_eq(game.channel.community, 50)
	assert_eq(game.channel.reputation, 50)
	assert_true(game.channel.get_history().is_empty(), "Protokoll sollte leer sein")


func test_scores_are_limited_to_0_and_100() -> void:
	var channel := _channel(0, 95, 5)
	channel.apply({"community": 20, "reputation": -20}, "test", "Grenzen")
	assert_eq(channel.community, 100)
	assert_eq(channel.reputation, 0)
	var change: ChannelSystemScript.ChannelChangeScript = channel.get_history()[0]
	assert_eq(change.requested, {"community": 20, "reputation": -20})
	assert_eq(change.applied, {"community": 5, "reputation": -5})
	assert_true(change.was_limited(), "Begrenzung nicht erkannt")


func test_growth_brake_scales_with_followers() -> void:
	assert_eq(_channel(0).damped_follower_gain(1000), 1000)
	assert_eq(_channel(500000).damped_follower_gain(1000), 500)
	assert_eq(_channel(900000).damped_follower_gain(1000), 100)
	assert_eq(_channel(ChannelSystemScript.MAX_FOLLOWERS).damped_follower_gain(1000), 0)
	assert_eq(_channel(500000).damped_follower_gain(-300), -300)
	# Kleine Kanäle verlieren durch Rundung nichts.
	assert_eq(_channel(120).damped_follower_gain(10), 10)
	assert_eq(_channel(120).damped_follower_gain(1), 1)


func test_followers_never_exceed_maximum() -> void:
	var channel := _channel(999990)
	for i in 50:
		channel.apply({"followers": 1000000}, "test", "Riesenwelle %d" % i)
	assert_true(channel.followers <= ChannelSystemScript.MAX_FOLLOWERS, "Maximum überschritten")
	assert_true(channel.followers >= 999990, "Follower verloren")


func test_brake_is_recorded_in_history() -> void:
	var channel := _channel(500000)
	var change := channel.apply({"followers": 200}, "content", "Livestream")
	assert_eq(change.requested, {"followers": 200})
	assert_eq(change.applied, {"followers": 100})
	assert_eq(channel.followers, 500100)


func test_losses_are_not_braked_and_stop_at_zero() -> void:
	var channel := _channel(50)
	channel.apply({"followers": -80}, "event", "Shitstorm")
	assert_eq(channel.followers, 0)


func test_change_entry_has_id_time_source_reason() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(2, 9, 30))
	var channel := ChannelSystemScript.new(time, 100)
	var first := channel.apply({"followers": 10}, "content", "Kurzvideo", "short_video")
	var second := channel.apply({"community": 2}, "event", "Raid")
	assert_eq(first.id, "ch_000001")
	assert_eq(second.id, "ch_000002")
	assert_eq(first.time_minutes, TimeSystemScript.at(2, 9, 30))
	assert_eq(first.source, "content")
	assert_eq(first.reason, "Kurzvideo")
	assert_eq(first.reference, "short_video")


func test_invalid_changes_are_rejected_without_effect() -> void:
	var channel := _channel(100)
	expect_error_output()
	assert_true(channel.apply({"money": 5}, "test", "falscher Schlüssel") == null, "unbekannter Schlüssel")
	expect_error_output()
	assert_true(channel.apply({"followers": 1.5}, "test", "keine ganze Zahl") == null, "Kommazahl")
	expect_error_output()
	assert_true(channel.apply({"followers": 5}, "test", "") == null, "ohne Begründung")
	assert_true(channel.apply({"followers": 0}, "test", "nichts") == null, "Änderung 0")
	assert_eq(channel.followers, 100)
	assert_true(channel.get_history().is_empty(), "abgelehnte Änderung im Protokoll")


func test_idempotency_key_prevents_double_application() -> void:
	var channel := _channel(100)
	assert_true(channel.apply({"followers": 10}, "event", "Raid", "raid", "event:raid@3") != null, "erste Anwendung")
	assert_true(channel.apply({"followers": 10}, "event", "Raid", "raid", "event:raid@3") == null, "zweite Anwendung")
	assert_eq(channel.followers, 110)


func test_signal_reports_change() -> void:
	var channel := _channel(100)
	var seen: Array = []
	channel.channel_changed.connect(func(change) -> void: seen.append(change.id))
	channel.apply({"reputation": 3}, "test", "Lob")
	assert_eq(seen, ["ch_000001"])


func test_history_is_limited_but_ids_continue() -> void:
	var channel := _channel(0)
	for i in ChannelSystemScript.HISTORY_LIMIT + 5:
		channel.apply({"community": 1 if i % 2 == 0 else -1}, "test", "Schwankung")
	var history := channel.get_history()
	assert_eq(history.size(), ChannelSystemScript.HISTORY_LIMIT)
	assert_eq(history[history.size() - 1].id, "ch_%06d" % (ChannelSystemScript.HISTORY_LIMIT + 5))


func test_round_trip_restores_values_history_and_keys() -> void:
	var channel := _channel(400, 60, 70)
	channel.apply({"followers": 50, "community": -3}, "content", "Livestream", "livestream", "content:1")
	var copy := _channel()
	assert_eq(copy.restore(JSON.parse_string(JSON.stringify(channel.to_dict()))), "")
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(channel.to_dict()))
	assert_eq(copy.followers, channel.followers)
	assert_true(copy.apply({"followers": 5}, "content", "x", "", "content:1") == null, "Schlüssel nach Laden vergessen")
	assert_eq(copy.apply({"followers": 5}, "content", "y").id, "ch_000002")


func test_restore_rejects_invalid_data_without_change() -> void:
	var channel := _channel(100, 40, 30)
	var data := channel.to_dict()
	data["community"] = 140
	assert_true(not channel.restore(data).is_empty(), "Community 140 akzeptiert")
	data = channel.to_dict()
	data["followers"] = ChannelSystemScript.MAX_FOLLOWERS + 1
	assert_true(not channel.restore(data).is_empty(), "zu viele Follower akzeptiert")
	data = channel.to_dict()
	data["history"] = [{"id": "ch_000001"}]
	assert_true(not channel.restore(data).is_empty(), "unvollständiger Eintrag akzeptiert")
	assert_eq(channel.followers, 100)
	assert_eq(channel.community, 40)
