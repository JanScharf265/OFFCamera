extends "res://tests/base_test.gd"

## Unternehmen (Ticket 4.2): Daten, Gründung über Ledger und Zeit, Einlage/Entnahme, Protokoll, Speichern.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")

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
	saved.erase("obligations")
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


# --- Tagesabschluss (Ticket 4.3) ---------------------------------------------------

func _to_next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_preview_day_at_start_is_exact() -> void:
	var game := _founded()  # 120 Follower, Auslastung 50, Ruf 50
	var outcome := game.company.preview_day()
	assert_eq(outcome["reach_cents"], 180)        # 120 × 1500 / 1000
	assert_eq(outcome["revenue_cents"], 1590)     # (3000 + 180) × 50 / 100 × 100 / 100
	assert_eq(outcome["costs_cents"], 2000)
	assert_eq(outcome["reputation_percent"], 0)


func test_settlement_books_revenue_and_costs_on_company_account() -> void:
	var game := _founded()  # Firmenkonto 200 €
	_to_next_morning(game)  # rechnet Tag 1 ab
	assert_eq(game.ledger.get_balance("company"), 20000 + 1590 - 2000)
	var sales := game.ledger.get_entries_by_category("sales")
	assert_eq(sales.size(), 1)
	if sales.size() == 1:
		assert_eq(sales[0].account, "company")
		assert_eq(sales[0].reference, "day:1")
		assert_eq(sales[0].time_minutes, TimeSystemScript.at(2, 8))  # Zeitpunkt der Abrechnung
	assert_eq(game.ledger.get_entries_by_category("fixed_costs").size(), 1)
	assert_eq(game.ledger.get_balance("private"), 15000)  # Privatkonto unberührt


func test_settlement_explains_itself_once() -> void:
	var game := _founded()
	_to_next_morning(game)
	var expected := "Tag 1: Umsatz +15,90 € (30,00 € + 1,80 € Reichweite · Auslastung 50 % · Ruf ±0 %) · Fixkosten -20,00 € · Ergebnis -4,10 €"
	assert_eq(game.company.get_settlements()[0]["text"], expected)
	assert_eq(game.company.take_settlement_notices(), PackedStringArray([expected]))
	assert_eq(game.company.take_settlement_notices(), PackedStringArray())


func test_utilization_decays_each_day_with_reason() -> void:
	var game := _founded()
	_to_next_morning(game)
	_to_next_morning(game)
	assert_eq(game.company.utilization, 44)
	var last = game.company.get_history()[-1]
	assert_eq(last.reason, "Tag 2: ohne Pflege sinkt die Auslastung")
	assert_eq(last.applied, {"utilization": -3})


func test_each_day_is_settled_exactly_once_even_when_skipping_days() -> void:
	var game := _founded()
	game.time.advance(TimeSystemScript.at(5, 8) - game.time.get_minutes())  # Tage 1–4
	var days := []
	for settlement in game.company.get_settlements():
		days.append(settlement["day"])
	assert_eq(days, [1, 2, 3, 4])
	assert_eq(game.ledger.get_entries_by_category("sales").size(), 4)


func test_company_account_never_goes_negative_and_unpaid_costs_cost_reputation() -> void:
	var game := _founded()
	game.company.withdraw(20000)  # Firmenkonto leer
	_to_next_morning(game)
	assert_eq(game.ledger.get_balance("company"), 1590)  # Umsatz ja, Fixkosten nicht
	assert_eq(game.ledger.get_entries_by_category("fixed_costs").size(), 0)
	assert_eq(game.company.reputation, 45)
	var settlement: Dictionary = game.company.get_settlements()[0]
	assert_eq(settlement["paid"], false)
	assert_true("nicht bezahlt" in settlement["text"], settlement["text"])
	for account in ["private", "company"]:
		assert_true(game.ledger.get_balance(account) >= 0, account)


