extends "res://tests/base_test.gd"

const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")


func _valid(id: String = "rest") -> Dictionary:
	return {"id": id, "display_name": "Ausruhen", "duration_minutes": 60, "effects": {"energy": 15}}


func test_real_data_file_loads_without_errors() -> void:
	var catalog := ActivityCatalogScript.new()
	var ok := catalog.load_file()
	assert_true(ok, "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["stream_short", "rest", "eat_out"]))


func test_json_numbers_become_ints() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	var stream := catalog.get_definition("stream_short")
	assert_eq(stream.duration_minutes, 120)
	assert_eq(stream.money_cents, 2500)
	assert_eq(stream.get_effect("energy"), -20)
	assert_eq(stream.get_effect("unknown"), 0)


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
		{"id": "Bad-ID", "display_name": "x", "duration_minutes": 10},
		{"id": "no_name", "duration_minutes": 10},
		{"id": "zero_duration", "display_name": "x", "duration_minutes": 0},
		{"id": "fraction", "display_name": "x", "duration_minutes": 1.5},
		{"id": "money_no_category", "display_name": "x", "duration_minutes": 10, "money_cents": -100},
		{"id": "bad_effect", "display_name": "x", "duration_minutes": 10, "effects": {"health": 5}},
	]
	assert_eq(catalog.load_data(data), false)
	assert_eq(catalog.errors.size(), 6, "; ".join(catalog.errors))


func test_one_error_loads_nothing() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_data([_valid("rest"), {"id": "broken"}])
	assert_eq(catalog.has("rest"), false)
	assert_eq(catalog.get_ids().size(), 0)


func test_unknown_id_returns_null() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_data([_valid("rest")])
	assert_true(catalog.get_definition("fly") == null)
