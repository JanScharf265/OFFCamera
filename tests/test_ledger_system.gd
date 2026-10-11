extends "res://tests/base_test.gd"

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")


func _make_ledger(opening_cents: int = 10000) -> LedgerSystemScript:
	return LedgerSystemScript.new(TimeSystemScript.new(TimeSystemScript.at(1, 8)), opening_cents)


func test_opening_balance_without_entries() -> void:
	var ledger := _make_ledger(50000)
	assert_eq(ledger.get_balance(), 50000)
	assert_eq(ledger.get_entries().size(), 0)


func test_income_is_booked_with_all_fields() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 20))
	var ledger := LedgerSystemScript.new(time, 0)
	var entry := ledger.post(2500, "creator", "Kurzer Stream", "activity", "stream_short")
	assert_true(entry != null, "Buchung wurde abgelehnt")
	assert_eq(entry.id, "tx_000001")
	assert_eq(entry.time_minutes, TimeSystemScript.at(1, 20))
	assert_eq(entry.amount_cents, 2500)
	assert_eq(entry.category, "creator")
	assert_eq(entry.description, "Kurzer Stream")
	assert_eq(entry.source, "activity")
	assert_eq(entry.reference, "stream_short")
	assert_true(entry.is_income())
	assert_eq(ledger.get_balance(), 2500)


func test_expense_reduces_balance_and_is_in_journal() -> void:
	var ledger := _make_ledger(10000)
	var entry := ledger.post(-1250, "food", "Mittagessen", "activity")
	assert_true(entry != null, "Buchung wurde abgelehnt")
	assert_eq(entry.is_income(), false)
	assert_eq(ledger.get_balance(), 8750)
	assert_eq(ledger.get_entries().size(), 1)


func test_entry_time_follows_time_system() -> void:
	var time := TimeSystemScript.new(TimeSystemScript.at(1, 8))
	var ledger := LedgerSystemScript.new(time, 10000)
	ledger.post(-100, "food", "Kaffee", "activity")
	time.advance(90)
	ledger.post(-200, "food", "Snack", "activity")
	var entries := ledger.get_entries()
	assert_eq(entries[0].time_minutes, TimeSystemScript.at(1, 8))
	assert_eq(entries[1].time_minutes, TimeSystemScript.at(1, 9, 30))


func test_ids_are_unique_and_sequential() -> void:
	var ledger := _make_ledger()
	var a := ledger.post(100, "misc", "A", "test")
	var b := ledger.post(100, "misc", "B", "test")
	var c := ledger.post(-50, "misc", "C", "test")
	assert_eq([a.id, b.id, c.id], ["tx_000001", "tx_000002", "tx_000003"])


func test_invalid_entries_are_rejected_without_change() -> void:
	var ledger := _make_ledger(10000)
	var posted := []
	var on_posted := func(entry) -> void: posted.append(entry)
	ledger.entry_posted.connect(on_posted)
	expect_error_output()
	assert_true(ledger.post(0, "misc", "Nichts", "test") == null, "hätte abgelehnt werden müssen")
	assert_eq(ledger.last_rejection, LedgerSystemScript.Rejection.INVALID)
	expect_error_output()
	assert_true(ledger.post(500, "", "Ohne Kategorie", "test") == null, "hätte abgelehnt werden müssen")
	assert_eq(ledger.get_balance(), 10000)
	assert_eq(posted.size(), 0)
	ledger.entry_posted.disconnect(on_posted)


func test_insufficient_funds_is_rejected() -> void:
	var ledger := _make_ledger(1000)
	assert_eq(ledger.can_afford(1001), false)
	assert_true(ledger.post(-1001, "shopping", "Zu teuer", "activity") == null, "hätte abgelehnt werden müssen")
	assert_eq(ledger.last_rejection, LedgerSystemScript.Rejection.INSUFFICIENT_FUNDS)
	assert_eq(ledger.get_balance(), 1000)
	assert_eq(ledger.get_entries().size(), 0)


