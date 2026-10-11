extends "res://tests/base_test.gd"

## Texte und ein Durchklick-Test der App ohne Fenster.

const AppScript := preload("res://scripts/ui/app.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


func test_format_duration() -> void:
	assert_eq(TimeSystemScript.format_duration(45), "45 min")
	assert_eq(TimeSystemScript.format_duration(60), "1 h")
	assert_eq(TimeSystemScript.format_duration(90), "1 h 30 min")


func test_format_stamp() -> void:
	assert_eq(TimeSystemScript.format_stamp(TimeSystemScript.at(2, 14, 5)), "Tag 2 · 14:05")


func test_activity_summaries() -> void:
	var catalog := ActivityCatalogScript.new()
	catalog.load_file()
	assert_eq(ActivityText.summary(catalog.get_definition("stream_short")), "2 h · Energie -20 · Stimmung +5 · +25,00 €")
	assert_eq(ActivityText.summary(catalog.get_definition("rest")), "1 h · Energie +15 · Stimmung +3")
	assert_eq(ActivityText.summary(catalog.get_definition("eat_out")), "1 h · Energie +10 · Stimmung +5 · -15,00 €")


func test_click_through_new_game_activity_menu_and_continue() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var app := AppScript.new()
	tree.root.add_child(app)

	var new_game := _find(app, "NewGameButton") as Button
	assert_true(new_game != null, "NewGameButton fehlt")
	assert_true(_find(app, "ContinueButton") == null, "Fortsetzen darf ohne Spiel nicht da sein")
	if new_game == null:
		app.free()
		return
	new_game.pressed.emit()

	assert_eq((_find(app, "ClockLabel") as Label).text, "08:00")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 500,00 €")

	(_find(app, "StartButton_stream_short") as Button).pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:00")
	assert_eq((_find(app, "BalanceLabel") as Label).text, "Konto: 525,00 €")
	assert_eq(app.game.ledger.get_entries().size(), 1)
	assert_eq((_find(app, "LedgerList") as Node).get_child_count(), 1)

	(_find(app, "MenuButton") as Button).pressed.emit()
	var continue_button := _find(app, "ContinueButton") as Button
	assert_true(continue_button != null, "Fortsetzen fehlt nach dem ersten Spiel")
	continue_button.pressed.emit()
	assert_eq((_find(app, "ClockLabel") as Label).text, "10:00")

	app.free()


func test_disabled_activity_shows_reason() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var app := AppScript.new()
	tree.root.add_child(app)
	(_find(app, "NewGameButton") as Button).pressed.emit()

	app.game.stats.apply({"energy": -75})  # 80 -> 5
	(_find(app, "StartButton_rest") as Button).pressed.emit()  # 5 -> 20, aktualisiert die Anzeige
	app.game.stats.apply({"energy": -5})  # 20 -> 15
	(_find(app, "StartButton_rest") as Button).pressed.emit()  # 15 -> 30
	assert_eq((_find(app, "StartButton_stream_short") as Button).disabled, false)

	app.game.stats.apply({"energy": -20})  # 30 -> 10
	(_find(app, "MenuButton") as Button).pressed.emit()
	(_find(app, "ContinueButton") as Button).pressed.emit()
	assert_eq((_find(app, "StartButton_stream_short") as Button).disabled, true)

	app.free()


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
