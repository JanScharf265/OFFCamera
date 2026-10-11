class_name LedgerSystem
extends RefCounted

## Einzige Autorität für Geld. Jede Änderung des Kontostands ist eine Buchung.
##
## Kontostand = Startwert + Summe aller Buchungen (ganze Cent).
## Regeln:
## - Betrag 0 sowie leere Kategorie/Beschreibung/Quelle sind ungültig.
## - Ausgaben, die den Kontostand unter 0 bringen würden, werden abgelehnt,
##   außer der Aufrufer erlaubt es ausdrücklich (allow_negative).
## - Eine Buchung mit idempotency_key wird höchstens einmal angenommen –
##   Schutz gegen Doppelbuchungen bei erneut ausgeführten Ereignissen.
## Abgelehnte Buchungen ändern nichts, senden keine Signale und setzen
## last_rejection auf den Grund.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerEntryScript := preload("res://scripts/models/ledger_entry.gd")

signal entry_posted(entry: LedgerEntryScript)
signal balance_changed(balance_cents: int)

enum Rejection { NONE, INVALID, INSUFFICIENT_FUNDS, DUPLICATE }

var last_rejection: Rejection = Rejection.NONE

var _time: TimeSystemScript
var _opening_balance_cents: int
var _balance_cents: int
var _entries: Array[LedgerEntryScript] = []
var _next_number := 1
var _used_keys := {}


func _init(time: TimeSystemScript, opening_balance_cents: int = 0) -> void:
	_time = time
	_opening_balance_cents = opening_balance_cents
	_balance_cents = opening_balance_cents


## Bucht einen Betrag. Gibt die neue Buchung zurück oder null bei Ablehnung.
func post(amount_cents: int, category: String, description: String, source: String,
		reference: String = "", idempotency_key: String = "",
		allow_negative: bool = false) -> LedgerEntryScript:
	if amount_cents == 0 or category.is_empty() or description.is_empty() or source.is_empty():
		push_error("LedgerSystem: ungültige Buchung (Betrag %d, Kategorie '%s', Beschreibung '%s', Quelle '%s')."
				% [amount_cents, category, description, source])
		last_rejection = Rejection.INVALID
		return null
	if not idempotency_key.is_empty() and _used_keys.has(idempotency_key):
		last_rejection = Rejection.DUPLICATE
		return null
	if amount_cents < 0 and not allow_negative and _balance_cents + amount_cents < 0:
		last_rejection = Rejection.INSUFFICIENT_FUNDS
		return null

	var entry := LedgerEntryScript.new("tx_%06d" % _next_number, _time.get_minutes(), amount_cents,
			category, description, source, reference)
	_next_number += 1
	_entries.append(entry)
	if not idempotency_key.is_empty():
		_used_keys[idempotency_key] = entry.id
	_balance_cents += amount_cents
	last_rejection = Rejection.NONE

	entry_posted.emit(entry)
	balance_changed.emit(_balance_cents)
	return entry


func can_afford(cost_cents: int) -> bool:
	return cost_cents <= _balance_cents


func get_balance() -> int:
	return _balance_cents


func get_opening_balance() -> int:
	return _opening_balance_cents


## Alle Buchungen in Buchungsreihenfolge (Kopie der Liste).
func get_entries() -> Array[LedgerEntryScript]:
	return _entries.duplicate()


func get_entries_by_category(category: String) -> Array[LedgerEntryScript]:
	var result: Array[LedgerEntryScript] = []
	for entry in _entries:
		if entry.category == category:
			result.append(entry)
	return result


## Kontostand frisch aus Startwert + Buchungen. Muss immer get_balance() entsprechen.
func recalculate_balance() -> int:
	var total := _opening_balance_cents
	for entry in _entries:
		total += entry.amount_cents
	return total


## z. B. 123456 -> "1.234,56 €", -5 -> "-0,05 €"
@warning_ignore("integer_division")
static func format_cents(cents: int) -> String:
	var prefix := "-" if cents < 0 else ""
	var abs_cents := absi(cents)
	var euros := str(abs_cents / 100)
	var grouped := ""
	for i in euros.length():
		if i > 0 and (euros.length() - i) % 3 == 0:
			grouped += "."
		grouped += euros[i]
	return "%s%s,%02d €" % [prefix, grouped, abs_cents % 100]
