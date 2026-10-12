class_name CompanySystem
extends RefCounted

## Einzige Autorität für das eigene Unternehmen (Phase 4). Abstrakte Spielwerte:
##   utilization  Auslastung, 0–100
##   reputation   Ruf des Unternehmens, 0–100
## Geld liegt nicht hier, sondern auf dem Firmenkonto im LedgerSystem.
##
## Gründung (found): am Gründungsort, Ort für die ganze Dauer geöffnet, genug Geld auf dem
## Privatkonto für Gebühr + Mindesteinlage. Ausführung in fester Reihenfolge:
##   1. Gebühr vom Privatkonto (Schutzschlüssel "company:found:fee")
##   2. Einlage privat -> Firma (Umbuchung "company:deposit:1")
##   3. Unternehmen anlegen, Protokolleintrag
##   4. Zeitfortschritt um die Gründungsdauer
##   5. Signal company_founded
## Einlage/Entnahme: Umbuchungen mit fortlaufenden Schlüsseln "company:deposit:<n>" /
## "company:withdraw:<n>" (Zähler im Spielstand), kosten keine Spielzeit.
## Änderungen an Auslastung/Ruf nur über apply() – mit Begründung im Unternehmens-Protokoll
## (gleiches Eintragsmodell wie das Kanal-Protokoll).
##
## Tagesabschluss (Ticket 4.3): beim Tageswechsel (über den DayCycle) wird der Vortag abgerechnet – nur dann,
## kein Zeitfortschritt im Hintergrund. Exakt und ganzzahlig (abgerundet):
##   Grundlage = base_revenue + Follower × revenue_per_1000 / 1000
##   Umsatz    = Grundlage × Auslastung / 100 × (100 + (Ruf − 50) / 2) / 100
##   1. Umsatz aufs Firmenkonto      (Kategorie "sales",       Schlüssel "company:day:<t>:revenue")
##   2. Fixkosten vom Firmenkonto    (Kategorie "fixed_costs", Schlüssel "company:day:<t>:costs");
##      reicht das Firmenkonto nicht, wird nichts abgebucht (nie negativ), dafür sinkt der Ruf
##      um unpaid_reputation_penalty ("company:day:<t>:unpaid")
##   3. Auslastung sinkt um utilization_decay_per_day ("company:day:<t>:decay") – Pflege vor Ort hält dagegen
## Jeder Tag wird höchstens einmal abgerechnet (last_settled_day + Schutzschlüssel), auch nach dem Laden.
##
## Filiale (Ticket 4.4): open_branch() am Filial-Ort, Kosten vom Firmenkonto ("company:branch:open"),
## Spielzeit. Danach zählen Filial-Grundumsatz zur Grundlage und Filial-Fixkosten zu den Fixkosten.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")
const CompanyTypeScript := preload("res://scripts/models/company_type.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const ChangeScript := preload("res://scripts/models/channel_change.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal company_founded(type_id: String)
signal company_changed(change: ChangeScript)
signal day_settled(day: int)
signal branch_opened

const KEYS := ["utilization", "reputation"]
const LABELS := {"utilization": "Auslastung", "reputation": "Ruf des Unternehmens"}
const MAX_SCORE := 100
const HISTORY_LIMIT := 200
const SOURCE := "company"
const SETTLEMENT_LIMIT := 60

var utilization := 0
var reputation := 0

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _locations: LocationSystemScript
var _catalog: CompanyTypeCatalogScript
var _channel: ChannelSystemScript
var _type_id := ""
var _founded_minutes := -1
var _deposits := 0
var _withdrawals := 0
var _history: Array[ChangeScript] = []
var _next_number := 1
var _used_keys := {}
## Letzter abgerechneter Tag (Gründungstag − 1 direkt nach der Gründung).
var _last_settled_day := 0
var _branch_open := false
## Tagesabschlüsse, älteste zuerst: {day, revenue_cents, costs_cents, paid, text}
var _settlements: Array[Dictionary] = []
## Seit dem letzten take_settlement_notices() neu abgerechnete Tage (nicht gespeichert).
var _new_settlements: Array[int] = []


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, locations: LocationSystemScript,
		channel: ChannelSystemScript, catalog: CompanyTypeCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_locations = locations
	_channel = channel
	_catalog = catalog


func get_catalog() -> CompanyTypeCatalogScript:
	return _catalog


func is_founded() -> bool:
	return not _type_id.is_empty()


## Art des gegründeten Unternehmens oder null.
func get_type() -> CompanyTypeScript:
	return _catalog.get_definition(_type_id) if is_founded() else null


## Spielzeit der Gründung (Minuten) oder -1.
func get_founded_minutes() -> int:
	return _founded_minutes


func is_branch_open() -> bool:
	return _branch_open


## "" wenn die Filiale jetzt eröffnet werden kann, sonst ein Grund für die Anzeige.
func check_open_branch() -> String:
	var definition := get_type()
	if definition == null:
		return "Erst ein Unternehmen gründen (im Büro)."
	if not definition.has_branch:
		return "Für dieses Unternehmen gibt es keine Filiale."
	if _branch_open:
		return "Die Filiale ist bereits eröffnet."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if definition.branch_location != _locations.get_current():
		var location := _locations.get_catalog().get_definition(definition.branch_location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else definition.branch_location)
	var closed_reason := _locations.check_open_during(definition.branch_location, _time.get_minutes(),
			definition.branch_opening_minutes)
	if not closed_reason.is_empty():
		return closed_reason
	if not _ledger.can_afford(definition.branch_opening_fee_cents, LedgerSystemScript.COMPANY):
		return "Nicht genug Geld auf dem Firmenkonto (kostet %s)." % LedgerSystemScript.format_cents(
				definition.branch_opening_fee_cents)
	return ""


## Eröffnet die Filiale: Kosten vom Firmenkonto → Protokoll → Zeitfortschritt → Signal. "" = eröffnet.
func open_branch() -> String:
	var reason := check_open_branch()
	if not reason.is_empty():
		return reason
	var definition := get_type()
	var entry := _ledger.post(-definition.branch_opening_fee_cents, "company",
			"Eröffnung: %s" % definition.branch_display_name, SOURCE, definition.branch_location,
			"company:branch:open", false, LedgerSystemScript.COMPANY)
	if entry == null:
		push_error("CompanySystem: Eröffnung der Filiale abgelehnt (Grund %d)." % _ledger.last_rejection)
		return "Die Buchung ist fehlgeschlagen."
	_branch_open = true
	_record({}, {}, SOURCE, "Filiale eröffnet: %s (+%s Grundumsatz, %s Fixkosten pro Tag)" % [
			definition.branch_display_name, LedgerSystemScript.format_cents(definition.branch_base_revenue_per_day_cents),
			LedgerSystemScript.format_cents(definition.branch_fixed_costs_per_day_cents)], definition.branch_location)
	_time.advance(definition.branch_opening_minutes)
	branch_opened.emit()
	return ""


func get_value(key: String) -> int:
	assert(key in KEYS)
	return get(key)


## "" wenn die Gründung jetzt möglich ist, sonst ein Grund für die Anzeige.
func check_found(type_id: String) -> String:
	var definition := _catalog.get_definition(type_id)
	if definition == null:
		return "Unbekannte Unternehmensart: %s" % type_id
	if is_founded():
		return "Du hast bereits ein Unternehmen."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if definition.found_location != _locations.get_current():
		var location := _locations.get_catalog().get_definition(definition.found_location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else definition.found_location)
	var closed_reason := _locations.check_open_during(definition.found_location, _time.get_minutes(),
			definition.founding_minutes)
	if not closed_reason.is_empty():
		return closed_reason
	var needed := definition.founding_fee_cents + definition.min_deposit_cents
	if not _ledger.can_afford(needed, LedgerSystemScript.PRIVATE):
		return "Nicht genug Geld auf dem Privatkonto (Gebühr + Einlage: %s)." % LedgerSystemScript.format_cents(needed)
	return ""


## Gründet das Unternehmen. Rückgabe wie check_found(): "" = gegründet.
func found(type_id: String) -> String:
	var reason := check_found(type_id)
	if not reason.is_empty():
		return reason
	var definition := _catalog.get_definition(type_id)
	var fee := _ledger.post(-definition.founding_fee_cents, "company", "Gründung: %s" % definition.display_name,
			SOURCE, type_id, "company:found:fee", false, LedgerSystemScript.PRIVATE)
	if fee == null:
		push_error("CompanySystem: Gründungsgebühr abgelehnt (Grund %d)." % _ledger.last_rejection)
		return "Die Buchung ist fehlgeschlagen."
	var moved := _ledger.transfer(definition.min_deposit_cents, LedgerSystemScript.PRIVATE, LedgerSystemScript.COMPANY,
			"Einlage bei Gründung", SOURCE, "company:deposit:1")
	if moved.is_empty():
		push_error("CompanySystem: Einlage bei Gründung abgelehnt (Grund %d)." % _ledger.last_rejection)
		return "Die Einlage ist fehlgeschlagen."
	_deposits = 1
	_type_id = type_id
	_founded_minutes = _time.get_minutes()
	_last_settled_day = TimeSystemScript.day_of(_founded_minutes) - 1
	utilization = definition.start_utilization
	reputation = definition.start_reputation
	_record({}, {}, SOURCE, "Gegründet: %s (Auslastung %d, Ruf %d)" % [definition.display_name, utilization,
			reputation], type_id)
	_time.advance(definition.founding_minutes)
	company_founded.emit(type_id)
	return ""


## "" wenn die Einlage möglich ist, sonst ein Grund.
func check_deposit(amount_cents: int) -> String:
	if not is_founded():
		return "Noch kein Unternehmen gegründet."
	if amount_cents <= 0:
		return "Betrag muss größer als 0 sein."
	if not _ledger.can_afford(amount_cents, LedgerSystemScript.PRIVATE):
		return "Nicht genug Geld auf dem Privatkonto."
	return ""


## Einlage privat -> Firma. "" = gebucht.
func deposit(amount_cents: int) -> String:
	var reason := check_deposit(amount_cents)
	if not reason.is_empty():
		return reason
	var moved := _ledger.transfer(amount_cents, LedgerSystemScript.PRIVATE, LedgerSystemScript.COMPANY,
			"Einlage ins Unternehmen", SOURCE, "company:deposit:%d" % (_deposits + 1))
	if moved.is_empty():
		return "Die Einlage ist fehlgeschlagen."
	_deposits += 1
	return ""


## "" wenn die Entnahme möglich ist, sonst ein Grund.
func check_withdraw(amount_cents: int) -> String:
	if not is_founded():
		return "Noch kein Unternehmen gegründet."
	if amount_cents <= 0:
		return "Betrag muss größer als 0 sein."
	if not _ledger.can_afford(amount_cents, LedgerSystemScript.COMPANY):
		return "Nicht genug Geld auf dem Firmenkonto."
	return ""


## Entnahme Firma -> privat. "" = gebucht.
func withdraw(amount_cents: int) -> String:
	var reason := check_withdraw(amount_cents)
	if not reason.is_empty():
		return reason
	var moved := _ledger.transfer(amount_cents, LedgerSystemScript.COMPANY, LedgerSystemScript.PRIVATE,
			"Entnahme aus dem Unternehmen", SOURCE, "company:withdraw:%d" % (_withdrawals + 1))
	if moved.is_empty():
		return "Die Entnahme ist fehlgeschlagen."
	_withdrawals += 1
	return ""


## Ändert Auslastung/Ruf (begrenzt auf 0–100) mit Begründung. Eintrag oder null bei
## Ablehnung: nicht gegründet, unbekannter Schlüssel, keine ganze Zahl, leere Quelle/Begründung,
## alles 0, idempotency_key schon verwendet.
func apply(deltas: Dictionary, source: String, reason: String, reference: String = "",
		idempotency_key: String = "") -> ChangeScript:
	if not is_founded():
		return null
	if source.is_empty() or reason.is_empty():
		push_error("CompanySystem: Quelle und Begründung sind Pflicht.")
		return null
	var requested := {}
	for key in deltas:
		if key not in KEYS or not DataReaderScript.is_whole_number(deltas[key]):
			push_error("CompanySystem: ungültige Änderung '%s' = %s." % [key, deltas[key]])
			return null
		if int(deltas[key]) != 0:
			requested[key] = int(deltas[key])
	if requested.is_empty():
		return null
	if not idempotency_key.is_empty() and _used_keys.has(idempotency_key):
		return null
	var applied := {}
	for key in KEYS:
		if requested.has(key):
			var new_value := clampi(get(key) + int(requested[key]), 0, MAX_SCORE)
			if new_value != get(key):
				applied[key] = new_value - get(key)
				set(key, new_value)
	var change := _record(requested, applied, source, reason, reference)
	if not idempotency_key.is_empty():
		_used_keys[idempotency_key] = change.id
	return change


## Protokoll, älteste zuerst (Kopie).
func get_history() -> Array[ChangeScript]:
	return _history.duplicate()


## Erwarteter Tagesabschluss beim aktuellen Stand (für Anzeige und Abrechnung):
## {base_cents, reach_cents, utilization, reputation_percent, revenue_cents, costs_cents}. {} ohne Unternehmen.
@warning_ignore("integer_division")
func preview_day() -> Dictionary:
	var definition := get_type()
	if definition == null:
		return {}
	var reach := _channel.followers * definition.revenue_per_1000_followers_cents / 1000
	var branch_base := definition.branch_base_revenue_per_day_cents if _branch_open else 0
	var branch_costs := definition.branch_fixed_costs_per_day_cents if _branch_open else 0
	var reputation_percent := (reputation - 50) / 2
	var revenue := (definition.base_revenue_per_day_cents + branch_base + reach) * utilization / 100 \
			* (100 + reputation_percent) / 100
	return {
		"base_cents": definition.base_revenue_per_day_cents,
		"branch_cents": branch_base,
		"reach_cents": reach,
		"utilization": utilization,
		"reputation_percent": reputation_percent,
		"revenue_cents": revenue,
		"costs_cents": definition.fixed_costs_per_day_cents + branch_costs,
	}


## Tagesabschlüsse, älteste zuerst (Kopie).
func get_settlements() -> Array[Dictionary]:
	return _settlements.duplicate(true)


## Texte der seit dem letzten Aufruf neu abgerechneten Tage (je einmal, für die Rückmeldung).
func take_settlement_notices() -> PackedStringArray:
	var texts := PackedStringArray()
	for settlement in _settlements:
		if int(settlement["day"]) in _new_settlements:
			texts.append(settlement["text"])
	_new_settlements.clear()
	return texts


func to_dict() -> Dictionary:
	if not is_founded():
		return {"founded": false}
	var entries := []
	for change in _history:
		entries.append({
			"id": change.id, "time_minutes": change.time_minutes, "source": change.source,
			"reason": change.reason, "reference": change.reference,
			"requested": change.requested.duplicate(), "applied": change.applied.duplicate(),
		})
	return {
		"founded": true,
		"type": _type_id,
		"founded_minutes": _founded_minutes,
		"utilization": utilization,
		"reputation": reputation,
		"deposits": _deposits,
		"withdrawals": _withdrawals,
		"next_number": _next_number,
		"history": entries,
		"used_keys": _used_keys.duplicate(),
		"last_settled_day": _last_settled_day,
		"settlements": _settlements.duplicate(true),
		"branch_open": _branch_open,
	}


## Stellt einen gespeicherten Zustand her, ohne Signale. "" = ok, sonst Fehlertext (dann unverändert).
func restore(data: Dictionary) -> String:
	var founded: Variant = data.get("founded")
	if typeof(founded) != TYPE_BOOL:
		return "Unternehmen: 'founded' fehlt."
	if not founded:
		_reset()
		return ""
	var reader := DataReaderScript.new()
	var where := "Unternehmen"
	var type_id := reader.string_field(data, "type", where, true)
	if not type_id.is_empty() and not _catalog.has(type_id):
		reader.errors.append("Unternehmen: unbekannte Art '%s'." % type_id)
	var founded_minutes := reader.int_field(data, "founded_minutes", where, true)
	var values := {}
	for key in KEYS:
		var value := reader.int_field(data, key, where, true)
		if value < 0 or value > MAX_SCORE:
			reader.errors.append("Unternehmen: '%s' liegt nicht zwischen 0 und %d." % [key, MAX_SCORE])
		values[key] = value
	var deposits := reader.int_field(data, "deposits", where, true)
	var withdrawals := reader.int_field(data, "withdrawals", where, true)
	var next_number := reader.int_field(data, "next_number", where, true)
	var last_settled_day := reader.int_field(data, "last_settled_day", where, true)
	var branch_open: Variant = data.get("branch_open")
	if typeof(branch_open) != TYPE_BOOL:
		reader.errors.append("Unternehmen: 'branch_open' fehlt.")
	var settlements: Array[Dictionary] = []
	var raw_settlements: Variant = data.get("settlements")
	if typeof(raw_settlements) != TYPE_ARRAY:
		reader.errors.append("Unternehmen: 'settlements' fehlt oder ist keine Liste.")
	else:
		for i in raw_settlements.size():
			var raw: Variant = raw_settlements[i]
			var context := "Tagesabschluss #%d" % (i + 1)
			if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("paid")) != TYPE_BOOL:
				reader.errors.append("%s: ungültig." % context)
				continue
			settlements.append({
				"day": reader.int_field(raw, "day", context, true),
				"revenue_cents": reader.int_field(raw, "revenue_cents", context, true),
				"costs_cents": reader.int_field(raw, "costs_cents", context, true),
				"paid": raw["paid"],
				"text": reader.string_field(raw, "text", context, true),
			})

	var history: Array[ChangeScript] = []
	var raw_history: Variant = data.get("history")
	if typeof(raw_history) != TYPE_ARRAY:
		reader.errors.append("Unternehmen: 'history' fehlt oder ist keine Liste.")
	else:
		for i in raw_history.size():
			var raw: Variant = raw_history[i]
			var context := "Unternehmens-Eintrag #%d" % (i + 1)
			if typeof(raw) != TYPE_DICTIONARY:
				reader.errors.append("%s: muss ein Objekt sein." % context)
				continue
			var error_count := reader.errors.size()
			var id := reader.string_field(raw, "id", context, true)
			var time_minutes := reader.int_field(raw, "time_minutes", context, true)
			var source := reader.string_field(raw, "source", context, true)
			var reason := reader.string_field(raw, "reason", context, true)
			var reference := reader.string_field(raw, "reference", context, false)
			var requested := _read_deltas(reader, raw, "requested", context)
			var applied := _read_deltas(reader, raw, "applied", context)
			if reader.errors.size() == error_count:
				history.append(ChangeScript.new(id, time_minutes, source, reason, reference, requested, applied))

	var used_keys := {}
	var raw_keys: Variant = data.get("used_keys", {})
	if typeof(raw_keys) != TYPE_DICTIONARY:
		reader.errors.append("Unternehmen: 'used_keys' muss ein Objekt sein.")
	else:
		for key in raw_keys:
			if typeof(key) != TYPE_STRING or typeof(raw_keys[key]) != TYPE_STRING:
				reader.errors.append("Unternehmen: 'used_keys' enthält ungültige Einträge.")
				break
			used_keys[key] = raw_keys[key]
	if reader.errors.is_empty() and (deposits < 1 or withdrawals < 0 or next_number < 1):
		reader.errors.append("Unternehmen: Zähler ungültig.")
	if not reader.errors.is_empty():
		return "; ".join(reader.errors)

	_type_id = type_id
	_founded_minutes = founded_minutes
	utilization = values["utilization"]
	reputation = values["reputation"]
	_deposits = deposits
	_withdrawals = withdrawals
	_next_number = next_number
	_history = history
	_used_keys = used_keys
	_last_settled_day = last_settled_day
	_settlements = settlements
	_branch_open = branch_open
	_new_settlements.clear()
	return ""


