extends "res://tests/base_test.gd"

const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")


func _valid(id: String = "rest") -> Dictionary:
	return {"id": id, "display_name": "Ausruhen", "location": "home", "tab": "alltag", "duration_minutes": 60, "effects": {"energy": 15}}


func test_real_data_file_loads_without_errors() -> void:
	var catalog := ActivityCatalogScript.new()
	var ok := catalog.load_file()
	assert_true(ok, "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["rest", "sleep", "eat_out", "coffee", "training", "plan_week",
			"order_stock", "plan_campaign", "merch_shoutout", "run_store", "prison_yard", "prison_read"]))
	assert_eq(catalog.get_ids_at("cafe_harbor"), PackedStringArray(["eat_out", "coffee"]))


func test_json_numbers_become_ints() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	var meal := catalog.get_definition("eat_out")
	assert_eq(meal.duration_minutes, 60)
	assert_eq(meal.money_cents, -1500)
	assert_eq(meal.get_effect("energy"), 10)
	assert_eq(meal.get_effect("unknown"), 0)


func test_missing_file_is_reported() -> void:
	var catalog := ActivityCatalogScript.new()
	assert_eq(catalog.load_file("res://data/gibt_es_nicht.json"), false)
	assert_eq(catalog.errors.size(), 1)


func test_data_must_be_a_list() -> void:
	var catalog := ActivityCatalogScript.new()
	assert_eq(catalog.load_data({"id": "rest"}), false)


func test_duplicate_ids_are_rejected() -> void:
	var catalog := ActivityCatalogScript.new()
	assert_eq(catalog.load_data([_valid("rest"), _valid("rest")]), false)
	assert_true("doppelt" in catalog.errors[0], catalog.errors[0])


func test_invalid_fields_are_all_reported() -> void:
	var catalog := ActivityCatalogScript.new()
	var data := [
		{"id": "Bad-ID", "display_name": "x", "location": "home", "tab": "alltag", "duration_minutes": 10},
		{"id": "no_name", "location": "home", "tab": "alltag", "duration_minutes": 10},
		{"id": "zero_duration", "display_name": "x", "location": "home", "tab": "alltag", "duration_minutes": 0},
		{"id": "fraction", "display_name": "x", "location": "home", "tab": "alltag", "duration_minutes": 1.5},
		{"id": "money_no_category", "display_name": "x", "location": "home", "tab": "alltag", "duration_minutes": 10, "money_cents": -100},
		{"id": "bad_effect", "display_name": "x", "location": "home", "tab": "alltag", "duration_minutes": 10, "effects": {"health": 5}},
		{"id": "no_location", "display_name": "x", "tab": "alltag", "duration_minutes": 10},
	]
	assert_eq(catalog.load_data(data), false)
	assert_eq(catalog.errors.size(), 7, "; ".join(catalog.errors))


func test_one_error_loads_nothing() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_data([_valid("rest"), {"id": "broken"}])
	assert_eq(catalog.has("rest"), false)
	assert_eq(catalog.get_ids().size(), 0)


func test_unknown_id_returns_null() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_data([_valid("rest")])
	assert_true(catalog.get_definition("fly") == null)


func test_new_activities_have_expected_values() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	var sleep := catalog.get_definition("sleep")
	assert_eq(sleep.duration_minutes, 480)
	assert_eq(sleep.get_effect("energy"), 60)
	assert_eq(sleep.location, "home")
	assert_eq(catalog.get_definition("coffee").location, "cafe_harbor")
	assert_eq(catalog.get_definition("training").location, "gym")
	assert_eq(catalog.get_definition("plan_week").location, "office")
