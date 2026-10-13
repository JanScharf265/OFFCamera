extends "res://tests/base_test.gd"

## Ausrüstung (Ticket 3.3): Daten, Kauf Stufe für Stufe über das Ledger, Qualitätsbonus, Speichern.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const EquipmentCatalogScript := preload("res://scripts/systems/equipment_catalog.gd")


func _game_at_studio() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.locations.travel("studio"), "", "Fahrt ins Studio")
	return game


func _valid(id: String = "tripod") -> Dictionary:
	return {"id": id, "display_name": "Stativ", "location": "studio", "tab": "content", "formats": ["livestream"],
			"levels": [{"name": "Klein", "price_cents": 1000, "quality_percent": 2},
				{"name": "Groß", "price_cents": 3000, "quality_percent": 4}]}


func test_real_equipment_file_loads() -> void:
	var catalog := EquipmentCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["camera", "microphone", "lighting"]))
	for id in catalog.get_ids():
		assert_eq(catalog.get_definition(id).max_level(), 3, id)


func test_catalog_rejects_invalid_equipment() -> void:
	var catalog := EquipmentCatalogScript.new()
	var no_formats := _valid()
	no_formats["formats"] = []
	assert_eq(catalog.load_data([no_formats]), false)
	var free := _valid()
	free["levels"][0]["price_cents"] = 0
	assert_eq(catalog.load_data([free]), false)
	var falling := _valid()
	falling["levels"][1]["quality_percent"] = 1
	assert_eq(catalog.load_data([falling]), false)
	assert_eq(catalog.load_data([_valid()]), true)


func test_unknown_references_are_reported() -> void:
	var data := Helpers.game_data()
	var item := _valid()
	item["formats"] = ["hologramm"]
	item["location"] = "mond"
	data.equipment.load_data([item])
	var problems := data.check_references()
	assert_true("Ausrüstung 'tripod': unbekannter Ort 'mond'." in problems, "Ort nicht geprüft")
	assert_true("Ausrüstung 'tripod': unbekanntes Format 'hologramm'." in problems, "Format nicht geprüft")


func test_buy_first_level_books_expense_and_raises_level() -> void:
	var game := _game_at_studio()
	var clock := game.time.format_clock()
	assert_eq(game.equipment.buy("camera"), "")
	assert_eq(game.equipment.get_level("camera"), 1)
	assert_eq(game.ledger.get_balance(), 50000 - 12000)
	assert_eq(game.time.format_clock(), clock)  # Kauf kostet keine Zeit
	var entry = game.ledger.get_entries()[0]
	assert_eq(entry.category, "equipment")
	assert_eq(entry.source, "equipment")
	assert_eq(entry.description, "Kamera: Webcam HD")
	assert_eq(entry.reference, "camera:1")


func test_levels_are_bought_one_after_another_up_to_maximum() -> void:
	var game := _game_at_studio()
	game.ledger.post(300000, "test", "Startkapital für Test", "test")
	assert_eq(game.equipment.buy("lighting"), "")
	assert_eq(game.equipment.buy("lighting"), "")
	assert_eq(game.equipment.buy("lighting"), "")
	assert_eq(game.equipment.get_level("lighting"), 3)
	assert_eq(game.equipment.buy("lighting"), "Höchste Stufe erreicht.")
	assert_eq(game.ledger.get_entries_by_category("equipment").size(), 3)


func test_buy_elsewhere_or_without_money_changes_nothing() -> void:
	var game := Helpers.new_game()  # Wohnung
	assert_eq(game.equipment.buy("camera"), "Nur vor Ort erhältlich: Studio.")
	game.locations.travel("studio")
	game.ledger.post(-45000, "test", "Ausgabe für Test", "test")  # 500 € -> 50 €
	assert_eq(game.equipment.buy("camera"), "Nicht genug Geld (kostet 120,00 €).")
	assert_eq(game.equipment.get_level("camera"), 0)
	assert_eq(game.ledger.get_balance(), 5000)


func test_equipment_raises_content_quality_only_for_its_formats() -> void:
	var game := _game_at_studio()
	game.equipment.buy("camera")      # +5 % Kurzvideo, Livestream, Langes Video
	game.equipment.buy("microphone")  # +5 % Livestream, Langes Video, Q&A
	assert_eq(game.content.quality_percent("livestream"), 110)
	assert_eq(game.content.quality_percent("community_qa"), 105)
	assert_eq(game.content.quality_percent("short_video"), 105)
	assert_eq(game.content.quality_text("livestream"),
			"Qualität 110 % (Kamera (Webcam HD) +5 %, Mikrofon (USB-Mikrofon) +5 %)")
	assert_eq(game.content.preview("livestream")["income_cents"], 2750)


func test_bonus_is_level_value_not_sum() -> void:
	var game := _game_at_studio()
	game.ledger.post(300000, "test", "Startkapital für Test", "test")
	game.equipment.buy("camera")
	game.equipment.buy("camera")  # Systemkamera: 10 %, nicht 5 + 10
	assert_eq(game.content.quality_percent("livestream"), 110)


func test_levels_survive_round_trip() -> void:
	var game := _game_at_studio()
	game.equipment.buy("camera")
	var copy := Helpers.new_game()
	assert_eq(copy.equipment.restore(JSON.parse_string(JSON.stringify(game.equipment.to_dict()))), "")
	assert_eq(copy.equipment.get_level("camera"), 1)
	assert_eq(copy.equipment.get_level("lighting"), 0)


func test_restore_ignores_removed_items_and_clamps_levels() -> void:
	var game := Helpers.new_game()
	assert_eq(game.equipment.restore({"levels": {"camera": 7, "jetpack": 2}}), "")
	assert_eq(game.equipment.get_level("camera"), 3)
	assert_eq(game.equipment.get_level("jetpack"), 0)
	assert_true(not game.equipment.restore({"levels": {"camera": -1}}).is_empty(), "negative Stufe akzeptiert")
	assert_eq(game.equipment.get_level("camera"), 3)