func _reset() -> void:
	_type_id = ""
	_founded_minutes = -1
	utilization = 0
	reputation = 0
	_deposits = 0
	_withdrawals = 0
	_history = []
	_next_number = 1
	_used_keys = {}
	_last_settled_day = 0
	_branch_open = false
	_settlements = []
	_new_settlements.clear()


## Vom DayCycle aufgerufen (feste Reihenfolge am Tageswechsel): rechnet den Vortag ab.
func on_day_changed(day: int) -> void:
	var settled_day := day - 1
	if not is_founded() or settled_day <= _last_settled_day:
		return
	_settle(settled_day)


func _settle(day: int) -> void:
	var definition := get_type()
	var outcome := preview_day()
	var prefix := "company:day:%d" % day
	var reference := "day:%d" % day
	# Wertstellung = abgerechneter Tag, 23:59 – nicht der Zeitpunkt der Abrechnung (Fristen, Wochen).
	var effective := TimeSystemScript.at(day, 23, 59)
	var revenue: int = outcome["revenue_cents"]
	var costs: int = outcome["costs_cents"]
	if revenue > 0:
		_ledger.post(revenue, "sales", "Tagesumsatz Tag %d" % day, SOURCE, reference, prefix + ":revenue",
				false, LedgerSystemScript.COMPANY, effective)
	var paid := true
	if costs > 0:
		paid = _ledger.can_afford(costs, LedgerSystemScript.COMPANY)
		if paid:
			_ledger.post(-costs, "fixed_costs", "Fixkosten Tag %d" % day, SOURCE, reference, prefix + ":costs",
					false, LedgerSystemScript.COMPANY, effective)
	var branch_text := ""
	if outcome["branch_cents"] > 0:
		branch_text = " + %s Filiale" % LedgerSystemScript.format_cents(outcome["branch_cents"])
	var text := "Tag %d: Umsatz %s (%s%s + %s Reichweite · Auslastung %d %% · Ruf %s %%)" % [day,
			_signed_money(revenue), LedgerSystemScript.format_cents(outcome["base_cents"]), branch_text,
			LedgerSystemScript.format_cents(outcome["reach_cents"]), outcome["utilization"],
			_signed_percent(outcome["reputation_percent"])]
	if paid:
		text += " · Fixkosten %s · Ergebnis %s" % [_signed_money(-costs), _signed_money(revenue - costs)]
	else:
		text += " · Fixkosten %s nicht bezahlt (Firmenkonto zu leer) – Ruf -%d" % [
				LedgerSystemScript.format_cents(costs), definition.unpaid_reputation_penalty]
		apply({"reputation": -definition.unpaid_reputation_penalty}, SOURCE,
				"Tag %d: Fixkosten nicht bezahlt" % day, reference, prefix + ":unpaid")
	if definition.utilization_decay_per_day > 0:
		apply({"utilization": -definition.utilization_decay_per_day}, SOURCE,
				"Tag %d: ohne Pflege sinkt die Auslastung" % day, reference, prefix + ":decay")
	_settlements.append({"day": day, "revenue_cents": revenue, "costs_cents": costs, "paid": paid, "text": text})
	if _settlements.size() > SETTLEMENT_LIMIT:
		_settlements = _settlements.slice(_settlements.size() - SETTLEMENT_LIMIT)
	_new_settlements.append(day)
	_last_settled_day = day
	day_settled.emit(day)


static func _signed_money(cents: int) -> String:
	var text := LedgerSystemScript.format_cents(cents)
	return "+" + text if cents > 0 else text


static func _signed_percent(value: int) -> String:
	return "±0" if value == 0 else "%+d" % value


func _record(requested: Dictionary, applied: Dictionary, source: String, reason: String,
		reference: String) -> ChangeScript:
	var change := ChangeScript.new("co_%06d" % _next_number, _time.get_minutes(), source, reason, reference,
			requested, applied)
	_next_number += 1
	_history.append(change)
	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)
	company_changed.emit(change)
	return change


static func _read_deltas(reader: DataReaderScript, entry: Dictionary, field: String, where: String) -> Dictionary:
	var raw: Variant = entry.get(field)
	var result := {}
	if typeof(raw) != TYPE_DICTIONARY:
		reader.errors.append("%s: '%s' muss ein Objekt sein." % [where, field])
		return result
	for key in raw:
		if key not in KEYS or not DataReaderScript.is_whole_number(raw[key]):
			reader.errors.append("%s: '%s' enthält ungültige Werte." % [where, field])
			return result
		result[key] = int(raw[key])
	return result
