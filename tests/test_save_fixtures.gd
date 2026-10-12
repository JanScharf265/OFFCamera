extends "res://tests/base_test.gd"

## Ticket 6.1: echte Spielstände aller Versionen, erzeugt mit dem Code des jeweiligen Commits
## (tests/fixtures/make_save.gd, per `git archive` im Scratchpad ausgeführt – siehe README).
## Jede Datei muss bis zur aktuellen Version laden, ihre Kernwerte behalten und weiterspielbar sein.

const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const FIXTURE_DIR := "res://tests/fixtures/saves/"
const PATH := "user://test_fixture_save.json"


func _expect(version: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DIR + "v%d.expect.json" % version))


## Kopiert die Testdatei nach user:// und lädt sie mit den aktuellen Spieldaten.
func _load_fixture(version: int) -> Dictionary:
	SaveSystemScript.delete_save(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURE_DIR + "v%d.json" % version))
	file.close()
	return SaveSystemScript.load_game(Helpers.game_data(), PATH)


func test_every_version_has_a_fixture() -> void:
	for version in range(1, SaveSystemScript.SAVE_VERSION + 1):
		assert_true(FileAccess.file_exists(FIXTURE_DIR + "v%d.json" % version), "Testdatei v%d fehlt" % version)
		assert_true(FileAccess.file_exists(FIXTURE_DIR + "v%d.expect.json" % version), "Erwartung v%d fehlt" % version)


func test_fixtures_are_really_of_their_version() -> void:
	for version in range(1, SaveSystemScript.SAVE_VERSION + 1):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DIR + "v%d.json" % version))
		assert_eq(int(data["version"]), version, "v%d" % version)


func test_every_fixture_loads_and_keeps_core_values() -> void:
	for version in range(1, SaveSystemScript.SAVE_VERSION + 1):
		var result := _load_fixture(version)
		var label := "v%d" % version
		var game: GameStateScript = result["game"]
		assert_true(game != null, "%s lädt nicht: %s" % [label, result["error"]])
		if game == null:
			continue
		assert_eq(result["from_backup"], false, label)
		var expect := _expect(version)
		assert_eq(game.time.get_minutes(), int(expect["time_minutes"]), label + " Zeit")
		assert_eq(game.ledger.get_balance("private"), int(expect["private_balance_cents"]), label + " Privatkonto")
		assert_eq(game.ledger.get_entries().size(), int(expect["entry_count"]), label + " Buchungen")
		assert_eq(game.ledger.recalculate_balance("private"), game.ledger.get_balance("private"), label)
		assert_eq(game.ledger.recalculate_balance("company"), game.ledger.get_balance("company"), label)
		if not String(expect["location"]).is_empty():
			assert_eq(game.locations.get_current(), expect["location"], label + " Ort")
		if int(expect["followers"]) >= 0:
			assert_eq(game.channel.followers, int(expect["followers"]), label + " Follower")
		else:
			assert_eq(game.channel.followers, GameStateScript.START_FOLLOWERS, label + " Follower (Startwert)")
		if int(expect["camera_level"]) >= 0:
			assert_eq(game.equipment.get_level("camera"), int(expect["camera_level"]), label + " Kamera")
		assert_eq(game.company.is_founded(), bool(expect["company_founded"]), label + " Unternehmen")
	SaveSystemScript.delete_save(PATH)


func test_every_fixture_can_be_played_and_saved_again() -> void:
	for version in range(1, SaveSystemScript.SAVE_VERSION + 1):
		var label := "v%d" % version
		var game: GameStateScript = _load_fixture(version)["game"]
		if game == null:
			assert_true(false, "%s lädt nicht" % label)
			continue
		while game.events.has_pending():
			var instance := game.events.get_next_pending_id()
			game.events.resolve(instance, game.events.get_definition_for(instance).options[-1].id)
		# Bis in die nächste Woche: Tagesabschlüsse, Fristen und Zufallsereignisse laufen über den Altstand.
		var target := TimeSystemScript.at(TimeSystemScript.day_of(game.time.get_minutes()) + 8, 9)
		assert_true(game.time.advance(target - game.time.get_minutes()), label + " Zeitfortschritt")
		for account in ["private", "company"]:
			assert_true(game.ledger.get_balance(account) >= 0, "%s %s negativ" % [label, account])
		assert_eq(SaveSystemScript.save(game, PATH), "", label + " speichern")
		var again: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), PATH)["game"]
		assert_true(again != null, label + " lädt nach dem Weiterspielen nicht")
		if again != null:
			assert_eq(JSON.stringify(again.to_dict()), JSON.stringify(game.to_dict()), label + " Rundlauf")
	SaveSystemScript.delete_save(PATH)


func test_migration_steps_cover_every_old_version() -> void:
	var game := Helpers.new_game().to_dict()
	for step in range(1, SaveSystemScript.SAVE_VERSION):
		var copy: Dictionary = JSON.parse_string(JSON.stringify(game))
		var error: String = SaveSystemScript._run_migration(step, copy)
		assert_true(not error.begins_with("Kein Migrationsschritt"), "Schritt %d → %d fehlt" % [step, step + 1])
