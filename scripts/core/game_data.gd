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

## Ort, an dem ein neues Spiel beginnt.
const START_LOCATION := "home"

var activities := ActivityCatalogScript.new()
var events := EventCatalogScript.new()
var locations := LocationCatalogScript.new()
var appointments := AppointmentCatalogScript.new()
var formats := ContentFormatCatalogScript.new()
var equipment := EquipmentCatalogScript.new()

var errors: PackedStringArray = []


## Lädt alle Standarddateien und prüft die Verweise. false = errors beschreibt alles.
func load_all() -> bool:
	errors.clear()
	for catalog in [activities, events, locations, appointments, formats, equipment]:
		if not catalog.load_file():
			errors.append_array(catalog.errors)
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
	for appointment in appointments.get_all():
		if not locations.has(appointment.location):
			problems.append("Termin '%s': unbekannter Ort '%s'." % [appointment.id, appointment.location])
	return problems
