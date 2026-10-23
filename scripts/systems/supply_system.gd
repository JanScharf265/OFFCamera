extends RefCounted

## Lieferant und Bestand (U.6): Einkauf auf Vorkasse bei einem erfundenen Lieferanten (SupplierCatalog), Lieferung
## beim Tageswechsel nach `delivery_days` – sie kann platzen (deterministisch über den Spiel-Seed), dann ist das Geld
## weg. Gelieferte Ware landet im Bestand (Einheiten je Produkt, reine Spielwerte). Bezahlt wird als Buchung: aus dem
## Schwarzgeld, wenn es reicht, sonst vom Privatkonto. Erreichbar, sobald der Freischalt-Auftrag erledigt ist.
## Schritt im DayCycle (nach der Organisation); jeder Tag höchstens einmal, auch nach dem Laden.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SupplierCatalogScript := preload("res://scripts/systems/supplier_catalog.gd")
const ProductCatalogScript := preload("res://scripts/systems/product_catalog.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

signal stock_changed
signal order_finished(order_id: String, delivered: bool)

const STATUS_PENDING := "pending"
const STATUS_DELIVERED := "delivered"
const STATUS_FAILED := "failed"
const CATEGORY := "underworld_purchase"
const SOURCE := "supply"
## Gespeicherte Bestellungen (erledigte ältere fallen weg)
const HISTORY_LIMIT := 30

var _time
var _ledger: LedgerSystemScript
var _suppliers: SupplierCatalogScript
var _products: ProductCatalogScript
## Fragt, ob ein Auftrag erledigt ist (MissionSystem.is_completed) – als Callable statt Verweis, sonst hielten sich
## Lieferant und Aufträge gegenseitig fest (Speicherleck, test_memory).
var _is_mission_completed: Callable
## Liefert den Spiel-Seed (EventSystem.get_seed) – bei jedem Wurf neu gelesen, damit er nach dem Laden stimmt.
var _get_seed: Callable
## product_id -> Einheiten
var _stock := {}
var _orders: Array = []
var _next_number := 1
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, suppliers: SupplierCatalogScript, products: ProductCatalogScript,
		missions, get_seed: Callable) -> void:
	_time = time
	_ledger = ledger
	_suppliers = suppliers
	_products = products
	_is_mission_completed = missions.is_completed
	_get_seed = get_seed
	_last_processed_day = time.get_day()


func get_suppliers() -> SupplierCatalogScript:
	return _suppliers


func get_products() -> ProductCatalogScript:
	return _products


func is_unlocked(supplier_id: String) -> bool:
	var supplier = _suppliers.get_definition(supplier_id)
	return supplier != null and _is_mission_completed.call(supplier.unlocked_by_mission)


## Lieferanten, die schon erreichbar sind.
func get_unlocked() -> Array:
	return _suppliers.get_all().filter(func(supplier) -> bool: return is_unlocked(supplier.id))


func get_stock(product_id: String) -> int:
	return int(_stock.get(product_id, 0))


func total_stock() -> int:
	var total := 0
	for product_id in _stock:
		total += int(_stock[product_id])
	return total


## Offene Bestellungen (Kopien), älteste zuerst.
func get_pending_orders() -> Array:
	return _orders.filter(func(order) -> bool: return order["status"] == STATUS_PENDING).map(
			func(order) -> Dictionary: return order.duplicate())


## Gesamtpreis einer Bestellung (Cent).
func order_cost(product_id: String, units: int) -> int:
	var product = _products.get_definition(product_id)
	return product.buy_price_cents * units if product != null else 0


