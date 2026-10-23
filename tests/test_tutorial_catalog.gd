extends "res://tests/base_test.gd"

## Ticket T.1: Datenformat und Katalog für Tutorials – echte Datei lädt; jeder Fehler wird gemeldet und lädt nichts;
## Zyklen in „requires“ werden erkannt.

const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")


func _entry(id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "mechanic": "map", "trigger": "first_game_start", "title": "Titel", "text": "Kurzer Text.",
			"ui_target": "", "order": 0, "requires": []}
	result.merge(extra, true)
	return result


## Lädt `data` und erwartet einen Fehler, der `fragment` enthält – und dass nichts geladen ist.
func _expect_error(data: Variant, fragment: String) -> void:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_file(), "Vorab: echte Datei lädt nicht")
	assert_eq(catalog.load_data(data), false, "angenommen: %s" % fragment)
	assert_true(" ".join(catalog.errors).contains(fragment), "„%s“ nicht in: %s" % [fragment, "; ".join(catalog.errors)])
	assert_eq(catalog.get_all().size(), 0, "trotz Fehler geladen (%s)" % fragment)


func test_real_file_loads() -> void:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	var ids := []
	for definition in catalog.get_all():
		ids.append(definition.id)
		assert_true(definition.trigger in TutorialCatalogScript.TRIGGERS)
		assert_true(definition.text.length() <= TutorialCatalogScript.MAX_TEXT_LENGTH)
	assert_eq(ids, ["tut_map", "tut_map_tap_building", "tut_map_swipe", "tut_activities", "tut_travel", "tut_trip",
			"tut_stats", "tut_calendar", "tut_reminder", "tut_conflict", "tut_wait", "tut_event", "tut_save",
			"tut_channel", "tut_content", "tut_equipment", "tut_symbols", "tut_company", "tut_transfer", "tut_branch",
			"tut_settlement", "tut_obligations", "tut_ledger", "tut_black_money", "tut_heat"],
			"sortiert nach order")
	var tap = catalog.get_definition("tut_map_tap_building")
	assert_eq(tap.mechanic, "location_open")
	assert_eq(tap.ui_target, "MapPin_studio")
	assert_eq(tap.requires, PackedStringArray(["tut_map"]))
	assert_eq(catalog.get_for_trigger("first_game_start").map(func(d) -> String: return d.id),
			["tut_map", "tut_map_tap_building"])
	assert_eq(catalog.has("nope"), false)


func test_empty_target_and_requires_are_allowed() -> void:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_data([_entry("tut_a"), _entry("tut_b", {"requires": ["tut_a"], "order": 3})]),
			"; ".join(catalog.errors))
	assert_eq(catalog.get_definition("tut_a").ui_target, "")


func test_missing_fields_are_reported() -> void:
	for field in TutorialCatalogScript.FIELDS:
		if field == "id":
			continue
		var entry := _entry("tut_a")
		entry.erase(field)
		_expect_error([entry], "'%s'" % field)
	_expect_error([{"title": "ohne ID"}], "'id'")


func test_bad_values_are_reported() -> void:
	_expect_error([_entry("tut_a", {"extra": 1})], "unbekanntes Feld 'extra'")
	_expect_error([_entry("tut_a"), _entry("tut_a")], "doppelt")
	_expect_error([_entry("tut_a", {"trigger": "whenever"})], "unbekannter 'trigger' 'whenever'")
	_expect_error([_entry("tut_a", {"requires": ["tut_x"]})], "unbekanntes Tutorial 'tut_x'")
	_expect_error([_entry("tut_a", {"requires": ["tut_a"]})], "auf sich selbst")
	_expect_error([_entry("tut_a", {"requires": "tut_b"})], "'requires' fehlt oder ist keine Liste")
	_expect_error([_entry("tut_a", {"order": -1})], "'order' darf nicht negativ")
	_expect_error([_entry("tut_a", {"order": 1.5})], "'order'")
	_expect_error([_entry("tut_a", {"ui_target": "Travel Button"})], "'ui_target'")
	_expect_error([_entry("tut_a", {"ui_target": "Tile-?"})], "'ui_target'")
	_expect_error([_entry("tut_a", {"ui_target": 5})], "'ui_target'")
	_expect_error([_entry("tut_a", {"mechanic": "Map-Tap"})], "'mechanic' ist ungültig")
	_expect_error([_entry("tut_a", {"text": "x".repeat(TutorialCatalogScript.MAX_TEXT_LENGTH + 1)})], "zu lang")
	_expect_error([_entry("tut_a", {"title": ""})], "'title'")
	_expect_error({"tut_a": {}}, "Liste")
	_expect_error(["kein Objekt"], "Objekt")
	# Ein fehlerhafter Eintrag neben gültigen: nichts wird geladen.
	_expect_error([_entry("tut_ok"), _entry("tut_bad", {"trigger": "x"})], "unbekannter 'trigger'")


func test_cycle_in_requires_is_detected() -> void:
	_expect_error([_entry("tut_a", {"requires": ["tut_b"]}), _entry("tut_b", {"requires": ["tut_a"]})], "Zyklus")
	_expect_error([_entry("tut_a", {"requires": ["tut_c"]}), _entry("tut_b", {"requires": ["tut_a"]}),
			_entry("tut_c", {"requires": ["tut_b"]}), _entry("tut_d")], "Zyklus")
	# Raute ohne Zyklus ist erlaubt.
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_data([_entry("tut_a"), _entry("tut_b", {"requires": ["tut_a"]}),
			_entry("tut_c", {"requires": ["tut_a"]}), _entry("tut_d", {"requires": ["tut_b", "tut_c"]})]),
			"; ".join(catalog.errors))


func test_broken_json_file_loads_nothing() -> void:
	var path := "user://test_tutorials_broken.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[{\"id\": ")
	file.close()
	var catalog := TutorialCatalogScript.new()
	assert_eq(catalog.load_file(path), false)
	assert_true(not catalog.errors.is_empty())
	assert_eq(catalog.get_all().size(), 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
