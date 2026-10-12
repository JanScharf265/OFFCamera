extends "res://tests/base_test.gd"

## Zufällige Karriere-Ereignisse (Ticket 3.4): deterministisch per Seed, regelbasiert,
## höchstens eins pro Tag, nie doppelt – auch nicht nach dem Laden.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const PATH := "user://test_random_events.json"


func _random(id: String, chance: int, extra: Dictionary = {}, options: Array = []) -> Dictionary:
	var spec := {"chance_percent": chance}
	spec.merge(extra)
	if options.is_empty():
		options = [{"id": "ok", "label": "Okay", "channel": {"community": 1}}]
	return {"id": id, "title": "Titel %s" % id, "text": "X", "trigger": {"random": spec}, "options": options}


## Spiel nur mit den angegebenen Ereignissen, ohne Termine.
func _game(events: Array, game_seed: int = Helpers.TEST_SEED) -> GameStateScript:
	var data := Helpers.game_data()
	data.appointments.load_data([])
	assert_true(data.events.load_data(events), "Testdaten ungültig: %s" % "; ".join(data.events.errors))
	return GameStateScript.new(data, game_seed)


## Spielt bis zum Beginn von Tag `day` (08:00) – jedes Ereignis wird gleich entschieden.
func _play_to_day(game: GameStateScript, day: int) -> void:
	while game.time.get_day() < day:
		game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())
		while game.events.has_pending():
			var instance := game.events.get_next_pending_id()
			game.events.resolve(instance, game.events.get_definition_for(instance).options[0].id)


func test_real_events_load() -> void:
	var catalog := EventCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	var random_ids := PackedStringArray()
	for definition in catalog.get_all():
		if definition.is_random:
			random_ids.append(definition.id)
	assert_eq(random_ids, PackedStringArray(["brand_deal", "shitstorm", "raid", "tech_failure", "viral_short"]))


func test_catalog_rejects_invalid_random_triggers() -> void:
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([_random("a", 0)]), false)
	assert_eq(catalog.load_data([_random("a", 101)]), false)
	assert_eq(catalog.load_data([_random("a", 50, {"from_day": 1})]), false)
	assert_eq(catalog.load_data([_random("a", 50, {"conditions": {"min_money": 5}})]), false)
	var bad_option := _random("a", 50, {}, [{"id": "x", "label": "X", "channel": {"fame": 3}}])
	assert_eq(catalog.load_data([bad_option]), false)
	assert_eq(catalog.load_data([_random("a", 50, {"cooldown_days": 2, "conditions": {"min_followers": 10}})]), true)


func test_fnv_hash_is_stable() -> void:
	# Referenzwerte FNV-1a 32 Bit – dürfen sich nie ändern, sonst ändern sich alte Spielverläufe.
	assert_eq(EventSystemScript.fnv1a(""), 2166136261)
	assert_eq(EventSystemScript.fnv1a("a"), 3826002220)
	assert_eq(EventSystemScript.fnv1a("foobar"), 3214735720)


func test_always_event_triggers_on_new_day_not_on_day_one() -> void:
	var game := _game([_random("always", 100)])
	game.time.advance(10 * 60)  # Tag 1, 18:00
	assert_eq(game.events.has_pending(), false)
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
	assert_eq(game.events.get_next_pending_id(), "always@2")


func test_same_seed_same_history_different_seed_differs() -> void:
	var events := [_random("coin", 50)]
	var a := _game(events, 7)
	var b := _game(events, 7)
	_play_to_day(a, 30)
	_play_to_day(b, 30)
	assert_eq(a.events.get_triggered_ids(), b.events.get_triggered_ids())
	assert_true(a.events.get_triggered_ids().size() > 5, "50 % über 29 Tage sollte öfter auslösen")
	var differs := false
	for other_seed in [8, 9, 10]:
		var c := _game(events, other_seed)
		_play_to_day(c, 30)
		differs = differs or c.events.get_triggered_ids() != a.events.get_triggered_ids()
	assert_true(differs, "Seed hat keinen Einfluss")


func test_trigger_matches_documented_roll() -> void:
	var game := _game([_random("coin", 50)])
	_play_to_day(game, 20)
	for day in range(2, 21):
		var expected := game.events.roll(day, "coin") < 50
		assert_eq(game.events.is_triggered("coin@%d" % day), expected, "Tag %d" % day)


