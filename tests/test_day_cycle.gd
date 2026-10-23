extends "res://tests/base_test.gd"

## Ticket 5.1: Wertstellung, Wochen-Auswertung und fester Ablauf am Tageswechsel.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const PATH := "user://test_day_cycle_save.json"


func _founded(data = null) -> GameStateScript:
	var game := Helpers.new_game(data)
	game.locations.travel("office")
	assert_eq(game.company.found("merch_label"), "", "Gründung")
	return game


func _to_morning(game: GameStateScript, day: int) -> void:
	game.time.advance(TimeSystemScript.at(day, 8) - game.time.get_minutes())
	while game.events.has_pending():
		var instance := game.events.get_next_pending_id()
		game.events.resolve(instance, game.events.get_definition_for(instance).options[0].id)


func test_weeks_start_on_monday() -> void:
	assert_eq(TimeSystemScript.week_of(TimeSystemScript.at(1, 0)), 1)
	assert_eq(TimeSystemScript.week_of(TimeSystemScript.at(7, 23, 59)), 1)
	assert_eq(TimeSystemScript.week_of(TimeSystemScript.at(8, 0)), 2)
	assert_eq(TimeSystemScript.week_start(2), TimeSystemScript.at(8, 0))
	var day_of_week_3 := TimeSystemScript.day_of(TimeSystemScript.week_start(3))
	assert_eq(TimeSystemScript.WEEKDAY_NAMES[(day_of_week_3 - 1) % TimeSystemScript.DAYS_PER_WEEK], "Mo")


func test_effective_date_defaults_to_booking_time() -> void:
	var game := Helpers.new_game()
	var entry := game.ledger.post(500, "test", "Test", "test")
	assert_eq(entry.effective_minutes, entry.time_minutes)


func test_effective_date_in_the_future_is_rejected() -> void:
	var game := Helpers.new_game()
	expect_error_output()
	var entry := game.ledger.post(500, "test", "Test", "test", "", "", false, "private",
			game.time.get_minutes() + 1)
	assert_true(entry == null, "Wertstellung in der Zukunft akzeptiert")
	assert_eq(game.ledger.get_entries().size(), 0)


func test_settlement_is_dated_to_the_settled_day() -> void:
	var game := _founded()
	_to_morning(game, 2)
	for entry in game.ledger.get_entries_by_category("sales") + game.ledger.get_entries_by_category("fixed_costs"):
		assert_eq(entry.time_minutes, TimeSystemScript.at(2, 8), "Buchungszeit = Abrechnung")
		assert_eq(entry.effective_minutes, TimeSystemScript.at(1, 23, 59), "Wertstellung = abgerechneter Tag")


## Regressionstest zur Frage aus der Phase-5-Planung: Ein Abschluss für Tag 7, der erst am
## Morgen von Tag 8 gebucht wird, gehört zu Woche 1 – nicht zu Woche 2.
func test_settlement_of_last_day_counts_for_its_week() -> void:
	var game := _founded()
	game.time.advance(TimeSystemScript.at(7, 22) - game.time.get_minutes())
	while game.events.has_pending():
		var instance := game.events.get_next_pending_id()
		game.events.resolve(instance, game.events.get_definition_for(instance).options[0].id)
	_to_morning(game, 8)  # über Mitternacht: Abschluss Tag 7 wird jetzt gebucht
	var week1 := game.ledger.summarize(LedgerSystemScript.COMPANY, TimeSystemScript.week_start(1),
			TimeSystemScript.week_start(2))
	var week2 := game.ledger.summarize(LedgerSystemScript.COMPANY, TimeSystemScript.week_start(2),
			TimeSystemScript.week_start(3))
	var sales := game.ledger.get_entries_by_category("sales")
	assert_eq(sales.size(), 7)  # Tage 1–7
	var expected := 0
	for entry in game.ledger.get_entries_for_account(LedgerSystemScript.COMPANY):
		if entry.category != "transfer":
			expected += entry.amount_cents
	assert_eq(week1["net_cents"], expected)
	assert_eq(week2["income_cents"], 0)
	assert_eq(week2["expense_cents"], 0)


