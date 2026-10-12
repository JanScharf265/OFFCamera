class_name LedgerSystem
extends RefCounted

## Einzige Autorität für Geld. Jede Änderung eines Kontostands ist eine Buchung.
##
## Konten (Phase 4): "private" (Privatkonto) und "company" (Firmenkonto) – beide in
## diesem einen Ledger, jede Buchung trägt ihr Konto. Kontostand je Konto =
## Startwert des Kontos + Summe seiner Buchungen (ganze Cent).
## Regeln:
## - Betrag 0, unbekanntes Konto sowie leere Kategorie/Beschreibung/Quelle sind ungültig.
## - Ausgaben, die den Kontostand des Kontos unter 0 bringen würden, werden abgelehnt,
##   außer der Aufrufer erlaubt es ausdrücklich (allow_negative).
## - Eine Buchung mit idempotency_key wird höchstens einmal angenommen –
##   Schutz gegen Doppelbuchungen bei erneut ausgeführten Ereignissen.
## - Umbuchung (transfer) zwischen Konten = genau zwei Buchungen mit gemeinsamer
##   Referenz und den Schutzschlüsseln "<schlüssel>|out" / "<schlüssel>|in".
##   Erst wird alles geprüft, dann beide gebucht – nie nur eine Hälfte.
## - Wertstellung (Phase 5): jede Buchung hat zusätzlich effective_minutes (Standard = Buchungszeit).
##   Sie darf nicht in der Zukunft liegen. Fristen und Zeiträume (summarize) rechnen nur damit.
## Abgelehnte Buchungen ändern nichts, senden keine Signale und setzen
## last_rejection auf den Grund.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerEntryScript := preload("res://scripts/models/ledger_entry.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal entry_posted(entry: LedgerEntryScript)
signal balance_changed(balance_cents: int, account: String)

enum Rejection { NONE, INVALID, INSUFFICIENT_FUNDS, DUPLICATE }

const PRIVATE := "private"
const COMPANY := "company"
const ACCOUNTS: Array[String] = [PRIVATE, COMPANY]
const ACCOUNT_LABELS := {PRIVATE: "Privatkonto", COMPANY: "Firmenkonto"}
const TRANSFER_CATEGORY := "transfer"
## "|" kommt in keinem anderen Schutzschlüssel vor (IDs sind a–z, 0–9, _; sonst ":" und "@").
const TRANSFER_OUT_SUFFIX := "|out"
const TRANSFER_IN_SUFFIX := "|in"

var last_rejection: Rejection = Rejection.NONE

var _time: TimeSystemScript
## account -> Startwert in Cent
var _opening := {}
## account -> laufender Kontostand in Cent
var _balances := {}
var _entries: Array[LedgerEntryScript] = []
var _next_number := 1
var _used_keys := {}


## opening_balance_cents ist der Startwert des Privatkontos; das Firmenkonto beginnt bei 0.
func _init(time: TimeSystemScript, opening_balance_cents: int = 0) -> void:
	_time = time
	_opening = {PRIVATE: opening_balance_cents, COMPANY: 0}
	_balances = _opening.duplicate()


## Bucht einen Betrag auf ein Konto. Gibt die neue Buchung zurück oder null bei Ablehnung.
func post(amount_cents: int, category: String, description: String, source: String,
		reference: String = "", idempotency_key: String = "",
		allow_negative: bool = false, account: String = PRIVATE, effective_minutes: int = -1) -> LedgerEntryScript:
	if amount_cents == 0 or category.is_empty() or description.is_empty() or source.is_empty() \
			or account not in ACCOUNTS or effective_minutes > _time.get_minutes():
		push_error("LedgerSystem: ungültige Buchung (Betrag %d, Kategorie '%s', Beschreibung '%s', Quelle '%s', Konto '%s')."
				% [amount_cents, category, description, source, account])
		last_rejection = Rejection.INVALID
		return null
	if not idempotency_key.is_empty() and _used_keys.has(idempotency_key):
		last_rejection = Rejection.DUPLICATE
		return null
	if amount_cents < 0 and not allow_negative and _balances[account] + amount_cents < 0:
		last_rejection = Rejection.INSUFFICIENT_FUNDS
		return null
	return _book(amount_cents, category, description, source, reference, idempotency_key, account,
			effective_minutes)


