extends "res://tests/base_test.gd"

## Ticket G5.7: „Hinfahren und starten“ – Fahrt + Aktion genau einmal über die normalen Systeme; Prüfung für die
## Gesamtzeit (Öffnungszeiten bei Ankunft, Geld, Energie, fehlende Firma vor „Nur vor Ort“); Konflikt-Popup mit
## Gesamtzeit; scheitert die Aktion nach der Fahrt, ist man trotzdem angekommen.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const TripSystemScript := preload("res://scripts/systems/trip_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const ACTIVITY := TripSystemScript.KIND_ACTIVITY
const CONTENT := TripSystemScript.KIND_CONTENT
const SAVE_PATH := "user://test_trips_save.json"


func _game_at(hour: int, minute: int = 0) -> GameStateScript:
	var game := Helpers.new_game()  # Wohnung
	game.time.advance(TimeSystemScript.at(1, hour, minute) - game.time.get_minutes())
	return game


func _snapshot(game: GameStateScript) -> Dictionary:
	return {"minutes": game.time.get_minutes(), "location": game.locations.get_current(), "energy": game.stats.energy,
			"mood": game.stats.mood, "entries": game.ledger.get_entries().size(), "balance": game.ledger.get_balance(),
			"followers": game.channel.followers}


# --- System ---------------------------------------------------------------------------

func test_trip_runs_travel_and_action_exactly_once() -> void:
	var game := _game_at(10)
	var before := _snapshot(game)
	var travel: int = game.trips.travel_minutes(ACTIVITY, "training")
	assert_true(travel > 0)
	assert_eq(game.trips.offers(ACTIVITY, "training"), true)
	assert_eq(game.trips.check(ACTIVITY, "training"), "")
	assert_eq(game.trips.total_minutes(ACTIVITY, "training"), travel + 90)
	var traveled := []
	var done := []
	game.locations.traveled.connect(func(_from: String, to: String) -> void: traveled.append(to))
	game.activities.activity_completed.connect(func(id: String) -> void: done.append(id))
	assert_eq(game.trips.run(ACTIVITY, "training"), {"arrived": true, "reason": ""})
	assert_eq(traveled, ["gym"])
	assert_eq(done, ["training"])
	assert_eq(game.locations.get_current(), "gym")
	assert_eq(game.time.get_minutes(), before["minutes"] + travel + 90)
	assert_eq(game.stats.energy, before["energy"] - 15)
	assert_eq(game.stats.mood, before["mood"] + 10)
	assert_eq(game.ledger.get_entries().size(), before["entries"], "Training kostet nichts, Fahrt auch nicht")
	# Ein zweites Mal ist es keine Kombi mehr (man ist dort) – nichts passiert.
	var after := _snapshot(game)
	assert_eq(game.trips.offers(ACTIVITY, "training"), false)
	assert_eq(game.trips.run(ACTIVITY, "training")["arrived"], false)
	assert_eq(_snapshot(game), after)
	assert_eq(done, ["training"])


func test_content_trip_produces_once() -> void:
	var game := _game_at(10)
	var followers := game.channel.followers
	assert_eq(game.trips.run(CONTENT, "livestream")["reason"], "")
	assert_eq(game.locations.get_current(), "studio")
	assert_eq(game.time.format_clock(), "12:20")
	assert_true(game.channel.followers > followers, "Livestream lief nicht")


func test_closed_on_arrival_is_locked_without_change() -> void:
	# Büro schließt um 18:00: 17:30 noch offen, aber Fahrt + 1 h Wochenplanung gehen darüber hinaus.
	var game := _game_at(17, 30)
	var before := _snapshot(game)
	var reason: String = game.trips.check(ACTIVITY, "plan_week")
	assert_true(reason.begins_with("Büro schließt vorher"), reason)
	assert_eq(game.trips.run(ACTIVITY, "plan_week"), {"arrived": false, "reason": reason})
	assert_eq(_snapshot(game), before)
	# Bei Ankunft schon zu: 17:55 + Fahrt → nach 18:00.
	var late := _game_at(17, 55)
	reason = late.trips.check(ACTIVITY, "plan_week")
	assert_true(reason.begins_with("Büro ist geschlossen"), reason)


func test_missing_company_comes_before_only_on_site() -> void:
	var game := _game_at(10)
	var before := _snapshot(game)
	assert_eq(game.activities.check("merch_shoutout"), "Nur vor Ort möglich: Studio.", "vor Ort-Prüfung unverändert")
	assert_eq(game.trips.check(ACTIVITY, "merch_shoutout"), "Erst ein Unternehmen gründen (im Büro).")
	assert_eq(game.trips.run(ACTIVITY, "merch_shoutout")["arrived"], false)
	assert_eq(_snapshot(game), before)


func test_too_little_energy_or_money_is_locked() -> void:
	var game := _game_at(10)
	game.stats.energy = 10
	assert_eq(game.trips.check(CONTENT, "livestream"), "Zu wenig Energie (benötigt 20).")
	var poor := _game_at(10)
	assert_true(poor.ledger.post(-(poor.ledger.get_balance() - 100), "misc", "Test: fast pleite", "test") != null)
	var before := _snapshot(poor)
	assert_eq(poor.trips.check(ACTIVITY, "eat_out"), "Nicht genug Geld (kostet 15,00 €).")
	assert_eq(poor.trips.run(ACTIVITY, "eat_out")["arrived"], false)
	assert_eq(_snapshot(poor), before)


