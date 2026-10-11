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
