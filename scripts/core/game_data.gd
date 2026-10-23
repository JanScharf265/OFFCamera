class_name GameData
extends RefCounted

## Alle Spieldaten-Kataloge an einem Ort, inklusive Prüfung der Verweise
## zwischen ihnen (z. B. Aktivität/Format -> Ort). Wird einmal beim App-Start geladen
## und von jedem GameState nur gelesen.
##
## Tests können einzelne Kataloge mit load_data() überschreiben.

const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const AppointmentCatalogScript := preload("res://scripts/systems/appointment_catalog.gd")
const ContentFormatCatalogScript := preload("res://scripts/systems/content_format_catalog.gd")
const EquipmentCatalogScript := preload("res://scripts/systems/equipment_catalog.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")
const ObligationCatalogScript := preload("res://scripts/systems/obligation_catalog.gd")
const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")
const OrganisationRulesScript := preload("res://scripts/systems/organisation_rules.gd")
const MissionCatalogScript := preload("res://scripts/systems/mission_catalog.gd")
const ProductCatalogScript := preload("res://scripts/systems/product_catalog.gd")
const SupplierCatalogScript := preload("res://scripts/systems/supplier_catalog.gd")
const SiteCatalogScript := preload("res://scripts/systems/site_catalog.gd")
const SaleSystemScript := preload("res://scripts/systems/sale_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")
const DistrictCatalogScript := preload("res://scripts/systems/district_catalog.gd")
const TerritorySystemScript := preload("res://scripts/systems/territory_system.gd")
const RivalSystemScript := preload("res://scripts/systems/rival_system.gd")
const LaunderingSystemScript := preload("res://scripts/systems/laundering_system.gd")
const BlackSpendingSystemScript := preload("res://scripts/systems/black_spending_system.gd")
const PoliceSystemScript := preload("res://scripts/systems/police_system.gd")
const JusticeSystemScript := preload("res://scripts/systems/justice_system.gd")
const DoubleLifeSystemScript := preload("res://scripts/systems/double_life_system.gd")

## Ort, an dem ein neues Spiel beginnt.
const START_LOCATION := "home"

var activities := ActivityCatalogScript.new()
var events := EventCatalogScript.new()
var locations := LocationCatalogScript.new()
var appointments := AppointmentCatalogScript.new()
var formats := ContentFormatCatalogScript.new()
var equipment := EquipmentCatalogScript.new()
var company_types := CompanyTypeCatalogScript.new()
var obligations := ObligationCatalogScript.new()
## Tutorials (T.2)
var tutorials := TutorialCatalogScript.new()
## Regeln der Organisation (U.2)
var organisation := OrganisationRulesScript.new()
## Story-Aufträge (U.4)
var missions := MissionCatalogScript.new()
## Produkte der Unterwelt (U.5) – reine Spielwerte je Einheit
var products := ProductCatalogScript.new()
## Erfundene Lieferanten (U.6)
var suppliers := SupplierCatalogScript.new()
## Standorte der Unterwelt (U.8)
var sites := SiteCatalogScript.new()
## Verkaufsorte (U.9)
var sale_spots := SaleSystemScript.Catalog.new()
## Crew-Regeln und Rollen (U.10)
var crew := CrewSystemScript.Catalog.new()
## Gebiete (U.12)
var districts := DistrictCatalogScript.new()
## Gebietsregeln (U.13)
var territory := TerritorySystemScript.Rules.new()
## Rivalen (U.14)
var rivals := RivalSystemScript.Catalog.new()
## Waschregeln (U.16)
var laundering := LaunderingSystemScript.Rules.new()
## Regeln fürs Schwarzgeld-Ausgeben (U.17)
var black_spending := BlackSpendingSystemScript.Rules.new()
## Polizeiregeln (U.19)
var police := PoliceSystemScript.Rules.new()
## Justizregeln (U.21)
var justice := JusticeSystemScript.Rules.new()
## Doppelleben (U.22)
var double_life := DoubleLifeSystemScript.Rules.new()

var errors: PackedStringArray = []
## Kennung der geladenen Datendateien (MD5 über alle Inhalte, Phase 6) – steht im Spielstand-Kopf,
## damit sich später erkennen lässt, mit welchen Daten ein Stand gespeichert wurde. "" = nicht aus Dateien.
var fingerprint := ""


