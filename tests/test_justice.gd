extends "res://tests/base_test.gd"

## Ticket U.21: Justiz – Festnahme nach Razzia (Seed), Haftanstalt (nur sichtbar, wenn man dort ist; Reisen gesperrt),
## Optionen bei der Festnahme (Anwalt, Bestechung, schweigen) und im Prozess (Crew belasten, kooperieren, warten),
## Kaution, Urteil nach Beweislage, Haft als Spieltage über das TimeSystem, Entlassung; jede Zahlung eine Buchung;
## kein Game Over; Speichern/Laden; Migration v33 → v34; Fenster „Verfahren“.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const JusticeSystemScript := preload("res://scripts/systems/justice_system.gd")

const SAVE_PATH := "user://test_justice_save.json"


func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.organisation.change({"respect": 50})
	game.ledger.post(1000000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


func _arrested() -> GameStateScript:
	var game := _ready_game()
	game.justice.arrest(game.time.get_day())
	return game


func _pending(game: GameStateScript, prefix: String) -> String:
	for id in game.events.to_dict()["pending"]:
		if String(id).begins_with(prefix):
			return id
	return ""


func _to_day(game: GameStateScript, day: int) -> void:
	game.time.advance(TimeSystemScript.at(day, 8) - game.time.get_minutes())


func test_rules_load() -> void:
	var rules := JusticeSystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq([rules.get_value("start_evidence"), rules.get_value("trial_after_days"), rules.get_value("conviction_min_evidence")],
			[60, 5, 40])
	var bad: Dictionary = rules.values.duplicate()
	bad["trial_after_days"] = 0
	assert_eq(JusticeSystemScript.Rules.new().load_data(bad), false)


func test_arrest_puts_into_prison_and_blocks_travel() -> void:
	var game := _arrested()
	assert_eq(game.justice.get_state(), "custody")
	assert_eq(game.locations.get_current(), "prison")
	assert_eq(game.locations.is_known("prison"), true)
	assert_eq(game.locations.check_travel("home"), "Du sitzt in Haft.")
	assert_true(not _pending(game, "justice_arrest").is_empty())
	assert_true(game.events.get_text(_pending(game, "justice_arrest")).contains("5 Tage"))
	assert_eq(game.activities.check("prison_yard"), "", "Hofgang in der Haftanstalt")


func test_prison_hidden_when_free() -> void:
	var game := _ready_game()
	assert_eq(game.locations.is_known("prison"), false)
	assert_eq(game.locations.check_travel("prison"), "Diesen Ort kennst du noch nicht.")


func test_lawyer_books_and_lowers_evidence() -> void:
	var game := _arrested()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_eq(game.events.resolve(_pending(game, "justice_arrest"), "lawyer"), "")
	assert_eq(game.justice.get_evidence(), 35)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 200000)


func test_bribe_is_risky_and_deterministic() -> void:
	var outcomes := {}
	for seed in [1, 2, 3, 4, 5, 6, 7, 8]:
		var game := Helpers.new_game(null, seed)
		game.organisation.found("Los Lobos")
		game.ledger.post(1000000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
		game.justice.arrest(game.time.get_day())
		var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
		assert_eq(game.events.resolve(_pending(game, "justice_arrest"), "bribe"), "")
		assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - 500000, "Bestechung ist eine Buchung")
		outcomes[game.justice.get_state()] = true
		if game.justice.get_state() == "free":
			assert_eq(game.locations.get_current(), "home")
		else:
			assert_eq(game.justice.get_evidence(), 90, "aufgeflogen: +30")
	assert_eq(outcomes.size(), 2, "mal klappt es, mal nicht: %s" % outcomes)


func test_bail_then_trial_acquittal() -> void:
	var game := _arrested()
	game.events.resolve(_pending(game, "justice_arrest"), "lawyer")  # 35 %
	assert_eq(game.justice.bail_cents(), 35 * 5000)
	assert_eq(game.justice.pay_bail(), "")
	assert_eq([game.justice.get_state(), game.locations.get_current()], ["bail", "home"])
	assert_eq(game.justice.wait(), "")
	var trial := _pending(game, "justice_trial")
	assert_true(not trial.is_empty(), "Prozess am Prozesstag")
	assert_eq(game.events.resolve(trial, "await"), "")
	assert_eq(game.justice.get_state(), "free", "unter 40 %: Freispruch")
	assert_true(game.justice.get_last_verdict().begins_with("Freispruch"))


