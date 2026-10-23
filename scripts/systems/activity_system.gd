class_name ActivitySystem
extends RefCounted

## Prüft und führt Aktivitäten aus. Eine Aktivität geht nur an ihrem Ort und
## nur, wenn der Ort für die ganze Dauer geöffnet ist. Ändert nichts selbst, sondern nutzt die
## zuständigen Systeme: Geld -> LedgerSystem, Werte -> PlayerStats, Zeit -> TimeSystem.
##
## start() ist alles-oder-nichts: Erst werden alle Bedingungen geprüft, dann
## in fester Reihenfolge ausgeführt:
##   1. Buchung (Zeitstempel = Beginn der Aktivität)
##   2. Effekte auf Spielerwerte
##   3. Effekte aufs Unternehmen (Phase 4, mit Begründung im Unternehmens-Protokoll)
##   4. Zeitfortschritt um die Dauer
##   5. Signal activity_completed
## Voraussetzung "company"/"branch": Unternehmen gegründet bzw. Filiale eröffnet.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const CompanySystemScript := preload("res://scripts/systems/company_system.gd")

signal activity_completed(activity_id: String)

## U.17: Konto-Wahl für Ausgaben (Schwarzgeld oder privat) und Meldung danach
var _choose_account: Callable
var _record_black: Callable
var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _catalog: ActivityCatalogScript
var _locations: LocationSystemScript
var _company: CompanySystemScript


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		locations: LocationSystemScript, company: CompanySystemScript, catalog: ActivityCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_stats = stats
	_locations = locations
	_company = company
	_catalog = catalog


func get_catalog() -> ActivityCatalogScript:
	return _catalog


## "" wenn die Aktivität jetzt möglich ist, sonst ein Grund für die Anzeige.
func check(activity_id: String) -> String:
	return _check(activity_id, false, _time.get_minutes())


## G5.7 („Hinfahren und starten“): Prüfung, als wäre man um `start_minutes` am Ort der Aktivität angekommen –
## alle Gründe außer „Nur vor Ort“, Öffnungszeiten ab der Ankunft. "" = möglich.
func check_on_arrival(activity_id: String, start_minutes: int) -> String:
	return _check(activity_id, true, start_minutes)


func _check(activity_id: String, assume_there: bool, start_minutes: int) -> String:
	var definition := _catalog.get_definition(activity_id)
	if definition == null:
		return "Unbekannte Aktivität: %s" % activity_id
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if not assume_there and definition.location != _locations.get_current():
		var location := _locations.get_catalog().get_definition(definition.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else definition.location)
	if definition.requires == "company" and not _company.is_founded():
		return "Erst ein Unternehmen gründen (im Büro)."
	if definition.requires == "branch" and not _company.is_branch_open():
		return "Erst die Filiale eröffnen."
	var closed_reason := _locations.check_open_during(definition.location, start_minutes,
			definition.duration_minutes)
	if not closed_reason.is_empty():
		return closed_reason
	var energy_change := definition.get_effect("energy")
	if energy_change < 0 and _stats.energy + energy_change < 0:
		return "Zu wenig Energie (benötigt %d)." % -energy_change
	if definition.money_cents < 0 and not _ledger.can_afford(-definition.money_cents, _account_for(-definition.money_cents)):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(-definition.money_cents)
	return ""


## Führt die Aktivität aus. Rückgabe wie check(): "" = erfolgreich.
func start(activity_id: String) -> String:
	var reason := check(activity_id)
	if not reason.is_empty():
		return reason

	var definition := _catalog.get_definition(activity_id)
	if definition.money_cents != 0:
		var account := _account_for(-definition.money_cents) if definition.money_cents < 0 else LedgerSystemScript.PRIVATE
		var entry := _ledger.post(definition.money_cents, definition.category,
				definition.display_name, "activity", definition.id, "", false, account)
		if entry == null:
			push_error("ActivitySystem: Buchung für '%s' trotz Prüfung abgelehnt." % activity_id)
			return "Die Buchung ist fehlgeschlagen."
		if account == LedgerSystemScript.BLACK and _record_black.is_valid():
			_record_black.call(-definition.money_cents, definition.display_name)
	_stats.apply(definition.effects)
	if not definition.company_effects.is_empty():
		_company.apply(definition.company_effects, "activity", definition.display_name, definition.id)
	_time.advance(definition.duration_minutes)
	activity_completed.emit(definition.id)
	return ""


## U.17: Schwarzgeld ausgeben – BlackSpendingSystem.account_for / record (vom GameState).
func set_black_spending(account_for: Callable, record: Callable) -> void:
	_choose_account = account_for
	_record_black = record


func _account_for(cost_cents: int) -> String:
	return _choose_account.call(cost_cents) if _choose_account.is_valid() else LedgerSystemScript.PRIVATE
