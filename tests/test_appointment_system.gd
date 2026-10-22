extends "res://tests/base_test.gd"

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const AppointmentCatalogScript := preload("res://scripts/systems/appointment_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

## Echter Termin: Treffen im Studio, Tag 1 14:00, 1 h, Stimmung +5, verpasst -10.
const MEETING := "camera_meeting"


func _new_game() -> GameStateScript:
	return Helpers.new_game()


func _advance_to(game: GameStateScript, minutes: int) -> void:
	game.time.advance(minutes - game.time.get_minutes())


func _appointment(id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "title": "T", "location": "home", "start": {"day": 1, "hour": 10},
			"duration_minutes": 30, "missed_effects": {"mood": -5}}
	result.merge(extra, true)
	return result


func test_real_appointment_data_loads_sorted() -> void:
	var catalog := AppointmentCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var ids := []
	for definition in catalog.get_all():
		ids.append(definition.id)
	assert_eq(ids, ["camera_meeting", "gym_trial", "week_meeting"])
	assert_eq(catalog.get_definition(MEETING).start_minutes, TimeSystemScript.at(1, 14))


func test_invalid_appointments_are_reported() -> void:
	var catalog := AppointmentCatalogScript.new()
	var data := [
		_appointment("ok"),
		_appointment("no_start", {"start": null}),
		_appointment("bad_hour", {"start": {"day": 1, "hour": 24}}),
		_appointment("no_penalty", {"missed_effects": {"mood": 0}}),
		_appointment("zero", {"duration_minutes": 0}),
		_appointment("ok"),
	]
	assert_eq(catalog.load_data(data), false)
	assert_eq(catalog.errors.size(), 5, "; ".join(catalog.errors))
	assert_eq(catalog.get_all().size(), 0)


func test_attend_needs_presence_and_time_window() -> void:
	var game := _new_game()
	game.locations.travel("studio")  # 08:20
	assert_eq(game.appointments.check(MEETING), "Wahrnehmen ab Tag 1 · 13:00 möglich.")
	_advance_to(game, TimeSystemScript.at(1, 13))
	assert_eq(game.appointments.check(MEETING), "")
	game.locations.travel("home")  # 13:20
	assert_eq(game.appointments.check(MEETING), "Nur vor Ort möglich: Studio.")


func test_attending_early_waits_until_start_then_runs_duration() -> void:
	var game := _new_game()
	game.locations.travel("studio")
	_advance_to(game, TimeSystemScript.at(1, 13, 20))
	var mood := game.stats.mood
	assert_eq(game.appointments.minutes_to_attend(MEETING), 40 + 60)
	assert_eq(game.appointments.attend(MEETING), "")
	assert_eq(game.time.format_clock(), "15:00")
	assert_eq(game.stats.mood, mood + 5)
	assert_eq(game.appointments.is_attended(MEETING), true)
	assert_eq(game.appointments.is_missed(MEETING), false)
	assert_eq(game.appointments.attend(MEETING), "Termin bereits wahrgenommen.")
	assert_eq(game.time.format_clock(), "15:00")


func test_attending_exactly_at_start_is_possible() -> void:
	var game := _new_game()
	game.locations.travel("studio")
	_advance_to(game, TimeSystemScript.at(1, 14))
	assert_eq(game.appointments.attend(MEETING), "")
	assert_eq(game.time.format_clock(), "15:00")


func test_missed_appointment_costs_mood_exactly_once() -> void:
	var game := _new_game()
	var missed := []
	game.appointments.appointment_missed.connect(func(id: String) -> void: missed.append(id))
	_advance_to(game, TimeSystemScript.at(1, 14))
	assert_eq(game.appointments.is_open(MEETING), true, "um 14:00 noch nicht verpasst")
	assert_eq(game.stats.mood, 60)
	game.activities.start("rest")  # 14:00 -> 15:00
	assert_eq(missed, [MEETING])
	assert_eq(game.stats.mood, 60 + 3 - 10)
	assert_eq(game.appointments.take_missed_notices(), PackedStringArray([MEETING]))
	assert_eq(game.appointments.take_missed_notices(), PackedStringArray())
	game.time.advance(3 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(missed.count(MEETING), 1)
	assert_eq(game.appointments.check(MEETING), "Termin ist vorbei.")


func test_long_jump_misses_all_appointments_in_order() -> void:
	var game := _new_game()
	var missed := []
	game.appointments.appointment_missed.connect(func(id: String) -> void: missed.append(id))
	game.time.advance(5 * TimeSystemScript.MINUTES_PER_DAY)
	assert_eq(missed, ["camera_meeting", "gym_trial", "week_meeting"])
	assert_eq(game.stats.mood, 60 - 10 - 8 - 10)
	assert_eq(game.appointments.get_upcoming().size(), 0)


func test_conflict_warning_for_activity_and_travel() -> void:
	var game := _new_game()
	_advance_to(game, TimeSystemScript.at(1, 13, 30))
	# Ausruhen bis 14:30 würde den Termin um 14:00 verpassen lassen.
	assert_eq(game.appointments.conflict_warning(60),
			"Achtung: Damit verpasst du „Treffen mit der Kamerafrau“ (Tag 1 · 14:00).")
	# Fahrt ins Studio (20 min) kommt um 13:50 an – keine Warnung.
	assert_eq(game.appointments.conflict_warning(game.locations.travel_minutes_to("studio")), "")
	# Endet genau zum Beginn: keine Warnung.
	assert_eq(game.appointments.conflict_warning(30), "")
	assert_eq(game.appointments.conflict_warning(31).is_empty(), false)
	# Die Warnung ändert nichts.
	assert_eq(game.time.format_clock(), "13:30")
	assert_eq(game.appointments.is_open(MEETING), true)


func test_travel_arriving_late_warns() -> void:
	var game := _new_game()
	_advance_to(game, TimeSystemScript.at(1, 13, 50))
	var minutes := game.locations.travel_minutes_to("studio")  # 20 min -> 14:10
	assert_eq(game.appointments.get_conflicts(minutes).size(), 1)


func test_attended_or_missed_appointment_does_not_warn() -> void:
	var game := _new_game()
	_advance_to(game, TimeSystemScript.at(1, 15))
	assert_eq(game.appointments.conflict_warning(24 * 60).contains("Kamerafrau"), false)


func test_appointment_without_presence_is_ignored_in_conflicts_with_itself() -> void:
	var game := _new_game()
	game.locations.travel("studio")
	_advance_to(game, TimeSystemScript.at(1, 13, 30))
	var minutes := game.appointments.minutes_to_attend(MEETING)
	assert_eq(game.appointments.conflict_warning(minutes, MEETING), "")


func test_restore_rejects_invalid_data_without_change() -> void:
	var game := _new_game()
	var before := game.appointments.to_dict()
	assert_true(not game.appointments.restore({"since_minutes": 1.5}).is_empty(), "Bruchzahl")
	assert_true(not game.appointments.restore({"since_minutes": 0, "attended": "x"}).is_empty(), "keine Liste")
	assert_true(not game.appointments.restore({"since_minutes": 0, "attended": ["a"], "missed": ["a"]}).is_empty(),
			"doppelt")
	assert_eq(game.appointments.to_dict(), before)


# --- G5.5: Warten bis Terminbeginn ---------------------------------------------------

func _snapshot(game: GameStateScript) -> Dictionary:
	return {"minutes": game.time.get_minutes(), "energy": game.stats.energy, "mood": game.stats.mood,
			"balance": game.ledger.get_balance(), "entries": game.ledger.get_entries().size(),
			"location": game.locations.get_current(), "appointments": game.appointments.to_dict()}


func test_wait_sets_clock_exactly_to_start() -> void:
	var game := _new_game()
	game.locations.travel("studio")
	_advance_to(game, TimeSystemScript.at(1, 12, 40))
	var before := _snapshot(game)
	assert_eq(game.appointments.offers_wait(MEETING), true)
	assert_eq(game.appointments.check_wait(MEETING), "")
	assert_eq(game.appointments.minutes_to_start(MEETING), 80)
	assert_eq(game.appointments.wait_until_start(MEETING), "")
	assert_eq(game.time.get_minutes(), TimeSystemScript.at(1, 14))
	# Kostet nichts, ändert keine Werte, der Termin ist nicht verpasst.
	assert_eq(game.stats.energy, before["energy"])
	assert_eq(game.stats.mood, before["mood"])
	assert_eq(game.ledger.get_balance(), before["balance"])
	assert_eq(game.ledger.get_entries().size(), before["entries"])
	assert_eq(game.appointments.is_missed(MEETING), false)
	assert_eq(game.appointments.take_missed_notices().size(), 0)
	# Danach: kein Warten mehr, direkt wahrnehmen.
	assert_eq(game.appointments.offers_wait(MEETING), false)
	assert_eq(game.appointments.check_wait(MEETING), "Termin hat schon begonnen.")
	assert_eq(game.appointments.check(MEETING), "")
	assert_eq(game.appointments.attend(MEETING), "")
	assert_eq(game.time.format_clock(), "15:00")


func test_wait_wrong_location_is_locked_without_change() -> void:
	var game := _new_game()
	_advance_to(game, TimeSystemScript.at(1, 12, 40))  # zu Hause
	var before := _snapshot(game)
	assert_eq(game.appointments.offers_wait(MEETING), true)
	assert_eq(game.appointments.check_wait(MEETING), "Erst hinfahren: Studio")
	assert_eq(game.appointments.wait_until_start(MEETING), "Erst hinfahren: Studio")
	assert_eq(_snapshot(game), before)


func test_wait_for_past_or_other_day_is_locked_without_change() -> void:
	var game := _new_game()
	game.locations.travel("studio")
	_advance_to(game, TimeSystemScript.at(1, 14, 30))  # verpasst
	var before := _snapshot(game)
	assert_eq(game.appointments.offers_wait(MEETING), false)
	assert_eq(game.appointments.wait_until_start(MEETING), "Termin ist vorbei.")
	# Probetraining ist morgen – heute kein Warten, auch nicht vor Ort.
	game.locations.travel("gym")
	before = _snapshot(game)
	assert_eq(game.appointments.offers_wait("gym_trial"), false)
	assert_eq(game.appointments.wait_until_start("gym_trial"), "Termin ist nicht heute.")
	assert_eq(_snapshot(game), before)
	assert_eq(game.appointments.wait_until_start("nope"), "Unbekannter Termin: nope")


## Das feste Ereignis (Tag 1, 20:00) liegt in der Wartezeit bis zu einem Test-Termin um 21:00 zu Hause:
## Es kommt genau einmal – auch nach Speichern/Laden und weiterem Zeitfortschritt nicht erneut.
func test_event_during_wait_comes_exactly_once() -> void:
	var data := Helpers.game_data()
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/appointments/appointments.json"))
	list.append(_appointment("late_call", {"start": {"day": 1, "hour": 21}, "duration_minutes": 30}))
	assert_true(data.appointments.load_data(list), "; ".join(data.appointments.errors))
	var game := Helpers.new_game(data)
	_advance_to(game, TimeSystemScript.at(1, 19))
	var triggered := []
	game.events.event_triggered.connect(func(id: String) -> void: triggered.append(id))
	var entries := game.ledger.get_entries().size()
	assert_eq(game.appointments.wait_until_start("late_call"), "")
	assert_eq(game.time.format_clock(), "21:00")
	assert_eq(triggered, ["first_brand_request"])
	assert_eq(game.events.get_next_pending_id(), "first_brand_request")
	assert_eq(game.ledger.get_entries().size(), entries)
	var copy := Helpers.new_game(data)
	assert_eq(copy.restore(game.to_dict()), "")
	copy.events.event_triggered.connect(func(id: String) -> void: triggered.append(id))
	copy.time.advance(60)
	assert_eq(triggered, ["first_brand_request"])
	assert_eq(copy.events.get_triggered_ids(), PackedStringArray(["first_brand_request"]))
