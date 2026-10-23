extends RefCounted

## Lädt und prüft Tutorials (T.1, JSON). Alles-oder-nichts wie die anderen Kataloge: Bei einem Fehler wird nichts
## geladen, `errors` beschreibt alles.
##
## Format je Eintrag (alle Felder Pflicht, andere Felder sind ein Fehler):
##   id         stabile ID (a–z, 0–9, _), z. B. "tut_map_tap_building"
##   mechanic   ID der erklärten Mechanik (a–z, 0–9, _) – für den Abdeckungstest (T.7)
##   trigger    eine ID aus TRIGGERS
##   title      kurzer Titel
##   text       kurzer Lesetext (höchstens MAX_TEXT_LENGTH Zeichen, etwa 2–3 Sätze)
##   ui_target  stabile UI-ID (Knotenname, A–Z, a–z, 0–9, _) des hervorgehobenen Elements, "" = keins;
##              „*“ als Platzhalter (T.5): das erste sichtbare passende Element, z. B. „Tile_*“
##   order      ganze Zahl ≥ 0, Reihenfolge bei mehreren gleichzeitig fälligen (kleiner zuerst)
##   requires   Liste von Tutorial-IDs, die vorher gesehen sein müssen (darf leer sein; keine Zyklen)
## Noch nicht in GameData eingebunden – das TutorialSystem (T.2) lädt den Katalog.

