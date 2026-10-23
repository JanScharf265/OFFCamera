extends RefCounted

## Lädt und prüft die Standorte der Unterwelt (U.8, data/underworld/sites.json) – Felder nach Leitfaden 9.3.
## Alles-oder-nichts wie die anderen Kataloge.
##
## Format je Standort (alle Felder Pflicht, andere sind ein Fehler):
##   id, display_name, type (einer aus TYPES), location (Orts-ID), description (≤ 200 Zeichen),
##   unlocked_by_mission (Auftrags-ID), start_cost_cents ≥ 0, running_cost_per_day_cents ≥ 0, setup_minutes ≥ 0,
##   capacity_units ≥ 0, staff_slots ≥ 0, productivity_per_day ≥ 0, risk 0–100, activities [IDs], requires [Standort-IDs]
##   U.18: product (Produkt-ID der Produktion, sonst ""), sale_units_per_day ≥ 0 (Verkaufspunkt/Club),
##   laundering_limit_cents ≥ 0 (Club als Tarnfirma: mehr Waschlimit), supplier_discount_percent 0–100 (Liegeplatz),
##   max_level ≥ 1, upgrade_cost_cents ≥ 0 (je Stufe × aktuelle Stufe), upgrade_percent ≥ 0 (Wirkung und laufende
##   Kosten je weiterer Stufe)
## Verweise (Ort, Auftrag, requires) prüft GameData.check_references().

const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/sites.json"
## Standorttypen (Vision 3): Versteck, Lager, Verkaufspunkt, Club, Produktion, Liegeplatz am Hafen
const TYPES := ["stash", "storage", "sales_point", "club", "production", "berth"]
const TYPE_LABELS := {"stash": "Versteck", "storage": "Lager", "sales_point": "Verkaufspunkt", "club": "Club",
		"production": "Produktion", "berth": "Liegeplatz"}
const INT_FIELDS := ["start_cost_cents", "running_cost_per_day_cents", "setup_minutes", "capacity_units", "staff_slots",
		"productivity_per_day", "risk", "sale_units_per_day", "laundering_limit_cents", "supplier_discount_percent",
		"max_level", "upgrade_cost_cents", "upgrade_percent"]
const FIELDS := ["id", "display_name", "type", "location", "description", "unlocked_by_mission", "activities",
		"requires", "product"] + INT_FIELDS


## Ein Standort (nur Daten).
class Site extends RefCounted:
	var id: String
	var display_name: String
	var type: String
	var location: String
	var description: String
	var unlocked_by_mission: String
	var start_cost_cents: int
	var running_cost_per_day_cents: int
	var setup_minutes: int
	var capacity_units: int
	var staff_slots: int
	var productivity_per_day: int
	var risk: int
	var activities: PackedStringArray
	var requires: PackedStringArray
	var product: String
	var sale_units_per_day: int
	var laundering_limit_cents: int
	var supplier_discount_percent: int
	var max_level: int
	var upgrade_cost_cents: int
	var upgrade_percent: int


var errors: PackedStringArray = []

var _definitions: Array = []


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		_definitions.clear()
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_definitions.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Standortdaten müssen eine Liste sein."])
		return false
	var definitions: Array = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Standort '%s': ID kommt doppelt vor." % definition.id)
			continue
		seen[definition.id] = true
		definitions.append(definition)
	errors = reader.errors
	if not errors.is_empty():
		return false
	_definitions = definitions
	return true


func get_all() -> Array:
	return _definitions.duplicate()


func get_definition(id: String):
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func has(id: String) -> bool:
	return get_definition(id) != null


## Standorte an einem Ort.
func get_at(location_id: String) -> Array:
	return _definitions.filter(func(site) -> bool: return site.location == location_id)


func _parse(reader: DataReaderScript, entry: Variant, index: int):
	var where := "Standort #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Standort '%s'" % id
	for key in entry:
		if String(key) not in FIELDS:
			reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
	var site := Site.new()
	site.id = id
	for field in ["display_name", "type", "location", "description", "unlocked_by_mission"]:
		site.set(field, reader.string_field(entry, field, where, true))
	if not site.type.is_empty() and site.type not in TYPES:
		reader.errors.append("%s: unbekannter Typ '%s'." % [where, site.type])
	if site.description.length() > 200:
		reader.errors.append("%s: 'description' ist zu lang." % where)
	for field in INT_FIELDS:
		var value := reader.int_field(entry, field, where, true)
		if value < 0:
			reader.errors.append("%s: '%s' darf nicht negativ sein." % [where, field])
		site.set(field, value)
	if site.risk > 100 or site.supplier_discount_percent > 100:
		reader.errors.append("%s: 'risk' und 'supplier_discount_percent' müssen zwischen 0 und 100 liegen." % where)
	if site.max_level < 1:
		reader.errors.append("%s: 'max_level' muss ≥ 1 sein." % where)
	if typeof(entry.get("product")) != TYPE_STRING:
		reader.errors.append("%s: 'product' fehlt (\"\" ohne Produktion)." % where)
	else:
		site.product = entry["product"]
	if site.productivity_per_day > 0 and site.product.is_empty():
		reader.errors.append("%s: Produktion ohne 'product'." % where)
	for field in ["activities", "requires"]:
		var raw: Variant = entry.get(field)
		if typeof(raw) != TYPE_ARRAY:
			reader.errors.append("%s: '%s' fehlt oder ist keine Liste." % [where, field])
			continue
		var items := PackedStringArray()
		for item in raw:
			if typeof(item) != TYPE_STRING or item.is_empty():
				reader.errors.append("%s: ungültiger Eintrag in '%s'." % [where, field])
			else:
				items.append(item)
		site.set(field, items)
	return site if reader.errors.size() == error_count else null
