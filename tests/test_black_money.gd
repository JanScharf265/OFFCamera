extends "res://tests/base_test.gd"

## Ticket U.1: Schwarzgeld als drittes Konto – Migration v15 → v16, Anzeige in der HUD-Leiste und im Buchungen-Fenster
## erst, wenn es welches gibt; mit Firma + Schwarzgeld passt die Leiste auf alle 4 Geräteklassen.

const Layout := preload("res://tests/layout_helper.gd")
const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SAVE_PATH := "user://test_black_money_save.json"
const BLACK := LedgerSystemScript.BLACK


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_press(app, "NewGameButton")
	app.find_child("CityMap", true, false).get_parent().call("close_tutorial")
	return app


func _screen(app: AppScript) -> Control:
	return app.find_child("CityMap", true, false).get_parent() as Control


func test_migration_15_to_16_adds_empty_black_account() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v15.json"))
	file.close()
	var result := SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)
	var game = result["game"]
	assert_true(game != null, "v15 lädt nicht: %s" % result["error"])
	if game != null:
		assert_eq(game.ledger.get_balance(BLACK), 0)
		assert_eq(game.ledger.get_opening_balance(BLACK), 0)
		assert_eq(game.ledger.is_account_used(BLACK), false)
		var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v15.expect.json"))
		assert_eq(game.ledger.get_balance(), int(expect["private_balance_cents"]), "Privatkonto unverändert")
	assert_true(not SaveSystemScript._run_migration(15, {"ledger": "kaputt"}).is_empty(), "kaputtes Ledger angenommen")
	SaveSystemScript.delete_save(SAVE_PATH)


func test_hud_shows_black_money_only_when_used() -> void:
	var app := _app()
	var block := app.find_child("BlackBlock", true, false) as Control
	assert_eq(block.visible, false, "ohne Schwarzgeld sichtbar")
	app.game.ledger.post(123400, "test", "Test", "test", "", "", false, BLACK)
	Layout.apply(app, "iPhone 15/16 Pro Max (Dynamic Island)")
	_screen(app).call("_refresh")
	assert_eq(block.visible, true)
	assert_eq((app.find_child("BlackBalanceLabel", true, false) as Label).text, "1.234,00 €")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


## Ungünstigster Fall: Firma gegründet und Schwarzgeld – alles in einer Leiste, nichts abgeschnitten, in der Safe Area.
func test_hud_with_all_accounts_fits_every_device() -> void:
	var levels := {}
	for device in Layout.DEVICES:
		var app := _app()
		app.game.locations.travel("office")
		assert_eq(app.game.company.found("merch_label"), "")
		app.game.ledger.post(9999999, "test", "Test", "test", "", "", false, BLACK)  # 99.999,99 €
		assert_eq(app.game.organisation.found("Los Testigos"), "")  # U.2: Hitze dazu
		app.game.organisation.change({"heat": 100})
		_screen(app).call("_refresh")
		Layout.apply(app, device)
		var hud := app.find_child("HudBar", true, false) as Control
		Layout.settle_in_place(hud)
		assert_true(hud.get_combined_minimum_size().x <= hud.size.x + 0.5, "%s: Leiste zu breit (%d > %d)" % [device,
				hud.get_combined_minimum_size().x, hud.size.x])
		assert_true(Layout.safe_rect(device).grow(0.5).encloses(Layout.rect_of(hud)), "%s: Leiste außerhalb %s / safe %s / min %d" % [
				device, Layout.rect_of(hud), Layout.safe_rect(device), hud.get_combined_minimum_size().x])
		levels[device] = hud.call("get_compact_level")
		for name in ["BalanceLabel", "CompanyBalanceLabel", "BlackBalanceLabel", "HeatValue"]:
			var label := app.find_child(name, true, false) as Label
			assert_true(label.is_visible_in_tree(), "%s: %s nicht sichtbar" % [device, name])
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					label.get_theme_font_size("font_size")).x
			assert_true(width <= label.size.x + 0.5, "%s: „%s“ abgeschnitten" % [device, label.text])
		app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	print("          Verdichtung der HUD-Leiste je Gerät: %s" % levels)
	# Ohne Schwarzgeld und Firma bleibt die Leiste überall vollständig.
	var plain := _app()
	for device in Layout.DEVICES:
		Layout.apply(plain, device)
		_screen(plain).call("_layout")
		assert_eq(plain.find_child("HudBar", true, false).call("get_compact_level"), 0, "%s: ohne Not verdichtet" % device)
	plain.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ledger_window_shows_black_money_when_used() -> void:
	var app := _app()
	_press(app, "LedgerButton")
	assert_eq((app.find_child("LedgerFilter_black", true, false) as Control).visible, false, "Filter ohne Schwarzgeld")
	assert_true(not (app.find_child("LedgerBalances", true, false) as Label).text.contains("Schwarzgeld"))
	_press(app, "WindowCloseButton")
	app.game.ledger.post(50000, "test", "Test: Einnahme", "test", "", "", false, BLACK)
	_screen(app).call("_refresh")
	_screen(app).call("close_tutorial")
	_press(app, "LedgerButton")
	_screen(app).call("close_tutorial")
	assert_true((app.find_child("LedgerBalances", true, false) as Label).text.contains("Schwarzgeld: 500,00 €"))
	assert_true(app.find_child("LedgerWeek_1_black", true, false) != null, "Wochenübersicht ohne Schwarzgeld")
	_press(app, "LedgerFilter_black")
	var texts := []
	for label in app.find_child("LedgerList", true, false).find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.size() == 2 and String(texts[0]).ends_with("Test: Einnahme (Schwarz)"), str(texts))
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