func test_spending_exact_balance_is_allowed() -> void:
	var ledger := _make_ledger(1000)
	assert_true(ledger.can_afford(1000))
	assert_true(ledger.post(-1000, "shopping", "Alles", "activity") != null)
	assert_eq(ledger.get_balance(), 0)


func test_allow_negative_permits_overdraft() -> void:
	var ledger := _make_ledger(1000)
	var entry := ledger.post(-5000, "fine", "Bußgeld", "event", "", "", true)
	assert_true(entry != null, "Buchung wurde abgelehnt")
	assert_eq(ledger.get_balance(), -4000)


func test_same_idempotency_key_is_booked_only_once() -> void:
	var ledger := _make_ledger(0)
	var first := ledger.post(3000, "creator", "Kooperation", "event", "evt_coop", "evt_coop_payout")
	var second := ledger.post(3000, "creator", "Kooperation", "event", "evt_coop", "evt_coop_payout")
	assert_true(first != null, "erste Buchung abgelehnt")
	assert_true(second == null, "hätte abgelehnt werden müssen")
	assert_eq(ledger.last_rejection, LedgerSystemScript.Rejection.DUPLICATE)
	assert_eq(ledger.get_balance(), 3000)
	assert_eq(ledger.get_entries().size(), 1)


func test_signals_fire_once_per_accepted_entry_only() -> void:
	var ledger := _make_ledger(1000)
	var posted_ids := []
	var balances := []
	var on_posted := func(entry) -> void: posted_ids.append(entry.id)
	var on_balance := func(balance: int) -> void: balances.append(balance)
	ledger.entry_posted.connect(on_posted)
	ledger.balance_changed.connect(on_balance)
	ledger.post(500, "misc", "Plus", "test")
	ledger.post(-9999, "misc", "Abgelehnt", "test")
	ledger.post(-300, "misc", "Minus", "test")
	assert_eq(posted_ids, ["tx_000001", "tx_000002"])
	assert_eq(balances, [1500, 1200])
	ledger.entry_posted.disconnect(on_posted)
	ledger.balance_changed.disconnect(on_balance)


func test_recalculated_balance_matches_running_balance() -> void:
	var ledger := _make_ledger(7777)
	ledger.post(1234, "creator", "A", "test")
	ledger.post(-999, "food", "B", "test")
	ledger.post(-4000, "fine", "C", "test", "", "", true)
	assert_eq(ledger.recalculate_balance(), ledger.get_balance())
	assert_eq(ledger.get_balance(), 7777 + 1234 - 999 - 4000)


func test_entries_can_be_filtered_by_category() -> void:
	var ledger := _make_ledger(10000)
	ledger.post(-100, "food", "Kaffee", "activity")
	ledger.post(2000, "creator", "Stream", "activity")
	ledger.post(-300, "food", "Essen", "activity")
	var food := ledger.get_entries_by_category("food")
	assert_eq(food.size(), 2)
	assert_eq(food[0].description, "Kaffee")
	assert_eq(food[1].description, "Essen")


func test_returned_entry_list_is_a_copy() -> void:
	var ledger := _make_ledger(10000)
	ledger.post(-100, "food", "Kaffee", "activity")
	var entries := ledger.get_entries()
	entries.clear()
	assert_eq(ledger.get_entries().size(), 1)


func test_format_cents() -> void:
	assert_eq(LedgerSystemScript.format_cents(0), "0,00 €")
	assert_eq(LedgerSystemScript.format_cents(5), "0,05 €")
	assert_eq(LedgerSystemScript.format_cents(-5), "-0,05 €")
	assert_eq(LedgerSystemScript.format_cents(123456), "1.234,56 €")
	assert_eq(LedgerSystemScript.format_cents(100000000), "1.000.000,00 €")
	assert_eq(LedgerSystemScript.format_cents(-99900), "-999,00 €")
