class_name GameState
extends RefCounted

## Bündelt alle Systeme einer Spielsitzung. Kein Autoload: Wer ein Spiel
## startet, erzeugt einen GameState und reicht ihn weiter.
##
## Startwerte sind Platzhalter für Phase 1.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const ActivitySystemScript := preload("res://scripts/systems/activity_system.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

const START_DAY := 1
const START_HOUR := 8
const START_BALANCE_CENTS := 50000
const START_ENERGY := 80
const START_MOOD := 60

var time: TimeSystemScript
var ledger: LedgerSystemScript
var stats: PlayerStatsScript
var activities: ActivitySystemScript
var events: EventSystemScript


## Neues Spiel mit Startwerten. Die Kataloge müssen bereits geladen sein;
## ohne Ereigniskatalog gibt es keine Ereignisse.
func _init(activity_catalog: ActivityCatalogScript, event_catalog: EventCatalogScript = null) -> void:
	if event_catalog == null:
		event_catalog = EventCatalogScript.new()
	time = TimeSystemScript.new(TimeSystemScript.at(START_DAY, START_HOUR))
	ledger = LedgerSystemScript.new(time, START_BALANCE_CENTS)
	stats = PlayerStatsScript.new(START_ENERGY, START_MOOD)
	activities = ActivitySystemScript.new(time, ledger, stats, activity_catalog)
	events = EventSystemScript.new(time, ledger, stats, event_catalog)


func to_dict() -> Dictionary:
	return {
		"time": time.to_dict(),
		"ledger": ledger.to_dict(),
		"stats": stats.to_dict(),
		"events": events.to_dict(),
	}


## Überschreibt den Zustand mit gespeicherten Daten. "" = ok, sonst Fehlertext.
## Bei einem Fehler kann der GameState teilweise geändert sein – der Aufrufer
## verwirft ihn dann (SaveSystem erzeugt dafür immer einen frischen GameState).
func restore(data: Dictionary) -> String:
	for section in ["time", "ledger", "stats"]:
		if typeof(data.get(section)) != TYPE_DICTIONARY:
			return "Abschnitt '%s' fehlt." % section
	var error := time.restore(data["time"])
	if error.is_empty():
		error = ledger.restore(data["ledger"])
	if error.is_empty():
		error = stats.restore(data["stats"])
	if error.is_empty():
		var events_data: Variant = data.get("events", {})
		error = events.restore(events_data) if typeof(events_data) == TYPE_DICTIONARY \
				else "Abschnitt 'events' ist ungültig."
	return error
