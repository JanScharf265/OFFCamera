extends "res://tests/base_test.gd"

## Ticket T.7: Abdeckungstest – jede Mechanik aus scripts/models/mechanics.gd hat mindestens ein Tutorial, jedes Tutorial
## gehört zu einer bekannten Mechanik, jeder Auslöser der festen Liste wird im Spiel wirklich gemeldet und von einem
## Tutorial genutzt. (Erscheinen und Layout jedes Tutorials auf den 4 Geräteklassen: tests/test_tutorial_texts.gd.)

const MechanicsScript := preload("res://scripts/models/mechanics.gd")
const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")

## Hier wird nach Meldungen gesucht (Spielcode, nicht Tests).
const CODE_DIRS := ["res://scripts/"]


func _catalog() -> TutorialCatalogScript:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	return catalog


func test_every_mechanic_has_a_tutorial() -> void:
	var covered := {}
	for definition in _catalog().get_all():
		covered[definition.mechanic] = true
	var missing := PackedStringArray()
	for id in MechanicsScript.ids():
		if not covered.has(id):
			missing.append("„%s“ (%s)" % [id, MechanicsScript.NAMES[id]])
	assert_true(missing.is_empty(), "Mechanik ohne Tutorial: %s – Tutorial in data/tutorials/tutorials.json ergänzen."
			% ", ".join(missing))


func test_every_tutorial_belongs_to_a_known_mechanic() -> void:
	var unknown := PackedStringArray()
	for definition in _catalog().get_all():
		if not MechanicsScript.NAMES.has(definition.mechanic):
			unknown.append("%s → „%s“" % [definition.id, definition.mechanic])
	assert_true(unknown.is_empty(), "Tutorial mit unbekannter Mechanik: %s – Mechanik-ID in scripts/models/mechanics.gd eintragen."
			% ", ".join(unknown))


## Jeder Auslöser der festen Liste wird im Spielcode gemeldet: `report("<id>")` oder (Systemsignale)
## `report.bind("<id>")`. Ein Auslöser, den nichts meldet, ließe sein Tutorial nie erscheinen.
func test_every_trigger_is_reported_in_game_code() -> void:
	var code := ""
	for dir in CODE_DIRS:
		code += _read_all(dir)
	var silent := PackedStringArray()
	for trigger in TutorialCatalogScript.TRIGGERS:
		if not ('report("%s")' % trigger in code or 'report.bind("%s")' % trigger in code):
			silent.append(trigger)
	assert_true(silent.is_empty(), "Auslöser, die das Spiel nie meldet: %s" % ", ".join(silent))


func test_every_trigger_is_used_by_a_tutorial() -> void:
	var used := {}
	for definition in _catalog().get_all():
		used[definition.trigger] = true
	var unused := PackedStringArray()
	for trigger in TutorialCatalogScript.TRIGGERS:
		if not used.has(trigger):
			unused.append(trigger)
	assert_true(unused.is_empty(), "Auslöser ohne Tutorial: %s" % ", ".join(unused))


## Der Test selbst schlägt an: eine Mechanik ohne Tutorial wird mit Namen gemeldet.
func test_coverage_reports_missing_mechanic_by_name() -> void:
	var catalog := TutorialCatalogScript.new()
	assert_true(catalog.load_data([{"id": "tut_only", "mechanic": "map", "trigger": "first_game_start", "title": "T",
			"text": "T.", "ui_target": "", "order": 0, "requires": []}]))
	var covered := {}
	for definition in catalog.get_all():
		covered[definition.mechanic] = true
	assert_eq(covered.has("travel"), false)
	assert_eq(MechanicsScript.NAMES["travel"], "Hinfahren")


func _read_all(dir_path: String) -> String:
	var text := ""
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return text
	for file in dir.get_files():
		if file.ends_with(".gd"):
			text += FileAccess.get_file_as_string(dir_path.path_join(file))
	for sub in dir.get_directories():
		text += _read_all(dir_path.path_join(sub))
	return text
