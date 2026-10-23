extends "res://tests/base_test.gd"

## Ticket U.19: Polizei 1 – Beobachtung und Ermittlung nach Hitze (Tage in Folge), zurück bei Ruhe; Ereignisse im
## EventSystem; Akte mit Fortschritt nach Hitze; Anwalt (Buchung, Wartezeit); Verbindung zu den Behördenereignissen
## (Bedingung min_police_level) und zum Festnahme-Risiko; Speichern/Laden; Migration v31 → v32; Anzeige.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PoliceSystemScript := preload("res://scripts/systems/police_system.gd")

const SAVE_PATH := "user://test_police_save.json"


func _ready_game() -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.ledger.post(500000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	return game


## Hält die Hitze vor jedem Tageswechsel auf `heat` (gegen die Abkühlung) und geht `days` Tage weiter.
func _days_at(game: GameStateScript, heat: int, days: int) -> void:
	for i in days:
		game.organisation.change({"heat": heat + 3 - game.organisation.get_value("heat")})
		game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())
		while game.events.has_pending():
			var id: String = game.events.get_next_pending_id()
			game.events.resolve(id, game.events.get_definition_for(id).options[0].id)


func _triggered(game: GameStateScript, prefix: String) -> bool:
	for id in game.events.to_dict()["triggered"]:
		if String(id).begins_with(prefix):
			return true
	return false


func test_rules_load() -> void:
	var rules := PoliceSystemScript.Rules.new()
	assert_true(rules.load_file(), "; ".join(rules.errors))
	assert_eq([rules.get_value("observation_heat"), rules.get_value("investigation_heat"), rules.get_value("days_to_escalate")],
			[40, 70, 3])
	var good: Dictionary = rules.values.duplicate()
	for change in [{"calm_heat": 50}, {"days_to_escalate": 0}, {"x": 1}]:
		var bad := good.duplicate()
		bad.merge(change, true)
		assert_eq(PoliceSystemScript.Rules.new().load_data(bad), false, "angenommen: %s" % change)


func test_observation_after_three_hot_days() -> void:
	var game := _ready_game()
	_days_at(game, 45, 2)
	assert_eq(game.police.get_level(), 0)
	_days_at(game, 45, 1)
	assert_eq(game.police.get_level(), 1, "drei Tage in Folge ≥ 40")
	assert_true(_triggered(game, "police_observation"))


func test_streak_breaks() -> void:
	var game := _ready_game()
	_days_at(game, 45, 2)
	_days_at(game, 35, 1)
	_days_at(game, 45, 2)
	assert_eq(game.police.get_level(), 0, "Unterbrechung setzt zurück")


func test_investigation_case_and_progress() -> void:
	var game := _ready_game()
	_days_at(game, 75, 3)
	assert_eq(game.police.get_level(), 1)
	_days_at(game, 75, 3)
	assert_eq(game.police.get_level(), 2)
	assert_true(game.police.get_case().begins_with("MB-"))
	assert_true(_triggered(game, "police_investigation"))
	var progress := game.police.get_progress()
	_days_at(game, 75, 1)
	assert_eq(game.police.get_progress(), progress + 7, "Hitze 75 → +7")


func test_investigation_text_names_case() -> void:
	var game := _ready_game()
	_days_at(game, 75, 5)
	var data := game.events.to_dict()
	var instance := game.events.trigger_scripted("police_investigation", game.time.get_day() + 50)
	game.police.restore(_with(game.police.to_dict(), {"level": 2, "case": "MB-1234"}))
	assert_true(game.events.get_text(instance).contains("Aktenzeichen MB-1234"))


func _with(data: Dictionary, change: Dictionary) -> Dictionary:
	data.merge(change, true)
	return data


func test_calm_steps_down() -> void:
	var game := _ready_game()
	_days_at(game, 45, 3)
	assert_eq(game.police.get_level(), 1)
	_days_at(game, 20, 5)
	assert_eq(game.police.get_level(), 0)
	assert_true(_triggered(game, "police_calm"))


func test_lawyer() -> void:
	var game := _ready_game()
	assert_eq(game.police.check_lawyer(), "Es gibt keine Ermittlung.")
	game.police.restore(_with(game.police.to_dict(), {"level": 2, "case": "MB-1", "progress": 50}))
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	assert_eq(game.police.hire_lawyer(), "")
	assert_eq([game.police.get_progress(), game.ledger.get_balance(LedgerSystemScript.BLACK)], [30, black - 100000])
	assert_eq(game.police.check_lawyer(), "Der Anwalt arbeitet noch (3 Tage).")


func test_authority_link_and_arrest_bonus() -> void:
	var game := _ready_game()
	assert_eq(game.events.condition_values()["police_level"], 0)
	assert_eq(game.police.arrest_bonus(), 0)
	game.police.restore(_with(game.police.to_dict(), {"level": 1}))
	assert_eq(game.events.condition_values()["police_level"], 1)
	assert_eq(game.police.arrest_bonus(), 2)
	var joint = game.data.events.get_definition("joint_inspection")
	assert_eq(joint.conditions.get("min_police_level"), 1, "Gemeinsame Kontrolle nur unter Beobachtung")


func test_saved_and_migrated() -> void:
	var game := _ready_game()
	_days_at(game, 75, 6)
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.police.to_dict(), game.police.to_dict())
	assert_true(not game.police.restore({"level": 3}).is_empty())
	assert_eq(SaveSystemScript._run_migration(31, {"time": {"minutes": 3000}}), "")
	assert_true(not SaveSystemScript._run_migration(31, {}).is_empty())
	SaveSystemScript.delete_save(SAVE_PATH)


func test_ui_section() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_police_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.ledger.post(500000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("PoliceStatus", true, false) as Label).text, "Keine Auffälligkeit")
	screen.call("_close_window")
	app.game.police.restore(_with(app.game.police.to_dict(), {"level": 2, "case": "MB-0042", "progress": 40, "since_day": 1}))
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_eq((app.find_child("PoliceStatus", true, false) as Label).text, "Ermittlung")
	assert_eq((app.find_child("PoliceDetail", true, false) as Label).text,
			"Akte MB-0042 · seit Tag 1 · Stand der Ermittlung 40 % (wächst mit der Hitze)")
	(app.find_child("PoliceLawyerButton", true, false) as Button).pressed.emit()
	assert_eq(app.game.police.get_progress(), 20)
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_police_settings.cfg"))
