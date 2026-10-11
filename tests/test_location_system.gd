extends "res://tests/base_test.gd"

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


func _location(id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "display_name": id, "map_position": [0.5, 0.5]}
	result.merge(extra, true)
	return result


func test_real_location_data_loads() -> void:
	var catalog := LocationCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["home", "studio", "cafe_harbor", "gym", "office", "label_store"]))
	var cafe := catalog.get_definition("cafe_harbor")
	assert_eq(cafe.display_name, "Café am Hafen")
	assert_eq(cafe.has_hours, true)
	assert_eq([cafe.open_hour, cafe.close_hour], [7, 20])
	assert_eq(catalog.get_definition("home").has_hours, false)


func test_invalid_locations_are_reported_and_nothing_loads() -> void:
	var catalog := LocationCatalogScript.new()
	var data := [
		_location("ok"),
		_location("outside", {"map_position": [1.5, 0.2]}),
		_location("no_position", {"map_position": null}),
		_location("bad_hours", {"opening_hours": {"open": 20, "close": 8}}),
		_location("late", {"opening_hours": {"open": 8, "close": 25}}),
		_location("ok"),
	]
	assert_eq(catalog.load_data(data), false)
	assert_eq(catalog.errors.size(), 5, "; ".join(catalog.errors))
	assert_eq(catalog.has("ok"), false)


func test_travel_formula_rounds_up_to_5_minutes() -> void:
	assert_eq(LocationSystemScript.travel_minutes_for(0), 5)    # 0 km: 5 min
	assert_eq(LocationSystemScript.travel_minutes_for(10), 10)  # 1 km: 8 -> 10
	assert_eq(LocationSystemScript.travel_minutes_for(34), 20)  # 3,4 km: 15,2 -> 20
	assert_eq(LocationSystemScript.travel_minutes_for(50), 20)  # 5 km: genau 20
	assert_eq(LocationSystemScript.travel_minutes_for(51), 25)  # 5,1 km: 20,3 -> 25


func test_real_travel_times() -> void:
	var game := Helpers.new_game()
	assert_eq(game.locations.distance_tenths("home", "studio"), 36)
	assert_eq(game.locations.travel_minutes_to("studio"), 20)
	assert_eq(game.locations.travel_minutes_to("gym"), 15)
	assert_eq(game.locations.travel_minutes_to("home"), 0)
	assert_eq(game.locations.distance_tenths("studio", "gym"), game.locations.distance_tenths("gym", "studio"))


func test_travel_advances_time_and_changes_location() -> void:
	var game := Helpers.new_game()
	var advanced := []
	var on_advanced := func(from: int, to: int) -> void: advanced.append(to - from)
	game.time.time_advanced.connect(on_advanced)
	assert_eq(game.locations.travel("studio"), "")
	assert_eq(game.locations.get_current(), "studio")
	assert_eq(game.time.format_clock(), "08:20")
	assert_eq(advanced, [20])
	assert_eq(game.ledger.get_entries().size(), 0)
	game.time.time_advanced.disconnect(on_advanced)


func test_invalid_travel_changes_nothing() -> void:
	var game := Helpers.new_game()
	assert_eq(game.locations.travel("home"), "Du bist schon hier.")
	assert_eq(game.locations.travel("moon"), "Unbekannter Ort: moon")
	assert_eq(game.time.format_clock(), "08:00")
	assert_eq(game.locations.get_current(), "home")


func test_travel_during_time_advance_is_rejected() -> void:
	var game := Helpers.new_game()
	var nested := []
	var on_advanced := func(_from: int, _to: int) -> void: nested.append(game.locations.travel("gym"))
	game.time.time_advanced.connect(on_advanced)
	game.activities.start("rest")
	assert_eq(nested, ["Gerade läuft bereits ein Zeitfortschritt."])
	assert_eq(game.locations.get_current(), "home")
	game.time.time_advanced.disconnect(on_advanced)


func test_opening_hours() -> void:
	var game := Helpers.new_game()
	var locations := game.locations
	assert_eq(locations.is_open_at("cafe_harbor", TimeSystemScript.at(1, 6, 59)), false)
	assert_eq(locations.is_open_at("cafe_harbor", TimeSystemScript.at(1, 7)), true)
	assert_eq(locations.is_open_at("cafe_harbor", TimeSystemScript.at(2, 19, 59)), true)
	assert_eq(locations.is_open_at("cafe_harbor", TimeSystemScript.at(2, 20)), false)
	assert_eq(locations.is_open_at("home", TimeSystemScript.at(1, 3)), true)
	assert_eq(locations.check_open_during("cafe_harbor", TimeSystemScript.at(1, 19, 30), 30), "")
	assert_eq(locations.check_open_during("cafe_harbor", TimeSystemScript.at(1, 19, 45), 30),
			"Café am Hafen schließt vorher (geöffnet 07:00–20:00).")
	assert_eq(locations.check_open_during("home", TimeSystemScript.at(1, 23), 480), "")


func test_travel_to_closed_location_is_allowed() -> void:
	var game := Helpers.new_game()
	game.time.advance(TimeSystemScript.at(1, 21) - game.time.get_minutes())
	assert_eq(game.locations.travel("office"), "")
	assert_eq(game.activities.check("plan_week"), "Büro ist geschlossen (geöffnet 08:00–18:00).")


func test_game_data_reports_broken_references() -> void:
	var data := Helpers.game_data()
	assert_eq(data.errors.size(), 0, "; ".join(data.errors))
	data.locations.load_data([_location("studio")])
	var problems := data.check_references()
	assert_true("Startort 'home' fehlt in den Ortsdaten." in problems, "; ".join(problems))
	assert_true("Aktivität 'rest': unbekannter Ort 'home'." in problems, "; ".join(problems))
	assert_true("Termin 'gym_trial': unbekannter Ort 'gym'." in problems, "; ".join(problems))
