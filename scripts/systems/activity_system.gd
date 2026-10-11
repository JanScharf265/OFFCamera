class_name ActivitySystem
extends RefCounted

## Prüft und führt Aktivitäten aus. Ändert nichts selbst, sondern nutzt die
## zuständigen Systeme: Geld -> LedgerSystem, Werte -> PlayerStats, Zeit -> TimeSystem.
##
## start() ist alles-oder-nichts: Erst werden alle Bedingungen geprüft, dann
## in fester Reihenfolge ausgeführt:
##   1. Buchung (Zeitstempel = Beginn der Aktivität)
##   2. Effekte auf Spielerwerte
##   3. Zeitfortschritt um die Dauer
##   4. Signal activity_completed

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")

signal activity_completed(activity_id: String)

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _catalog: ActivityCatalogScript


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		catalog: ActivityCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_stats = stats
	_catalog = catalog


func get_catalog() -> ActivityCatalogScript:
	return _catalog


## "" wenn die Aktivität jetzt möglich ist, sonst ein Grund für die Anzeige.
func check(activity_id: String) -> String:
	var definition := _catalog.get_definition(activity_id)
	if definition == null:
		return "Unbekannte Aktivität: %s" % activity_id
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var energy_change := definition.get_effect("energy")
	if energy_change < 0 and _stats.energy + energy_change < 0:
		return "Zu wenig Energie (benötigt %d)." % -energy_change
	if definition.money_cents < 0 and not _ledger.can_afford(-definition.money_cents):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(-definition.money_cents)
	return ""


## Führt die Aktivität aus. Rückgabe wie check(): "" = erfolgreich.
func start(activity_id: String) -> String:
	var reason := check(activity_id)
	if not reason.is_empty():
		return reason

	var definition := _catalog.get_definition(activity_id)
	if definition.money_cents != 0:
		var entry := _ledger.post(definition.money_cents, definition.category,
				definition.display_name, "activity", definition.id)
		if entry == null:
			push_error("ActivitySystem: Buchung für '%s' trotz Prüfung abgelehnt." % activity_id)
			return "Die Buchung ist fehlgeschlagen."
	_stats.apply(definition.effects)
	_time.advance(definition.duration_minutes)
	activity_completed.emit(definition.id)
	return ""
