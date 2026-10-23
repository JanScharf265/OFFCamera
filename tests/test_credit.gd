extends "res://tests/base_test.gd"

## Ticket U.7: Kredit beim Lieferanten – erst nach einer angekommenen Lieferung; keine Buchung bei der Bestellung;
## Schulden (Preis + 25 %) werden am Fälligkeitstag eine einmalige Frist (Schwarzgeld, ersatzweise privat), sonst
## offen mit Mahnaufschlag; überfällig → Druck-Ereignis (höchstens alle 2 Tage); platzt die Lieferung, entfällt die
## Schuld; nur eine laufende Schuld; Speichern/Laden; Migration v20 → v21.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

const SAVE_PATH := "user://test_credit_save.json"
const RUBIO := "el_rubio"


## Organisation, Treffen erledigt, eine angekommene Lieferung (Seed so gewählt, dass sie ankommt).
func _credit_game(p_seed: int = 12348) -> GameStateScript:
	var game := Helpers.new_game(null, p_seed)
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	assert_eq(game.supply.order(RUBIO, "weed", 1), "")
	_to_day(game, 2)
	_resolve_all(game)
	assert_eq(game.supply.count_delivered(RUBIO), 1, "Lieferung mit Seed %d nicht angekommen" % p_seed)
	return game


func _to_day(game: GameStateScript, day: int, hour: int = 8) -> void:
	game.time.advance(TimeSystemScript.at(day, hour) - game.time.get_minutes())


func _resolve_all(game: GameStateScript, keep_pressure: bool = false) -> void:
	for id in game.events.get_triggered_ids():
		if not game.events.is_resolved(id) and not (keep_pressure and id.begins_with("supplier_pressure")):
			game.events.resolve(id, game.events.get_definition_for(id).options[-1].id)


func _pressure_count(game: GameStateScript) -> int:
	return Array(game.events.get_triggered_ids()).filter(
			func(id: String) -> bool: return id.begins_with("supplier_pressure@")).size()


func test_credit_needs_one_delivery() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	game.time.advance(TimeSystemScript.at(1, 10) - game.time.get_minutes())
	game.locations.travel("cafe_harbor")
	assert_eq(game.supply.check_credit_order(RUBIO, "weed", 5), "Kredit erst nach der ersten Lieferung.")


func test_credit_order_books_nothing_and_debt_becomes_obligation() -> void:
	var game := _credit_game()
	var entries := game.ledger.get_entries().size()
	assert_eq(game.supply.check_credit_order(RUBIO, "weed", 11), "Auf Kredit 1–10 Einheiten.")
	assert_eq(game.supply.credit_cost(RUBIO, "weed", 10), 50000, "400 € + 25 %")
	assert_eq(game.supply.order_on_credit(RUBIO, "weed", 10), "")
	assert_eq(game.ledger.get_entries().size(), entries, "keine Buchung bei der Bestellung")
	assert_eq(game.supply.check_credit_order(RUBIO, "hash", 1), "Erst die Schulden bei El Rubio bezahlen.")
	var debts := game.supply.get_debts(RUBIO)
	assert_eq(debts.size(), 1)
	assert_eq([debts[0]["amount_cents"], debts[0]["due_day"], debts[0]["overdue"]], [50000, 5, false])
	_to_day(game, 3)
	_resolve_all(game)
	if game.supply.get_debts(RUBIO).is_empty():
		return  # Lieferung geplatzt → Schuld entfällt (eigener Test)
	# Fällig an Tag 5: 500 € – 50 € Schwarzgeld reichen nicht, das Privatkonto schon → automatisch bezahlt.
	game.ledger.post(5000, "test", "Test", "test", "", "", false, LedgerSystemScript.BLACK)
	game.ledger.post(20000, "test", "Test: Privat aufgefüllt", "test")
	var private := game.ledger.get_balance()
	_to_day(game, 5)
	_resolve_all(game)
	var instance: Dictionary = game.obligations.get_instance("debt_order_0002")
	assert_eq(instance["status"], "paid")
	assert_eq(instance["account"], "black")
	assert_eq(game.ledger.get_balance(), private - 50000, "ersatzweise vom Privatkonto")
	assert_eq(game.supply.get_debts(RUBIO).size(), 0)


func test_unpaid_debt_brings_reminder_and_pressure_every_two_days() -> void:
	var game := _credit_game()
	game.ledger.post(-game.ledger.get_balance(), "test", "Test: alles weg", "test")
	assert_eq(game.supply.order_on_credit(RUBIO, "coke", 10), "")
	_to_day(game, 3)
	_resolve_all(game)
	if game.supply.get_debts(RUBIO).is_empty():
		return
	_to_day(game, 5)
	_resolve_all(game)
	var instance: Dictionary = game.obligations.get_instance("debt_order_0002")
	assert_eq(instance["status"], "open", "kein Geld → offen")
	assert_eq(game.obligations.count_open() >= 1, true)
	assert_eq(_pressure_count(game), 0, "am Fälligkeitstag noch kein Besuch")
	_to_day(game, 7)  # Tag 6: Mahnung (+10 %), Tag 7: Druck
	assert_eq(game.obligations.open_amount("debt_order_0002"), 250000 + 25000)
	assert_eq(_pressure_count(game), 1)
	var respect := game.organisation.get_value("respect")
	var pending: String = Array(game.events.get_triggered_ids()).filter(
			func(id: String) -> bool: return id.begins_with("supplier_pressure@"))[0]
	assert_eq(game.events.resolve(pending, "promise"), "")
	assert_eq(game.organisation.get_value("respect"), respect - 3, "Folge für die Organisation")
	_resolve_all(game)
	_to_day(game, 8)
	assert_eq(_pressure_count(game), 1, "höchstens alle 2 Tage")
	_resolve_all(game)
	_to_day(game, 9)
	assert_eq(_pressure_count(game), 2)
	_resolve_all(game)
	# Bezahlen beendet den Druck.
	game.ledger.post(300000, "test", "Test", "test", "", "", false, LedgerSystemScript.BLACK)
	assert_eq(game.obligations.pay("debt_order_0002"), "")
	_to_day(game, 13)
	assert_eq(_pressure_count(game), 2, "nach dem Bezahlen kein Besuch mehr")


