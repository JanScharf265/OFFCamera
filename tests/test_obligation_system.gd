extends "res://tests/base_test.gd"

## Fristen (Phase 5): Daten, Fälligkeit montags ab Tag 8, automatische Zahlung, Stadtabgabe,
## genau einmal – auch nach dem Laden.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const ObligationCatalogScript := preload("res://scripts/systems/obligation_catalog.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const PATH := "user://test_obligation_save.json"


## Spiel ohne Termine und ohne Ereignisse, damit nur Fristen Geld bewegen.
func _game() -> GameStateScript:
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([])
	return GameStateScript.new(data, Helpers.TEST_SEED)


func _to_morning(game: GameStateScript, day: int) -> void:
	game.time.advance(TimeSystemScript.at(day, 8) - game.time.get_minutes())


func _valid(id: String = "fee") -> Dictionary:
	return {"id": id, "display_name": "Gebühr", "account": "private", "category": "fee",
			"schedule": {"weekday": "Mo", "first_day": 8}, "amount": {"fixed_cents": 100},
			"grace_days": 2, "reminder_fee_cents": 10}


func test_real_obligations_load() -> void:
	var catalog := ObligationCatalogScript.new()
	assert_true(catalog.load_file(), "Fehler: %s" % "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["rent_home", "rent_studio", "city_levy"]))
	assert_eq(catalog.get_definition("rent_home").fixed_cents, 8000)
	assert_eq(catalog.get_definition("rent_studio").fixed_cents, 4000)
	assert_eq(catalog.get_definition("city_levy").profit_percent, 15)
	assert_eq(catalog.get_definition("city_levy").account, "company")


func test_catalog_rejects_invalid_obligations() -> void:
	var catalog := ObligationCatalogScript.new()
	var both := _valid()
	both["amount"] = {"fixed_cents": 100, "profit_percent": 5}
	assert_eq(catalog.load_data([both]), false)
	var weekday := _valid()
	weekday["schedule"]["weekday"] = "Montag"
	assert_eq(catalog.load_data([weekday]), false)
	var account := _valid()
	account["account"] = "offshore"
	assert_eq(catalog.load_data([account]), false)
	var first_day := _valid()
	first_day["schedule"]["first_day"] = 1
	assert_eq(catalog.load_data([first_day]), false)
	assert_eq(catalog.load_data([_valid()]), true)


func test_nothing_is_due_in_the_first_week() -> void:
	var game := _game()
	_to_morning(game, 7)  # Sonntag
	assert_true(game.obligations.get_instances().is_empty(), "Frist vor Tag 8")
	assert_eq(game.ledger.get_balance(), 50000)


func test_rents_are_paid_automatically_on_monday() -> void:
	var game := _game()
	_to_morning(game, 8)  # Montag, Woche 2
	var rents := game.ledger.get_entries_by_category("rent")
	assert_eq(rents.size(), 2)
	assert_eq(game.ledger.get_balance(), 50000 - 8000 - 4000)
	if rents.size() == 2:
		assert_eq(rents[0].description, "Miete Wohnung (Woche 2)")
		assert_eq(rents[0].account, "private")
		assert_eq(rents[0].source, "obligation")
		assert_eq(rents[0].reference, "rent_home@8")
		assert_eq(rents[0].effective_minutes, TimeSystemScript.at(8, 0))
	for instance in game.obligations.get_instances():
		assert_eq(instance["status"], "paid", instance["id"])
	assert_true("Miete Wohnung (Woche 2) automatisch bezahlt: -80,00 €." in game.obligations.take_notices(),
			"Hinweis fehlt")


func test_rents_repeat_weekly_and_only_once_per_week() -> void:
	var game := _game()
	_to_morning(game, 22)  # Wochen 2, 3, 4
	assert_eq(game.ledger.get_entries_by_category("rent").size(), 6)
	var ids := PackedStringArray()
	for instance in game.obligations.get_instances():
		ids.append(instance["id"])
	assert_eq(ids, PackedStringArray(["rent_home@8", "rent_studio@8", "rent_home@15", "rent_studio@15",
			"rent_home@22", "rent_studio@22"]))


func test_unaffordable_rent_stays_open_and_nothing_is_booked() -> void:
	var game := _game()
	game.ledger.post(-45000, "test", "Ausgabe für Test", "test")  # 500 € -> 50 €
	_to_morning(game, 8)
	assert_eq(game.ledger.get_entries_by_category("rent").size(), 1)  # nur Studio (40 €) war gedeckt
	assert_eq(game.ledger.get_balance(), 1000)
	var open := game.obligations.get_open()
	assert_eq(open.size(), 1)
	if open.size() == 1:
		assert_eq(open[0]["id"], "rent_home@8")
		assert_eq(game.obligations.open_amount("rent_home@8"), 8000)
	assert_true(game.ledger.get_balance() >= 0, "Konto negativ")


func test_city_levy_needs_company_and_uses_last_weeks_profit() -> void:
	var game := _game()
	_to_morning(game, 8)
	assert_true(game.obligations.get_instance("city_levy@8").is_empty(), "Abgabe ohne Unternehmen")

	game.locations.travel("office")
	game.company.found("merch_label")  # Tag 8
	game.ledger.post(100000, "sales", "Großauftrag", "test", "", "", false, "company")  # Gewinn in Woche 2
	_to_morning(game, 15)
	var week2 := game.ledger.summarize("company", TimeSystemScript.week_start(2), TimeSystemScript.week_start(3))
	var expected: int = week2["net_cents"] * 15 / 100
	assert_true(expected > 0, "Testaufbau: Woche 2 sollte Gewinn haben")
	assert_eq(game.obligations.get_instance("city_levy@15")["amount_cents"], expected)
	var levy := game.ledger.get_entries_by_category("levy")
	assert_eq(levy.size(), 1)
	if levy.size() == 1:
		assert_eq(levy[0].account, "company")
		assert_eq(levy[0].amount_cents, -expected)
		assert_eq(levy[0].description, "Stadtabgabe (für Woche 2)")


func test_city_levy_is_waived_without_profit() -> void:
	var game := _game()
	game.locations.travel("office")
	game.company.found("merch_label")  # ohne Pflege macht das Label Verlust
	_to_morning(game, 8)
	var instance := game.obligations.get_instance("city_levy@8")
	assert_eq(instance["status"], "waived")
	assert_eq(instance["amount_cents"], 0)
	assert_eq(game.ledger.get_entries_by_category("levy").size(), 0)


func test_obligations_run_after_settlement_on_the_same_day_change() -> void:
	# Der Abschluss von Tag 7 muss in die Abgabe für Woche 1 eingehen (DayCycle-Reihenfolge).
	var game := _game()
	game.locations.travel("office")
	game.company.found("merch_label")
	game.time.advance(TimeSystemScript.at(7, 9) - game.time.get_minutes())
	game.ledger.post(50000, "sales", "Großauftrag Sonntag", "test", "", "", false, "company")
	_to_morning(game, 8)
	var week1 := game.ledger.summarize("company", TimeSystemScript.week_start(1), TimeSystemScript.week_start(2))
	var settlement_day7 := 0
	for entry in game.ledger.get_entries_by_category("sales") + game.ledger.get_entries_by_category("fixed_costs"):
		if entry.reference == "day:7":
			settlement_day7 += entry.amount_cents
	assert_true(settlement_day7 != 0, "Tag 7 nicht abgerechnet")
	assert_eq(game.obligations.get_instance("city_levy@8")["amount_cents"], week1["net_cents"] * 15 / 100)


func test_load_does_not_create_or_pay_again() -> void:
	var game := _game()
	_to_morning(game, 8)
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(game, PATH)
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([])
	var loaded: GameStateScript = SaveSystemScript.load_game(data, PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded == null:
		return
	assert_eq(loaded.obligations.get_instances().size(), 2)
	_to_morning(loaded, 9)
	assert_eq(loaded.ledger.get_entries_by_category("rent").size(), 2)
	assert_eq(loaded.ledger.get_balance(), game.ledger.get_balance())
	SaveSystemScript.delete_save(PATH)


func test_version_10_save_starts_obligations_from_now() -> void:
	var game := _game()
	_to_morning(game, 10)  # Fristen von Tag 8 bezahlt
	var saved := game.to_dict()
	saved.erase("obligations")
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 10, "game": saved}))
	file.close()
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([])
	var loaded: GameStateScript = SaveSystemScript.load_game(data, PATH)["game"]
	assert_true(loaded != null, "Migration 10 -> 11 fehlgeschlagen")
	if loaded == null:
		return
	assert_true(loaded.obligations.get_instances().is_empty(), "Verlauf sollte leer starten")
	_to_morning(loaded, 15)
	assert_eq(loaded.ledger.get_entries_by_category("rent").size(), 4)  # 2 alte + 2 neue, Tag 8 nicht doppelt
	SaveSystemScript.delete_save(PATH)


