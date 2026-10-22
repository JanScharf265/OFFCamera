extends Control

## Ladebildschirm (G5.1b): erste, sehr leichte Szene. Sie erscheint sofort nach dem Startbild und lädt das
## eigentliche Spiel in Schritten – die App-Szene im Hintergrund (ResourceLoader.load_threaded_request),
## die Spieldaten, die Kartengrafiken (ebenfalls im Hintergrund) und den Kopf des Spielstands. Der Fortschritt
## kommt aus diesen Schritten (beim Laden im Hintergrund aus dem Fortschritt des ResourceLoaders) und läuft nie
## rückwärts. Aussehen „Kamera-Sucher“: Sucher-Ecken, blinkendes „● REC“, Aufnahmeleiste mit Prozent,
## Statuszeile; bei 100 % schließt sich das „Halbe Objektiv“ wie eine Blende, dann übernimmt die App.
## G5.1c: Die App (Hauptmenü) und ein Probe-Spielbildschirm mit Stadtkarte werden VERDECKT unter dem Ladebildschirm
## aufgebaut und ein paar Bilder lang gezeichnet – so passieren der erste Aufbau, das Packen des Kartenatlas und das
## erste Zeichnen (Shader, Schriften) hinter dem Balken. Am Ende entfernt sich der Ladebildschirm nur noch; die App
## ist dann schon gezeichnet. Steht er kürzer als MIN_VISIBLE_SECONDS, bleibt er bis dahin stehen (kein Aufblitzen).
## Schlägt ein Schritt fehl, erscheint eine verständliche Meldung (kein Hänger, kein Absturz).
## Zeitstempel jedes Schritts gehen ins Log („[Start] …“) – auf dem iPhone in der Xcode-Konsole lesbar.
## Absichtlich wenige Abhängigkeiten (nur UiStyle und SafeArea): alles Schwere lädt erst in den Schritten.

signal step_started(step_id: String)
## Nach der Übergabe an die App (app = die neue Szene).
signal handed_over(app: Node)
signal failed(message: String)

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SafeAreaScript := preload("res://scripts/ui/safe_area.gd")
const LENS := preload("res://assets/icons/lens_mark.svg")

const APP_SCENE := "res://scenes/app/app.tscn"
const GAME_DATA_SCRIPT := "res://scripts/core/game_data.gd"
const CITY_MAP_SCRIPT := "res://scripts/ui/city_map.gd"
const SAVE_SYSTEM_SCRIPT := "res://scripts/systems/save_system.gd"
const GAME_STATE_SCRIPT := "res://scripts/core/game_state.gd"
const GAME_SCREEN_SCRIPT := "res://scripts/ui/game_screen.gd"
const StartLog := preload("res://scripts/ui/start_log.gd")

## Schritte in Reihenfolge; weight = Anteil am Balken (Summe 100).
const STEPS := [
	{"id": "scene", "text": "Licht an …", "weight": 30},
	{"id": "data", "text": "Drehbuch wird gelesen …", "weight": 5},
	{"id": "map", "text": "Kulissen werden geladen …", "weight": 20},
	{"id": "app", "text": "Kamera läuft warm …", "weight": 20},
	{"id": "warmup", "text": "Marbella wird aufgebaut …", "weight": 20},
	{"id": "save", "text": "Spielstand wird geprüft …", "weight": 5},
]
## Bilder, die App bzw. Probe-Spielbildschirm verdeckt gezeichnet werden (je Bild ein Aufruf von advance()).
const WARM_FRAMES := 3
## Mindestdauer, die der Ladebildschirm sichtbar ist (inkl. Blende), damit er nicht nur aufblitzt (DECISIONS 052).
const MIN_VISIBLE_SECONDS := 0.8
const FAIL_TEXT := "Das Spiel konnte nicht geladen werden (%s).\nBitte schließe die App ganz und starte sie neu."

const REC_RED := Color("#FF3B5C")
const CORNER_LENGTH := 56.0
const CORNER_WIDTH := 4.0
const LENS_SIZE := 150.0
const BAR_HEIGHT := 12.0
const IRIS_SECONDS := 0.45
const BLINK_SECONDS := 0.5

## Für Tests: andere Szene (z. B. eine fehlende), Pfade für die App, Blende aus.
var app_scene_path := APP_SCENE
var app_save_path := ""
var app_settings_path := ""
var animate := true

