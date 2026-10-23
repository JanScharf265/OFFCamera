extends RefCounted

## Standorte der Unterwelt (U.8): Sobald ihr Freischalt-Auftrag erledigt ist, kann man einen Standort vor Ort
## anmieten (Startkosten als Buchung, dauert `setup_minutes` Spielzeit). Danach kostet er jeden Tag
## `running_cost_per_day_cents` (Schritt im DayCycle): bezahlt aus Schwarzgeld, ersatzweise vom Privatkonto – reicht
## beides nicht, wird es eine einmalige Frist. Eigene Standorte erhöhen die Lager-Kapazität für Ware (Grundplatz
## BASE_CAPACITY ohne Versteck). Reine Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const SiteCatalogScript := preload("res://scripts/systems/site_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal site_acquired(site_id: String)

## Platz für Ware ohne eigenen Standort (Kofferraum, Wohnung)
const BASE_CAPACITY := 20
const CATEGORY := "underworld_site"
## U.18: Einnahmen der Verkaufspunkte und Clubs
const SALES_CATEGORY := "underworld_site_sales"
const SOURCE := "site"

var _time
var _ledger: LedgerSystemScript
var _locations
var _catalog: SiteCatalogScript
var _obligations
var _is_mission_completed: Callable
## site_id -> Zeitpunkt der Anmietung (Minuten)
var _owned := {}
var _last_processed_day := 0
var _notices := PackedStringArray()
## U.18: Stufe je eigenem Standort (fehlt = 1); Ware und Organisation für Produktion und Verkauf
var _levels := {}
var _supply
var _organisation


func _init(time, ledger: LedgerSystemScript, locations, catalog: SiteCatalogScript, obligations,
		is_mission_completed: Callable) -> void:
	_time = time
	_ledger = ledger
	_locations = locations
	_catalog = catalog
	_obligations = obligations
	_is_mission_completed = is_mission_completed
	_last_processed_day = time.get_day()


func get_catalog() -> SiteCatalogScript:
	return _catalog


func is_owned(site_id: String) -> bool:
	return _owned.has(site_id)


func is_unlocked(site_id: String) -> bool:
	var site = _catalog.get_definition(site_id)
	return site != null and _is_mission_completed.call(site.unlocked_by_mission)


## Eigene Standorte (Daten), in Katalogreihenfolge.
func get_owned() -> Array:
	return _catalog.get_all().filter(func(site) -> bool: return _owned.has(site.id))


func owns_type(site_type: String) -> bool:
	return not get_owned().filter(func(site) -> bool: return site.type == site_type).is_empty()


## Lager-Kapazität für Ware: Grundplatz + Kapazität aller eigenen Standorte.
func capacity() -> int:
	var total := BASE_CAPACITY
	for site in get_owned():
		total += int(effects(site.id)["capacity"])
	return total