# --- Überfällig, Mahngebühr, Bezahlen von Hand (Ticket 5.3) --------------------------------

## Privatkonto auf 50 € – die Wohnungsmiete (80 €) an Tag 8 bleibt offen, Studio (40 €) wird bezahlt.
func _game_with_open_rent() -> GameStateScript:
	var game := _game()
	game.ledger.post(-45000, "test", "Ausgabe für Test", "test")
	_to_morning(game, 8)
	assert_eq(game.obligations.get_open().size(), 1, "Testaufbau: Wohnungsmiete offen")
	return game


func test_no_reminder_within_grace_period() -> void:
	var game := _game_with_open_rent()
	_to_morning(game, 10)  # Kulanz: Tag 9 und 10
	var instance := game.obligations.get_instance("rent_home@8")
	assert_eq(instance["reminded"], false)
	assert_eq(instance["fee_cents"], 0)
	assert_eq(game.stats.mood, 60)


## Regressionstest (Entscheidung Game Director): Die Mahngebühr erhöht nur den offenen Betrag.
## Gebucht wird erst beim Bezahlen – kein Konto wird dadurch negativ.
func test_reminder_fee_raises_open_amount_without_booking() -> void:
	var game := _game_with_open_rent()
	var balance_before := game.ledger.get_balance()
	var entries_before := game.ledger.get_entries().size()
	_to_morning(game, 11)  # Kulanz vorbei -> Mahnung
	var instance := game.obligations.get_instance("rent_home@8")
	assert_eq(instance["reminded"], true)
	assert_eq(instance["fee_cents"], 1000)
	assert_eq(game.obligations.open_amount("rent_home@8"), 9000)
	assert_eq(game.ledger.get_balance(), balance_before, "Mahngebühr wurde gebucht")
	assert_eq(game.ledger.get_entries().size(), entries_before, "Buchung ohne Bezahlen")
	assert_eq(game.ledger.get_entries_by_category("reminder_fee").size(), 0)
	for account in ["private", "company"]:
		assert_true(game.ledger.get_balance(account) >= 0, "%s negativ" % account)
	assert_eq(game.stats.mood, 55)