func test_summary_ignores_transfers() -> void:
	var game := _founded()  # Einlage 200 € = Umbuchung
	game.company.deposit(5000)
	var week := game.ledger.summarize(LedgerSystemScript.COMPANY, TimeSystemScript.week_start(1),
			TimeSystemScript.week_start(2))
	assert_eq(week["transfer_in_cents"], 25000)
	assert_eq(week["income_cents"], 0)
	assert_eq(week["net_cents"], 0)
	var private_week := game.ledger.summarize(LedgerSystemScript.PRIVATE, TimeSystemScript.week_start(1),
			TimeSystemScript.week_start(2))
	assert_eq(private_week["expense_cents"], -15000)  # Gründungsgebühr
	assert_eq(private_week["transfer_out_cents"], -25000)


func test_day_cycle_runs_settlement_before_events() -> void:
	var data := Helpers.game_data()
	data.appointments.load_data([])
	data.events.load_data([{"id": "always", "title": "T", "text": "X",
			"trigger": {"random": {"chance_percent": 100}}, "options": [{"id": "ok", "label": "Ok"}]}])
	var game := _founded(data)
	var order: Array[String] = []
	game.company.day_settled.connect(func(day: int) -> void: order.append("abschluss %d" % day))
	game.events.event_triggered.connect(func(id: String) -> void: order.append("ereignis %s" % id))
	game.day_cycle.day_processed.connect(func(day: int) -> void: order.append("fertig %d" % day))
	game.time.advance(TimeSystemScript.at(3, 8) - game.time.get_minutes())  # Tage 2 und 3
	assert_eq(order, ["abschluss 1", "ereignis always@2", "fertig 2", "abschluss 2", "ereignis always@3", "fertig 3"] as Array[String])


func test_version_9_save_gets_effective_dates() -> void:
	var game := _founded()
	_to_morning(game, 3)
	var saved := game.to_dict()
	for entry in saved["ledger"]["entries"]:
		entry.erase("effective_minutes")
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 9, "game": saved}))
	file.close()
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Migration 9 -> 10 fehlgeschlagen")
	if loaded == null:
		return
	for entry in loaded.ledger.get_entries():
		if entry.source == "company" and entry.reference.begins_with("day:"):
			var day := int(entry.reference.substr(4))
			assert_eq(entry.effective_minutes, TimeSystemScript.at(day, 23, 59), entry.id)
		else:
			assert_eq(entry.effective_minutes, entry.time_minutes, entry.id)
	assert_eq(loaded.ledger.get_balance("company"), game.ledger.get_balance("company"))
	SaveSystemScript.delete_save(PATH)


func test_effective_dates_survive_save_and_load() -> void:
	var game := _founded()
	_to_morning(game, 2)
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(game, PATH)
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
	assert_true(loaded != null, "Laden fehlgeschlagen")
	if loaded != null:
		var sales = loaded.ledger.get_entries_by_category("sales")[0]
		assert_eq(sales.effective_minutes, TimeSystemScript.at(1, 23, 59))
	SaveSystemScript.delete_save(PATH)


## U.24: Reihenfolge am Tageswechsel – Abrechnung vor Abkühlung, Abkühlung vor Polizei, Fristen und Ereignisse zuletzt.
func test_full_day_order() -> void:
	var game := Helpers.new_game()
	var steps: Array = game.day_cycle.get("_steps")
	var names := []
	for step in steps:
		names.append(String(step.get_method()) if step is Callable else step.get_script().resource_path.get_file().get_basename())
	assert_eq(names, ["company_system", "organisation_system", "supply_system", "site_system", "crew_system",
			"territory_system", "rival_system", "cool_down", "police_system", "justice_system", "relationship_system",
			"obligation_system", "event_system"])


## U.24: Ein Dealer, der am Vortag Hitze gebracht hat, wird am selben Morgen erst abgerechnet, dann kühlt es ab.
func test_cooling_after_settlement() -> void:
	var game := Helpers.new_game()
	game.organisation.found("Los Lobos")
	game.organisation.change({"heat": 2})
	game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
	assert_eq(game.organisation.get_value("heat"), 0, "ohne Abrechnung: 2 − 3 → 0")
