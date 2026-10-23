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

var errors: PackedStringArray = []
## Kennung der geladenen Datendateien (MD5 über alle Inhalte, Phase 6) – steht im Spielstand-Kopf,
## damit sich später erkennen lässt, mit welchen Daten ein Stand gespeichert wurde. "" = nicht aus Dateien.
var fingerprint := ""


## Lädt alle Standarddateien und prüft die Verweise. false = errors beschreibt alles.
func load_all() -> bool:
	errors.clear()
	var contents := ""
	for catalog in [activities, events, locations, appointments, formats, equipment, company_types, obligations,
			tutorials, organisation, missions, products, suppliers]:
		if not catalog.load_file():
			errors.append_array(catalog.errors)
		contents += FileAccess.get_file_as_string(catalog.DEFAULT_PATH)
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
		if definition.goal.get("type") == MissionCatalogScript.GOAL_VISIT_LOCATION \
				and not locations.has(definition.goal["location"]):
			problems.append("Auftrag '%s': unbekannter Ort '%s'." % [definition.id, definition.goal["location"]])
	# U.6: Lieferanten verweisen auf Produkte und den Auftrag, der sie freischaltet.
	for supplier in suppliers.get_all():
		for product_id in supplier.products:
			if not products.has(product_id):
				problems.append("Lieferant '%s': unbekanntes Produkt '%s'." % [supplier.id, product_id])
		if not missions.has(supplier.unlocked_by_mission):
			problems.append("Lieferant '%s': unbekannter Auftrag '%s'." % [supplier.id, supplier.unlocked_by_mission])
	# U.3: Der Einstieg in die Unterwelt braucht ein vom Spiel ausgelöstes Ereignis mit der Annehmen-Option.
	var intro = events.get_definition(organisation.intro_event)
	if intro == null or not intro.is_scripted:
		problems.append("Organisation: Einstiegs-Ereignis '%s' fehlt oder ist nicht „scripted“." % organisation.intro_event)
	elif intro.options.filter(func(option) -> bool: return option.id == organisation.intro_accept_option).is_empty():
		problems.append("Organisation: Einstiegs-Ereignis ohne Option '%s'." % organisation.intro_accept_option)
	return problems
