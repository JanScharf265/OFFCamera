extends "res://tests/base_test.gd"

const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


func _valid(id: String = "evt") -> Dictionary:
	return {
		"id": id, "title": "Titel", "text": "Text", "trigger": {"day": 1, "hour": 12},
		"options": [{"id": "ok", "label": "Okay"}],
	}


func test_real_data_file_loads_without_errors() -> void:
	var catalog := EventCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	var event := catalog.get_definition("first_brand_request")
	assert_true(event != null, "first_brand_request fehlt")
	assert_eq(event.due_minutes, TimeSystemScript.at(1, 20))
	assert_eq(event.options.size(), 2)
	assert_eq(event.get_option("accept").money_cents, 3000)
	assert_eq(event.get_option("accept").effects, {"mood": 5})


func test_priority_and_minute_default_to_zero() -> void:
	var catalog := EventCatalogScript.new()
	catalog.load_data([_valid()])
	var event := catalog.get_definition("evt")
	assert_eq(event.priority, 0)
	assert_eq(event.due_minutes, TimeSystemScript.at(1, 12, 0))


func test_duplicate_event_ids_are_rejected() -> void:
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([_valid("a"), _valid("a")]), false)
	assert_eq(catalog.get_all().size(), 0)


func test_missing_or_empty_options_are_rejected() -> void:
	var no_options := _valid("no_options")
	no_options.erase("options")
	var empty_options := _valid("empty_options")
	empty_options["options"] = []
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([no_options, empty_options]), false)
	assert_eq(catalog.errors.size(), 2, "; ".join(catalog.errors))


func test_duplicate_option_ids_are_rejected() -> void:
	var event := _valid()
	event["options"] = [{"id": "ok", "label": "A"}, {"id": "ok", "label": "B"}]
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([event]), false)


func test_invalid_trigger_is_rejected() -> void:
	var event := _valid()
	event["trigger"] = {"day": 1, "hour": 24}
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([event]), false)
	assert_true("trigger" in catalog.errors[0], catalog.errors[0])


func test_option_rules_match_activity_rules() -> void:
	var money_without_category := _valid("money")
	money_without_category["options"] = [{"id": "pay", "label": "Zahlen", "money_cents": -500}]
	var unknown_effect := _valid("effect")
	unknown_effect["options"] = [{"id": "x", "label": "X", "effects": {"health": 1}}]
	var catalog := EventCatalogScript.new()
	assert_eq(catalog.load_data([money_without_category, unknown_effect]), false)
	assert_eq(catalog.errors.size(), 2, "; ".join(catalog.errors))
