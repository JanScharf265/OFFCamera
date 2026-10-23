extends "res://tests/base_test.gd"

## Ticket U.25: Reiter im Fenster „Organisation“ – drei Reiter mit festem Inhalt; nur der aktive ist sichtbar;
## öffnet auf „Geschäft“ oder auf dem Reiter mit einer fälligen Erklärung; passt auf beide iPhones.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const Layout := preload("res://tests/layout_helper.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const SAVE_PATH := "user://test_org_tabs_save.json"


func _app(tutorials: bool) -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_org_tabs_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", tutorials)
	if not tutorials:
		for definition in app.game.tutorials.get_catalog().get_all():
			app.game.tutorials.mark_seen(definition.id)
	screen.call("close_tutorial")
	screen.call("on_organisation_name_submitted", "Los Lobos")
	screen.call("_close_window")
	return app


func _cleanup(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_org_tabs_settings.cfg"))


func _visible(app: AppScript, node_name: String) -> bool:
	var node := app.find_child(node_name, true, false) as Control
	return node != null and node.is_visible_in_tree()


func test_tabs_and_content() -> void:
	var app := _app(false)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	var content := app.find_child("OrganisationContent", true, false)
	assert_eq(content.call("get_current_tab"), "business")
	assert_eq([_visible(app, "StockCapacity"), _visible(app, "PoliceStatus"), _visible(app, "OrganisationRow_heat")],
			[true, false, false])
	(app.find_child("OrgTab_people", true, false) as Button).pressed.emit()
	assert_eq([_visible(app, "StockCapacity"), _visible(app, "OrganisationRow_heat"), _visible(app, "ContactsButton")],
			[false, true, true])
	(app.find_child("OrgTab_police", true, false) as Button).pressed.emit()
	assert_eq([_visible(app, "PoliceStatus"), _visible(app, "DoubleLifeStatus"), _visible(app, "BlackSpendingToggle")],
			[true, true, true])
	_cleanup(app)


func test_opens_on_tab_with_due_tutorial() -> void:
	var app := _app(true)
	for definition in app.game.tutorials.get_catalog().get_all():
		if definition.id != "tut_police":
			app.game.tutorials.mark_seen(definition.id)
	var police: Dictionary = app.game.police.to_dict()
	police["level"] = 1
	app.game.police.restore(police)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq(app.find_child("OrganisationContent", true, false).call("get_current_tab"), "police")
	_cleanup(app)


func test_tabs_fit_every_device() -> void:
	for device in Layout.DEVICES:
		var app := _app(false)
		Layout.apply(app, device)
		(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
		var screen := app.find_child("CityMap", true, false).get_parent() as Control
		Layout.settle_in_place(screen.find_child("Window_organisation", false, false))
		var safe := Layout.safe_rect(device)
		for tab in ["business", "people", "police"]:
			var rect := Layout.screen_rect(app.find_child("OrgTab_%s" % tab, true, false) as Control, screen)
			assert_true(rect.size.y >= UiStyle.TOUCH_SIZE - 0.5, "%s: Reiter %s zu niedrig" % [device, tab])
			assert_true(safe.grow(0.5).encloses(rect), "%s: Reiter %s außerhalb" % [device, tab])
		_cleanup(app)
