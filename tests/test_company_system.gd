extends "res://tests/base_test.gd"

## Unternehmen (Ticket 4.2): Daten, Gründung über Ledger und Zeit, Einlage/Entnahme, Protokoll, Speichern.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const PATH := "user://test_company_save.json"


func _game_at_office() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.locations.travel("office"), "", "Fahrt ins Büro")  # 08:00 -> 08:20
	return game


func _founded() -> GameStateScript:
	var game := _game_at_office()
	assert_eq(game.company.found("merch_label"), "", "Gründung")
	return game


func test_real_company_types_load() -> void:
	var catalog := CompanyTypeCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["merch_label"]))
	assert_eq(catalog.get_ids_at("office"), PackedStringArray(["merch_label"]))


func test_catalog_rejects_invalid_types() -> void:
	var catalog := CompanyTypeCatalogScript.new()
	catalog.load_file()
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CompanyTypeCatalogScript.DEFAULT_PATH))[0]
	var free := valid.duplicate()
	free["founding_fee_cents"] = 0
	assert_eq(catalog.load_data([free]), false)
	var too_high := valid.duplicate()
	too_high["start_utilization"] = 120
	assert_eq(catalog.load_data([too_high]), false)
	var missing := valid.duplicate()
	missing.erase("fixed_costs_per_day_cents")
	assert_eq(catalog.load_data([missing]), false)
	assert_eq(catalog.load_data([valid]), true)


func test_new_game_has_no_company() -> void:
	var game := Helpers.new_game()
	assert_eq(game.company.is_founded(), false)
	assert_eq(game.company.to_dict(), {"founded": false})


func test_found_books_fee_and_deposit_and_takes_time() -> void:
	var game := _founded()
	assert_eq(game.company.is_founded(), true)
	assert_eq(game.company.get_type().id, "merch_label")
	assert_eq(game.company.utilization, 50)
	assert_eq(game.company.reputation, 50)
	assert_eq(game.time.format_clock(), "09:20")
	assert_eq(game.ledger.get_balance("private"), 50000 - 15000 - 20000)
	assert_eq(game.ledger.get_balance("company"), 20000)
	var entries := game.ledger.get_entries()
	assert_eq(entries.size(), 3)
	if entries.size() == 3:
		assert_eq(entries[0].description, "Gründung: Merch-Label")
		assert_eq(entries[0].time_minutes, TimeSystemScript.at(1, 8, 20))
		assert_eq(entries[1].reference, "company:deposit:1")
		assert_eq(entries[2].account, "company")
	assert_eq(game.company.get_history().size(), 1)
	assert_eq(game.company.get_history()[0].reason, "Gegründet: Merch-Label (Auslastung 50, Ruf 50)")


func test_found_only_once_and_only_at_office() -> void:
	var game := Helpers.new_game()
	assert_eq(game.company.found("merch_label"), "Nur vor Ort möglich: Büro.")
	game.locations.travel("office")
	assert_eq(game.company.found("merch_label"), "")
	assert_eq(game.company.found("merch_label"), "Du hast bereits ein Unternehmen.")
	assert_eq(game.ledger.get_entries().size(), 3)


func test_found_needs_money_and_open_office() -> void:
	var game := _game_at_office()
	game.ledger.post(-20000, "test", "Ausgabe für Test", "test")  # 500 € -> 300 €
	assert_eq(game.company.found("merch_label"), "Nicht genug Geld auf dem Privatkonto (Gebühr + Einlage: 350,00 €).")
	game.ledger.post(10000, "test", "Einnahme für Test", "test")
	game.time.advance(TimeSystemScript.at(1, 17, 30) - game.time.get_minutes())
	assert_eq(game.company.found("merch_label"), "Büro schließt vorher (geöffnet 08:00–18:00).")
	assert_eq(game.company.is_founded(), false)
	assert_eq(game.ledger.get_balance("company"), 0)


func test_deposit_and_withdraw_are_linked_transfers() -> void:
	var game := _founded()
	assert_eq(game.company.deposit(5000), "")
	assert_eq(game.company.withdraw(2000), "")
	assert_eq(game.ledger.get_balance("company"), 23000)
	assert_eq(game.ledger.get_balance("private"), 15000 - 5000 + 2000)
	assert_eq(game.company.withdraw(999999), "Nicht genug Geld auf dem Firmenkonto.")
	assert_eq(game.company.deposit(0), "Betrag muss größer als 0 sein.")
	var references := PackedStringArray()
	for entry in game.ledger.get_entries_by_category("transfer"):
		references.append(entry.reference)
	assert_eq(references, PackedStringArray(["company:deposit:1", "company:deposit:1", "company:deposit:2",
			"company:deposit:2", "company:withdraw:1", "company:withdraw:1"]))


func test_deposit_without_company_is_rejected() -> void:
	var game := Helpers.new_game()
	assert_eq(game.company.deposit(1000), "Noch kein Unternehmen gegründet.")
	assert_eq(game.ledger.get_entries().size(), 0)


func test_apply_limits_values_and_logs_reason() -> void:
	var game := _founded()
	var change := game.company.apply({"utilization": 70, "reputation": -5}, "test", "Großauftrag", "", "test:1")
	assert_eq(game.company.utilization, 100)
	assert_eq(game.company.reputation, 45)
	assert_eq(change.applied, {"utilization": 50, "reputation": -5})
	assert_true(change.was_limited(), "Grenze nicht erkannt")
	assert_true(game.company.apply({"utilization": -1}, "test", "nochmal", "", "test:1") == null, "Schlüssel ignoriert")


func test_apply_without_company_is_ignored() -> void:
	var game := Helpers.new_game()
	assert_true(game.company.apply({"utilization": 5}, "test", "x") == null, "ohne Unternehmen geändert")


func test_company_survives_save_and_load_and_counters_continue() -> void:
	var game := _founded()
	game.company.deposit(1000)
	SaveSystemScript.delete_save(PATH)
	assert_eq(SaveSystemScript.save(game, PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded != null:
		assert_eq(loaded.company.is_founded(), true)
		assert_eq(loaded.company.utilization, 50)
		assert_eq(loaded.ledger.get_balance("company"), 21000)
		assert_eq(loaded.company.deposit(1000), "")  # Schlüssel company:deposit:3, kein Duplikat
		assert_eq(loaded.ledger.get_balance("company"), 22000)
		assert_eq(loaded.company.get_history().size(), 1)
	SaveSystemScript.delete_save(PATH)


func test_version_6_save_gets_unfounded_company() -> void:
	var saved := Helpers.new_game().to_dict()
	saved.erase("company")
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 6, "game": saved}))
	file.close()
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Migration fehlgeschlagen")
	if loaded != null:
		assert_eq(loaded.company.is_founded(), false)
	SaveSystemScript.delete_save(PATH)


func test_restore_rejects_unknown_type() -> void:
	var game := _founded()
	var data := game.company.to_dict()
	data["type"] = "casino"
	var other := Helpers.new_game()
	assert_true("unbekannte Art" in other.company.restore(data), "unbekannte Art akzeptiert")
	assert_eq(other.company.is_founded(), false)