func test_no_settlement_before_founding_or_on_founding_day() -> void:
	var game := Helpers.new_game()
	_to_next_morning(game)
	assert_eq(game.ledger.get_entries_by_category("sales").size(), 0)
	game.locations.travel("office")
	game.company.found("merch_label")  # Tag 2
	assert_true(game.company.get_settlements().is_empty(), "Abschluss am Gründungstag")
	_to_next_morning(game)
	assert_eq(game.company.get_settlements()[0]["day"], 2)


func test_followers_and_reputation_raise_revenue() -> void:
	var game := _founded()
	game.channel.apply({"followers": 9880}, "test", "Wachstum")
	game.company.apply({"reputation": 20, "utilization": 30}, "test", "gute Arbeit")
	var outcome := game.company.preview_day()
	var followers := game.channel.followers
	@warning_ignore("integer_division")
	var expected: int = (3000 + followers * 1500 / 1000) * 80 / 100 * 110 / 100
	assert_eq(outcome["revenue_cents"], expected)


func test_load_does_not_settle_again() -> void:
	var game := _founded()
	_to_next_morning(game)
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(game, PATH)
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded == null:
		return
	assert_eq(loaded.company.get_settlements().size(), 1)
	assert_eq(loaded.company.take_settlement_notices(), PackedStringArray())
	_to_next_morning(loaded)
	_to_next_morning(game)
	assert_eq(loaded.ledger.get_balance("company"), game.ledger.get_balance("company"))
	assert_eq(loaded.ledger.get_entries_by_category("sales").size(), 2)
	SaveSystemScript.delete_save(PATH)


func test_version_7_founded_company_settles_from_current_day() -> void:
	var game := _founded()
	_to_next_morning(game)  # Tag 2, ein Abschluss
	var saved := game.to_dict()
	saved["company"].erase("last_settled_day")
	saved["company"].erase("settlements")
	saved["company"].erase("branch_open")
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 7, "game": saved}))
	file.close()
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Migration fehlgeschlagen")
	if loaded == null:
		return
	assert_true(loaded.company.get_settlements().is_empty(), "Verlauf sollte leer starten")
	_to_next_morning(loaded)
	assert_eq(loaded.company.get_settlements()[0]["day"], 2)
	assert_eq(loaded.ledger.get_entries_by_category("sales").size(), 2)  # Tag 1 (vor Migration) + Tag 2
	SaveSystemScript.delete_save(PATH)


# --- Zweiter Standort und Management (Ticket 4.4) ---------------------------------------

## Gegründet, Firmenkonto mit 500 € aufgefüllt, im Ladenlokal um 10:00.
func _founded_at_store() -> GameStateScript:
	var game := _founded()  # 09:20, Firmenkonto 200 €
	game.ledger.post(50000, "test", "Startkapital für Test", "test")
	game.company.deposit(30000)
	assert_eq(game.locations.travel("label_store"), "", "Fahrt zum Ladenlokal")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	return game


func test_branch_opens_with_company_money_and_time() -> void:
	var game := _founded_at_store()
	var company_before := game.ledger.get_balance("company")
	assert_eq(game.company.open_branch(), "")
	assert_eq(game.company.is_branch_open(), true)
	assert_eq(game.ledger.get_balance("company"), company_before - 30000)
	assert_eq(game.time.format_clock(), "12:00")
	assert_eq(game.company.open_branch(), "Die Filiale ist bereits eröffnet.")
	assert_eq(game.company.get_history()[-1].reason,
			"Filiale eröffnet: Merch-Laden (+40,00 € Grundumsatz, 25,00 € Fixkosten pro Tag)")