## Lädt alle Standarddateien und prüft die Verweise. false = errors beschreibt alles.
func load_all() -> bool:
	errors.clear()
	var contents := ""
	for catalog in [activities, events, locations, appointments, formats, equipment, company_types, obligations,
			tutorials, organisation, missions, products, suppliers, sites, sale_spots, crew, districts, territory, rivals, laundering, black_spending, police, justice, double_life]:
		if not catalog.load_file():
			errors.append_array(catalog.errors)
		# Kataloge als innere Klasse (Verkaufsorte, Crew) haben ihren Pfad im äußeren Skript.
		var path: String = SaleSystemScript.DEFAULT_PATH if catalog == sale_spots \
				else CrewSystemScript.DEFAULT_PATH if catalog == crew \
				else TerritorySystemScript.DEFAULT_PATH if catalog == territory \
				else RivalSystemScript.DEFAULT_PATH if catalog == rivals \
				else LaunderingSystemScript.DEFAULT_PATH if catalog == laundering \
				else BlackSpendingSystemScript.DEFAULT_PATH if catalog == black_spending \
				else PoliceSystemScript.DEFAULT_PATH if catalog == police \
				else JusticeSystemScript.DEFAULT_PATH if catalog == justice \
				else DoubleLifeSystemScript.DEFAULT_PATH if catalog == double_life else catalog.DEFAULT_PATH
		contents += FileAccess.get_file_as_string(path)
	fingerprint = contents.md5_text()
	if errors.is_empty():
		errors.append_array(check_references())
	return errors.is_empty()