## Umbuchung zwischen zwei Konten (z. B. Einlage privat -> Firma). Gibt beide Buchungen
## [Abgang, Zugang] zurück oder [] bei Ablehnung (dann keine Änderung).
## idempotency_key ist Pflicht; gebucht wird mit "<key>|out" und "<key>|in", Referenz = key.
func transfer(amount_cents: int, from_account: String, to_account: String, description: String,
		source: String, idempotency_key: String) -> Array[LedgerEntryScript]:
	var result: Array[LedgerEntryScript] = []
	if amount_cents <= 0 or from_account not in ACCOUNTS or to_account not in ACCOUNTS \
			or from_account == to_account or description.is_empty() or source.is_empty() \
			or idempotency_key.is_empty():
		push_error("LedgerSystem: ungültige Umbuchung (Betrag %d, %s -> %s, Schlüssel '%s')."
				% [amount_cents, from_account, to_account, idempotency_key])
		last_rejection = Rejection.INVALID
		return result
	var out_key := idempotency_key + TRANSFER_OUT_SUFFIX
	var in_key := idempotency_key + TRANSFER_IN_SUFFIX
	if _used_keys.has(out_key) or _used_keys.has(in_key):
		last_rejection = Rejection.DUPLICATE
		return result
	if _balances[from_account] < amount_cents:
		last_rejection = Rejection.INSUFFICIENT_FUNDS
		return result
	# Alles geprüft – beide Hälften können jetzt nicht mehr scheitern.
	result.append(_book(-amount_cents, TRANSFER_CATEGORY, description, source, idempotency_key, out_key, from_account))
	result.append(_book(amount_cents, TRANSFER_CATEGORY, description, source, idempotency_key, in_key, to_account))
	return result


func can_afford(cost_cents: int, account: String = PRIVATE) -> bool:
	return cost_cents <= _balances.get(account, 0)


func get_balance(account: String = PRIVATE) -> int:
	return _balances.get(account, 0)


func get_opening_balance(account: String = PRIVATE) -> int:
	return _opening.get(account, 0)


## Alle Buchungen in Buchungsreihenfolge (Kopie der Liste), über alle Konten.
func get_entries() -> Array[LedgerEntryScript]:
	return _entries.duplicate()


func get_entries_for_account(account: String) -> Array[LedgerEntryScript]:
	var result: Array[LedgerEntryScript] = []
	for entry in _entries:
		if entry.account == account:
			result.append(entry)
	return result


## Summen eines Kontos für Buchungen mit Wertstellung in [from_minutes, to_minutes):
## {income_cents, expense_cents (≤ 0), net_cents = Einnahmen + Ausgaben ohne Umbuchungen,
##  transfer_in_cents, transfer_out_cents (≤ 0)}. Umbuchungen zählen nicht als Gewinn oder Verlust.
func summarize(account: String, from_minutes: int, to_minutes: int) -> Dictionary:
	var result := {"income_cents": 0, "expense_cents": 0, "net_cents": 0, "transfer_in_cents": 0,
			"transfer_out_cents": 0}
	for entry in _entries:
		if entry.account != account or entry.effective_minutes < from_minutes or entry.effective_minutes >= to_minutes:
			continue
		if entry.category == TRANSFER_CATEGORY:
			result["transfer_in_cents" if entry.amount_cents > 0 else "transfer_out_cents"] += entry.amount_cents
		else:
			result["income_cents" if entry.amount_cents > 0 else "expense_cents"] += entry.amount_cents
	result["net_cents"] = result["income_cents"] + result["expense_cents"]
	return result


func get_entries_by_category(category: String) -> Array[LedgerEntryScript]:
	var result: Array[LedgerEntryScript] = []
	for entry in _entries:
		if entry.category == category:
			result.append(entry)
	return result