func test_branch_needs_company_location_hours_and_money() -> void:
	var game := Helpers.new_game()
	assert_eq(game.company.open_branch(), "Erst ein Unternehmen gründen (im Büro).")
	game = _founded()  # Firmenkonto 200 € < 300 €
	assert_eq(game.company.open_branch(), "Nur vor Ort möglich: Ladenlokal.")
	game.locations.travel("label_store")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	assert_eq(game.company.open_branch(), "Nicht genug Geld auf dem Firmenkonto (kostet 300,00 €).")
	game.time.advance(TimeSystemScript.at(1, 19) - game.time.get_minutes())
	assert_eq(game.company.check_open_branch(), "Ladenlokal schließt vorher (geöffnet 10:00–20:00).")
	assert_eq(game.company.is_branch_open(), false)


func test_branch_adds_revenue_and_costs_to_settlement() -> void:
	var game := _founded_at_store()
	game.company.open_branch()
	var outcome := game.company.preview_day()
	assert_eq(outcome["branch_cents"], 4000)
	assert_eq(outcome["revenue_cents"], (3000 + 4000 + 180) * 50 / 100)
	assert_eq(outcome["costs_cents"], 4500)
	_to_next_morning(game)
	var text: String = game.company.get_settlements()[0]["text"]
	assert_true(" + 40,00 € Filiale" in text, text)


func test_management_activity_needs_company_and_raises_utilization() -> void:
	var game := Helpers.new_game()
	game.locations.travel("office")
	assert_eq(game.activities.check("order_stock"), "Erst ein Unternehmen gründen (im Büro).")
	game.company.found("merch_label")
	assert_eq(game.activities.start("order_stock"), "")
	assert_eq(game.company.utilization, 56)
	var last = game.company.get_history()[-1]
	assert_eq(last.source, "activity")
	assert_eq(last.reason, "Ware nachbestellen")
	assert_eq(last.reference, "order_stock")


func test_run_store_needs_open_branch() -> void:
	var game := _founded_at_store()
	assert_eq(game.activities.check("run_store"), "Erst die Filiale eröffnen.")
	game.company.open_branch()  # -> 12:00
	assert_eq(game.activities.start("run_store"), "")
	assert_eq(game.company.utilization, 62)
	assert_eq(game.company.reputation, 52)
	assert_eq(game.time.format_clock(), "16:00")


func test_care_can_beat_decay() -> void:
	var game := _founded()
	for day in range(2, 5):
		_to_next_morning(game)  # Verfall -3 (wir bleiben im Büro)
		assert_eq(game.activities.start("order_stock"), "", "Tag %d" % day)  # Pflege +6
	assert_eq(game.company.utilization, 59)  # 50 + 3 × (6 − 3)


func test_activity_catalog_checks_company_fields() -> void:
	var catalog := ActivityCatalogScript.new()
	var base := {"id": "x", "display_name": "X", "location": "office", "duration_minutes": 30}
	var wrong_requirement := base.duplicate()
	wrong_requirement["requires"] = "yacht"
	assert_eq(catalog.load_data([wrong_requirement]), false)
	var effects_without_requirement := base.duplicate()
	effects_without_requirement["company"] = {"utilization": 3}
	assert_eq(catalog.load_data([effects_without_requirement]), false)
	var bad_key := base.duplicate()
	bad_key["requires"] = "company"
	bad_key["company"] = {"profit": 3}
	assert_eq(catalog.load_data([bad_key]), false)
	var valid := base.duplicate()
	valid["requires"] = "company"
	valid["company"] = {"utilization": 3}
	assert_eq(catalog.load_data([valid]), true)


func test_branch_state_survives_save_and_version_8_migration() -> void:
	var game := _founded_at_store()
	game.company.open_branch()
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(game, PATH)
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null and loaded.company.is_branch_open(), "Filiale nach Laden zu")
	var saved := game.to_dict()
	saved["company"].erase("branch_open")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 8, "game": saved}))
	file.close()
	var migrated: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(migrated != null, "Migration 8 -> 9 fehlgeschlagen")
	if migrated != null:
		assert_eq(migrated.company.is_branch_open(), false)
	SaveSystemScript.delete_save(PATH)