## Konto für eine Zahlung: Schwarzgeld, wenn es reicht, sonst Privatkonto.
func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## "" wenn der Standort jetzt angemietet werden kann, sonst ein Grund.
func check_acquire(site_id: String) -> String:
	var site = _catalog.get_definition(site_id)
	if site == null:
		return "Unbekannter Standort: %s" % site_id
	if _owned.has(site_id):
		return "Gehört schon dir."
	if not is_unlocked(site_id):
		return "Diesen Standort kennst du noch nicht."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if _locations.get_current() != site.location:
		var location = _locations.get_catalog().get_definition(site.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else site.location)
	for required in site.requires:
		if not _owned.has(required):
			return "Erst „%s“ anmieten." % _catalog.get_definition(required).display_name
	if not _ledger.can_afford(site.start_cost_cents, payment_account(site.start_cost_cents)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(site.start_cost_cents)
	return ""


## Mietet an: Buchung → Besitz → Zeit. "" = angemietet.
func acquire(site_id: String) -> String:
	var reason := check_acquire(site_id)
	if not reason.is_empty():
		return reason
	var site = _catalog.get_definition(site_id)
	if site.start_cost_cents > 0:
		var entry := _ledger.post(-site.start_cost_cents, CATEGORY, "Anmieten: %s" % site.display_name, SOURCE, site_id,
				"site:%s:start" % site_id, false, payment_account(site.start_cost_cents))
		if entry == null:
			push_error("SiteSystem: Startkosten für '%s' trotz Prüfung abgelehnt." % site_id)
			return "Die Buchung ist fehlgeschlagen."
	_owned[site_id] = _time.get_minutes()
	site_acquired.emit(site_id)
	if site.setup_minutes > 0:
		_time.advance(site.setup_minutes)
	return ""


## Hinweise (laufende Kosten) seit dem letzten Aufruf.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle: laufende Kosten je eigenem Standort für den neuen Tag.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	_work(day)
	for site in get_owned():
		var cost: int = int(effects(site.id)["running"])
		if cost <= 0:
			continue
		var account := payment_account(cost)
		var label := "Kosten %s (Tag %d)" % [site.display_name, day]
		if _ledger.can_afford(cost, account):
			_ledger.post(-cost, CATEGORY, label, SOURCE, site.id, "site:%s:day:%d" % [site.id, day], false, account,
					TimeSystemScript.at(day, 0))
		elif _obligations != null:
			_obligations.add_one_off("site_%s@%d" % [site.id, day], label, cost, LedgerSystemScript.BLACK, CATEGORY, 2,
					0, TimeSystemScript.at(day, 0))
			_notices.append("%s: Das Geld reicht nicht – offen unter „Fristen“." % label)


# --- U.18: Stufen, Wirkungen, tägliche Produktion und Verkauf -------------------------

## Vom GameState (U.18): Ware und Organisation für Produktion und Verkaufspunkte.
func set_underworld(supply, organisation) -> void:
	_supply = supply
	_organisation = organisation


func get_level(site_id: String) -> int:
	return int(_levels.get(site_id, 1)) if _owned.has(site_id) else 0


## Wert eines Standorts auf seiner Stufe: Stufe 1 = Datenwert, jede weitere + upgrade_percent.
@warning_ignore("integer_division")
func scaled(site, value: int, level: int = -1) -> int:
	var at := level if level > 0 else maxi(1, get_level(site.id))
	return value * (100 + (at - 1) * site.upgrade_percent) / 100


## Wirkungen eines Standorts auf seiner (oder einer gegebenen) Stufe – für Anzeige und Regeln.
func effects(site_id: String, level: int = -1) -> Dictionary:
	var site = _catalog.get_definition(site_id)
	if site == null:
		return {}
	return {"capacity": scaled(site, site.capacity_units, level), "production": scaled(site, site.productivity_per_day, level),
			"sales": scaled(site, site.sale_units_per_day, level), "laundering": scaled(site, site.laundering_limit_cents, level),
			"discount": mini(100, scaled(site, site.supplier_discount_percent, level)),
			"running": scaled(site, site.running_cost_per_day_cents, level)}


## Mehr Waschlimit durch eigene Clubs (Cent je Tag) – vom LaunderingSystem.
func laundering_bonus() -> int:
	var total := 0
	for site in get_owned():
		total += int(effects(site.id)["laundering"])
	return total


## Rabatt beim Lieferanten (Prozent, höchster eigener Liegeplatz) – vom SupplySystem.
func supplier_discount_percent() -> int:
	var best := 0
	for site in get_owned():
		best = maxi(best, int(effects(site.id)["discount"]))
	return best


func upgrade_cost(site_id: String) -> int:
	var site = _catalog.get_definition(site_id)
	return site.upgrade_cost_cents * get_level(site_id) if site != null else 0


## "" wenn der Standort jetzt ausgebaut werden kann, sonst ein Grund.
func check_upgrade(site_id: String) -> String:
	var site = _catalog.get_definition(site_id)
	if site == null:
		return "Unbekannter Standort: %s" % site_id
	if not _owned.has(site_id):
		return "Erst anmieten."
	if get_level(site_id) >= site.max_level:
		return "Voll ausgebaut (Stufe %d)." % site.max_level
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if _locations.get_current() != site.location:
		var location = _locations.get_catalog().get_definition(site.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else site.location)
	var cost := upgrade_cost(site_id)
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Baut aus: Buchung → Stufe → Zeit (wie beim Anmieten). "" = ausgebaut.
func upgrade(site_id: String) -> String:
	var reason := check_upgrade(site_id)
	if not reason.is_empty():
		return reason
	var site = _catalog.get_definition(site_id)
	var cost := upgrade_cost(site_id)
	var level := get_level(site_id) + 1
	if cost > 0:
		var entry := _ledger.post(-cost, CATEGORY, "Ausbau: %s (Stufe %d)" % [site.display_name, level], SOURCE, site_id,
				"site:%s:level:%d" % [site_id, level], false, payment_account(cost))
		if entry == null:
			return "Die Buchung ist fehlgeschlagen."
	_levels[site_id] = level
	if site.setup_minutes > 0:
		_time.advance(site.setup_minutes)
	return ""


## Tageswechsel: Produktion (in den Bestand, soweit Platz ist) und Verkaufspunkte (aus dem Bestand → Schwarzgeld, Hitze).
func _work(day: int) -> void:
	if _supply == null:
		return
	for site in get_owned():
		var effect := effects(site.id)
		if int(effect["production"]) > 0 and not site.product.is_empty():
			var added: int = _supply.add_stock(site.product, int(effect["production"]))
			var product = _supply.get_products().get_definition(site.product)
			var name: String = product.display_name if product != null else site.product
			if added > 0:
				_notices.append("%s: %d × %s produziert." % [site.display_name, added, name])
			else:
				_notices.append("%s: kein Platz für die Ernte – Lager voll." % site.display_name)
		if int(effect["sales"]) > 0:
			_sell_from(site, int(effect["sales"]), day)


@warning_ignore("integer_division")
func _sell_from(site, units_wanted: int, day: int) -> void:
	var units_total := 0
	var income := 0
	var heat := 0
	for product in _supply.get_products().get_all():
		var units := mini(units_wanted - units_total, _supply.get_stock(product.id))
		if units <= 0 or not _supply.remove_stock(product.id, units):
			continue
		units_total += units
		income += product.sell_price_cents * units
		heat += product.heat_per_unit * units
	if units_total == 0:
		_notices.append("%s: keine Ware zum Verkaufen." % site.display_name)
		return
	_ledger.post(income, SALES_CATEGORY, "%s: Verkauf (Tag %d, %d Einheiten)" % [site.display_name, day - 1, units_total],
			SOURCE, site.id, "site:%s:sales:%d" % [site.id, day], false, LedgerSystemScript.BLACK, TimeSystemScript.at(day, 0))
	if heat > 0 and _organisation != null:
		_organisation.change({"heat": heat})
	_notices.append("%s: %d Einheiten verkauft (+%s Schwarzgeld, Hitze +%d)." % [site.display_name, units_total,
			LedgerSystemScript.format_cents(income), heat])


func to_dict() -> Dictionary:
	var owned := {}
	for id in _owned:
		owned[id] = _owned[id]
	return {"owned": owned, "levels": _levels.duplicate(), "last_processed_day": _last_processed_day}


## Unbekannte IDs (Standort aus den Daten entfernt) bleiben erhalten. "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var raw: Variant = data.get("owned")
	if typeof(raw) != TYPE_DICTIONARY:
		return "Standorte: 'owned' fehlt oder ist kein Objekt."
	var owned := {}
	for id in raw:
		if typeof(id) != TYPE_STRING or not DataReaderScript.is_whole_number(raw[id]) or int(raw[id]) < 0:
			return "Standorte: ungültiger Eintrag in 'owned'."
		owned[id] = int(raw[id])
	if not DataReaderScript.is_whole_number(data.get("last_processed_day")) or int(data["last_processed_day"]) < 0:
		return "Standorte: 'last_processed_day' fehlt oder ist ungültig."
	var raw_levels: Variant = data.get("levels")
	if typeof(raw_levels) != TYPE_DICTIONARY:
		return "Standorte: 'levels' fehlt oder ist kein Objekt."
	var levels := {}
	for id in raw_levels:
		if typeof(id) != TYPE_STRING or not DataReaderScript.is_whole_number(raw_levels[id]) or int(raw_levels[id]) < 1:
			return "Standorte: ungültige Stufe für '%s'." % id
		levels[id] = int(raw_levels[id])
	_levels = levels
	_owned = owned
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