## 0..1, steigt nur.
var progress := 0.0
## Jeder neue Fortschrittswert (für Tests: nie rückwärts).
var progress_log: Array[float] = []
var done := false
var error_message := ""

var _step := 0
var _step_running := false
var _scene: PackedScene
var _data
var _texture_paths: PackedStringArray = []
## Vorab geladene Ressourcen – gehen an die App, damit sie im Cache bleiben.
var _resources: Array = []
var _margins: Array[float] = [24.0, 24.0, 24.0, 24.0]
## Verdeckt aufgebaute App (wird am Ende sichtbar) und Probe-Spielbildschirm (nur zum Aufwärmen).
var _app: Node
var _warmup: Control
var _warm_ticks := 0
var _elapsed := 0.0
var _iris := -1.0
var _logged_first_frame := false

var _rec_label: Label
var _timecode_label: Label
var _status_label: Label
var _percent_label: Label
var _error_label: Label


func _ready() -> void:
	name = "LoadingScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log("Ladebildschirm bereit")
	_rec_label = _label("RecLabel", "REC", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	_timecode_label = _label("TimecodeLabel", "00:00:00", UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	_status_label = _label("StatusLabel", "", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_label = _label("PercentLabel", "0 %", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_error_label = _label("ErrorLabel", "", UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	resized.connect(_layout)
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()
	RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_elapsed += delta
	_timecode_label.text = "00:00:%02d" % mini(int(_elapsed), 59)
	if _iris >= 0.0:
		_iris = minf(_iris + delta / IRIS_SECONDS, 1.0)
		if _iris >= 1.0:
			_hand_over()
	elif done and animate:
		# Fertig: Blende erst, wenn der Ladebildschirm mit ihr zusammen MIN_VISIBLE_SECONDS stand.
		if _elapsed >= MIN_VISIBLE_SECONDS - IRIS_SECONDS:
			_iris = 0.0
	elif not done and error_message.is_empty():
		advance()
	queue_redraw()


## Ein Arbeitsschritt (je Bild einer). Auch von Tests aufgerufen; blockiert nie.
func advance() -> void:
	if done or not error_message.is_empty():
		return
	if _step >= STEPS.size():
		_finish()
		return
	var step: Dictionary = STEPS[_step]
	if not _step_running:
		_step_running = true
		_status_label.text = step["text"]
		_log("Schritt „%s“ beginnt" % step["id"])
		step_started.emit(step["id"])
	match step["id"]:
		"scene":
			_advance_scene()
		"data":
			_advance_data()
		"map":
			_advance_map()
		"app":
			_advance_app()
		"warmup":
			_advance_warmup()
		"save":
			_advance_save()


## Für Tests und den Notfall: alle Schritte nacheinander, bis fertig oder fehlgeschlagen (mit Zeitlimit).
func run_to_end(timeout_ms: int = 20000) -> void:
	var start := Time.get_ticks_msec()
	while not done and error_message.is_empty() and Time.get_ticks_msec() - start < timeout_ms:
		advance()
		OS.delay_msec(1)
	if not done and error_message.is_empty():
		_fail("Zeitüberschreitung")


func _advance_scene() -> void:
	if _scene == null and ResourceLoader.load_threaded_get_status(app_scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if not ResourceLoader.exists(app_scene_path):
			_fail("Szene fehlt")
			return
		var error := ResourceLoader.load_threaded_request(app_scene_path)
		if error != OK:
			_fail("Szene: %s" % error_string(error))
			return
	var amount := []
	var status := ResourceLoader.load_threaded_get_status(app_scene_path, amount)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_set_step_progress(float(amount[0]) if not amount.is_empty() else 0.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			_scene = ResourceLoader.load_threaded_get(app_scene_path) as PackedScene
			if _scene == null:
				_fail("Szene unlesbar")
				return
			_next_step()
		_:
			_fail("Szene: Ladefehler")


func _advance_data() -> void:
	_data = load(GAME_DATA_SCRIPT).new()
	if not _data.load_all():
		var problems: PackedStringArray = _data.errors
		_fail("Spieldaten: %s" % "; ".join(problems.slice(0, 2)))
		return
	_next_step()


func _advance_map() -> void:
	if _texture_paths.is_empty():
		for path in load(CITY_MAP_SCRIPT).texture_paths().values():
			if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
				_texture_paths.append(path)
		if _texture_paths.is_empty():
			_next_step()
			return
	var finished := 0
	for path in _texture_paths:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			finished += 1
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_fail("Kartengrafik %s" % path.get_file())
			return
	_set_step_progress(float(finished) / _texture_paths.size())
	if finished == _texture_paths.size():
		for path in _texture_paths:
			_resources.append(ResourceLoader.load_threaded_get(path))
		_next_step()


## App unter dem Ladebildschirm aufbauen (zeigt dort ihr Hauptmenü) und WARM_FRAMES Bilder zeichnen lassen.
func _advance_app() -> void:
	if _app == null:
		_app = _scene.instantiate()
		_app.set("preloaded_data", _data)
		_app.set("preloaded_resources", _resources)
		if not app_save_path.is_empty():
			_app.set("save_path", app_save_path)
		if not app_settings_path.is_empty():
			_app.set("settings_path", app_settings_path)
		_add_below(_app)
		_warm_ticks = 0
		return
	_warm_ticks += 1
	_set_step_progress(float(_warm_ticks) / WARM_FRAMES)
	if _warm_ticks >= WARM_FRAMES:
		_next_step()


## Probe-Spielbildschirm (neues Spiel im Speicher, nie gespeichert) mit Stadtkarte und HUD verdeckt zeichnen:
## packt den geteilten Kartenatlas und zeichnet Karte, Schilder und Leiste einmal vor – danach wieder weg.
func _advance_warmup() -> void:
	if _warmup == null:
		_warmup = load(GAME_SCREEN_SCRIPT).new()
		_warmup.name = "WarmupGameScreen"
		_warmup.call("setup", load(GAME_STATE_SCRIPT).new(_data, 1))
		_warmup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_add_below(_warmup)
		_warmup.call("set_safe_margins", _margins)
		_warm_ticks = 0
		return
	_warm_ticks += 1
	_set_step_progress(float(_warm_ticks) / WARM_FRAMES)
	if _warm_ticks >= WARM_FRAMES:
		_warmup.get_parent().remove_child(_warmup)
		_warmup.queue_free()
		_warmup = null
		_next_step()


## Unter dem Ladebildschirm einhängen (gleicher Eltern-Knoten, davor in der Reihenfolge = darunter gezeichnet).
func _add_below(node: Node) -> void:
	var parent := get_parent()
	parent.add_child(node)
	parent.move_child(node, get_index())


func _advance_save() -> void:
	var save_system = load(SAVE_SYSTEM_SCRIPT)
	var path: String = app_save_path if not app_save_path.is_empty() else save_system.DEFAULT_PATH
	if save_system.has_save(path):
		save_system.read_meta(path)  # nur prüfen, ob der Kopf lesbar ist – Laden macht die App bei „Fortsetzen“
	_next_step()


func _next_step() -> void:
	_set_step_progress(1.0)
	_log("Schritt „%s“ fertig" % STEPS[_step]["id"])
	_step += 1
	_step_running = false


## Fortschritt innerhalb des aktuellen Schritts (0..1) → Gesamtfortschritt; nie rückwärts.
func _set_step_progress(fraction: float) -> void:
	var before := 0.0
	for i in _step:
		before += float(STEPS[i]["weight"])
	var value: float = (before + float(STEPS[_step]["weight"]) * clampf(fraction, 0.0, 1.0)) / 100.0
	if value > progress:
		progress = value
		progress_log.append(progress)
	_percent_label.text = "%d %%" % floori(progress * 100.0)


func _finish() -> void:
	done = true
	progress = 1.0
	progress_log.append(progress)
	_percent_label.text = "100 %"
	_status_label.text = "Aufnahme läuft."
	_log("Alles geladen")
	if not animate:
		_hand_over()


## Die App liegt schon (fertig gezeichnet) darunter – der Ladebildschirm geht nur noch weg.
func _hand_over() -> void:
	if not is_inside_tree() or _app == null:
		return
	_iris = -1.0
	set_process(false)
	var tree := get_tree()
	if tree.current_scene == self:
		tree.current_scene = _app
	_log("Übergabe an die App")
	handed_over.emit(_app)
	queue_free()


func _fail(detail: String) -> void:
	error_message = FAIL_TEXT % detail
	_error_label.text = error_message
	_error_label.visible = true
	_status_label.text = ""
	set_process(false)
	_log("FEHLER: %s" % detail)
	push_warning("Ladebildschirm: %s" % detail)
	failed.emit(error_message)
	_layout()


func _log(text: String) -> void:
	StartLog.mark(text)


func _on_frame_drawn() -> void:
	if not _logged_first_frame:
		_logged_first_frame = true
		_log("Erstes Bild des Ladebildschirms gezeichnet")


func _label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := UiStyle.label(text, font_size, color)
	label.name = node_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _update_margins() -> void:
	_margins = SafeAreaScript.current(get_viewport_rect().size, UiStyle.PADDING)
	_layout()


## Für Tests: Abstände eines Geräts setzen (wie set_safe_margins der Spielansicht).
func set_safe_margins(margins: Array[float]) -> void:
	_margins = margins
	_layout()


func _safe_rect() -> Rect2:
	return Rect2(_margins[0], _margins[1], size.x - _margins[0] - _margins[2], size.y - _margins[1] - _margins[3])


func _bar_rect() -> Rect2:
	var safe := _safe_rect()
	var bar_left := safe.position.x + 48.0
	var bar_right := safe.end.x - 48.0 - 110.0
	return Rect2(bar_left, safe.end.y - 44.0, bar_right - bar_left, BAR_HEIGHT)


func _lens_center() -> Vector2:
	var safe := _safe_rect()
	return Vector2(safe.get_center().x, safe.position.y + safe.size.y * 0.42)


func _layout() -> void:
	if _rec_label == null:
		return
	var safe := _safe_rect()
	_rec_label.position = Vector2(safe.position.x + 52.0, safe.position.y + 20.0)
	_rec_label.size = Vector2(_rec_label.get_minimum_size().x, 34.0)
	_timecode_label.size = Vector2(_timecode_label.get_minimum_size().x, 34.0)
	_timecode_label.position = Vector2(safe.end.x - 28.0 - _timecode_label.size.x, safe.position.y + 20.0)
	var bar := _bar_rect()
	_status_label.size = Vector2(safe.size.x - 96.0, 34.0)
	_status_label.position = Vector2(safe.position.x + 48.0, _lens_center().y + LENS_SIZE / 2.0 + 24.0)
	_percent_label.size = Vector2(96.0, 34.0)
	_percent_label.position = Vector2(bar.end.x + 14.0, bar.get_center().y - 17.0)
	_error_label.size = Vector2(safe.size.x - 96.0, 0.0)
	_error_label.position = Vector2(safe.position.x + 48.0, _status_label.position.y)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BACKGROUND)
	var frame := _safe_rect().grow(-8.0)
	var white := Color(1, 1, 1, 0.75)
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		var dx := CORNER_LENGTH if corner.x == frame.position.x else -CORNER_LENGTH
		var dy := CORNER_LENGTH if corner.y == frame.position.y else -CORNER_LENGTH
		draw_line(corner, corner + Vector2(dx, 0), white, CORNER_WIDTH)
		draw_line(corner, corner + Vector2(0, dy), white, CORNER_WIDTH)
	# Blinkender REC-Punkt
	if int(_elapsed / BLINK_SECONDS) % 2 == 0:
		draw_circle(Vector2(_rec_label.position.x - 18.0, _rec_label.position.y + 17.0), 10.0, REC_RED)
	# Halbes Objektiv; bei 100 % schließt sich eine Blende darüber
	var center := _lens_center()
	draw_texture_rect(LENS, Rect2(center - Vector2(LENS_SIZE, LENS_SIZE) / 2.0, Vector2(LENS_SIZE, LENS_SIZE)), false)
	if _iris >= 0.0:
		var outer := LENS_SIZE * 0.56
		var hole := outer * (1.0 - _iris)
		draw_arc(center, (outer + hole) / 2.0, 0.0, TAU, 64, UiStyle.BACKGROUND, outer - hole + 1.0, true)
	# Aufnahmeleiste
	if error_message.is_empty():
		var bar := _bar_rect()
		draw_rect(bar, UiStyle.SURFACE_PRESSED)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), REC_RED)
