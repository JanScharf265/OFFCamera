extends "res://tests/base_test.gd"

## Ticket G5.1b: Ladebildschirm – endet im Hauptmenü, Fortschritt steigt nur, Fehlerfall zeigt eine Meldung.
## (Layout auf allen Geräteklassen: test_touch_and_fonts.gd.)

const LoadingScene := preload("res://scenes/boot/loading.tscn")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")

const SAVE_PATH := "user://test_loading_save.json"
const SETTINGS_PATH := "user://test_loading_settings.cfg"

var _app: Node


func _screen() -> Control:
	var screen := LoadingScene.instantiate() as Control
	screen.set("app_save_path", SAVE_PATH)
	screen.set("app_settings_path", SETTINGS_PATH)
	screen.set("animate", false)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.connect("handed_over", func(app: Node) -> void: _app = app)
	return screen


func test_loading_ends_in_main_menu() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	_app = null
	var screen := _screen()
	screen.call("run_to_end")
	assert_eq(screen.get("done"), true)
	assert_eq(screen.get("error_message"), "")
	assert_true(_app != null, "keine Übergabe an die App")
	if _app != null:
		assert_true(_app.find_child("NewGameButton", true, false) != null, "Hauptmenü fehlt")
		assert_true(_app.get("preloaded_data") != null, "Spieldaten nicht übergeben")
		assert_true((_app.get("preloaded_resources") as Array).size() > 10, "Kartengrafiken nicht vorgeladen")
		_app.free()
	if is_instance_valid(screen):
		screen.free()


func test_progress_only_rises_to_100() -> void:
	var screen := _screen()
	var seen_steps := []
	screen.connect("step_started", func(step_id: String) -> void: seen_steps.append(step_id))
	screen.call("run_to_end")
	var log: Array = screen.get("progress_log")
	assert_true(log.size() >= 4, "zu wenige Fortschrittswerte: %s" % [log])
	for i in range(1, log.size()):
		assert_true(log[i] >= log[i - 1], "Fortschritt rückwärts: %s" % [log])
	assert_eq(log[log.size() - 1], 1.0)
	assert_eq(seen_steps, ["scene", "data", "map", "app", "warmup", "save"])
	if _app != null and is_instance_valid(_app):
		_app.free()
	if is_instance_valid(screen):
		screen.free()


func test_failed_step_shows_message_instead_of_hanging() -> void:
	_app = null
	var screen := _screen()
	screen.set("app_scene_path", "res://gibt_es_nicht.tscn")
	screen.call("run_to_end", 3000)
	assert_eq(screen.get("done"), false)
	var message: String = screen.get("error_message")
	assert_true(message.begins_with("Das Spiel konnte nicht geladen werden"), message)
	assert_eq((screen.find_child("ErrorLabel", false, false) as Label).visible, true)
	assert_true(_app == null, "trotz Fehler übergeben")
	screen.free()


## G5.1c: App und Probe-Spielbildschirm entstehen VERDECKT unter dem Ladebildschirm; danach ist nur die App übrig.
func test_app_and_warmup_are_built_below_the_loading_screen() -> void:
	_app = null
	var screen := _screen()
	var root := screen.get_parent()
	var seen := {"app_below": false, "warmup_gone": false}  # Lambdas kopieren lokale Variablen – daher ein Dictionary
	screen.connect("step_started", func(step_id: String) -> void:
		var app = screen.get("_app")
		if step_id == "warmup" and app != null:
			seen["app_below"] = app.get_index() < screen.get_index()
		if step_id == "save":
			seen["warmup_gone"] = root.find_child("WarmupGameScreen", false, false) == null)
	for i in 5000:
		screen.call("advance")
		OS.delay_msec(1)  # Laden im Hintergrund braucht echte Zeit
		var warm := root.find_child("WarmupGameScreen", false, false)
		if warm != null:
			assert_true(warm.get_index() < screen.get_index(), "Probe-Spielbildschirm liegt über dem Ladebildschirm")
		if screen.get("done"):
			break
	assert_true(seen["app_below"], "App nicht unter dem Ladebildschirm")
	assert_true(seen["warmup_gone"], "Probe-Spielbildschirm nach dem Aufwärmen nicht entfernt")
	assert_true(_app != null and _app.find_child("NewGameButton", true, false) != null, "Hauptmenü fehlt")
	if _app != null:
		_app.free()
	if is_instance_valid(screen):
		screen.free()


## G5.1c: Mit Blende bleibt der Ladebildschirm mindestens MIN_VISIBLE_SECONDS sichtbar – nicht länger als nötig.
func test_loading_screen_stays_at_least_min_time() -> void:
	_app = null
	var screen := _screen()
	screen.set("animate", true)
	screen.call("run_to_end")
	assert_eq(screen.get("done"), true)
	var elapsed := 0.0
	while _app == null and elapsed < 3.0:
		screen.call("_process", 0.05)
		elapsed += 0.05
	var minimum: float = screen.get("MIN_VISIBLE_SECONDS")
	assert_true(elapsed >= minimum - 0.06, "zu früh übergeben: %.2f s" % elapsed)
	assert_true(elapsed <= minimum + 0.11, "zu lange gewartet: %.2f s" % elapsed)
	if _app != null:
		_app.free()
	if is_instance_valid(screen):
		screen.free()