func test_failed_delivery_cancels_debt() -> void:
	# Suche einen Seed, bei dem die Kreditlieferung platzt (order_0002).
	for p_seed in range(12340, 12420):
		var roll: int = load("res://scripts/systems/event_system.gd").fnv1a("%d:order_0002" % p_seed) % 100
		var first: int = load("res://scripts/systems/event_system.gd").fnv1a("%d:order_0001" % p_seed) % 100
		if roll < 15 and first >= 15:
			var game := _credit_game(p_seed)
			assert_eq(game.supply.order_on_credit(RUBIO, "weed", 2), "")
			_to_day(game, 3)
			assert_eq(game.supply.get_debts(RUBIO).size(), 0, "Schuld nicht entfallen")
			assert_true(Array(game.supply.take_notices()).has(
					"Lieferung geplatzt: El Rubio meldet sich nicht – die Schulden entfallen."))
			return
	assert_true(false, "kein passender Seed gefunden")


func test_credit_survives_save_and_load() -> void:
	var game := _credit_game()
	game.supply.order_on_credit(RUBIO, "hash", 4)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.supply.get_debts(RUBIO), game.supply.get_debts(RUBIO))
		assert_eq(loaded.supply.to_dict(), game.supply.to_dict())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_migration_20_to_21() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v20.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	assert_true(result["game"] != null, "v20 lädt nicht: %s" % result["error"])
	# Ein v20-Stand mit einer Barbestellung bekommt die Kreditfelder.
	var game := _credit_game()
	var data := game.to_dict()
	for order in data["supply"]["orders"]:
		for key in ["credit", "debt_cents", "debt_due_day", "debt_status"]:
			order.erase(key)
	data["supply"].erase("last_pressure_day")
	data["supply"].erase("delivered_before_trim")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 20, "game": data}))
	file.close()
	var migrated: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(migrated != null)
	if migrated != null:
		assert_eq(migrated.supply.count_delivered(RUBIO), 1, "angekommene Lieferung zählt weiter")
		assert_eq(migrated.supply.get_debts().size(), 0)
	assert_true(not SaveSystemScript._run_migration(20, {"supply": "x"}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_credit_button_and_debt_lines() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = 12348
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.time.advance(TimeSystemScript.at(1, 10) - app.game.time.get_minutes())
	app.game.locations.travel("cafe_harbor")
	screen.call("open_supplier", RUBIO)
	var credit := app.find_child("SupplierCreditButton_weed", true, false) as Button
	assert_eq(credit.disabled, true)
	assert_eq((app.find_child("SupplierCreditNote_weed", true, false) as Label).text, "Kredit erst nach der ersten Lieferung.")
	var data: Dictionary = app.game.supply.to_dict()
	data["delivered_before_trim"] = {RUBIO: 1}
	app.game.supply.restore(data)
	screen.call("open_supplier", RUBIO)
	credit = app.find_child("SupplierCreditButton_weed", true, false) as Button
	assert_eq(credit.disabled, false)
	assert_eq(credit.text, "Auf Kredit · 250,00 € später")
	var entries: int = app.game.ledger.get_entries().size()
	credit.pressed.emit()
	assert_eq(app.game.ledger.get_entries().size(), entries)
	assert_true((app.find_child("FeedbackLabel", true, false) as Label).text.begins_with(
			"Auf Kredit bestellt: 5 × Gras (Schulden -250,00 €)"))
	assert_true(app.find_child("SupplierDebt_order_0001", true, false) != null, "Schuld im Lieferanten-Fenster")
	(app.find_child("WindowCloseButton", true, false) as Button).pressed.emit()
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("Debt_order_0001", true, false) as Label).text, "Schulden bei El Rubio: 250,00 € · fällig Tag 4")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Gefunden vom langen Störungstest: „obligation“ ist in einer beschädigten Datei kein Text → Fehler statt Absturz.
func test_damaged_obligation_field_is_rejected() -> void:
	var game := Helpers.new_game()
	var data := {"last_processed_day": 1, "instances": [{"id": "x", "obligation": {"a": 1}, "due_minutes": 0,
			"amount_cents": 100, "fee_cents": 0, "status": "open", "paid_minutes": -1, "reminded": false}]}
	assert_true(not game.obligations.restore(data).is_empty())


## Selbstprüfung U.7: Bei einem Sprung über mehrere Tage steht die Schuld mit ihrem echten Fälligkeitstag in den Fristen.
func test_debt_due_day_survives_long_jump() -> void:
	var game := _credit_game()
	game.ledger.post(-game.ledger.get_balance(), "test", "Test: alles weg", "test")
	assert_eq(game.supply.order_on_credit(RUBIO, "weed", 2), "")
	_to_day(game, 9)
	_resolve_all(game)
	var instance: Dictionary = game.obligations.get_instance("debt_order_0002")
	if instance.is_empty():
		return  # Lieferung geplatzt
	assert_eq(instance["due_minutes"], TimeSystemScript.at(5, 0), "bestellt an Tag 2, fällig nach 3 Tagen")
	assert_eq(game.obligations.check_pay("debt_order_0002"),
			"Nicht genug Schwarzgeld oder Geld auf dem Privatkonto (offen: 110,00 €).")