## Konto, von dem eine Bestellung bezahlt würde: Schwarzgeld, wenn es reicht, sonst Privatkonto.
func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## "" wenn die Bestellung jetzt möglich ist, sonst ein Grund für die Anzeige.
func check_order(supplier_id: String, product_id: String, units: int) -> String:
	var supplier = _suppliers.get_definition(supplier_id)
	if supplier == null:
		return "Unbekannter Lieferant: %s" % supplier_id
	if not is_unlocked(supplier_id):
		return "Diesen Lieferanten kennst du noch nicht."
	var product = _products.get_definition(product_id)
	if product == null or product_id not in supplier.products:
		return "%s hat das nicht." % supplier.name
	if units < supplier.min_units or units > supplier.max_units:
		return "Menge %d–%d Einheiten." % [supplier.min_units, supplier.max_units]
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var cost := order_cost(product_id, units)
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (Vorkasse %s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Bestellt auf Vorkasse. "" = bestellt (bezahlt, Lieferung offen).
func order(supplier_id: String, product_id: String, units: int) -> String:
	var reason := check_order(supplier_id, product_id, units)
	if not reason.is_empty():
		return reason
	var supplier = _suppliers.get_definition(supplier_id)
	var product = _products.get_definition(product_id)
	var cost := order_cost(product_id, units)
	var account := payment_account(cost)
	var order_id := "order_%04d" % _next_number
	var entry := _ledger.post(-cost, CATEGORY, "Vorkasse: %d × %s (%s)" % [units, product.display_name, supplier.name],
			SOURCE, order_id, "supply:%s" % order_id, false, account)
	if entry == null:
		push_error("SupplySystem: Vorkasse für '%s' trotz Prüfung abgelehnt." % order_id)
		return "Die Buchung ist fehlgeschlagen."
	_next_number += 1
	_orders.append({"id": order_id, "supplier": supplier_id, "product": product_id, "units": units,
			"paid_cents": cost, "account": account, "ordered_minutes": _time.get_minutes(),
			"due_day": _time.get_day() + supplier.delivery_days, "status": STATUS_PENDING})
	return ""


## Hinweise (Lieferung da / geplatzt) seit dem letzten Aufruf, je einmal.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle: fällige Lieferungen kommen an – oder platzen (Seed + Bestell-ID, deterministisch).
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	var changed := false
	for order in _orders:
		if order["status"] != STATUS_PENDING or int(order["due_day"]) > day:
			continue
		var supplier = _suppliers.get_definition(order["supplier"])
		var product = _products.get_definition(order["product"])
		var supplier_name: String = supplier.name if supplier != null else order["supplier"]
		var product_name: String = product.display_name if product != null else order["product"]
		var failure: int = supplier.failure_percent if supplier != null else 0
		if roll(order["id"]) < failure:
			order["status"] = STATUS_FAILED
			_notices.append("Lieferung geplatzt: %s meldet sich nicht – %s sind weg." % [supplier_name,
					LedgerSystemScript.format_cents(int(order["paid_cents"]))])
			order_finished.emit(order["id"], false)
		else:
			order["status"] = STATUS_DELIVERED
			_stock[order["product"]] = get_stock(order["product"]) + int(order["units"])
			_notices.append("Lieferung von %s: %d × %s ist da." % [supplier_name, int(order["units"]), product_name])
			changed = true
			order_finished.emit(order["id"], true)
	_trim_history()
	if changed:
		stock_changed.emit()


## 0–99, fest je Spiel-Seed und Bestellung.
func roll(order_id: String) -> int:
	return EventSystemScript.fnv1a("%d:%s" % [_get_seed.call(), order_id]) % 100


func _trim_history() -> void:
	while _orders.size() > HISTORY_LIMIT:
		var index := -1
		for i in _orders.size():
			if _orders[i]["status"] != STATUS_PENDING:
				index = i
				break
		if index < 0:
			return
		_orders.remove_at(index)


func to_dict() -> Dictionary:
	var stock := {}
	for product_id in _stock:
		stock[product_id] = int(_stock[product_id])
	var orders := []
	for order in _orders:
		orders.append(order.duplicate())
	return {"stock": stock, "orders": orders, "next_number": _next_number, "last_processed_day": _last_processed_day}


## Unbekannte Produkte im Bestand bleiben erhalten. "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var raw_stock: Variant = data.get("stock")
	if typeof(raw_stock) != TYPE_DICTIONARY:
		return "Bestand fehlt oder ist kein Objekt."
	var stock := {}
	for product_id in raw_stock:
		if typeof(product_id) != TYPE_STRING or not DataReaderScript.is_whole_number(raw_stock[product_id]) \
				or int(raw_stock[product_id]) < 0:
			return "Bestand: ungültiger Eintrag."
		stock[product_id] = int(raw_stock[product_id])
	var raw_orders: Variant = data.get("orders")
	if typeof(raw_orders) != TYPE_ARRAY:
		return "Bestellungen fehlen oder sind keine Liste."
	var orders: Array = []
	for raw in raw_orders:
		if typeof(raw) != TYPE_DICTIONARY:
			return "Bestellung ist kein Objekt."
		for key in ["id", "supplier", "product", "account", "status"]:
			if typeof(raw.get(key)) != TYPE_STRING:
				return "Bestellung: '%s' fehlt." % key
		for key in ["units", "paid_cents", "ordered_minutes", "due_day"]:
			if not DataReaderScript.is_whole_number(raw.get(key)) or int(raw[key]) < 0:
				return "Bestellung: '%s' fehlt oder ist ungültig." % key
		if raw["status"] not in [STATUS_PENDING, STATUS_DELIVERED, STATUS_FAILED]:
			return "Bestellung: unbekannter Status."
		var order: Dictionary = raw.duplicate()
		for key in ["units", "paid_cents", "ordered_minutes", "due_day"]:
			order[key] = int(order[key])
		orders.append(order)
	for key in ["next_number", "last_processed_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Lieferungen: '%s' fehlt oder ist ungültig." % key
	# Ältere Bestellungen können gekürzt sein – die Nummer muss nur größer als jede vorhandene sein.
	for order in orders:
		if int(String(order["id"]).trim_prefix("order_")) >= int(data["next_number"]):
			return "Lieferungen: 'next_number' passt nicht zu den Bestellungen."
	_stock = stock
	_orders = orders
	_next_number = int(data["next_number"])
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""