func test_conditions_block_event() -> void:
	var game := _game([_random("big", 100, {"conditions": {"min_followers": 1000}})])
	_play_to_day(game, 3)
	assert_true(game.events.get_triggered_ids().is_empty(), "Bedingung ignoriert")
	game.channel.apply({"followers": 2000}, "test", "Wachstum")
	_play_to_day(game, 4)
	assert_eq(game.events.get_triggered_ids(), PackedStringArray(["big@4"]))


func test_from_day_cooldown_and_max_times() -> void:
	var game := _game([_random("rare", 100, {"from_day": 3, "cooldown_days": 3, "max_times": 2})])
	_play_to_day(game, 12)
	assert_eq(game.events.get_triggered_ids(), PackedStringArray(["rare@3", "rare@6"]))


func test_at_most_one_random_event_per_day_by_priority() -> void:
	var low := _random("low", 100)
	var high := _random("high", 100)
	high["priority"] = 5
	var game := _game([low, high])
	_play_to_day(game, 2)
	assert_eq(game.events.get_triggered_ids(), PackedStringArray(["high@2"]))


func test_channel_effects_with_percent_brake_and_reason() -> void:
	var option := {"id": "go", "label": "Los", "channel": {"followers": 100, "followers_percent": 10, "reputation": -2}}
	var game := _game([_random("wave", 100, {}, [option])])
	game.channel.apply({"followers": 880}, "test", "Start")  # 120 -> 1000
	_play_to_day(game, 2)
	# _play_to_day hat "go" gewählt: 100 + 10 % von 1000 = 200 (Bremse bei 1000 Followern: 200)
	assert_eq(game.channel.followers, 1200)
	assert_eq(game.channel.reputation, 48)
	var last = game.channel.get_history()[-1]
	assert_eq(last.source, "event")
	assert_eq(last.reason, "Titel wave: Los")
	assert_eq(last.reference, "wave@2")


func test_option_preview_matches_result() -> void:
	var option := {"id": "go", "label": "Los", "channel": {"followers_percent": -50, "community": 4}}
	var game := _game([_random("drop", 100, {}, [option])])
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
	var preview := game.events.option_channel_deltas("drop@2", "go")
	assert_eq(preview, {"followers": -60, "community": 4})
	assert_eq(game.events.resolve("drop@2", "go"), "")
	assert_eq(game.channel.followers, 60)
	assert_eq(game.channel.community, 54)


func test_money_of_random_event_is_booked_once_per_instance() -> void:
	var option := {"id": "pay", "label": "Zahlen", "money_cents": -1000, "category": "repair"}
	var game := _game([_random("bill", 100, {}, [option])])
	_play_to_day(game, 4)
	var entries := game.ledger.get_entries_by_category("repair")
	assert_eq(entries.size(), 3)
	assert_eq(entries[0].reference, "bill@2")
	assert_eq(game.ledger.get_balance(), 50000 - 3000)


func test_load_does_not_reroll_or_retrigger() -> void:
	var game := _game([_random("coin", 50)], 99)
	_play_to_day(game, 10)
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.save(game, PATH), "")
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([_random("coin", 50)])
	var loaded: GameStateScript = SaveSystemScript.load_game(data, PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded == null:
		return
	assert_eq(loaded.events.get_seed(), 99)
	assert_eq(loaded.events.get_triggered_ids(), game.events.get_triggered_ids())
	# Weiterspielen ergibt dasselbe wie ohne Speichern.
	_play_to_day(game, 20)
	_play_to_day(loaded, 20)
	assert_eq(loaded.events.get_triggered_ids(), game.events.get_triggered_ids())
	SaveSystemScript.delete_save(PATH)


func test_version_4_save_gets_fixed_seed() -> void:
	var game := Helpers.new_game()
	var saved := game.to_dict()
	saved["events"].erase("seed")
	saved.erase("company")
	saved.erase("obligations")
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "game": Helpers.with_single_account_ledger(saved)}))
	file.close()
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Migration fehlgeschlagen")
	if loaded != null:
		assert_eq(loaded.events.get_seed(), SaveSystemScript.MIGRATED_SEED)
	SaveSystemScript.delete_save(PATH)


func test_real_events_need_their_conditions() -> void:
	# Startkanal: 120 Follower, Ruf 50 – Kooperation (Ruf ≥ 60, ≥ 500 Follower) und Raid (≥ 300) unmöglich.
	var game := Helpers.new_game()
	game.appointments.restore({"since_minutes": 99999, "attended": [], "missed": []})
	_play_to_day(game, 40)
	for instance in game.events.get_triggered_ids():
		assert_true(not instance.begins_with("brand_deal@") and not instance.begins_with("raid@"),
				"%s trotz Bedingungen ausgelöst" % instance)
