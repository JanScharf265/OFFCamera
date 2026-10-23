extends RefCounted

## Lädt und prüft die erfundenen Lieferanten (U.6, data/underworld/suppliers.json). Alles-oder-nichts.
##
## Format je Lieferant (alle Felder Pflicht, andere sind ein Fehler):
##   id, name, description (≤ 160 Zeichen), products [Produkt-IDs, nicht leer], min_units ≥ 1,
##   max_units ≥ min_units, delivery_days ≥ 1, failure_percent 0–100, unlocked_by_mission (Auftrags-ID),
##   credit (optional, U.7) {after_deliveries ≥ 0, max_units ≥ 1, markup_percent 0–200, due_days ≥ 1, grace_days ≥ 0,
##     reminder_fee_percent 0–100, pressure_event (Ereignis-ID, „scripted“), pressure_every_days ≥ 1}
## Verweise auf Produkte und Aufträge prüft GameData.check_references().

const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/suppliers.json"
const FIELDS := ["id", "name", "description", "products", "min_units", "max_units", "delivery_days",
		"failure_percent", "unlocked_by_mission", "credit"]
const CREDIT_INT_FIELDS := {"after_deliveries": 0, "max_units": 1, "markup_percent": 0, "due_days": 1, "grace_days": 0,
		"reminder_fee_percent": 0, "pressure_every_days": 1}


## Ein Lieferant (nur Daten).
class Supplier extends RefCounted:
	var id: String
	var name: String
	var description: String
	var products: PackedStringArray
	var min_units: int
	var max_units: int
	var delivery_days: int
	var failure_percent: int
	var unlocked_by_mission: String
	## Kredit (U.7); leer = kein Kredit. Felder siehe Kopf.
	var credit: Dictionary = {}


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
		errors = PackedStringArray(["Lieferantendaten müssen eine Liste sein."])
		return false
	var definitions: Array = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Lieferant '%s': ID kommt doppelt vor." % definition.id)
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


func _parse(reader: DataReaderScript, entry: Variant, index: int):
	var where := "Lieferant #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Lieferant '%s'" % id
	for key in entry:
		if String(key) not in FIELDS:
			reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
	var definition := Supplier.new()
	definition.id = id
	definition.name = reader.string_field(entry, "name", where, true)
	definition.description = reader.string_field(entry, "description", where, true)
	if definition.description.length() > 160:
		reader.errors.append("%s: 'description' ist zu lang." % where)
	var products: Variant = entry.get("products")
	if typeof(products) != TYPE_ARRAY or products.is_empty():
		reader.errors.append("%s: 'products' muss eine nicht-leere Liste sein." % where)
	else:
		for product in products:
			if typeof(product) != TYPE_STRING or product.is_empty() or product in definition.products:
				reader.errors.append("%s: ungültiges oder doppeltes Produkt in 'products'." % where)
			else:
				definition.products.append(product)
	definition.min_units = reader.int_field(entry, "min_units", where, true)
	definition.max_units = reader.int_field(entry, "max_units", where, true)
	definition.delivery_days = reader.int_field(entry, "delivery_days", where, true)
	definition.failure_percent = reader.int_field(entry, "failure_percent", where, true)
	definition.unlocked_by_mission = reader.string_field(entry, "unlocked_by_mission", where, true)
	var credit: Variant = entry.get("credit")
	if credit != null:
		if typeof(credit) != TYPE_DICTIONARY:
			reader.errors.append("%s: 'credit' muss ein Objekt sein." % where)
		else:
			for key in credit:
				if key not in CREDIT_INT_FIELDS and key != "pressure_event":
					reader.errors.append("%s: unbekanntes Feld 'credit.%s'." % [where, key])
			for key in CREDIT_INT_FIELDS:
				var value: Variant = credit.get(key)
				if not DataReaderScript.is_whole_number(value) or int(value) < CREDIT_INT_FIELDS[key]:
					reader.errors.append("%s: 'credit.%s' fehlt oder ist zu klein." % [where, key])
				else:
					definition.credit[key] = int(value)
			if int(credit.get("markup_percent", 0)) > 200 or int(credit.get("reminder_fee_percent", 0)) > 100:
				reader.errors.append("%s: Kredit-Aufschlag oder Mahnaufschlag zu hoch." % where)
			if typeof(credit.get("pressure_event")) != TYPE_STRING or String(credit["pressure_event"]).is_empty():
				reader.errors.append("%s: 'credit.pressure_event' fehlt." % where)
			else:
				definition.credit["pressure_event"] = credit["pressure_event"]
	if reader.errors.size() == error_count:
		if definition.min_units < 1 or definition.max_units < definition.min_units:
			reader.errors.append("%s: Mengen ungültig (1 ≤ min_units ≤ max_units)." % where)
		if definition.delivery_days < 1:
			reader.errors.append("%s: 'delivery_days' muss mindestens 1 sein." % where)
		if definition.failure_percent < 0 or definition.failure_percent > 100:
			reader.errors.append("%s: 'failure_percent' muss zwischen 0 und 100 liegen." % where)
	return definition if reader.errors.size() == error_count else null
