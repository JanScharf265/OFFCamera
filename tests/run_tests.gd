extends SceneTree

## Führt alle tests/test_*.gd aus, ohne Fenster.
## Aufruf auf dem Mac (im Projektordner):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
## Exit-Code 0 = alle Tests bestanden, 1 = mindestens ein Fehler.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	var passed := 0
	var failed := 0

	for file in _test_files():
		print("\n%s" % file)
		var script: GDScript = load(TEST_DIR + file)
		if script == null or not script.can_instantiate():
			print("  FEHLER  Datei konnte nicht geladen werden (Parse-Fehler?)")
			failed += 1
			continue

		for method in _test_methods(script):
			var test_case = script.new()
			test_case.call(method)
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

	print("\n%d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
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
