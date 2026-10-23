extends RefCounted

## Lieferant und Bestand (U.6): Einkauf auf Vorkasse bei einem erfundenen Lieferanten (SupplierCatalog), Lieferung
## beim Tageswechsel nach `delivery_days` – sie kann platzen (deterministisch über den Spiel-Seed), dann ist das Geld
## weg. Gelieferte Ware landet im Bestand (Einheiten je Produkt, reine Spielwerte). Bezahlt wird als Buchung: aus dem
## Schwarzgeld, wenn es reicht, sonst vom Privatkonto. Erreichbar, sobald der Freischalt-Auftrag erledigt ist.
## Schritt im DayCycle (nach der Organisation); jeder Tag höchstens einmal, auch nach dem Laden.
##
## Kredit (U.7): Nach `credit.after_deliveries` angekommenen Lieferungen liefert der Lieferant auch auf Kredit – keine
## Buchung bei der Bestellung, dafür Schulden (Preis + `markup_percent`), fällig nach `due_days`. Am Fälligkeitstag
## wird daraus eine einmalige Frist im ObligationSystem (Schwarzgeld, ersatzweise Privatkonto; Mahnaufschlag nach
## `grace_days`). Platzt die Lieferung, entfällt die Schuld. Ist die Schuld überfällig, kommt alle
## `pressure_every_days` Tage das Druck-Ereignis (EventSystem, „scripted“). Nur eine laufende Schuld je Lieferant.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SupplierCatalogScript := preload("res://scripts/systems/supplier_catalog.gd")
const ProductCatalogScript := preload("res://scripts/systems/product_catalog.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

signal stock_changed
signal order_finished(order_id: String, delivered: bool)

const STATUS_PENDING := "pending"
const STATUS_DELIVERED := "delivered"
const STATUS_FAILED := "failed"
## Schuld einer Kreditbestellung: läuft (noch nicht fällig), an die Fristen übergeben, entfallen (Lieferung geplatzt)
const DEBT_RUNNING := "running"
const DEBT_HANDED := "handed"
const DEBT_CANCELLED := "cancelled"
const DEBT_CATEGORY := "underworld_debt"
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
## U.8: Lager-Kapazität (SiteSystem.capacity) – Bestand + unterwegs darf sie nicht übersteigen. Ohne: unbegrenzt.
var _capacity: Callable
var _discount: Callable


func set_capacity_check(capacity: Callable) -> void:
	_capacity = capacity


## U.18: Rabatt beim Einkauf (SiteSystem.supplier_discount_percent, Liegeplatz).
func set_discount(discount_percent: Callable) -> void:
	_discount = discount_percent


## U.18: Ware in den Bestand (Produktion), höchstens so viel, wie Platz ist. Rückgabe: aufgenommen.
func add_stock(product_id: String, units: int) -> int:
	if units <= 0 or _products.get_definition(product_id) == null:
		return 0
	var room := units
	if _capacity.is_valid():
		room = mini(units, int(_capacity.call()) - total_stock() - incoming_units())
	if room <= 0:
		return 0
	_stock[product_id] = get_stock(product_id) + room
	stock_changed.emit()
	return room


## Einheiten, die noch unterwegs sind.
func incoming_units() -> int:
	var total := 0
	for order in _orders:
		if order["status"] == STATUS_PENDING:
			total += int(order["units"])
	return total


## Grund, wenn `units` mehr Einheiten nicht mehr ins Lager passen, sonst "".
func check_space(units: int) -> String:
	if not _capacity.is_valid():
		return ""
	var room: int = _capacity.call() - total_stock() - incoming_units()
	if units > room:
		return "Kein Platz: noch %d Einheit%s frei (Bestand + unterwegs)." % [maxi(room, 0), "" if room == 1 else "en"]
	return ""


## Liefert den Spiel-Seed (EventSystem.get_seed) – bei jedem Wurf neu gelesen, damit er nach dem Laden stimmt.
var _get_seed: Callable
## product_id -> Einheiten
var _stock := {}
var _orders: Array = []
var _next_number := 1
var _last_processed_day := 0
var _notices := PackedStringArray()
var _obligations
var _events
## Letzter Tag mit Druck-Ereignis (U.7)
var _last_pressure_day := 0
## Angekommene Lieferungen je Lieferant, deren Bestellung schon aus der Liste gefallen ist
var _delivered_before_trim := {}


func _init(time, ledger: LedgerSystemScript, suppliers: SupplierCatalogScript, products: ProductCatalogScript,
		missions, get_seed: Callable, obligations = null, events = null) -> void:
	_time = time
	_ledger = ledger
	_suppliers = suppliers
	_products = products
	_is_mission_completed = missions.is_completed
	_get_seed = get_seed
	_obligations = obligations
	_events = events
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


## U.9: nimmt Ware aus dem Bestand (Verkauf). false, wenn nicht genug da ist (dann unverändert).
func remove_stock(product_id: String, units: int) -> bool:
	if units < 1 or get_stock(product_id) < units:
		return false
	_stock[product_id] = get_stock(product_id) - units
	if _stock[product_id] == 0:
		_stock.erase(product_id)
	stock_changed.emit()
	return true


func total_stock() -> int:
	var total := 0
	for product_id in _stock:
		total += int(_stock[product_id])
	return total


## Offene Bestellungen (Kopien), älteste zuerst.
func get_pending_orders() -> Array:
	return _orders.filter(func(order) -> bool: return order["status"] == STATUS_PENDING).map(
			func(order) -> Dictionary: return order.duplicate())


## Gesamtpreis einer Bestellung (Cent) – U.18: abzüglich Rabatt eines eigenen Liegeplatzes.
@warning_ignore("integer_division")
func order_cost(product_id: String, units: int) -> int:
	var product = _products.get_definition(product_id)
	if product == null:
		return 0
	var cost: int = product.buy_price_cents * units
	var discount: int = int(_discount.call()) if _discount.is_valid() else 0
	return cost - cost * discount / 100


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
	var space := check_space(units)
	if not space.is_empty():
		return space
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
			"due_day": _time.get_day() + supplier.delivery_days, "status": STATUS_PENDING, "credit": false,
			"debt_cents": 0, "debt_due_day": 0, "debt_status": ""})
	return ""