func test_action_failing_after_travel_still_arrives() -> void:
	var game := _game_at(10)
	var travel: int = game.trips.travel_minutes(CONTENT, "livestream")
	# Etwas während der Fahrt (hier künstlich) nimmt die Energie – der Livestream scheitert danach.
	game.locations.traveled.connect(func(_from: String, _to: String) -> void: game.stats.energy = 0)
	var result: Dictionary = game.trips.run(CONTENT, "livestream")
	assert_eq(result, {"arrived": true, "reason": "Zu wenig Energie (benötigt 20)."})
	assert_eq(game.locations.get_current(), "studio")
	assert_eq(game.time.get_minutes(), TimeSystemScript.at(1, 10) + travel)


func test_purchases_have_no_trip() -> void:
	var game := _game_at(10)
	assert_eq(game.trips.target_location("purchase", "camera"), "")
	assert_eq(game.trips.offers("purchase", "camera"), false)


# --- Spielansicht ---------------------------------------------------------------------

func _app() -> AppScript:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.new_game_seed = Helpers.TEST_SEED
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _done(app: AppScript) -> void:
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)


func _press(root: Node, node_name: String) -> void:
	var button := root.find_child(node_name, true, false) as Button
	assert_true(button != null, "%s fehlt" % node_name)
	if button != null:
		button.pressed.emit()


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func _app_at(hour: int, minute: int = 0) -> AppScript:
	var app := _app()
	_press(app, "NewGameButton")
	app.game.time.advance(TimeSystemScript.at(1, hour, minute) - app.game.time.get_minutes())
	return app


func test_tile_shows_trip_with_total_time() -> void:
	var app := _app_at(10)
	_press(app, "MapPin_studio")
	var button := _find(app, "ContentButton_livestream") as Button
	assert_eq(button.text, "Hinfahren und starten")
	assert_eq(button.disabled, false)
	assert_true(button.icon != null, "Auto-Symbol fehlt im Button")
	assert_eq((_find(app, "TileTime_livestream") as Label).text, "20 min + 2 h")
	assert_eq((_find(app, "TileTripIcon_livestream") as Control).visible, true)
	assert_eq((_find(app, "TileHint_livestream") as Label).text, "Ende 12:20")
	# Käufe: kein Kombi-Button.
	assert_eq((_find(app, "EquipmentButton_camera") as Button).text, "Nur vor Ort erhältlich: Studio.")
	# Firma fehlt: dieser Grund statt „Nur vor Ort“.
	assert_eq((_find(app, "StartButton_merch_shoutout") as Button).text, "Erst ein Unternehmen gründen (im Büro).")
	_press(app, "ContentButton_livestream")
	assert_eq(app.game.locations.get_current(), "studio")
	assert_eq(app.game.time.format_clock(), "12:20")
	assert_true(_find(app, "ConflictPopup") == null, "Popup ohne Konflikt")
	assert_true((_find(app, "FeedbackLabel") as Label).text.begins_with("Angekommen: Studio · Livestream erledigt"))
	# Jetzt vor Ort: normaler Button.
	assert_eq((_find(app, "ContentButton_livestream") as Button).text, "Produzieren")
	assert_eq((_find(app, "TileTripIcon_livestream") as Control).visible, false)
	_done(app)


## 12:50 zu Hause: Community-Q&A (1 h) allein endete 13:50 – mit 20 min Fahrt erst 14:10 → Konflikt mit 14:00.
func test_conflict_uses_total_time_and_cancel_changes_nothing() -> void:
	var app := _app_at(12, 50)
	_press(app, "MapPin_studio")
	assert_eq((_find(app, "TileHint_community_qa") as Label).text, "⚠ Verpasst: 14:00")
	var before := _snapshot(app.game)
	_press(app, "ContentButton_community_qa")
	assert_true(_find(app, "ConflictPopup") != null, "kein Konflikt-Popup für die Gesamtzeit")
	assert_eq((_find(app, "ConflictAction") as Label).text, "Fahrt nach Studio + Community-Q&A · 1 h 20 min · Ende 14:10")
	_press(app, "ConflictCancelButton")
	assert_eq(_snapshot(app.game), before)
	_press(app, "ContentButton_community_qa")
	_press(app, "ConflictConfirmButton")
	assert_eq(app.game.locations.get_current(), "studio")
	assert_eq(app.game.time.format_clock(), "14:10")
	assert_eq(app.game.appointments.is_missed("camera_meeting"), true)
	_done(app)


func test_closed_on_arrival_shows_reason_in_tile() -> void:
	var app := _app_at(17, 55)
	_press(app, "MapPin_office")
	var button := _find(app, "StartButton_plan_week") as Button
	assert_eq(button.disabled, true)
	assert_true(button.text.begins_with("Büro ist geschlossen"), button.text)
	_done(app)


func test_failure_after_travel_gives_clear_message() -> void:
	var app := _app_at(10)
	app.game.locations.traveled.connect(func(_from: String, _to: String) -> void: app.game.stats.energy = 0)
	_press(app, "MapPin_studio")
	_press(app, "ContentButton_livestream")
	assert_eq(app.game.locations.get_current(), "studio")
	assert_true((_find(app, "FeedbackLabel") as Label).text.begins_with(
			"Angekommen: Studio – aber Livestream: Zu wenig Energie (benötigt 20) – jetzt 10:20."),
			(_find(app, "FeedbackLabel") as Label).text)
	var saved = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(saved != null and saved.locations.get_current() == "studio", "Ankunft nicht gespeichert")
	_done(app)


func test_travel_button_differs_from_active_tab() -> void:
	var app := _app_at(10)
	_press(app, "MapPin_studio")
	var travel := _find(app, "TravelButton") as Button
	assert_true(travel.icon != null, "Auto-Symbol fehlt")
	var box := travel.get_theme_stylebox("normal") as StyleBoxFlat
	assert_true(box.bg_color != UiStyle.ACCENT, "Hinfahren gefüllt wie der aktive Reiter")
	assert_eq(box.border_color, UiStyle.ACCENT)
	_done(app)
