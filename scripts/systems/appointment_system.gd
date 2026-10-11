class_name AppointmentSystem
extends RefCounted

## Feste Termine aus Daten.
##
## Wahrnehmen: nur vor Ort und frühestens ATTEND_WINDOW_MINUTES vor Beginn,
## spätestens zum Beginn. Wer früher da ist, wartet bis zum Beginn; danach läuft
## die Dauer. Reihenfolge wie bei Aktivitäten: Status setzen -> Buchung ->
## Effekte -> Zeitfortschritt.
##
## Verpassen: Bei jedem time_advanced(from, to) gilt jeder offene Termin mit
## Beginn vor `to` als verpasst; missed_effects werden genau einmal angewendet.
## Weil nur time_advanced das auslöst, passiert beim Laden nichts erneut.
##
## Termine mit Beginn vor `since_minutes` (Spielbeginn bzw. Zeitpunkt der
## Migration eines älteren Spielstands) entfallen – ohne Strafe.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const AppointmentCatalogScript := preload("res://scripts/systems/appointment_catalog.gd")
const AppointmentDefinitionScript := preload("res://scripts/models/appointment_definition.gd")

signal appointment_attended(appointment_id: String)
signal appointment_missed(appointment_id: String)

const ATTEND_WINDOW_MINUTES := 60

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _locations: LocationSystemScript
var _catalog: AppointmentCatalogScript
var _since := 0
## appointment_id -> true
var _attended := {}
var _missed := {}
## Verpasste Termine seit dem letzten take_missed_notices() – nur für die Anzeige,
## wird nicht gespeichert.
var _missed_notices := PackedStringArray()


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		locations: LocationSystemScript, catalog: AppointmentCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_stats = stats
	_locations = locations
	_catalog = catalog
	_since = time.get_minutes()
	time.time_advanced.connect(_on_time_advanced)


func get_catalog() -> AppointmentCatalogScript:
	return _catalog


func is_attended(appointment_id: String) -> bool:
	return _attended.has(appointment_id)


func is_missed(appointment_id: String) -> bool:
	return _missed.has(appointment_id)


## Offen = weder wahrgenommen noch verpasst noch entfallen.
func is_open(appointment_id: String) -> bool:
	var definition := _catalog.get_definition(appointment_id)
	return definition != null and _is_open(definition)


## Offene Termine, sortiert nach Beginn.
func get_upcoming() -> Array[AppointmentDefinitionScript]:
	var result: Array[AppointmentDefinitionScript] = []
	for definition in _catalog.get_all():
		if _is_open(definition):
			result.append(definition)
	return result


## IDs der seit dem letzten Aufruf verpassten Termine; leert die Liste.
func take_missed_notices() -> PackedStringArray:
	var notices := _missed_notices
	_missed_notices = PackedStringArray()
	return notices


## "" wenn der Termin jetzt wahrgenommen werden kann, sonst ein Grund für die Anzeige.
func check(appointment_id: String) -> String:
	var definition := _catalog.get_definition(appointment_id)
	if definition == null:
		return "Unbekannter Termin: %s" % appointment_id
	if _attended.has(appointment_id):
		return "Termin bereits wahrgenommen."
	if not _is_open(definition):
		return "Termin ist vorbei."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var now := _time.get_minutes()
	if now < definition.start_minutes - ATTEND_WINDOW_MINUTES:
		return "Wahrnehmen ab %s möglich." % TimeSystemScript.format_stamp(definition.start_minutes - ATTEND_WINDOW_MINUTES)
	if _locations.get_current() != definition.location:
		var location := _locations.get_catalog().get_definition(definition.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else definition.location)
	if definition.money_cents < 0 and not _ledger.can_afford(-definition.money_cents):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(-definition.money_cents)
	return ""


