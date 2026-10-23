extends RefCounted

## Verkaufen (U.9): An einem Verkaufsort (Daten: data/underworld/sale_spots.json) verkauft man Ware aus dem Bestand –
## eine Aktion mit Spielzeit. Einnahme = Einheiten × Verkaufspreis × price_percent als Buchung aufs Schwarzgeld,
## Hitze = Einheiten × Hitze je Einheit × heat_percent für die Organisation. Reihenfolge wie bei Aktivitäten:
## Bestand → Buchung → Hitze → Zeitfortschritt. Nur vor Ort, mit gegründeter Organisation und erledigtem
## Freischalt-Auftrag. Reine Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal sold(spot_id: String, product_id: String, units: int)

const DEFAULT_PATH := "res://data/underworld/sale_spots.json"
const CATEGORY := "underworld_sale"
const SOURCE := "sale"
const FIELDS := ["id", "display_name", "location", "description", "unlocked_by_mission", "minutes", "max_units",
		"price_percent", "heat_percent"]


## Ein Verkaufsort (nur Daten).
class Spot extends RefCounted:
	var id: String
	var display_name: String
	var location: String
	var description: String
	var unlocked_by_mission: String
	var minutes: int
	var max_units: int
	var price_percent: int
	var heat_percent: int


## Katalog der Verkaufsorte. Alles-oder-nichts.
class Catalog extends RefCounted:
	var errors: PackedStringArray = []
	var _spots: Array = []

	func load_file(path: String = DEFAULT_PATH) -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			_spots.clear()
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		var reader := DataReaderScript.new()
		_spots.clear()
		if typeof(data) != TYPE_ARRAY:
			errors = PackedStringArray(["Verkaufsorte müssen eine Liste sein."])
			return false
		var spots: Array = []
		var seen := {}
		for i in data.size():
			var entry: Variant = data[i]
			var where := "Verkaufsort #%d" % (i + 1)
			if typeof(entry) != TYPE_DICTIONARY:
				reader.errors.append("%s: muss ein Objekt sein." % where)
				continue
			var error_count := reader.errors.size()
			var id := reader.id_field(entry, where)
			if id.is_empty():
				continue
			where = "Verkaufsort '%s'" % id
			for key in entry:
				if String(key) not in FIELDS:
					reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
			var spot := Spot.new()
			spot.id = id
			for field in ["display_name", "location", "description", "unlocked_by_mission"]:
				spot.set(field, reader.string_field(entry, field, where, true))
			for field in ["minutes", "max_units", "price_percent", "heat_percent"]:
				spot.set(field, reader.int_field(entry, field, where, true))
			if spot.minutes < 1 or spot.max_units < 1 or spot.price_percent < 1 or spot.heat_percent < 0:
				reader.errors.append("%s: Werte ungültig (minutes, max_units, price_percent ≥ 1, heat_percent ≥ 0)." % where)
			if seen.has(id):
				reader.errors.append("%s: ID kommt doppelt vor." % where)
			if reader.errors.size() == error_count:
				seen[id] = true
				spots.append(spot)
		errors = reader.errors
		if not errors.is_empty():
			return false
		_spots = spots
		return true

	func get_all() -> Array:
		return _spots.duplicate()

	func get_definition(id: String):
		for spot in _spots:
			if spot.id == id:
				return spot
		return null

	func get_at(location_id: String) -> Array:
		return _spots.filter(func(spot) -> bool: return spot.location == location_id)


var _time
var _ledger: LedgerSystemScript
var _locations
var _catalog: Catalog
var _supply
var _organisation
var _is_mission_completed: Callable
## Verkaufte Einheiten insgesamt (für Aufträge und Anzeige)
var _sold_units := 0


func _init(time, ledger: LedgerSystemScript, locations, catalog: Catalog, supply, organisation,
		is_mission_completed: Callable) -> void:
	_time = time
	_ledger = ledger
	_locations = locations
	_catalog = catalog
	_supply = supply
	_organisation = organisation
	_is_mission_completed = is_mission_completed


