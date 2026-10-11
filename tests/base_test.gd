extends RefCounted

## Minimale Basisklasse für Tests (ohne externe Addons).
## Testdateien heißen tests/test_*.gd, erben von dieser Datei und
## enthalten Methoden, die mit "test_" beginnen.

var failures: PackedStringArray = []
var assertion_count := 0


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertion_count += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("erwartet %s, erhalten %s %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_true(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if not condition:
		failures.append("Bedingung nicht erfüllt %s" % message)


## Kennzeichnet in der Ausgabe, dass die nächste ERROR-Zeile beabsichtigt ist.
func expect_error_output() -> void:
	print("          (die folgende ERROR-Meldung ist erwartet)")