## Minuten, die wahrnehmen ab jetzt kostet (Warten bis Beginn + Dauer).
func minutes_to_attend(appointment_id: String) -> int:
	var definition := _catalog.get_definition(appointment_id)
	if definition == null:
		return 0
	return maxi(definition.start_minutes - _time.get_minutes(), 0) + definition.duration_minutes


## Nimmt den Termin wahr. Rückgabe wie check(): "" = erfolgreich.
func attend(appointment_id: String) -> String:
	var reason := check(appointment_id)
	if not reason.is_empty():
		return reason
	var definition := _catalog.get_definition(appointment_id)
	var minutes := minutes_to_attend(appointment_id)
	_attended[appointment_id] = true
	if definition.money_cents != 0:
		var entry := _ledger.post(definition.money_cents, definition.category, definition.title,
				"appointment", appointment_id, "appointment:%s" % appointment_id)
		if entry == null:
			_attended.erase(appointment_id)
			push_error("AppointmentSystem: Buchung für '%s' trotz Prüfung abgelehnt." % appointment_id)
			return "Die Buchung ist fehlgeschlagen."
	_stats.apply(definition.effects)
	_time.advance(minutes)
	appointment_attended.emit(appointment_id)
	return ""


## Offene Termine, die verpasst würden, wenn ab jetzt `minutes` Minuten vergehen.
func get_conflicts(minutes: int, except_id: String = "") -> Array[AppointmentDefinitionScript]:
	var result: Array[AppointmentDefinitionScript] = []
	var now := _time.get_minutes()
	for definition in _catalog.get_all():
		if definition.id != except_id and _is_open(definition) \
				and definition.start_minutes >= now and definition.start_minutes < now + minutes:
			result.append(definition)
	return result


## Warntext für die Anzeige oder "", wenn nichts kollidiert.
func conflict_warning(minutes: int, except_id: String = "") -> String:
	var conflicts := get_conflicts(minutes, except_id)
	if conflicts.is_empty():
		return ""
	var names := PackedStringArray()
	for definition in conflicts:
		names.append("„%s“ (%s)" % [definition.title, TimeSystemScript.format_stamp(definition.start_minutes)])
	return "Achtung: Damit verpasst du %s." % ", ".join(names)


func to_dict() -> Dictionary:
	var attended := _attended.keys()
	var missed := _missed.keys()
	attended.sort()
	missed.sort()
	return {"since_minutes": _since, "attended": attended, "missed": missed}


## Stellt einen gespeicherten Zustand her, ohne etwas anzuwenden.
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var since: Variant = data.get("since_minutes")
	if typeof(since) not in [TYPE_INT, TYPE_FLOAT] or since != floorf(since) or since < 0:
		return "Termine: 'since_minutes' fehlt oder ist ungültig."
	var attended := {}
	var missed := {}
	for pair in [["attended", attended], ["missed", missed]]:
		var raw: Variant = data.get(pair[0], [])
		if typeof(raw) != TYPE_ARRAY:
			return "Termine: '%s' muss eine Liste sein." % pair[0]
		for id in raw:
			if typeof(id) != TYPE_STRING:
				return "Termine: ungültige ID in '%s'." % pair[0]
			pair[1][id] = true
	for id in attended:
		if missed.has(id):
			return "Termine: '%s' ist zugleich wahrgenommen und verpasst." % id
	_since = int(since)
	_attended = attended
	_missed = missed
	_missed_notices.clear()
	return ""


func _is_open(definition: AppointmentDefinitionScript) -> bool:
	return definition.start_minutes >= _since and not _attended.has(definition.id) \
			and not _missed.has(definition.id)


func _on_time_advanced(_from_minutes: int, to_minutes: int) -> void:
	for definition in _catalog.get_all():  # sortiert nach Beginn
		if _is_open(definition) and definition.start_minutes < to_minutes:
			_missed[definition.id] = true
			_missed_notices.append(definition.id)
			_stats.apply(definition.missed_effects)
			appointment_missed.emit(definition.id)
