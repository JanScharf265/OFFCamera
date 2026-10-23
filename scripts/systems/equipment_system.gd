class_name EquipmentSystem
extends RefCounted

## Ausrüstung des Kanals (Phase 3): welche Stufe jedes Teil hat, Kauf der nächsten Stufe
## und der Qualitätsbonus für Content-Formate.
##
## Kauf (buy): nur Stufe für Stufe, nur am Kaufort, nur mit genug Geld. Ausführung:
##   1. Ausgabe im Ledger (Kategorie "equipment", Quelle "equipment",
##      Schutzschlüssel "equipment:<id>:<stufe>" – jede Stufe wird höchstens einmal bezahlt)
##   2. Stufe erhöhen
##   3. Signal equipment_bought
## Ein Kauf kostet keine Spielzeit.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const EquipmentCatalogScript := preload("res://scripts/systems/equipment_catalog.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal equipment_bought(equipment_id: String, level: int)

const EXPENSE_CATEGORY := "equipment"

## U.17: Konto-Wahl für Ausgaben (Schwarzgeld oder privat) und Meldung danach
var _choose_account: Callable
var _record_black: Callable
var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _locations: LocationSystemScript
var _catalog: EquipmentCatalogScript
## equipment_id -> Stufe (fehlt = 0, nichts gekauft)
var _levels := {}


## Hinweise des letzten restore() zu entfernten Daten (Phase 6).
var restore_notices := PackedStringArray()

func _init(time: TimeSystemScript, ledger: LedgerSystemScript, locations: LocationSystemScript,
		catalog: EquipmentCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_locations = locations
	_catalog = catalog


func get_catalog() -> EquipmentCatalogScript:
	return _catalog


func get_level(equipment_id: String) -> int:
	return _levels.get(equipment_id, 0)


## Daten der nächsten Stufe oder {} wenn schon die höchste erreicht ist.
func get_next_level(equipment_id: String) -> Dictionary:
	var definition := _catalog.get_definition(equipment_id)
	if definition == null:
		return {}
	return definition.get_level(get_level(equipment_id) + 1)


## Qualitätsanteile für ein Format, z. B. [{"label": "Kamera (Webcam HD)", "percent": 5}],
## in der Reihenfolge der Datei, nur gekaufte Teile, die das Format verbessern.
func quality_parts(format_id: String) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for id in _catalog.get_ids():
		var definition := _catalog.get_definition(id)
		var level := get_level(id)
		if level == 0 or format_id not in definition.formats:
			continue
		var data := definition.get_level(level)
		parts.append({"label": "%s (%s)" % [definition.display_name, data["name"]],
				"percent": data["quality_percent"]})
	return parts


## "" wenn die nächste Stufe jetzt gekauft werden kann, sonst ein Grund für die Anzeige.
func check_buy(equipment_id: String) -> String:
	var definition := _catalog.get_definition(equipment_id)
	if definition == null:
		return "Unbekannte Ausrüstung: %s" % equipment_id
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var next := get_next_level(equipment_id)
	if next.is_empty():
		return "Höchste Stufe erreicht."
	if definition.location != _locations.get_current():
		var location := _locations.get_catalog().get_definition(definition.location)
		return "Nur vor Ort erhältlich: %s." % (location.display_name if location != null else definition.location)
	if not _ledger.can_afford(next["price_cents"], _account_for(next["price_cents"])):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(next["price_cents"])
	return ""


## Kauft die nächste Stufe. Rückgabe wie check_buy(): "" = gekauft.
func buy(equipment_id: String) -> String:
	var reason := check_buy(equipment_id)
	if not reason.is_empty():
		return reason
	var definition := _catalog.get_definition(equipment_id)
	var level := get_level(equipment_id) + 1
	var data := definition.get_level(level)
	var account := _account_for(data["price_cents"])
	var entry := _ledger.post(-data["price_cents"], EXPENSE_CATEGORY,
			"%s: %s" % [definition.display_name, data["name"]], "equipment",
			"%s:%d" % [equipment_id, level], "equipment:%s:%d" % [equipment_id, level], false, account)
	if entry == null:
		push_error("EquipmentSystem: Buchung für '%s' Stufe %d abgelehnt." % [equipment_id, level])
		return "Die Buchung ist fehlgeschlagen."
	if account == LedgerSystemScript.BLACK and _record_black.is_valid():
		_record_black.call(data["price_cents"], "%s: %s" % [definition.display_name, data["name"]])
	_levels[equipment_id] = level
	equipment_bought.emit(equipment_id, level)
	return ""


func to_dict() -> Dictionary:
	var levels := {}
	for id in _levels:
		levels[id] = _levels[id]
	return {"levels": levels}


## Stellt gespeicherte Stufen her (ohne Signale). Teile, die es in den Daten nicht mehr gibt,
## werden ignoriert; eine Stufe über dem Maximum wird auf das Maximum gesetzt.
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var raw: Variant = data.get("levels")
	if typeof(raw) != TYPE_DICTIONARY:
		return "Ausrüstung: 'levels' fehlt oder ist kein Objekt."
	var levels := {}
	var notices := PackedStringArray()
	for id in raw:
		if typeof(id) != TYPE_STRING or not DataReaderScript.is_whole_number(raw[id]) or int(raw[id]) < 0:
			return "Ausrüstung: ungültige Stufe für '%s'." % id
		var definition := _catalog.get_definition(id)
		if definition != null and int(raw[id]) > 0:
			levels[id] = mini(int(raw[id]), definition.max_level())
		elif definition == null and int(raw[id]) > 0:
			notices.append("Die Ausrüstung „%s“ gibt es nicht mehr – sie wurde entfernt." % id)
	_levels = levels
	restore_notices = notices
	return ""


## U.17: Schwarzgeld ausgeben – BlackSpendingSystem.account_for / record (vom GameState).
func set_black_spending(account_for: Callable, record: Callable) -> void:
	_choose_account = account_for
	_record_black = record


func _account_for(cost_cents: int) -> String:
	return _choose_account.call(cost_cents) if _choose_account.is_valid() else LedgerSystemScript.PRIVATE
