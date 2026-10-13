extends "res://tests/base_test.gd"

## G4.6: Pflichtfeld "tab" (Reiter im Ortsfenster) in allen Daten, die Kacheln im Ortsfenster erzeugen.
## Fehlend oder unbekannt = Ladefehler, wie bei den anderen Feldern.

const LocationTabScript := preload("res://scripts/models/location_tab.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const ContentFormatCatalogScript := preload("res://scripts/systems/content_format_catalog.gd")
const EquipmentCatalogScript := preload("res://scripts/systems/equipment_catalog.gd")
const CompanyTypeCatalogScript := preload("res://scripts/systems/company_type_catalog.gd")

const CATALOGS := [
	[ActivityCatalogScript, "res://data/activities/activities.json"],
	[ContentFormatCatalogScript, "res://data/content/formats.json"],
	[EquipmentCatalogScript, "res://data/equipment/equipment.json"],
	[CompanyTypeCatalogScript, "res://data/company/company_types.json"],
]


func _real(path: String) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_real_data_has_valid_tabs() -> void:
	for pair in CATALOGS:
		var catalog = pair[0].new()
		assert_true(catalog.load_data(_real(pair[1])), "%s: %s" % [pair[1], "; ".join(catalog.errors)])
		for id in catalog.get_ids():
			assert_true(catalog.get_definition(id).tab in LocationTabScript.IDS, "%s: %s" % [pair[1], id])


func test_missing_tab_is_a_load_error() -> void:
	for pair in CATALOGS:
		var data := _real(pair[1])
		data[0].erase("tab")
		var catalog = pair[0].new()
		assert_eq(catalog.load_data(data), false, pair[1])
		assert_true("'tab' fehlt" in "; ".join(catalog.errors), "%s: %s" % [pair[1], "; ".join(catalog.errors)])


func test_unknown_tab_is_a_load_error() -> void:
	for pair in CATALOGS:
		var data := _real(pair[1])
		data[0]["tab"] = "freizeit"
		var catalog = pair[0].new()
		assert_eq(catalog.load_data(data), false, pair[1])
		assert_true("'tab' muss einer von" in "; ".join(catalog.errors), "%s: %s" % [pair[1], "; ".join(catalog.errors)])


func test_tab_assignment_of_real_data() -> void:
	var activities := ActivityCatalogScript.new()
	activities.load_data(_real("res://data/activities/activities.json"))
	for id in ["rest", "sleep", "eat_out", "coffee", "training", "plan_week"]:
		assert_eq(activities.get_definition(id).tab, "alltag", id)
	for id in ["order_stock", "plan_campaign", "merch_shoutout", "run_store"]:
		assert_eq(activities.get_definition(id).tab, "geschaeft", id)