## Kontostand frisch aus Startwert + Buchungen des Kontos. Muss immer get_balance() entsprechen.
func recalculate_balance(account: String = PRIVATE) -> int:
	var total: int = _opening.get(account, 0)
	for entry in _entries:
		if entry.account == account:
			total += entry.amount_cents
	return total


func to_dict() -> Dictionary:
	var entries := []
	for entry in _entries:
		entries.append({
			"id": entry.id, "time_minutes": entry.time_minutes, "amount_cents": entry.amount_cents,
			"category": entry.category, "description": entry.description, "source": entry.source,
			"reference": entry.reference, "account": entry.account, "effective_minutes": entry.effective_minutes,
		})
	return {
		"opening_balances": _opening.duplicate(),
		"next_number": _next_number,
		"entries": entries,
		"used_keys": _used_keys.duplicate(),
	}


## Stellt einen gespeicherten Zustand her, ohne Signale zu senden. Kontostände
## werden aus Startwerten + Buchungen neu berechnet, nie aus der Datei übernommen.
## Umbuchungen müssen vollständig sein (zu jedem "<key>|out" ein "<key>|in" und umgekehrt).
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var reader := DataReaderScript.new()
	var opening := {}
	var raw_opening: Variant = data.get("opening_balances")
	if typeof(raw_opening) != TYPE_DICTIONARY:
		reader.errors.append("Ledger: 'opening_balances' fehlt oder ist kein Objekt.")
	else:
		for account in ACCOUNTS:
			opening[account] = reader.int_field(raw_opening, account, "Ledger (opening_balances)", true)
	var next_number := reader.int_field(data, "next_number", "Ledger", true)

	var entries: Array[LedgerEntryScript] = []
	var ids := {}
	var raw_entries: Variant = data.get("entries")
	if typeof(raw_entries) != TYPE_ARRAY:
		reader.errors.append("Ledger: 'entries' fehlt oder ist keine Liste.")
	else:
		for i in raw_entries.size():
			var raw: Variant = raw_entries[i]
			var where := "Buchung #%d" % (i + 1)
			if typeof(raw) != TYPE_DICTIONARY:
				reader.errors.append("%s: muss ein Objekt sein." % where)
				continue
			var error_count := reader.errors.size()
			var id := reader.string_field(raw, "id", where, true)
			var time_minutes := reader.int_field(raw, "time_minutes", where, true)
			var amount := reader.int_field(raw, "amount_cents", where, true)
			var category := reader.string_field(raw, "category", where, true)
			var description := reader.string_field(raw, "description", where, true)
			var source := reader.string_field(raw, "source", where, true)
			var reference := reader.string_field(raw, "reference", where, false)
			var account := reader.string_field(raw, "account", where, true)
			var effective := reader.int_field(raw, "effective_minutes", where, true)
			if amount == 0 or time_minutes < 0 or effective < 0:
				reader.errors.append("%s: Betrag 0 oder negative Zeit." % where)
			if not account.is_empty() and account not in ACCOUNTS:
				reader.errors.append("%s: unbekanntes Konto '%s'." % [where, account])
			if ids.has(id):
				reader.errors.append("%s: ID '%s' kommt doppelt vor." % [where, id])
			if reader.errors.size() == error_count:
				ids[id] = true
				entries.append(LedgerEntryScript.new(id, time_minutes, amount, category, description, source,
						reference, account, effective))

	var used_keys := {}
	var raw_keys: Variant = data.get("used_keys", {})
	if typeof(raw_keys) != TYPE_DICTIONARY:
		reader.errors.append("Ledger: 'used_keys' muss ein Objekt sein.")
	else:
		for key in raw_keys:
			if typeof(key) != TYPE_STRING or typeof(raw_keys[key]) != TYPE_STRING:
				reader.errors.append("Ledger: 'used_keys' enthält ungültige Einträge.")
				break
			used_keys[key] = raw_keys[key]
		for key in used_keys:
			var partner := _transfer_partner_key(key)
			if not partner.is_empty() and not used_keys.has(partner):
				reader.errors.append("Ledger: Umbuchung '%s' ist unvollständig (es fehlt '%s')." % [key, partner])

	if reader.errors.is_empty() and next_number <= entries.size():
		reader.errors.append("Ledger: 'next_number' (%d) passt nicht zu %d Buchungen." % [next_number, entries.size()])
	if not reader.errors.is_empty():
		return "; ".join(reader.errors)

	_opening = opening
	_entries = entries
	_next_number = next_number
	_used_keys = used_keys
	_balances = {}
	for account in ACCOUNTS:
		_balances[account] = recalculate_balance(account)
	last_rejection = Rejection.NONE
	return ""