func test_conviction_prison_days_and_release() -> void:
	var game := _arrested()
	game.events.resolve(_pending(game, "justice_arrest"), "silent")  # 50 %
	assert_eq(game.justice.wait(), "")
	var day := game.time.get_day()
	game.events.resolve(_pending(game, "justice_trial"), "await")
	assert_eq(game.justice.get_state(), "prison")
	assert_eq(game.justice.get_release_day(), day + 10, "50 % → 5 × 2 Tage")
	assert_eq(game.locations.get_current(), "prison")
	assert_eq(game.justice.wait(), "")
	assert_eq([game.justice.get_state(), game.locations.get_current()], ["free", "home"], "entlassen, Spiel geht weiter")
	assert_eq(game.time.get_day(), day + 10, "Haft ist Spielzeit")


func test_sacrifice_and_cooperate() -> void:
	var game := _arrested()
	var crew := game.crew.to_dict()
	crew["members"].append({"id": "a", "name": "Toni V.", "role": "dealer", "skill": 50, "loyalty": 20, "greed": 30,
			"wage_cents": 100, "hired_day": 0, "rank": 1, "district": ""})
	crew["members"].append({"id": "b", "name": "Lucía M.", "role": "dealer", "skill": 50, "loyalty": 70, "greed": 30,
			"wage_cents": 100, "hired_day": 0, "rank": 1, "district": ""})
	game.crew.restore(crew)
	game.justice.wait()
	var stability := game.organisation.get_value("stability")
	var loyalty: int = game.crew.get_member("b")["loyalty"]
	game.events.resolve(_pending(game, "justice_trial"), "sacrifice")
	assert_true(game.crew.get_member("a").is_empty(), "am wenigsten loyal belastet")
	assert_eq(game.crew.get_member("b")["loyalty"], loyalty - 10, "die anderen verlieren Loyalität")
	assert_eq(game.organisation.get_value("stability"), stability - 15)
	assert_eq(game.justice.get_state(), "free", "60 − 40 = 20 %: Freispruch")
	var second := _arrested()
	second.justice.wait()
	var respect := second.organisation.get_value("respect")
	second.events.resolve(_pending(second, "justice_trial"), "cooperate")
	assert_eq(second.organisation.get_value("respect"), respect - 20)
	assert_eq(second.justice.get_state(), "free")


func test_arrest_after_raid_follows_seed() -> void:
	var arrested := 0
	for seed in range(1, 9):
		var game := Helpers.new_game(null, seed)
		game.organisation.found("Los Lobos")
		var police := game.police.to_dict()
		police.merge({"level": 2, "case": "MB-1", "progress": 100}, true)
		game.police.restore(police)
		game.time.advance(TimeSystemScript.at(2, 8) - game.time.get_minutes())
		if game.justice.get_state() == "custody":
			arrested += 1
			assert_eq(game.justice.get_case(), "MB-1", "Aktenzeichen der Polizei")
	assert_true(arrested > 0 and arrested < 8, "Festnahme nur manchmal (%d von 8)" % arrested)


func test_saved_and_migrated() -> void:
	var game := _arrested()
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.justice.to_dict(), game.justice.to_dict())
		assert_eq(loaded.locations.get_current(), "prison")
		assert_eq(loaded.locations.check_travel("home"), "Du sitzt in Haft.")
	assert_true(not game.justice.restore({"state": "dead"}).is_empty())
	assert_eq(SaveSystemScript._run_migration(33, {"time": {"minutes": 3000}}), "")
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_window() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_justice_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.ledger.post(1000000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	app.game.justice.arrest(app.game.time.get_day())
	app.game.events.resolve(_pending(app.game, "justice_arrest"), "silent")
	screen.call("_refresh")
	screen.call("_close_window")
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	(app.find_child("JusticeButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("JusticeStatus", true, false) as Label).text, "In Untersuchungshaft")
	var bail := app.find_child("JusticeBailButton", true, false) as Button
	assert_eq([bail.disabled, bail.text], [false, "Kaution zahlen · 2.500,00 €"])
	bail.pressed.emit()
	assert_eq(app.game.justice.get_state(), "bail")
	assert_eq((app.find_child("MapPin_prison", true, false) as Control).visible, false, "Haftanstalt wieder unsichtbar")
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_justice_settings.cfg"))
