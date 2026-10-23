extends SceneTree

## Führt alle tests/test_*.gd aus, ohne Fenster.
## Aufruf auf dem Mac (im Projektordner):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
## Exit-Code 0 = alle Tests bestanden, 1 = mindestens ein Fehler.
## Lange Läufe (Phase 6: Rundlauf, Störungen, Messung) liegen in tests/long/ und laufen nur mit
##   … -s res://tests/run_tests.gd -- --long
## (siehe README; am Ende jedes Tickets, das das Speichern betrifft, und am Ende einer Phase).
##
## Skriptfehler (z. B. Zugriff auf null) brechen einen Test ab, ohne dass eine Prüfung fehlschlägt.
## Ein eigener Logger (OS.add_logger, Godot ≥ 4.5) zählt sie; tritt während eines Tests einer auf,
## gilt der Test als fehlgeschlagen. Gewollte push_error-Meldungen (ERROR_TYPE_ERROR) zählen nicht.

const TEST_DIR := "res://tests/"
## T.7: Echte Dateien des Nutzers – kein Test darf sie ändern (Vergleich vor/nach dem Lauf).
const PROTECTED_FILES := ["user://settings.cfg", "user://settings.cfg.tmp", "user://savegame.json",
		"user://savegame.json.tmp", "user://savegame.json.bak", "user://savegame.json.bak2", "user://savegame.json.bak3"]
## Pfade, auf die eine App ohne eigenen Pfad während der Tests zeigt.
const TEST_DEFAULT_SAVE := "user://test_default_savegame.json"
const TEST_DEFAULT_SETTINGS := "user://test_default_settings.cfg"
const LONG_TEST_DIR := "res://tests/long/"


class ScriptErrorCounter extends Logger:
	var count := 0
	var last_message := ""
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		count += 1
		last_message = "%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file.get_file(), line]
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errors := ScriptErrorCounter.new()
var _dir := TEST_DIR


func _initialize() -> void:
	OS.add_logger(_errors)
	if "--long" in OS.get_cmdline_user_args():
		_dir = LONG_TEST_DIR
	# Erst im ersten Frame starten: In _initialize() hängt root noch nicht im
	# Baum, eingefügte Knoten bekämen sonst kein _ready() (UI-Tests).
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var passed := 0
	var failed := 0
	var app_script = load("res://scripts/ui/app.gd")
	app_script.default_save_path = TEST_DEFAULT_SAVE
	app_script.default_settings_path = TEST_DEFAULT_SETTINGS
	var protected_before := _fingerprints()

	for file in _test_files():
		print("\n%s" % file)
		var script: GDScript = load(_dir + file)
		if script == null or not script.can_instantiate():
			print("  FEHLER  Datei konnte nicht geladen werden (Parse-Fehler?)")
			failed += 1
			continue

		for method in _test_methods(script):
			var test_case = script.new()
			var errors_before := _errors.count
			test_case.call(method)
			if _errors.count > errors_before:
				test_case.failures.append("Skriptfehler im Test (abgebrochen): %s" % _errors.last_message)
			if test_case.assertion_count == 0:
				test_case.failures.append("keine Prüfung ausgeführt – abgebrochen?")
			if test_case.failures.is_empty():
				passed += 1
				print("  ok      %s" % method)
			else:
				failed += 1
				print("  FEHLER  %s" % method)
				for failure in test_case.failures:
					print("          - %s" % failure)

	var protected_after := _fingerprints()
	for path in PROTECTED_FILES:
		if protected_before[path] != protected_after[path]:
			failed += 1
			print("\n  FEHLER  Ein Test hat die echte Datei %s verändert (eigenen Testpfad verwenden)." % path)
	load("res://scripts/systems/save_system.gd").delete_save(TEST_DEFAULT_SAVE)
	_remove(TEST_DEFAULT_SETTINGS)

	print("\n%d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(_dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	return files


func _test_methods(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


## Inhalt (MD5) bzw. „fehlt“ je geschützter Datei.
func _fingerprints() -> Dictionary:
	var result := {}
	for path in PROTECTED_FILES:
		result[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else "fehlt"
	return result


func _remove(path: String) -> void:
	for candidate in [path, path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
