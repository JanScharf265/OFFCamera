extends "res://tests/base_test.gd"

## Phase 7: Wächter gegen Speicherlecks im Spiel. Neues Spiel, Laden (auch fehlgeschlagen) und ein
## App-Durchgang dürfen keine Objekte zurücklassen. (Die Warnung „ObjectDB instances leaked at exit“
## am Ende des Testlaufs stammt aus Tests, die Lambdas mit Bezug auf das Spiel an dessen Signale hängen –
## das Spiel selbst ist frei davon, siehe DECISIONS 032.)

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const AppScript := preload("res://scripts/ui/app.gd")

const PATH := "user://test_memory_save.json"


func _objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _play(data) -> void:
	var game := GameStateScript.new(data, 3)
	game.locations.travel("office")
	game.company.found("merch_label")
	game.time.advance(60 * 24 * 9)


func test_new_games_leave_no_objects() -> void:
	var data := Helpers.game_data()
	_play(data)  # Aufwärmen (einmalig geladene Skripte)
	var before := _objects()
	for i in 10:
		_play(data)
	assert_true(_objects() - before <= 0, "Objekte nach 10 Spielen übrig: %d" % (_objects() - before))


func test_loading_leaves_no_objects() -> void:
	var data := Helpers.game_data()
	SaveSystemScript.delete_save(PATH)
	SaveSystemScript.save(GameStateScript.new(data, 3), PATH)
	var valid := FileAccess.get_file_as_string(PATH)
	for text in [valid, "{ kaputt", valid.replace("\"ledger\"", "\"ledgerx\"")]:
		var before := -1
		for i in 6:
			if i == 1:
				before = _objects()  # erster Durchgang = Aufwärmen
			SaveSystemScript.delete_save(PATH)
			var file := FileAccess.open(PATH, FileAccess.WRITE)
			file.store_string(text)
			file.close()
			SaveSystemScript.load_game(data, PATH)
		SaveSystemScript.delete_save(PATH)
		var grown := _objects() - before
		assert_true(grown <= 0, "%d Objekte nach dem Laden übrig (%s…)" % [grown, text.substr(0, 10)])
