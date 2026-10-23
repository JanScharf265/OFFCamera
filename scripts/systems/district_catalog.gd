extends RefCounted

## Gebiete (U.12): Viertel der Stadt als Daten (data/underworld/districts.json) – Fläche auf dem Kartenraster
## (`area` = [x0, y0, x1, y1], Zellen einschließlich), Farbe für die Unterwelt-Ansicht und die Werte Nachfrage,
## Polizeipräsenz, Einfluss der Rivalen (je 0–100). Übernehmen, halten, verlieren folgt mit U.13. Flächen dürfen
## sich nicht überschneiden. Alles-oder-nichts.

const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/districts.json"
const FIELDS := ["id", "display_name", "description", "area", "label_cell", "color", "demand", "police", "rivals"]
const VALUE_KEYS := ["demand", "police", "rivals"]
const VALUE_LABELS := {"demand": "Nachfrage", "police": "Polizei", "rivals": "Rivalen"}
## Rasterbereich der Stadt (wie CityLayout: 15 Spalten, Land bis zur Promenade in Zeile 13)
const GRID_MAX := Vector2i(14, 13)


## Ein Gebiet (nur Daten).
class District extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	## Zellen einschließlich: position = (x0, y0), end = (x1 + 1, y1 + 1)
	var area: Rect2i
	## Zelle für das Namensschild (innerhalb der Fläche, frei von Ortsschildern)
	var label_cell: Vector2i
	var color: Color
	var demand: int
	var police: int
	var rivals: int

	func has_cell(cell: Vector2i) -> bool:
		return area.has_point(cell)


var errors: PackedStringArray = []
var _districts: Array = []


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		_districts.clear()
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_districts.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Gebiete müssen eine Liste sein."])
		return false
	var districts: Array = []
	var seen := {}
	for i in data.size():
		var entry: Variant = data[i]
		var where := "Gebiet #%d" % (i + 1)
		if typeof(entry) != TYPE_DICTIONARY:
			reader.errors.append("%s: muss ein Objekt sein." % where)
			continue
		var error_count := reader.errors.size()
		var id := reader.id_field(entry, where)
		if id.is_empty():
			continue
		where = "Gebiet '%s'" % id
		for key in entry:
			if String(key) not in FIELDS:
				reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
		var district := District.new()
		district.id = id
		district.display_name = reader.string_field(entry, "display_name", where, true)
		district.description = reader.string_field(entry, "description", where, true)
		for key in VALUE_KEYS:
			var value := reader.int_field(entry, key, where, true)
			if value < 0 or value > 100:
				reader.errors.append("%s: '%s' muss 0–100 sein." % [where, key])
			district.set(key, value)
		var color_text := reader.string_field(entry, "color", where, true)
		if not color_text.is_empty() and not Color.html_is_valid(color_text):
			reader.errors.append("%s: Farbe '%s' ungültig." % [where, color_text])
		else:
			district.color = Color.html(color_text) if not color_text.is_empty() else Color.WHITE
		var area: Variant = entry.get("area")
		if typeof(area) != TYPE_ARRAY or area.size() != 4 \
				or area.any(func(value) -> bool: return not DataReaderScript.is_whole_number(value)):
			reader.errors.append("%s: 'area' muss [x0, y0, x1, y1] sein." % where)
		else:
			var x0 := int(area[0])
			var y0 := int(area[1])
			var x1 := int(area[2])
			var y1 := int(area[3])
			if x0 < 0 or y0 < 0 or x1 < x0 or y1 < y0 or x1 > GRID_MAX.x or y1 > GRID_MAX.y:
				reader.errors.append("%s: 'area' liegt außerhalb der Stadt." % where)
			district.area = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
		var label: Variant = entry.get("label_cell")
		if typeof(label) != TYPE_ARRAY or label.size() != 2 \
				or label.any(func(value) -> bool: return not DataReaderScript.is_whole_number(value)):
			reader.errors.append("%s: 'label_cell' muss [x, y] sein." % where)
		else:
			district.label_cell = Vector2i(int(label[0]), int(label[1]))
			if not district.area.has_point(district.label_cell):
				reader.errors.append("%s: 'label_cell' liegt nicht im Gebiet." % where)
		if seen.has(id):
			reader.errors.append("%s: ID kommt doppelt vor." % where)
		if reader.errors.size() == error_count:
			for other in districts:
				if other.area.intersects(district.area):
					reader.errors.append("%s: überschneidet sich mit '%s'." % [where, other.id])
			seen[id] = true
			districts.append(district)
	errors = reader.errors
	if not errors.is_empty():
		return false
	_districts = districts
	return true


func get_all() -> Array:
	return _districts.duplicate()


func get_definition(id: String):
	for district in _districts:
		if district.id == id:
			return district
	return null


## Gebiet an einer Rasterzelle (oder null).
func get_at(cell: Vector2i):
	for district in _districts:
		if district.has_cell(cell):
			return district
	return null
