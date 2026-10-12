extends "res://tests/base_test.gd"

## Ticket 6.3: Konsistenz über System-Grenzen (hart: ablehnen, Backup versuchen) und
## einheitliche, tolerante Regel für Daten, die es nicht mehr gibt (Hinweis beim Laden).

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ConsistencyCheckScript := preload("res://scripts/core/consistency_check.gd")

const PATH := "user://test_consistency_save.json"


## Gespieltes Spiel bis Tag 9: Unternehmen, Einlage, Tagesabschlüsse, Fristen, Ereignis.
func _played() -> GameStateScript:
	var game := Helpers.new_game()
	game.locations.travel("office")
	game.company.found("merch_label")
	game.company.deposit(5000)
	game.time.advance(TimeSystemScript.at(9, 8) - game.time.get_minutes())
	while game.events.has_pending():
		var instance := game.events.get_next_pending_id()
		game.events.resolve(instance, game.events.get_definition_for(instance).options[-1].id)
	return game


func _write(data: Dictionary) -> void:
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveSystemScript.SAVE_VERSION, "game": data}))
	file.close()


func _load() -> Dictionary:
	return SaveSystemScript.load_game(Helpers.game_data(), PATH)


func _expect_rejected(data: Dictionary, needle: String) -> void:
	_write(data)
	var result := _load()
	assert_true(result["game"] == null, "unstimmiger Stand geladen (%s)" % needle)
	assert_true("unstimmig" in result["error"] and needle in result["error"], result["error"])
	assert_eq(SaveSystemScript.corrupt_files(PATH).size(), 1)
	SaveSystemScript.delete_save(PATH)


func test_played_game_is_consistent() -> void:
	assert_eq(ConsistencyCheckScript.check(_played()), PackedStringArray())


func test_entry_after_game_time_is_rejected() -> void:
	var data := _played().to_dict()
	data["ledger"]["entries"][0]["time_minutes"] = 999999
	_expect_rejected(data, "nach der Spielzeit")


func test_key_without_entry_is_rejected() -> void:
	var data := _played().to_dict()
	data["ledger"]["used_keys"]["event:geist"] = "tx_999999"
	_expect_rejected(data, "fehlende Buchung")


func test_deposit_counter_must_match_transfers() -> void:
	var data := _played().to_dict()
	data["company"]["deposits"] = 1  # gebucht sind 2 Einlagen
	_expect_rejected(data, "ohne passenden Zähler")


func test_paid_obligation_must_be_booked() -> void:
	var data := _played().to_dict()
	var instances: Array = data["obligations"]["instances"]
	var removed := ""
	for instance in instances:
		if instance["status"] == "paid" and int(instance["amount_cents"]) > 0:
			removed = "obligation:%s" % instance["id"]
			break
	assert_true(not removed.is_empty(), "Testaufbau: bezahlte Frist fehlt")
	var keys: Dictionary = data["ledger"]["used_keys"]
	keys.erase(removed)
	_expect_rejected(data, "nicht gebucht")


func test_settlement_for_today_is_rejected() -> void:
	var data := _played().to_dict()
	data["company"]["last_settled_day"] = 9
	_expect_rejected(data, "noch nicht vorbei")


func test_inconsistent_main_falls_back_to_backup() -> void:
	SaveSystemScript.delete_save(PATH)
	var game := _played()
	SaveSystemScript.save(game, PATH)
	SaveSystemScript.save(game, PATH)  # gutes Backup
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	data["game"]["company"]["last_settled_day"] = 9  # nur der Konsistenz-Prüfer erkennt das
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var result := _load()
	assert_true(result["game"] != null, "Backup nicht geladen")
	assert_eq(result["from_backup"], true)
	assert_true("unstimmig" in result["error"], result["error"])
	SaveSystemScript.delete_save(PATH)


# --- Entfernte Daten: tolerant, mit Hinweis ---------------------------------------------

func _load_with(data_changes: Callable, saved: Dictionary) -> Dictionary:
	_write(saved)
	var data := Helpers.game_data()
	data_changes.call(data)
	var result := SaveSystemScript.load_game(data, PATH)
	SaveSystemScript.delete_save(PATH)
	return result


func test_removed_data_loads_with_notices() -> void:
	var game := _played()
	game.equipment.restore({"levels": {"camera": 1}})
	var saved := game.to_dict()
	saved["location"]["current"] = "label_store"
	var result := _load_with(func(data) -> void:
		var catalog = data.locations
		var kept := []
		for id in catalog.get_ids():
			if id != "label_store":
				var definition = catalog.get_definition(id)
				kept.append({"id": id, "display_name": definition.display_name,
						"map_position": [definition.map_position.x, definition.map_position.y]})
		catalog.load_data(kept)
		data.equipment.load_data([])
		data.company_types.load_data([])
		data.obligations.load_data([]), saved)
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "Stand mit entfernten Daten lädt nicht: %s" % result["error"])
	if loaded == null:
		return
	var notices := "; ".join(result["notices"])
	assert_true("Ort „label_store“" in notices, notices)
	assert_true("Ausrüstung „camera“" in notices, notices)
	assert_true("Unternehmensart „merch_label“" in notices, notices)
	assert_eq(loaded.locations.get_current(), "home")
	assert_eq(loaded.company.is_founded(), true)
	assert_eq(loaded.ledger.get_balance("company"), game.ledger.get_balance("company"))


func test_open_obligation_without_definition_stays_payable() -> void:
	var game := Helpers.new_game()
	game.ledger.post(-45000, "test", "Ausgabe für Test", "test")
	game.appointments.restore({"since_minutes": 99999, "attended": [], "missed": []})
	game.time.advance(TimeSystemScript.at(8, 8) - game.time.get_minutes())
	assert_eq(game.obligations.count_open(), 1, "Testaufbau: offene Miete")
	var result := _load_with(func(data) -> void: data.obligations.load_data([]), game.to_dict())
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "lädt nicht: %s" % result["error"])
	if loaded == null:
		return
	assert_true("Frist „rent_home“" in "; ".join(result["notices"]), "; ".join(result["notices"]))
	loaded.ledger.post(10000, "test", "Einnahme für Test", "test")
	assert_eq(loaded.obligations.pay("rent_home@8"), "")
	var rent = loaded.ledger.get_entries_by_category("rent")
	assert_eq(rent[rent.size() - 1].description, "Miete Wohnung (Woche 2)")
	assert_eq(rent[rent.size() - 1].account, "private")


func test_removed_company_type_stops_settlements_without_backlog() -> void:
	var game := _played()
	var result := _load_with(func(data) -> void: data.company_types.load_data([]), game.to_dict())
	var loaded: GameStateScript = result["game"]
	assert_true(loaded != null, "lädt nicht: %s" % result["error"])
	if loaded == null:
		return
	var sales := loaded.ledger.get_entries_by_category("sales").size()
	loaded.time.advance(TimeSystemScript.at(12, 8) - loaded.time.get_minutes())
	assert_eq(loaded.ledger.get_entries_by_category("sales").size(), sales)
	assert_eq(ConsistencyCheckScript.check(loaded), PackedStringArray())


func test_version_11_obligations_get_account_and_label() -> void:
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v11.json"))
	file.close()
	var loaded: GameStateScript = _load()["game"]
	assert_true(loaded != null, "v11 lädt nicht")
	if loaded != null:
		for instance in loaded.obligations.get_instances():
			assert_true(instance["account"] in ["private", "company"], instance["id"])
			assert_true(not String(instance["label"]).is_empty(), instance["id"])
	SaveSystemScript.delete_save(PATH)
