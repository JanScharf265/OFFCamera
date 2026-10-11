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

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")
const CompanyTypeScript := preload("res://scripts/models/company_type.gd")
const ChangeScript := preload("res://scripts/models/channel_change.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal company_founded(type_id: String)
signal company_changed(change: ChangeScript)

const KEYS := ["utilization", "reputation"]
const LABELS := {"utilization": "Auslastung", "reputation": "Ruf des Unternehmens"}
const MAX_SCORE := 100
const HISTORY_LIMIT := 200
const SOURCE := "company"

var utilization := 0
var reputation := 0

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _locations: LocationSystemScript
var _catalog: CompanyTypeCatalogScript
var _type_id := ""
var _founded_minutes := -1
var _deposits := 0
var _withdrawals := 0
var _history: Array[ChangeScript] = []
var _next_number := 1
var _used_keys := {}


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, locations: LocationSystemScript,
		catalog: CompanyTypeCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_locations = locations
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
