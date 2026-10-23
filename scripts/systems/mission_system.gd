extends RefCounted

## Story-Aufträge (U.4): eine Kette aus Daten (MissionCatalog). Ein Auftrag wird aktiv, sobald die Organisation
## gegründet ist und alle `requires` erledigt sind – auch Aufträge, die ein späteres Update an die Kette hängt.
## Ziele prüft das System selbst (z. B. Ankunft an einem offenen Ort über LocationSystem.traveled, oder dort warten,
## bis er öffnet); beim Abschluss gibt es die
## Belohnung (Organisationswerte) und der nächste Auftrag der Kette wird aktiv. Kostet keine Spielzeit.
## Neues (gestartet/erledigt) zählt als „ungesehen“ bis zum Öffnen des Fensters – das ergibt den roten Punkt.

const MissionCatalogScript := preload("res://scripts/systems/mission_catalog.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)

var _time
var _catalog: MissionCatalogScript
var _organisation
var _locations
var _supply
var _sites
## mission_id -> true
var _active := {}
## mission_id -> Zeitpunkt des Abschlusses (Minuten)
var _completed := {}
## mission_id -> true (neu oder erledigt, noch nicht im Fenster gesehen)
var _unseen := {}
## Hinweise seit dem letzten take_notices() (nicht gespeichert)
var _notices := PackedStringArray()


func _init(time, catalog: MissionCatalogScript, locations, organisation) -> void:
	_time = time
	_catalog = catalog
	_organisation = organisation
	_locations = locations
	locations.traveled.connect(_on_traveled)
	time.time_advanced.connect(_on_time_advanced)
	organisation.founded.connect(_on_founded)


## Vom GameState (U.6): Bestand für Ziele vom Typ „have_stock“.
func set_supply(supply) -> void:
	_supply = supply
	supply.stock_changed.connect(_check_stock_goals)


## Vom GameState (U.8): Standorte für Ziele vom Typ „own_site“.
func set_sites(sites) -> void:
	_sites = sites
	sites.site_acquired.connect(_check_site_goals.unbind(1))


func _check_site_goals() -> void:
	if _sites == null:
		return
	for definition in get_active():
		if definition.goal.get("type") == MissionCatalogScript.GOAL_OWN_SITE \
				and _sites.owns_type(definition.goal["site_type"]):
			_complete(definition)


func get_catalog() -> MissionCatalogScript:
	return _catalog


func is_active(mission_id: String) -> bool:
	return _active.has(mission_id)


func is_completed(mission_id: String) -> bool:
	return _completed.has(mission_id)


## Aktive Aufträge in Kettenreihenfolge.
func get_active() -> Array:
	return _catalog.get_all().filter(func(definition) -> bool: return _active.has(definition.id))


## Erledigte Aufträge, zuletzt erledigte zuerst.
func get_completed() -> Array:
	var result := _catalog.get_all().filter(func(definition) -> bool: return _completed.has(definition.id))
	result.sort_custom(func(a, b) -> bool: return _completed[a.id] > _completed[b.id])
	return result


## Zahl für den roten Punkt: neue oder erledigte Aufträge, die noch nicht im Fenster gesehen wurden.
func count_unseen() -> int:
	return _unseen.size()


func is_unseen(mission_id: String) -> bool:
	return _unseen.has(mission_id)


## Fenster geöffnet: alles gesehen.
func mark_all_seen() -> void:
	_unseen.clear()


## Hinweise („Neuer Auftrag …“, „Auftrag erledigt …“) seit dem letzten Aufruf, je einmal.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Startet alle Aufträge, deren Voraussetzungen jetzt erfüllt sind (Organisation gegründet, requires erledigt).
## Mehrfach aufrufen schadet nicht; auch nach dem Laden (neue Aufträge aus einem Update).
func update_availability() -> void:
	if not _organisation.is_founded():
		return
	for definition in _catalog.get_all():
		if _active.has(definition.id) or _completed.has(definition.id):
			continue
		var ready := true
		for required in definition.requires:
			if not _completed.has(required):
				ready = false
		if ready:
			_active[definition.id] = true
			_unseen[definition.id] = true
			_notices.append("Neuer Auftrag: „%s“ (%s)" % [definition.title, definition.chapter])
			mission_started.emit(definition.id)
	_check_stock_goals()
	_check_site_goals()


func _on_founded(_name: String) -> void:
	update_availability()


## Ankunft: Ein Treffen zählt nur, wenn der Ort gerade offen ist (Game Director, nach U.4) – sonst ein Hinweis.
func _on_traveled(_from_id: String, to_id: String) -> void:
	for definition in get_active():
		if definition.goal.get("type") != MissionCatalogScript.GOAL_VISIT_LOCATION or definition.goal["location"] != to_id:
			continue
		if _locations.is_open_at(to_id, _time.get_minutes()):
			_complete(definition)
		else:
			var location = _locations.get_catalog().get_definition(to_id)
			_notices.append("„%s“: %s hat gerade zu – komm wieder, wenn geöffnet ist." % [definition.title,
					location.display_name if location != null else to_id])


## Wer am Ort bleibt (z. B. wartet), bis er öffnet, erfüllt das Treffen dann.
func _on_time_advanced(_from: int, to_minutes: int) -> void:
	for definition in get_active():
		if definition.goal.get("type") == MissionCatalogScript.GOAL_VISIT_LOCATION \
				and definition.goal["location"] == _locations.get_current() \
				and _locations.is_open_at(definition.goal["location"], to_minutes):
			_complete(definition)


func _check_stock_goals() -> void:
	if _supply == null:
		return
	for definition in get_active():
		if definition.goal.get("type") == MissionCatalogScript.GOAL_HAVE_STOCK \
				and _supply.total_stock() >= int(definition.goal["min_units"]):
			_complete(definition)


func _complete(definition) -> void:
	_active.erase(definition.id)
	_completed[definition.id] = _time.get_minutes()
	_unseen[definition.id] = true
	if not definition.reward.is_empty():
		_organisation.change(definition.reward)
	_notices.append("Auftrag erledigt: „%s“%s" % [definition.title, reward_suffix(definition.reward)])
	mission_completed.emit(definition.id)
	update_availability()


## z. B. " (Respekt +5)" oder "".
static func reward_suffix(reward: Dictionary) -> String:
	var labels := {"respect": "Respekt", "heat": "Hitze", "stability": "Stabilität"}
	var parts := PackedStringArray()
	for key in reward:
		parts.append("%s %+d" % [labels.get(key, key), int(reward[key])])
	return " (%s)" % ", ".join(parts) if not parts.is_empty() else ""


func to_dict() -> Dictionary:
	var completed := {}
	for id in _completed:
		completed[id] = _completed[id]
	var active := _active.keys()
	active.sort()
	var unseen := _unseen.keys()
	unseen.sort()
	return {"active": active, "completed": completed, "unseen": unseen}


## Unbekannte IDs (Auftrag aus den Daten entfernt) bleiben erhalten. "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var active := {}
	var unseen := {}
	for pair in [["active", active], ["unseen", unseen]]:
		var raw: Variant = data.get(pair[0])
		if typeof(raw) != TYPE_ARRAY:
			return "Aufträge: '%s' fehlt oder ist keine Liste." % pair[0]
		for id in raw:
			if typeof(id) != TYPE_STRING or id.is_empty():
				return "Aufträge: ungültige ID in '%s'." % pair[0]
			pair[1][id] = true
	var raw_completed: Variant = data.get("completed")
	if typeof(raw_completed) != TYPE_DICTIONARY:
		return "Aufträge: 'completed' fehlt oder ist kein Objekt."
	var completed := {}
	for id in raw_completed:
		if typeof(id) != TYPE_STRING or not DataReaderScript.is_whole_number(raw_completed[id]) \
				or int(raw_completed[id]) < 0:
			return "Aufträge: ungültiger Eintrag in 'completed'."
		if active.has(id):
			return "Aufträge: '%s' ist zugleich aktiv und erledigt." % id
		completed[id] = int(raw_completed[id])
	_active = active
	_completed = completed
	_unseen = unseen
	_notices.clear()
	return ""
