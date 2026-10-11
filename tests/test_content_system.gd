extends "res://tests/base_test.gd"

## Content-Formate (Ticket 3.2): Daten, exakte Berechnung, Ausführung über Ledger/Kanal/Zeit.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ContentFormatCatalogScript := preload("res://scripts/systems/content_format_catalog.gd")


func _game_at(location_id: String) -> GameStateScript:
	var game := Helpers.new_game()
	if location_id != game.locations.get_current():
		assert_eq(game.locations.travel(location_id), "", "Fahrt nach %s" % location_id)
	return game


func _valid(id: String = "clip") -> Dictionary:
	return {"id": id, "display_name": "Clip", "location": "home", "duration_minutes": 30,
			"channel": {"followers_base": 1, "followers_per_mille": 0},
			"income": {"base_cents": 0, "per_1000_followers_cents": 0}}


func test_real_format_file_loads() -> void:
	var catalog := ContentFormatCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["short_video", "livestream", "long_video", "community_qa"]))
	assert_eq(catalog.get_ids_at("studio"), PackedStringArray(["livestream", "long_video", "community_qa"]))
	assert_true(Helpers.game_data().errors.is_empty(), "Verweise der echten Daten fehlerhaft")


func test_catalog_rejects_invalid_formats() -> void:
	var catalog := ContentFormatCatalogScript.new()
	var negative := _valid()
	negative["channel"]["followers_base"] = -1
	assert_eq(catalog.load_data([negative]), false)
	var missing_income := _valid()
	missing_income.erase("income")
	assert_eq(catalog.load_data([missing_income]), false)
	var zero_duration := _valid()
	zero_duration["duration_minutes"] = 0
	assert_eq(catalog.load_data([zero_duration]), false)
	assert_eq(catalog.load_data([_valid(), _valid()]), false)
	assert_eq(catalog.get_ids().size(), 0)
	assert_eq(catalog.load_data([_valid()]), true)


func test_unknown_location_is_reported_by_game_data() -> void:
	var data := Helpers.game_data()
	var format := _valid()
	format["location"] = "mond"
	data.formats.load_data([format])
	assert_true("Format 'clip': unbekannter Ort 'mond'." in data.check_references(), "Verweis nicht geprüft")


func test_livestream_preview_at_start_is_exact() -> void:
	var game := Helpers.new_game()  # 120 Follower, Community 50
	var outcome := game.content.preview("livestream")
	assert_eq(outcome["quality_percent"], 100)
	assert_eq(outcome["followers_raw"], 17)  # 15 + 120 × 20 / 1000 = 17
	assert_eq(outcome["followers"], 17)       # Bremse bei 120 Followern unmerklich
	assert_eq(outcome["income_cents"], 2500)  # 2020 + 120 × 4000 / 1000
	assert_eq(outcome["community"], 2)
	assert_eq(outcome["reputation"], 0)


func test_community_changes_quality() -> void:
	var game := Helpers.new_game()
	game.channel.apply({"community": 20}, "test", "gute Laune")  # 50 -> 70: +10 %
	assert_eq(game.content.quality_percent("livestream"), 110)
	assert_eq(game.content.preview("livestream")["income_cents"], 2750)
	assert_eq(game.content.explain("livestream"), "Livestream · Qualität 110 % (Community-Stimmung +10 %)")
	game.channel.apply({"community": -70}, "test", "Ärger")  # -> 0: −25 %
	assert_eq(game.content.quality_percent("livestream"), 75)


func test_reach_increases_gain_and_income() -> void:
	var game := Helpers.new_game()
	game.channel.apply({"followers": 9880}, "test", "Sprung")  # -> etwa 10.000
	var outcome := game.content.preview("livestream")
	var followers := game.channel.followers
	@warning_ignore("integer_division")
	assert_eq(outcome["followers_raw"], 15 + followers * 20 / 1000)
	@warning_ignore("integer_division")
	assert_eq(outcome["income_cents"], 2020 + followers * 4000 / 1000)
	assert_eq(outcome["followers"], game.channel.damped_follower_gain(outcome["followers_raw"]))


func test_produce_applies_everything_in_one_go() -> void:
	var game := _game_at("studio")  # 08:20
	assert_eq(game.content.produce("livestream"), "")
	assert_eq(game.time.format_clock(), "10:20")
	assert_eq(game.stats.energy, 60)
	assert_eq(game.stats.mood, 65)
	assert_eq(game.ledger.get_balance(), 52500)
	assert_eq(game.channel.followers, 137)
	assert_eq(game.channel.community, 52)


func test_income_is_booked_in_ledger_at_start_time() -> void:
	var game := _game_at("studio")
	game.content.produce("livestream")
	var entries := game.ledger.get_entries()
	assert_eq(entries.size(), 1)
	if entries.size() != 1:
		return
	assert_eq(entries[0].amount_cents, 2500)
	assert_eq(entries[0].category, "creator")
	assert_eq(entries[0].source, "content")
	assert_eq(entries[0].reference, "livestream")
	assert_eq(entries[0].time_minutes, TimeSystemScript.at(1, 8, 20))


func test_channel_change_explains_why() -> void:
	var game := _game_at("studio")
	game.content.produce("livestream")
	var history := game.channel.get_history()
	assert_eq(history.size(), 1)
	if history.size() != 1:
		return
	assert_eq(history[0].source, "content")
	assert_eq(history[0].reference, "livestream")
	assert_eq(history[0].reason, "Livestream · Qualität 100 %")
	assert_eq(history[0].applied, {"followers": 17, "community": 2})
	assert_eq(history[0].time_minutes, TimeSystemScript.at(1, 8, 20))


func test_format_without_income_books_nothing() -> void:
	var game := _game_at("studio")
	assert_eq(game.content.produce("community_qa"), "")
	assert_eq(game.ledger.get_entries().size(), 0)
	assert_eq(game.channel.community, 56)


func test_short_video_at_home() -> void:
	var game := Helpers.new_game()
	assert_eq(game.content.produce("short_video"), "")
	assert_eq(game.time.format_clock(), "09:00")
	assert_eq(game.channel.followers, 129)  # 8 + 120 × 10 / 1000 = 9
	assert_eq(game.ledger.get_balance(), 50000 + 360)  # 300 + 120 × 500 / 1000


func test_wrong_place_and_low_energy_change_nothing() -> void:
	var game := Helpers.new_game()
	assert_eq(game.content.produce("livestream"), "Nur vor Ort möglich: Studio.")
	game.locations.travel("studio")
	game.stats.apply({"energy": -70})  # 80 -> 10
	assert_eq(game.content.produce("livestream"), "Zu wenig Energie (benötigt 20).")
	assert_eq(game.time.format_clock(), "08:20")
	assert_eq(game.ledger.get_entries().size(), 0)
	assert_eq(game.channel.followers, 120)
	assert_true(game.channel.get_history().is_empty(), "Kanal trotz Ablehnung geändert")


func test_same_result_for_same_state() -> void:
	var a := _game_at("studio")
	var b := _game_at("studio")
	a.content.produce("long_video")
	b.content.produce("long_video")
	assert_eq(a.channel.to_dict(), b.channel.to_dict())
	assert_eq(a.ledger.get_balance(), b.ledger.get_balance())


func test_two_productions_in_a_row_are_both_booked() -> void:
	var game := _game_at("studio")
	assert_eq(game.content.produce("community_qa"), "")
	assert_eq(game.content.produce("livestream"), "")
	assert_eq(game.content.produce("livestream"), "")
	assert_eq(game.ledger.get_entries_by_category("creator").size(), 2)
	assert_eq(game.channel.get_history().size(), 3)