# --- Kredit (U.7) ------------------------------------------------------------------

## Kreditbedingungen eines Lieferanten ({} = kein Kredit).
func credit_terms(supplier_id: String) -> Dictionary:
	var supplier = _suppliers.get_definition(supplier_id)
	return supplier.credit if supplier != null else {}


## Schulden für eine Kreditbestellung (Preis + Aufschlag), Cent.
@warning_ignore("integer_division")
func credit_cost(supplier_id: String, product_id: String, units: int) -> int:
	var cost := order_cost(product_id, units)
	return cost + cost * int(credit_terms(supplier_id).get("markup_percent", 0)) / 100


func count_delivered(supplier_id: String) -> int:
	return _orders.filter(func(order) -> bool: return order["supplier"] == supplier_id \
			and order["status"] == STATUS_DELIVERED).size() + int(_delivered_before_trim.get(supplier_id, 0))


## Offene Schulden bei einem Lieferanten: noch laufend (nicht fällig) oder als Frist offen. Liste von
## {"order_id", "amount_cents", "due_day", "overdue"}.
func get_debts(supplier_id: String = "") -> Array:
	var result := []
	for order in _orders:
		if not order.get("credit", false) or (not supplier_id.is_empty() and order["supplier"] != supplier_id):
			continue
		if order["debt_status"] == DEBT_RUNNING:
			result.append({"order_id": order["id"], "supplier": order["supplier"], "amount_cents": order["debt_cents"],
					"due_day": order["debt_due_day"], "overdue": false})
		elif order["debt_status"] == DEBT_HANDED and _obligations != null:
			var instance: Dictionary = _obligations.get_instance(_debt_instance_id(order["id"]))
			if not instance.is_empty() and instance["status"] == "open":
				result.append({"order_id": order["id"], "supplier": order["supplier"],
						"amount_cents": _obligations.open_amount(instance["id"]), "due_day": order["debt_due_day"],
						"overdue": true})
	return result