## Verweise zwischen Katalogen. Leere Liste = alles in Ordnung.
func check_references() -> PackedStringArray:
	var problems := PackedStringArray()
	if not locations.has(START_LOCATION):
		problems.append("Startort '%s' fehlt in den Ortsdaten." % START_LOCATION)
	for id in activities.get_ids():
		var location := activities.get_definition(id).location
		if not locations.has(location):
			problems.append("Aktivität '%s': unbekannter Ort '%s'." % [id, location])
	for id in formats.get_ids():
		var location := formats.get_definition(id).location
		if not locations.has(location):
			problems.append("Format '%s': unbekannter Ort '%s'." % [id, location])
	for id in equipment.get_ids():
		var item := equipment.get_definition(id)
		if not locations.has(item.location):
			problems.append("Ausrüstung '%s': unbekannter Ort '%s'." % [id, item.location])
		for format_id in item.formats:
			if not formats.has(format_id):
				problems.append("Ausrüstung '%s': unbekanntes Format '%s'." % [id, format_id])
	for id in company_types.get_ids():
		var company_type := company_types.get_definition(id)
		if not locations.has(company_type.found_location):
			problems.append("Unternehmensart '%s': unbekannter Ort '%s'." % [id, company_type.found_location])
		if company_type.has_branch and not locations.has(company_type.branch_location):
			problems.append("Unternehmensart '%s': unbekannter Ort der Filiale '%s'." % [id, company_type.branch_location])
	for appointment in appointments.get_all():
		if not locations.has(appointment.location):
			problems.append("Termin '%s': unbekannter Ort '%s'." % [appointment.id, appointment.location])
	# U.4: Ziele der Aufträge verweisen auf bestehende Orte.
	for definition in missions.get_all():
		if definition.goal.get("type") == MissionCatalogScript.GOAL_OWN_SITE \
				and definition.goal["site_type"] not in SiteCatalogScript.TYPES:
			problems.append("Auftrag '%s': unbekannter Standorttyp '%s'." % [definition.id, definition.goal["site_type"]])
		if definition.goal.get("type") == MissionCatalogScript.GOAL_VISIT_LOCATION \
				and not locations.has(definition.goal["location"]):
			problems.append("Auftrag '%s': unbekannter Ort '%s'." % [definition.id, definition.goal["location"]])
	# U.8: Standorte verweisen auf Orte, Aufträge und andere Standorte.
	for site in sites.get_all():
		if not locations.has(site.location):
			problems.append("Standort '%s': unbekannter Ort '%s'." % [site.id, site.location])
		if not missions.has(site.unlocked_by_mission):
			problems.append("Standort '%s': unbekannter Auftrag '%s'." % [site.id, site.unlocked_by_mission])
		for required in site.requires:
			if not sites.has(required):
				problems.append("Standort '%s': unbekannter Standort '%s' in 'requires'." % [site.id, required])
	# U.14: Rivalen – Freischalt-Auftrag, Reviere, „Ärger“-Ereignisse (vom Spiel ausgelöst).
	if not missions.has(rivals.unlocked_by_mission):
		problems.append("Rivalen: unbekannter Auftrag '%s'." % rivals.unlocked_by_mission)
	for gang in rivals.get_all():
		for district in gang.districts:
			if districts.get_definition(district) == null:
				problems.append("Bande '%s': unbekanntes Gebiet '%s'." % [gang.id, district])
		var clash = events.get_definition(gang.clash_event)
		if clash == null or not clash.is_scripted:
			problems.append("Bande '%s': Ereignis '%s' fehlt oder ist nicht „scripted“." % [gang.id, gang.clash_event])
	# U.15: Crew-Vorfälle brauchen ihre Ereignisse („scripted“).
	for event_id in CrewSystemScript.INCIDENT_EVENTS.values():
		var incident = events.get_definition(event_id)
		if incident == null or not incident.is_scripted:
			problems.append("Crew: Ereignis '%s' fehlt oder ist nicht „scripted“." % event_id)
	# Nachtrag U.20: Gebiete nennen bekannte Orte, jeder Ort höchstens einmal.
	var placed := {}
	for district in districts.get_all():
		for location_id in district.locations:
			if not locations.has(location_id):
				problems.append("Gebiet '%s': unbekannter Ort '%s'." % [district.id, location_id])
			if placed.has(location_id):
				problems.append("Ort '%s' steht in zwei Gebieten." % location_id)
			placed[location_id] = true
	# U.21: Justiz-Ereignisse („scripted“) und die Haftanstalt.
	for event_id in JusticeSystemScript.EVENTS.values():
		var justice_event = events.get_definition(event_id)
		if justice_event == null or not justice_event.is_scripted:
			problems.append("Justiz: Ereignis '%s' fehlt oder ist nicht „scripted“." % event_id)
	if not locations.has(JusticeSystemScript.PRISON) or not locations.has(JusticeSystemScript.HOME):
		problems.append("Justiz: Orte 'prison' und 'home' fehlen.")
	# U.19: Polizei-Ereignisse („scripted“).
	for event_id in PoliceSystemScript.EVENTS.values():
		var police_event = events.get_definition(event_id)
		if police_event == null or not police_event.is_scripted:
			problems.append("Polizei: Ereignis '%s' fehlt oder ist nicht „scripted“." % event_id)
	# U.18: Produktion verweist auf ein Produkt.
	for site in sites.get_all():
		if not site.product.is_empty() and products.get_definition(site.product) == null:
			problems.append("Standort '%s': unbekanntes Produkt '%s'." % [site.id, site.product])
	# U.10: Crew-Freischaltung und Rollen in Auftragszielen.
	if not missions.has(crew.unlocked_by_mission):
		problems.append("Crew: unbekannter Auftrag '%s'." % crew.unlocked_by_mission)
	for definition in missions.get_all():
		if definition.goal.get("type") == "crew_role" and not crew.has_role(definition.goal["role"]):
			problems.append("Auftrag '%s': unbekannte Rolle '%s'." % [definition.id, definition.goal["role"]])
	# U.9: Verkaufsorte verweisen auf Orte und Aufträge.
	for spot in sale_spots.get_all():
		if not locations.has(spot.location):
			problems.append("Verkaufsort '%s': unbekannter Ort '%s'." % [spot.id, spot.location])
		if not missions.has(spot.unlocked_by_mission):
			problems.append("Verkaufsort '%s': unbekannter Auftrag '%s'." % [spot.id, spot.unlocked_by_mission])
	# U.8: Orte, die erst ein Auftrag bekannt macht.
	for id in locations.get_ids():
		var mission_id: String = locations.get_definition(id).unlocked_by_mission
		if not mission_id.is_empty() and not missions.has(mission_id):
			problems.append("Ort '%s': unbekannter Auftrag '%s'." % [id, mission_id])
	# U.6: Lieferanten verweisen auf Produkte und den Auftrag, der sie freischaltet.
	for supplier in suppliers.get_all():
		for product_id in supplier.products:
			if not products.has(product_id):
				problems.append("Lieferant '%s': unbekanntes Produkt '%s'." % [supplier.id, product_id])
		if not missions.has(supplier.unlocked_by_mission):
			problems.append("Lieferant '%s': unbekannter Auftrag '%s'." % [supplier.id, supplier.unlocked_by_mission])
		if not supplier.credit.is_empty():
			var pressure = events.get_definition(supplier.credit["pressure_event"])
			if pressure == null or not pressure.is_scripted:
				problems.append("Lieferant '%s': Druck-Ereignis '%s' fehlt oder ist nicht „scripted“." % [supplier.id,
						supplier.credit["pressure_event"]])
	# U.3: Der Einstieg in die Unterwelt braucht ein vom Spiel ausgelöstes Ereignis mit der Annehmen-Option.
	var intro = events.get_definition(organisation.intro_event)
	if intro == null or not intro.is_scripted:
		problems.append("Organisation: Einstiegs-Ereignis '%s' fehlt oder ist nicht „scripted“." % organisation.intro_event)
	elif intro.options.filter(func(option) -> bool: return option.id == organisation.intro_accept_option).is_empty():
		problems.append("Organisation: Einstiegs-Ereignis ohne Option '%s'." % organisation.intro_accept_option)
	return problems
