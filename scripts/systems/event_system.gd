class_name EventSystem
extends RefCounted

## Zentrale Ereignisverarbeitung.
##
## Auslösen: Bei jedem time_advanced(from, to) werden alle noch nie ausgelösten
## Ereignisse mit Fälligkeit in (from, to] ausgelöst – sortiert nach Zeit,
## dann Priorität (höher zuerst), dann ID. Jedes Ereignis wird höchstens einmal
## ausgelöst und landet in der Warteschlange offener Ereignisse.
##
## Entscheiden: resolve(event_id, option_id) wendet die Folgen an
## (Geld -> LedgerSystem mit idempotency_key "event:<id>", Werte -> PlayerStats)
## und schließt das Ereignis. Entscheidungen kosten keine Spielzeit.
##
## Weil nur time_advanced auslöst, wird beim Laden eines Spielstands nichts
## erneut ausgelöst; der idempotency_key verhindert zusätzlich Doppelbuchungen.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const EventDefinitionScript := preload("res://scripts/models/event_definition.gd")

signal event_triggered(event_id: String)
signal event_resolved(event_id: String, option_id: String)

var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _catalog: EventCatalogScript
## event_id -> true für alle jemals ausgelösten Ereignisse (offen oder entschieden).
var _triggered := {}
## Offene Ereignisse in Auslösereihenfolge.
var _pending := PackedStringArray()
## event_id -> gewählte option_id
var _resolved := {}


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		catalog: EventCatalogScript) -> void:
	_ledger = ledger
	_stats = stats
	_catalog = catalog
	time.time_advanced.connect(_on_time_advanced)


func has_pending() -> bool:
	return not _pending.is_empty()


## Das nächste offene Ereignis oder null.
func get_next_pending() -> EventDefinitionScript:
	if _pending.is_empty():
		return null
	return _catalog.get_definition(_pending[0])


func is_triggered(event_id: String) -> bool:
	return _triggered.has(event_id)


func is_resolved(event_id: String) -> bool:
	return _resolved.has(event_id)


## "" wenn erfolgreich, sonst ein Anzeigetext. Bei Ablehnung ändert sich nichts.
func resolve(event_id: String, option_id: String) -> String:
	if not _pending.has(event_id):
		return "Dieses Ereignis ist nicht offen."
	var definition := _catalog.get_definition(event_id)
	var option := definition.get_option(option_id)
	if option == null:
		return "Unbekannte Auswahl: %s" % option_id
	if option.money_cents < 0 and not _ledger.can_afford(-option.money_cents):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(-option.money_cents)

	if option.money_cents != 0:
		var entry := _ledger.post(option.money_cents, option.category,
				"%s: %s" % [definition.title, option.label], "event", event_id, "event:%s" % event_id)
		if entry == null:
			push_error("EventSystem: Buchung für Ereignis '%s' abgelehnt (Grund %d)." % [event_id, _ledger.last_rejection])
			return "Die Buchung ist fehlgeschlagen."
	_stats.apply(option.effects)

	_pending.remove_at(_pending.find(event_id))
	_resolved[event_id] = option_id
	event_resolved.emit(event_id, option_id)
	return ""


func _on_time_advanced(from_minutes: int, to_minutes: int) -> void:
	var due: Array[EventDefinitionScript] = []
	for definition in _catalog.get_all():
		if not _triggered.has(definition.id) \
				and definition.due_minutes > from_minutes and definition.due_minutes <= to_minutes:
			due.append(definition)
	due.sort_custom(_comes_before)
	for definition in due:
		_triggered[definition.id] = true
		_pending.append(definition.id)
		event_triggered.emit(definition.id)


func _comes_before(a: EventDefinitionScript, b: EventDefinitionScript) -> bool:
	if a.due_minutes != b.due_minutes:
		return a.due_minutes < b.due_minutes
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.id < b.id