func test_reminder_happens_only_once() -> void:
	var game := _game_with_open_rent()
	_to_morning(game, 14)
	assert_eq(game.obligations.get_instance("rent_home@8")["fee_cents"], 1000)
	assert_eq(game.stats.mood, 55)


func test_pay_needs_the_whole_open_amount() -> void:
	var game := _game_with_open_rent()
	_to_morning(game, 11)  # offen 90 €, Konto 10 €
	assert_eq(game.obligations.pay("rent_home@8"), "Nicht genug Geld auf dem Privatkonto (offen: 90,00 €).")
	assert_eq(game.ledger.get_entries_by_category("rent").size(), 1)  # nur Studio
	game.ledger.post(8500, "test", "Einnahme für Test", "test")  # 95 €
	assert_eq(game.obligations.check_pay("rent_home@8"), "")
	assert_eq(game.obligations.pay("rent_home@8"), "")
	assert_eq(game.ledger.get_balance(), 500)
	assert_eq(game.obligations.get_instance("rent_home@8")["status"], "paid")
	assert_eq(game.obligations.open_amount("rent_home@8"), 0)
	assert_eq(game.obligations.pay("rent_home@8"), "Diese Frist ist nicht offen.")


func test_payment_books_rent_dated_to_due_day_and_fee_dated_now() -> void:
	var game := _game_with_open_rent()
	_to_morning(game, 11)
	game.ledger.post(10000, "test", "Einnahme für Test", "test")
	game.obligations.pay("rent_home@8")
	var rents := game.ledger.get_entries_by_category("rent")
	var home_rent = rents[rents.size() - 1]
	assert_eq(home_rent.reference, "rent_home@8")
	assert_eq(home_rent.amount_cents, -8000)
	assert_eq(home_rent.effective_minutes, TimeSystemScript.at(8, 0))
	var fees := game.ledger.get_entries_by_category("reminder_fee")
	assert_eq(fees.size(), 1)
	if fees.size() == 1:
		assert_eq(fees[0].amount_cents, -1000)
		assert_eq(fees[0].description, "Mahngebühr: Miete Wohnung (Woche 2)")
		assert_eq(fees[0].effective_minutes, game.time.get_minutes())


func test_open_obligation_is_not_paid_automatically_later() -> void:
	var game := _game_with_open_rent()
	game.ledger.post(50000, "test", "Einnahme für Test", "test")
	_to_morning(game, 12)
	assert_eq(game.obligations.get_instance("rent_home@8")["status"], "open")


func test_company_obligation_reminder_costs_company_reputation() -> void:
	var game := _game()
	game.locations.travel("office")
	game.company.found("merch_label")
	game.ledger.post(100000, "sales", "Großauftrag", "test", "", "", false, "company")
	game.company.withdraw(game.ledger.get_balance("company"))  # Firmenkonto leer, Gewinn bleibt in Woche 1
	_to_morning(game, 8)
	assert_eq(game.obligations.get_instance("city_levy@8")["status"], "open")
	_to_morning(game, 11)
	# Leeres Firmenkonto kostet auch über unbezahlte Fixkosten Ruf – daher die Mahnung gezielt prüfen.
	var reminders := []
	for change in game.company.get_history():
		if change.reason == "Mahnung: Stadtabgabe (für Woche 1)":
			reminders.append(change)
	assert_eq(reminders.size(), 1)
	if reminders.size() == 1:
		assert_eq(reminders[0].applied, {"reputation": -5})
		assert_eq(reminders[0].reference, "city_levy@8")
	assert_true(game.ledger.get_balance("company") >= 0, "Firmenkonto negativ")


func test_reminder_state_survives_save_and_load() -> void:
	var game := _game_with_open_rent()
	_to_morning(game, 11)
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(game, PATH)
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([])
	var loaded: GameStateScript = SaveSystemScript.load_game(data, PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded == null:
		return
	assert_eq(loaded.obligations.open_amount("rent_home@8"), 9000)
	_to_morning(loaded, 13)
	assert_eq(loaded.obligations.get_instance("rent_home@8")["fee_cents"], 1000)  # nicht nochmal gemahnt
	assert_eq(loaded.stats.mood, game.stats.mood)
	SaveSystemScript.delete_save(PATH)
