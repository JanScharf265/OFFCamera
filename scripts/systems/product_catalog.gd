extends RefCounted

## Lädt und prüft die Produkte der Unterwelt (U.5, data/underworld/products.json). Alles-oder-nichts wie die anderen
## Kataloge. Nur Spielwerte je abstrakter „Einheit“ – Inhaltsgrenze: keine Herstellung, keine echten Mengen.
##
## Format je Produkt (alle Felder Pflicht, andere sind ein Fehler):
##   id, display_name, description (≤ MAX_TEXT_LENGTH), buy_price_cents > 0, sell_price_cents > buy_price_cents,
##   quality 0–100, heat_per_unit 1–MAX_HEAT_PER_UNIT, order ≥ 0

const ProductDefinitionScript := preload("res://scripts/models/product_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/products.json"
const FIELDS := ["id", "display_name", "description", "buy_price_cents", "sell_price_cents", "quality",
		"heat_per_unit", "order"]
const MAX_TEXT_LENGTH := 160
const MAX_HEAT_PER_UNIT := 20

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
		errors = PackedStringArray(["Produktdaten müssen eine Liste sein."])
		return false
	var definitions: Array = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Produkt '%s': ID kommt doppelt vor." % definition.id)
			continue
		seen[definition.id] = true
		definitions.append(definition)
	errors = reader.errors
	if not errors.is_empty():
		return false
	definitions.sort_custom(func(a, b) -> bool: return a.order < b.order or (a.order == b.order and a.id < b.id))
	_definitions = definitions
	return true


## Alle Produkte, sortiert nach order (Kopie).
func get_all() -> Array:
	return _definitions.duplicate()


func get_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for definition in _definitions:
		ids.append(definition.id)
	return ids


func get_definition(id: String):
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func has(id: String) -> bool:
	return get_definition(id) != null


func _parse(reader: DataReaderScript, entry: Variant, index: int):
	var where := "Produkt #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Produkt '%s'" % id
	for key in entry:
		if String(key) not in FIELDS:
			reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
	var definition := ProductDefinitionScript.new()
	definition.id = id
	definition.display_name = reader.string_field(entry, "display_name", where, true)
	definition.description = reader.string_field(entry, "description", where, true)
	if definition.description.length() > MAX_TEXT_LENGTH:
		reader.errors.append("%s: 'description' ist zu lang (höchstens %d Zeichen)." % [where, MAX_TEXT_LENGTH])
	definition.buy_price_cents = reader.int_field(entry, "buy_price_cents", where, true)
	definition.sell_price_cents = reader.int_field(entry, "sell_price_cents", where, true)
	definition.quality = reader.int_field(entry, "quality", where, true)
	definition.heat_per_unit = reader.int_field(entry, "heat_per_unit", where, true)
	definition.order = reader.int_field(entry, "order", where, true)
	if reader.errors.size() == error_count:
		if definition.buy_price_cents <= 0:
			reader.errors.append("%s: 'buy_price_cents' muss größer als 0 sein." % where)
		if definition.sell_price_cents <= definition.buy_price_cents:
			reader.errors.append("%s: 'sell_price_cents' muss über dem Einkaufspreis liegen." % where)
		if definition.quality < 0 or definition.quality > 100:
			reader.errors.append("%s: 'quality' muss zwischen 0 und 100 liegen." % where)
		if definition.heat_per_unit < 1 or definition.heat_per_unit > MAX_HEAT_PER_UNIT:
			reader.errors.append("%s: 'heat_per_unit' muss zwischen 1 und %d liegen." % [where, MAX_HEAT_PER_UNIT])
		if definition.order < 0:
			reader.errors.append("%s: 'order' darf nicht negativ sein." % where)
	return definition if reader.errors.size() == error_count else null