const TutorialDefinitionScript := preload("res://scripts/models/tutorial_definition.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/tutorials/tutorials.json"
const FIELDS := ["id", "mechanic", "trigger", "title", "text", "ui_target", "order", "requires"]
## Feste Auslöser (das TutorialSystem in T.2 meldet genau diese; neue kommen hier dazu).
const TRIGGERS := [
	"first_game_start",
	"first_location_open",
	"first_location_elsewhere",
	"first_calendar_open",
	"first_appointment_reminder",
	"first_event",
	"first_obligation_due",
	# T.5
	"first_window_closed",
	"first_action",
	"first_conflict_popup",
	"first_wait_offered",
	"first_trip_offered",
	"first_new_day",
	# T.6
	"first_channel_open",
	"first_content_quality",
	"first_equipment_offered",
	"first_effect_symbols",
	"first_company_offered",
	"first_company_open",
	"first_branch_offered",
	"first_settlement",
	"first_ledger_open",
	# Paket U
	"first_black_money",
	"first_organisation_founded",
	"first_mission_available",
	"first_supplier_open",
	"first_credit_offered",
	"first_site_offered",
	"first_sale_offered",
	"first_crew_open",
	"first_dealer_in_crew",
	"first_promotion_possible",
	"first_view_toggle_shown",
	"first_underworld_view",
	"first_district_window",
	"first_rivals_open",
	"first_crew_risk_shown",
	"first_laundering_offered",
	"first_black_spending_offered",
	"first_site_types_offered",
	"first_site_upgrade_offered",
	"first_police_attention",
	"first_raid_warning",
	"first_justice_open",
]
const MAX_TEXT_LENGTH := 240

var errors: PackedStringArray = []

var _definitions: Array = []
## T.5: „*“ erlaubt (Muster, z. B. „Tile_*“ = erste sichtbare Kachel), weil manche Ziele je Ort anders heißen.
var _ui_target_regex := RegEx.create_from_string("^[A-Za-z0-9_*]*$")
var _mechanic_regex := RegEx.create_from_string("^[a-z0-9_]+$")


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
		errors = PackedStringArray(["Tutorialdaten müssen eine Liste sein."])
		return false

	var definitions: Array = []
	var by_id := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if by_id.has(definition.id):
			reader.errors.append("Tutorial '%s': ID kommt doppelt vor." % definition.id)
			continue
		by_id[definition.id] = definition
		definitions.append(definition)
	for definition in definitions:
		for required in definition.requires:
			if not by_id.has(required):
				reader.errors.append("Tutorial '%s': 'requires' verweist auf unbekanntes Tutorial '%s'." % [
						definition.id, required])
	if reader.errors.is_empty():
		var cycle := _find_cycle(definitions, by_id)
		if not cycle.is_empty():
			reader.errors.append("Tutorials: Zyklus in 'requires': %s." % " → ".join(cycle))

	errors = reader.errors
	if not errors.is_empty():
		return false
	definitions.sort_custom(func(a, b) -> bool: return a.order < b.order or (a.order == b.order and a.id < b.id))
	_definitions = definitions
	return true


## Alle Tutorials, sortiert nach order, dann ID (Kopie der Liste).
func get_all() -> Array:
	return _definitions.duplicate()


func has(id: String) -> bool:
	return get_definition(id) != null


## null, wenn es die ID nicht gibt.
func get_definition(id: String):
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


## Tutorials zu einem Auslöser, sortiert nach order.
func get_for_trigger(trigger: String) -> Array:
	return _definitions.filter(func(definition) -> bool: return definition.trigger == trigger)


func _parse(reader: DataReaderScript, entry: Variant, index: int):
	var where := "Tutorial #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Tutorial '%s'" % id
	for key in entry:
		if String(key) not in FIELDS:
			reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])

	var definition := TutorialDefinitionScript.new()
	definition.id = id
	definition.mechanic = reader.string_field(entry, "mechanic", where, true)
	if not definition.mechanic.is_empty() and _mechanic_regex.search(definition.mechanic) == null:
		reader.errors.append("%s: 'mechanic' ist ungültig (nur a–z, 0–9, _)." % where)
	definition.trigger = reader.string_field(entry, "trigger", where, true)
	if not definition.trigger.is_empty() and definition.trigger not in TRIGGERS:
		reader.errors.append("%s: unbekannter 'trigger' '%s' (erlaubt: %s)." % [where, definition.trigger,
				", ".join(TRIGGERS)])
	definition.title = reader.string_field(entry, "title", where, true)
	definition.text = reader.string_field(entry, "text", where, true)
	if definition.text.length() > MAX_TEXT_LENGTH:
		reader.errors.append("%s: 'text' ist zu lang (%d Zeichen, höchstens %d)." % [where, definition.text.length(),
				MAX_TEXT_LENGTH])
	var target: Variant = entry.get("ui_target")
	if typeof(target) != TYPE_STRING or _ui_target_regex.search(target) == null:
		reader.errors.append("%s: 'ui_target' fehlt oder ist ungültig (Text aus A–Z, a–z, 0–9, _, *; leer erlaubt)." % where)
	else:
		definition.ui_target = target
	definition.order = reader.int_field(entry, "order", where, true)
	if definition.order < 0:
		reader.errors.append("%s: 'order' darf nicht negativ sein." % where)
	var requires: Variant = entry.get("requires")
	if typeof(requires) != TYPE_ARRAY:
		reader.errors.append("%s: 'requires' fehlt oder ist keine Liste." % where)
	else:
		for required in requires:
			if typeof(required) != TYPE_STRING or required.is_empty():
				reader.errors.append("%s: 'requires' enthält eine ungültige ID." % where)
			elif required == id:
				reader.errors.append("%s: 'requires' verweist auf sich selbst." % where)
			elif required in definition.requires:
				reader.errors.append("%s: 'requires' nennt '%s' doppelt." % [where, required])
			else:
				definition.requires.append(required)

	return definition if reader.errors.size() == error_count else null


## Erster gefundener Zyklus als Liste von IDs (Anfang = Ende), sonst leer. Tiefensuche mit drei Farben.
func _find_cycle(definitions: Array, by_id: Dictionary) -> PackedStringArray:
	var state := {}  # id -> 1 = in Arbeit, 2 = fertig
	for definition in definitions:
		var path := PackedStringArray()
		var cycle := _visit(definition.id, by_id, state, path)
		if not cycle.is_empty():
			return cycle
	return PackedStringArray()


func _visit(id: String, by_id: Dictionary, state: Dictionary, path: PackedStringArray) -> PackedStringArray:
	if state.get(id, 0) == 2:
		return PackedStringArray()
	if state.get(id, 0) == 1:
		var start := path.find(id)
		var cycle := path.slice(start)
		cycle.append(id)
		return cycle
	state[id] = 1
	path.append(id)
	for required in by_id[id].requires:
		var cycle := _visit(required, by_id, state, path)
		if not cycle.is_empty():
			return cycle
	path.remove_at(path.size() - 1)
	state[id] = 2
	return PackedStringArray()