## Ergänzt die Wertstellung für Spielstände vor Version 10: = Buchungszeit; Tagesabschlüsse
## (Quelle "company", Referenz "day:<t>") gehören zum abgerechneten Tag, 23:59. Ändert `data` direkt.
static func migrate_effective_dates(data: Dictionary) -> String:
	if typeof(data.get("entries")) != TYPE_ARRAY:
		return "Ledger: Buchungen fehlen."
	for entry in data["entries"]:
		if typeof(entry) != TYPE_DICTIONARY or not DataReaderScript.is_whole_number(entry.get("time_minutes")):
			return "Ledger: Buchung ohne Zeit."
		entry["effective_minutes"] = int(entry["time_minutes"])
		var reference: Variant = entry.get("reference", "")
		var source: Variant = entry.get("source")  # beschädigte Dateien: Typ erst prüfen, dann vergleichen
		if typeof(source) == TYPE_STRING and source == "company" and typeof(reference) == TYPE_STRING \
				and reference.begins_with("day:") \
				and reference.substr(4).is_valid_int():
			entry["effective_minutes"] = TimeSystemScript.at(int(reference.substr(4)), 23, 59)
	return ""


## Wandelt einen Ledger-Stand von Spielstand-Version ≤ 5 (ein Konto) um: Startwert wird
## Privatkonto-Startwert, alle Buchungen gehören zum Privatkonto. Ändert `data` direkt.
static func migrate_single_account(data: Dictionary) -> String:
	if not DataReaderScript.is_whole_number(data.get("opening_balance_cents")):
		return "Ledger: Startwert fehlt."
	if typeof(data.get("entries")) != TYPE_ARRAY:
		return "Ledger: Buchungen fehlen."
	data["opening_balances"] = {PRIVATE: int(data["opening_balance_cents"]), COMPANY: 0}
	data.erase("opening_balance_cents")
	for entry in data["entries"]:
		if typeof(entry) == TYPE_DICTIONARY:
			entry["account"] = PRIVATE
	return ""


func _book(amount_cents: int, category: String, description: String, source: String,
		reference: String, idempotency_key: String, account: String, effective_minutes: int = -1) -> LedgerEntryScript:
	var entry := LedgerEntryScript.new("tx_%06d" % _next_number, _time.get_minutes(), amount_cents,
			category, description, source, reference, account, effective_minutes)
	_next_number += 1
	_entries.append(entry)
	if not idempotency_key.is_empty():
		_used_keys[idempotency_key] = entry.id
	_balances[account] += amount_cents
	last_rejection = Rejection.NONE

	entry_posted.emit(entry)
	balance_changed.emit(_balances[account], account)
	return entry


## "<k>|out" -> "<k>|in" und umgekehrt; "" für andere Schlüssel.
static func _transfer_partner_key(key: String) -> String:
	if key.ends_with(TRANSFER_OUT_SUFFIX):
		return key.trim_suffix(TRANSFER_OUT_SUFFIX) + TRANSFER_IN_SUFFIX
	if key.ends_with(TRANSFER_IN_SUFFIX):
		return key.trim_suffix(TRANSFER_IN_SUFFIX) + TRANSFER_OUT_SUFFIX
	return ""


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
