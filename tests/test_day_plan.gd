extends "res://tests/base_test.gd"

## Ticket G5.2: Tagesplan (scripts/core/day_plan.gd) – Sortierung, leerer Tag, Termin und Frist am selben Tag,
## vergangene Einträge, Jetzt-Linie, überfällige Frist.

const DayPlanScript := preload("res://scripts/core/day_plan.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


func _ids(plan: Dictionary) -> Array:
	var ids := []
	for entry in plan["entries"]:
		ids.append(entry["id"])
	return ids


func _entry(plan: Dictionary, id: String) -> Dictionary:
	for entry in plan["entries"]:
		if entry["id"] == id:
			return entry
	return {}


## Echte Daten plus zwei Termine an Tag 8 (Montag – dann sind auch die Mieten fällig).
func _game_with_monday_appointments():
	var data := Helpers.game_data()
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/appointments/appointments.json"))
	list.append({"id": "late_call", "title": "Späte Besprechung", "location": "office", "start": {"day": 8, "hour": 11},
			"duration_minutes": 60, "effects": {}, "missed_effects": {"mood": -2}})
	list.append({"id": "early_call", "title": "Frühe Besprechung", "location": "office", "start": {"day": 8, "hour": 9},
			"duration_minutes": 60, "effects": {}, "missed_effects": {"mood": -2}})
	assert_true(data.appointments.load_data(list), "; ".join(data.appointments.errors))
	return GameStateScript.new(data, Helpers.TEST_SEED)


func test_first_day_has_the_camera_meeting_as_next() -> void:
	var game := Helpers.new_game()
	var plan := DayPlanScript.for_day(game)
	assert_eq(plan["day"], 1)
	assert_eq(_ids(plan), ["camera_meeting"])
	var meeting := _entry(plan, "camera_meeting")
	assert_eq(meeting["state"], DayPlanScript.STATE_NEXT)
	assert_eq(meeting["travel_minutes"], game.locations.travel_minutes_to("studio"))
	assert_eq(meeting["start_minutes"], TimeSystemScript.at(1, 14))
	assert_eq(meeting["end_minutes"], TimeSystemScript.at(1, 15))
	assert_eq(plan["now_index"], 0, "Jetzt-Linie vor dem Termin")
	assert_eq(plan["next_later"]["id"], "gym_trial")


func test_empty_day() -> void:
	var game := Helpers.new_game()
	game.time.advance(TimeSystemScript.at(4, 10) - game.time.get_minutes())
	var plan := DayPlanScript.for_day(game)
	assert_eq(plan["entries"], [] as Array[Dictionary])
	assert_eq(plan["now_index"], 0)
	assert_eq(plan["next_later"], {}, "nach Tag 3 gibt es keine Termine mehr")


func test_appointment_and_obligations_on_the_same_day_are_sorted() -> void:
	var game = _game_with_monday_appointments()
	game.time.advance(TimeSystemScript.at(8, 10, 30) - game.time.get_minutes())
	var plan := DayPlanScript.for_day(game)
	# Fristen (00:00) zuerst, nach ID sortiert; dann die Termine nach Uhrzeit (nicht nach Dateireihenfolge).
	assert_eq(_ids(plan), ["rent_home@8", "rent_studio@8", "early_call", "late_call"])
	assert_eq(_entry(plan, "rent_home@8")["kind"], DayPlanScript.KIND_OBLIGATION)
	assert_eq(_entry(plan, "rent_home@8")["state"], DayPlanScript.STATE_PAID)
	assert_eq(_entry(plan, "rent_home@8")["amount_cents"], 8000)
	assert_eq(_entry(plan, "early_call")["state"], DayPlanScript.STATE_MISSED, "09:00–10:00 ist vorbei")
	assert_eq(_entry(plan, "late_call")["state"], DayPlanScript.STATE_NEXT)
	assert_eq(plan["now_index"], 3, "Jetzt-Linie nach den vergangenen Einträgen")
	assert_eq(DayPlanScript.is_past(_entry(plan, "early_call")), true)
	assert_eq(DayPlanScript.is_past(_entry(plan, "late_call")), false)


func test_attended_and_missed_appointments() -> void:
	var game := Helpers.new_game()
	game.locations.travel("studio")
	game.time.advance(TimeSystemScript.at(1, 13, 30) - game.time.get_minutes())
	assert_eq(game.appointments.attend("camera_meeting"), "")
	var plan := DayPlanScript.for_day(game)
	assert_eq(_entry(plan, "camera_meeting")["state"], DayPlanScript.STATE_ATTENDED)
	assert_eq(_entry(plan, "camera_meeting")["travel_minutes"], 0, "schon im Studio")
	# Verstreicht der Beginn ohne Wahrnehmen, ist der Termin verpasst (auch vor seinem Ende) – keiner ist „als Nächstes“.
	var other := Helpers.new_game()
	other.time.advance(TimeSystemScript.at(1, 14, 10) - other.time.get_minutes())
	var other_plan := DayPlanScript.for_day(other)
	assert_eq(_entry(other_plan, "camera_meeting")["state"], DayPlanScript.STATE_MISSED)
	assert_eq(other_plan["now_index"], 1)


func test_open_obligation_stays_visible_as_overdue_on_later_days() -> void:
	var game := Helpers.new_game()
	game.ledger.post(-48000, "test", "Geld weg", "test")  # 20 € übrig – die Mieten an Tag 8 bleiben offen
	game.time.advance(TimeSystemScript.at(8, 9) - game.time.get_minutes())
	var monday := DayPlanScript.for_day(game)
	assert_eq(_entry(monday, "rent_home@8")["state"], DayPlanScript.STATE_OPEN)
	assert_eq(_entry(monday, "rent_home@8")["overdue"], false)
	game.time.advance(TimeSystemScript.at(9, 9) - game.time.get_minutes())
	var tuesday := DayPlanScript.for_day(game)
	assert_eq(_entry(tuesday, "rent_home@8")["overdue"], true)
	assert_eq(_entry(tuesday, "rent_home@8")["state"], DayPlanScript.STATE_OPEN)
	# Ein früherer Tag zeigt keine überfälligen Fristen, nur seine eigenen Einträge.
	assert_eq(_ids(DayPlanScript.for_day(game, 2)), ["gym_trial"])


func test_day_plan_changes_nothing() -> void:
	var game := Helpers.new_game()
	var before := JSON.stringify(game.to_dict())
	DayPlanScript.for_day(game)
	DayPlanScript.for_day(game, 3)
	assert_eq(JSON.stringify(game.to_dict()), before)
