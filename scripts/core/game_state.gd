class_name GameState
extends RefCounted

## Bündelt alle Systeme einer Spielsitzung. Kein Autoload: Wer ein Spiel
## startet, erzeugt einen GameState und reicht ihn weiter.
##
## Startwerte sind Platzhalter.

const GameDataScript := preload("res://scripts/core/game_data.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const ActivitySystemScript := preload("res://scripts/systems/activity_system.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")
const AppointmentSystemScript := preload("res://scripts/systems/appointment_system.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const ContentSystemScript := preload("res://scripts/systems/content_system.gd")
const EquipmentSystemScript := preload("res://scripts/systems/equipment_system.gd")
const CompanySystemScript := preload("res://scripts/systems/company_system.gd")
const DayCycleScript := preload("res://scripts/core/day_cycle.gd")
const ObligationSystemScript := preload("res://scripts/systems/obligation_system.gd")
const DayStartSystemScript := preload("res://scripts/systems/day_start_system.gd")
const ReminderSystemScript := preload("res://scripts/systems/reminder_system.gd")
const TripSystemScript := preload("res://scripts/systems/trip_system.gd")
const TutorialSystemScript := preload("res://scripts/systems/tutorial_system.gd")
const OrganisationSystemScript := preload("res://scripts/systems/organisation_system.gd")
const MissionSystemScript := preload("res://scripts/systems/mission_system.gd")
const SupplySystemScript := preload("res://scripts/systems/supply_system.gd")
const SiteSystemScript := preload("res://scripts/systems/site_system.gd")
const SaleSystemScript := preload("res://scripts/systems/sale_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")
const TerritorySystemScript := preload("res://scripts/systems/territory_system.gd")
const RivalSystemScript := preload("res://scripts/systems/rival_system.gd")
const LaunderingSystemScript := preload("res://scripts/systems/laundering_system.gd")
const BlackSpendingSystemScript := preload("res://scripts/systems/black_spending_system.gd")
const PoliceSystemScript := preload("res://scripts/systems/police_system.gd")

const START_DAY := 1
const START_HOUR := 8
const START_BALANCE_CENTS := 50000
const START_ENERGY := 80
const START_MOOD := 60
const START_FOLLOWERS := 120
const START_COMMUNITY := 50
const START_REPUTATION := 50

var data: GameDataScript
var time: TimeSystemScript
var ledger: LedgerSystemScript
var stats: PlayerStatsScript
var locations: LocationSystemScript
var activities: ActivitySystemScript
var events: EventSystemScript
var appointments: AppointmentSystemScript
var channel: ChannelSystemScript
var content: ContentSystemScript
var equipment: EquipmentSystemScript
var company: CompanySystemScript
var obligations: ObligationSystemScript
var day_cycle: DayCycleScript
## Tagesbeginn: Kalender genau einmal je Tag (G5.3).
var day_start: DayStartSystemScript
## Erinnerung ≤ 30 Spielminuten vor einem Termin, genau einmal je Termin (G5.6).
var reminders: ReminderSystemScript
## „Hinfahren und starten“ (G5.7) – ohne eigenen Zustand, nicht im Spielstand.
var trips: TripSystemScript
## Tutorials (T.2): Auslöser, fällig, gesehen.
var tutorials: TutorialSystemScript
## Organisation in der Unterwelt (U.2): Name, Respekt, Hitze, Stabilität.
var organisation: OrganisationSystemScript
## Story-Aufträge (U.4)
var missions: MissionSystemScript
## Lieferant und Bestand (U.6)
var supply: SupplySystemScript
## Standorte der Unterwelt (U.8)
var sites: SiteSystemScript
## Verkaufen (U.9)
var sales: SaleSystemScript
## Crew (U.10)
var crew: CrewSystemScript
## Gebiete übernehmen, halten, verlieren (U.13)
var territory: TerritorySystemScript
## Rivalen (U.14)
var rivals: RivalSystemScript
## Waschen über die Tarnfirma (U.16)
var laundering: LaunderingSystemScript
## Schwarzgeld ausgeben (U.17)
var black_spending: BlackSpendingSystemScript
## Polizei (U.19)
var police: PoliceSystemScript


## Neues Spiel mit Startwerten. Die Daten müssen bereits geladen sein.
## p_seed bestimmt die Zufallsereignisse (gleicher Seed = gleicher Verlauf);
## -1 = neuer zufälliger Seed (wird mit dem Spielstand gespeichert).
func _init(game_data: GameDataScript, p_seed: int = -1) -> void:
	data = game_data
	time = TimeSystemScript.new(TimeSystemScript.at(START_DAY, START_HOUR))
	ledger = LedgerSystemScript.new(time, START_BALANCE_CENTS)
	stats = PlayerStatsScript.new(START_ENERGY, START_MOOD)
	locations = LocationSystemScript.new(time, data.locations, GameDataScript.START_LOCATION)
	appointments = AppointmentSystemScript.new(time, ledger, stats, locations, data.appointments)
	channel = ChannelSystemScript.new(time, START_FOLLOWERS, START_COMMUNITY, START_REPUTATION)
	events = EventSystemScript.new(time, ledger, stats, channel, data.events, p_seed if p_seed >= 0 else new_seed())
	equipment = EquipmentSystemScript.new(time, ledger, locations, data.equipment)
	company = CompanySystemScript.new(time, ledger, locations, channel, data.company_types)
	activities = ActivitySystemScript.new(time, ledger, stats, locations, company, data.activities)
	content = ContentSystemScript.new(time, ledger, stats, locations, channel, equipment, data.formats)
	obligations = ObligationSystemScript.new(time, ledger, stats, company, data.obligations)
	events.set_world(company, obligations)
	organisation = OrganisationSystemScript.new(time, data.organisation)
	organisation.set_events(events)
	events.set_organisation_changer(organisation.change)
	missions = MissionSystemScript.new(time, data.missions, locations, organisation)
	locations.set_mission_check(missions.is_completed)
	supply = SupplySystemScript.new(time, ledger, data.suppliers, data.products, missions, events.get_seed, obligations,
			events)
	missions.set_supply(supply)
	sites = SiteSystemScript.new(time, ledger, locations, data.sites, obligations, missions.is_completed)
	supply.set_capacity_check(sites.capacity)
	supply.set_discount(sites.supplier_discount_percent)
	sites.set_underworld(supply, organisation)
	missions.set_sites(sites)
	sales = SaleSystemScript.new(time, ledger, locations, data.sale_spots, supply, organisation, missions.is_completed)
	missions.set_sales(sales)
	crew = CrewSystemScript.new(time, ledger, data.crew, organisation, supply, obligations, missions.is_completed, events.get_seed)
	missions.set_crew(crew)
	territory = TerritorySystemScript.new(time, ledger, data.districts, data.territory, organisation)
	crew.set_territory(territory.add_influence, territory.unit_bonus, territory.influence_for_skill,
			data.districts.get_definition)
	missions.set_territory(territory)
	rivals = RivalSystemScript.new(time, ledger, data.rivals, organisation, territory, missions.is_completed,
			events.get_seed, events.trigger_scripted)
	territory.set_pressure_modifier(rivals.pressure_percent)
	events.set_rival_handler(rivals.apply_event_action)
	crew.set_incident_hooks(events.trigger_scripted, data.rivals.get_for_district)
	events.set_crew_handler(crew.apply_event_action)
	events.add_text_context(crew.text_context)
	laundering = LaunderingSystemScript.new(time, ledger, data.laundering, organisation, company)
	laundering.set_limit_bonus(sites.laundering_bonus)
	black_spending = BlackSpendingSystemScript.new(time, ledger, data.black_spending, organisation)
	activities.set_black_spending(black_spending.account_for, black_spending.record)
	equipment.set_black_spending(black_spending.account_for, black_spending.record)
	police = PoliceSystemScript.new(time, ledger, data.police, organisation, events.get_seed, events.trigger_scripted)
	events.add_condition_values(police.condition_values)
	events.add_text_context(police.text_context)
	crew.set_arrest_bonus(police.arrest_bonus)
	# Feste Reihenfolge am Tageswechsel: Tagesabschluss → Hitze (U.2) → Lieferungen (U.6) → Standortkosten (U.8)
	# → Fristen → Ereignisse.
	day_cycle = DayCycleScript.new(time, [company, organisation, supply, sites, crew, territory, rivals, police, obligations, events])
	# Neues Spiel: Der erste Tag gilt als begonnen – der Kalender öffnet sich ab dem ersten Tageswechsel.
	day_start = DayStartSystemScript.new(time, START_DAY)
	reminders = ReminderSystemScript.new(time, appointments, locations)
	trips = TripSystemScript.new(time, locations, activities, content, company)
	tutorials = TutorialSystemScript.new(data.tutorials)
	# Auslöser aus den Systemen; die übrigen meldet die Spielansicht. Gebundene Methode statt Lambda: Ein Lambda hielte
	# den GameState fest (Kreisverweis, Speicherleck – test_memory).
	events.event_triggered.connect(tutorials.report.bind("first_event").unbind(1))
	obligations.obligation_due.connect(tutorials.report.bind("first_obligation_due").unbind(1))
	company.day_settled.connect(tutorials.report.bind("first_settlement").unbind(1))
	ledger.entry_posted.connect(tutorials.on_ledger_entry)
	organisation.founded.connect(tutorials.report.bind("first_organisation_founded").unbind(1))
	missions.mission_started.connect(tutorials.report.bind("first_mission_available").unbind(1))


## Zufälliger Seed für ein neues Spiel (0 … 2^31 − 1).
static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7FFFFFFF


func to_dict() -> Dictionary:
	return {
		"time": time.to_dict(),
		"ledger": ledger.to_dict(),
		"stats": stats.to_dict(),
		"location": locations.to_dict(),
		"events": events.to_dict(),
		"appointments": appointments.to_dict(),
		"channel": channel.to_dict(),
		"equipment": equipment.to_dict(),
		"company": company.to_dict(),
		"obligations": obligations.to_dict(),
		"day_start": day_start.to_dict(),
		"reminders": reminders.to_dict(),
		"tutorials": tutorials.to_dict(),
		"organisation": organisation.to_dict(),
		"missions": missions.to_dict(),
		"supply": supply.to_dict(),
		"sites": sites.to_dict(),
		"sales": sales.to_dict(),
		"crew": crew.to_dict(),
		"territory": territory.to_dict(),
		"rivals": rivals.to_dict(),
		"laundering": laundering.to_dict(),
		"black_spending": black_spending.to_dict(),
		"police": police.to_dict(),
	}


## Überschreibt den Zustand mit gespeicherten Daten (aktuelles Format). "" = ok,
## sonst Fehlertext. Bei einem Fehler kann der GameState teilweise geändert sein –
## der Aufrufer verwirft ihn dann (SaveSystem erzeugt dafür immer einen frischen GameState).
func restore(saved: Dictionary) -> String:
	for section in ["time", "ledger", "stats", "location", "events", "appointments", "channel", "equipment", "company",
			"obligations", "day_start", "reminders", "tutorials", "organisation", "missions", "supply", "sites", "sales", "crew", "territory", "rivals", "laundering", "black_spending", "police"]:
		if typeof(saved.get(section)) != TYPE_DICTIONARY:
			return "Abschnitt '%s' fehlt oder ist ungültig." % section
	var error := time.restore(saved["time"])
	if error.is_empty():
		error = ledger.restore(saved["ledger"])
	if error.is_empty():
		error = stats.restore(saved["stats"])
	if error.is_empty():
		error = locations.restore(saved["location"])
	if error.is_empty():
		error = events.restore(saved["events"])
	if error.is_empty():
		error = appointments.restore(saved["appointments"])
	if error.is_empty():
		error = channel.restore(saved["channel"])
	if error.is_empty():
		error = equipment.restore(saved["equipment"])
	if error.is_empty():
		error = company.restore(saved["company"])
	if error.is_empty():
		error = obligations.restore(saved["obligations"])
	if error.is_empty():
		error = day_start.restore(saved["day_start"])
	if error.is_empty():
		error = reminders.restore(saved["reminders"])
	if error.is_empty():
		error = tutorials.restore(saved["tutorials"])
	if error.is_empty():
		error = organisation.restore(saved["organisation"])
	if error.is_empty():
		error = supply.restore(saved["supply"])
	if error.is_empty():
		error = sites.restore(saved["sites"])
	if error.is_empty():
		error = sales.restore(saved["sales"])
	if error.is_empty():
		error = crew.restore(saved["crew"])
	if error.is_empty():
		error = territory.restore(saved["territory"])
	if error.is_empty():
		error = rivals.restore(saved["rivals"])
	if error.is_empty():
		error = laundering.restore(saved["laundering"])
	if error.is_empty():
		error = black_spending.restore(saved["black_spending"])
	if error.is_empty():
		error = police.restore(saved["police"])
	if error.is_empty():
		error = missions.restore(saved["missions"])
	if error.is_empty():
		missions.update_availability()  # Aufträge, die ein Update an die Kette gehängt hat
	return error


## Hinweise des letzten restore() zu Daten, die es nicht mehr gibt (Phase 6) – zum Anzeigen nach dem Laden.
func load_notices() -> PackedStringArray:
	var notices := PackedStringArray()
	for system in [locations, equipment, events, company, obligations]:
		notices.append_array(system.restore_notices)
	return notices


## U.12: Orte mit Unterwelt-Bezug für die Unterwelt-Ansicht der Karte – Orte eigener oder bekannter Standorte und
## verfügbarer Verkaufsorte. Nur zur Anzeige.
func underworld_location_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for site in sites.get_catalog().get_all():
		if (sites.is_owned(site.id) or sites.is_unlocked(site.id)) and site.location not in ids:
			ids.append(site.location)
	for spot in sales.get_catalog().get_all():
		if sales.is_available(spot.id) and spot.location not in ids:
			ids.append(spot.location)
	return ids