## "" wenn die Kreditbestellung jetzt möglich ist, sonst ein Grund.
func check_credit_order(supplier_id: String, product_id: String, units: int) -> String:
	var supplier = _suppliers.get_definition(supplier_id)
	if supplier == null:
		return "Unbekannter Lieferant: %s" % supplier_id
	var terms := credit_terms(supplier_id)
	if terms.is_empty():
		return "%s gibt keinen Kredit." % supplier.name
	if not is_unlocked(supplier_id):
		return "Diesen Lieferanten kennst du noch nicht."
	if count_delivered(supplier_id) < int(terms["after_deliveries"]):
		return "Kredit erst nach der ersten Lieferung."
	if not get_debts(supplier_id).is_empty():
		return "Erst die Schulden bei %s bezahlen." % supplier.name
	var product = _products.get_definition(product_id)
	if product == null or product_id not in supplier.products:
		return "%s hat das nicht." % supplier.name
	if units < supplier.min_units or units > int(terms["max_units"]):
		return "Auf Kredit %d–%d Einheiten." % [supplier.min_units, int(terms["max_units"])]
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	return check_space(units)


## Bestellt auf Kredit (keine Buchung jetzt). "" = bestellt.
func order_on_credit(supplier_id: String, product_id: String, units: int) -> String:
	var reason := check_credit_order(supplier_id, product_id, units)
	if not reason.is_empty():
		return reason
	var supplier = _suppliers.get_definition(supplier_id)
	var order_id := "order_%04d" % _next_number
	_next_number += 1
	_orders.append({"id": order_id, "supplier": supplier_id, "product": product_id, "units": units,
			"paid_cents": 0, "account": "", "ordered_minutes": _time.get_minutes(),
			"due_day": _time.get_day() + supplier.delivery_days, "status": STATUS_PENDING, "credit": true,
			"debt_cents": credit_cost(supplier_id, product_id, units),
			"debt_due_day": _time.get_day() + int(supplier.credit["due_days"]), "debt_status": DEBT_RUNNING})
	return ""


static func _debt_instance_id(order_id: String) -> String:
	return "debt_%s" % order_id


## Fällige Schulden werden Fristen; überfällige bringen Druck (höchstens ein Besuch je `pressure_every_days`).
@warning_ignore("integer_division")
func _process_debts(day: int) -> void:
	if _obligations == null:
		return
	for order in _orders:
		if not order.get("credit", false) or order["debt_status"] != DEBT_RUNNING or day < int(order["debt_due_day"]):
			continue
		var supplier = _suppliers.get_definition(order["supplier"])
		var product = _products.get_definition(order["product"])
		var terms: Dictionary = supplier.credit if supplier != null else {}
		var label := "Schulden bei %s (%d × %s)" % [supplier.name if supplier != null else order["supplier"],
				int(order["units"]), product.display_name if product != null else order["product"]]
		var fee := int(order["debt_cents"]) * int(terms.get("reminder_fee_percent", 0)) / 100
		_obligations.add_one_off(_debt_instance_id(order["id"]), label, int(order["debt_cents"]),
				LedgerSystemScript.BLACK, DEBT_CATEGORY, int(terms.get("grace_days", 0)), fee,
				TimeSystemScript.at(int(order["debt_due_day"]), 0))
		order["debt_status"] = DEBT_HANDED
	if _events == null or day <= _last_pressure_day:
		return
	for debt in get_debts():
		var supplier = _suppliers.get_definition(debt["supplier"])
		if supplier == null or supplier.credit.is_empty() or not debt["overdue"]:
			continue
		var terms: Dictionary = supplier.credit
		if day <= int(debt["due_day"]) + int(terms["grace_days"]):
			continue
		if _last_pressure_day > 0 and day - _last_pressure_day < int(terms["pressure_every_days"]):
			continue
		if not _events.trigger_scripted(terms["pressure_event"], day).is_empty():
			_last_pressure_day = day
		return


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
			if order.get("credit", false):
				order["debt_status"] = DEBT_CANCELLED
				_notices.append("Lieferung geplatzt: %s meldet sich nicht – die Schulden entfallen." % supplier_name)
			else:
				_notices.append("Lieferung geplatzt: %s meldet sich nicht – %s sind weg." % [supplier_name,
						LedgerSystemScript.format_cents(int(order["paid_cents"]))])
			order_finished.emit(order["id"], false)
		else:
			order["status"] = STATUS_DELIVERED
			_stock[order["product"]] = get_stock(order["product"]) + int(order["units"])
			_notices.append("Lieferung von %s: %d × %s ist da." % [supplier_name, int(order["units"]), product_name])
			changed = true
			order_finished.emit(order["id"], true)
	_process_debts(day)
	_trim_history()
	if changed:
		stock_changed.emit()