func get_catalog() -> Catalog:
	return _catalog


func get_sold_units() -> int:
	return _sold_units


## Verkaufsort verfügbar (Organisation steht, Freischalt-Auftrag erledigt).
func is_available(spot_id: String) -> bool:
	var spot = _catalog.get_definition(spot_id)
	return spot != null and _organisation.is_founded() and _is_mission_completed.call(spot.unlocked_by_mission)


## Einnahme für einen Verkauf (Cent).
@warning_ignore("integer_division")
func income_cents(spot_id: String, product_id: String, units: int) -> int:
	var spot = _catalog.get_definition(spot_id)
	var product = _supply.get_products().get_definition(product_id)
	if spot == null or product == null:
		return 0
	return product.sell_price_cents * units * spot.price_percent / 100


## Hitze durch einen Verkauf.
@warning_ignore("integer_division")
func heat_for(spot_id: String, product_id: String, units: int) -> int:
	var spot = _catalog.get_definition(spot_id)
	var product = _supply.get_products().get_definition(product_id)
	if spot == null or product == null:
		return 0
	return product.heat_per_unit * units * spot.heat_percent / 100


## "" wenn der Verkauf jetzt möglich ist, sonst ein Grund.
func check_sale(spot_id: String, product_id: String, units: int) -> String:
	var spot = _catalog.get_definition(spot_id)
	if spot == null:
		return "Unbekannter Verkaufsort: %s" % spot_id
	if not is_available(spot_id):
		return "Hier verkaufst du noch nichts."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if _locations.get_current() != spot.location:
		var location = _locations.get_catalog().get_definition(spot.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else spot.location)
	if _supply.get_products().get_definition(product_id) == null:
		return "Unbekannte Ware: %s" % product_id
	if units < 1 or units > spot.max_units:
		return "Je Verkauf 1–%d Einheiten." % spot.max_units
	if _supply.get_stock(product_id) < units:
		return "Nicht genug im Bestand (%d)." % _supply.get_stock(product_id)
	return ""


## "" wenn das Verkaufsfenster sinnvoll ist (Ort verfügbar, vor Ort, Ware da), sonst ein Grund.
func check_open(spot_id: String) -> String:
	var spot = _catalog.get_definition(spot_id)
	if spot == null:
		return "Unbekannter Verkaufsort: %s" % spot_id
	if not is_available(spot_id):
		return "Hier verkaufst du noch nichts."
	if _locations.get_current() != spot.location:
		var location = _locations.get_catalog().get_definition(spot.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else spot.location)
	if _supply.total_stock() < 1:
		return "Keine Ware im Bestand."
	return ""


## Verkauft: Bestand → Buchung (Schwarzgeld) → Hitze → Zeit. "" = verkauft.
func sell(spot_id: String, product_id: String, units: int) -> String:
	var reason := check_sale(spot_id, product_id, units)
	if not reason.is_empty():
		return reason
	var spot = _catalog.get_definition(spot_id)
	var product = _supply.get_products().get_definition(product_id)
	var income := income_cents(spot_id, product_id, units)
	if not _supply.remove_stock(product_id, units):
		return "Nicht genug im Bestand."
	var entry := _ledger.post(income, CATEGORY, "Verkauf: %d × %s (%s)" % [units, product.display_name, spot.display_name],
			SOURCE, spot_id, "", false, LedgerSystemScript.BLACK)
	if entry == null:
		push_error("SaleSystem: Einnahme für '%s' abgelehnt." % spot_id)
	var heat := heat_for(spot_id, product_id, units)
	if heat > 0:
		_organisation.change({"heat": heat})
	_sold_units += units
	sold.emit(spot_id, product_id, units)
	_time.advance(spot.minutes)
	return ""


func to_dict() -> Dictionary:
	return {"sold_units": _sold_units}


## "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var value: Variant = data.get("sold_units")
	if not DataReaderScript.is_whole_number(value) or int(value) < 0:
		return "Verkäufe: 'sold_units' fehlt oder ist ungültig."
	_sold_units = int(value)
	return ""