## 0–99, fest je Spiel-Seed und Bestellung.
func roll(order_id: String) -> int:
	return EventSystemScript.fnv1a("%d:%s" % [_get_seed.call(), order_id]) % 100


## Alte, ganz erledigte Bestellungen fallen weg (keine laufende Schuld); angekommene werden je Lieferant mitgezählt
## (Freischaltung des Kredits).
func _trim_history() -> void:
	while _orders.size() > HISTORY_LIMIT:
		var index := -1
		for i in _orders.size():
			var order: Dictionary = _orders[i]
			if order["status"] != STATUS_PENDING and order.get("debt_status", "") != DEBT_RUNNING \
					and (order.get("debt_status", "") != DEBT_HANDED or get_debts().filter(
					func(debt) -> bool: return debt["order_id"] == order["id"]).is_empty()):
				index = i
				break
		if index < 0:
			return
		if _orders[index]["status"] == STATUS_DELIVERED:
			var supplier: String = _orders[index]["supplier"]
			_delivered_before_trim[supplier] = int(_delivered_before_trim.get(supplier, 0)) + 1
		_orders.remove_at(index)


func to_dict() -> Dictionary:
	var stock := {}
	for product_id in _stock:
		stock[product_id] = int(_stock[product_id])
	var orders := []
	for order in _orders:
		orders.append(order.duplicate())
	return {"stock": stock, "orders": orders, "next_number": _next_number, "last_processed_day": _last_processed_day,
			"last_pressure_day": _last_pressure_day, "delivered_before_trim": _delivered_before_trim.duplicate()}


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
		if typeof(raw.get("credit")) != TYPE_BOOL or typeof(raw.get("debt_status")) != TYPE_STRING \
				or raw["debt_status"] not in ["", DEBT_RUNNING, DEBT_HANDED, DEBT_CANCELLED]:
			return "Bestellung: Kreditangaben fehlen."
		for key in ["debt_cents", "debt_due_day"]:
			if not DataReaderScript.is_whole_number(raw.get(key)) or int(raw[key]) < 0:
				return "Bestellung: '%s' fehlt oder ist ungültig." % key
		var order: Dictionary = raw.duplicate()
		for key in ["units", "paid_cents", "ordered_minutes", "due_day", "debt_cents", "debt_due_day"]:
			order[key] = int(order[key])
		orders.append(order)
	for key in ["next_number", "last_processed_day", "last_pressure_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Lieferungen: '%s' fehlt oder ist ungültig." % key
	var raw_trimmed: Variant = data.get("delivered_before_trim")
	if typeof(raw_trimmed) != TYPE_DICTIONARY:
		return "Lieferungen: 'delivered_before_trim' fehlt."
	var trimmed := {}
	for supplier in raw_trimmed:
		if typeof(supplier) != TYPE_STRING or not DataReaderScript.is_whole_number(raw_trimmed[supplier]):
			return "Lieferungen: 'delivered_before_trim' ungültig."
		trimmed[supplier] = int(raw_trimmed[supplier])
	# Ältere Bestellungen können gekürzt sein – die Nummer muss nur größer als jede vorhandene sein.
	for order in orders:
		if int(String(order["id"]).trim_prefix("order_")) >= int(data["next_number"]):
			return "Lieferungen: 'next_number' passt nicht zu den Bestellungen."
	_stock = stock
	_orders = orders
	_next_number = int(data["next_number"])
	_last_processed_day = int(data["last_processed_day"])
	_last_pressure_day = int(data["last_pressure_day"])
	_delivered_before_trim = trimmed
	_notices.clear()
	return ""

