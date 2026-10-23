extends "res://tests/base_test.gd"

## Ticket U.20: Polizei 2 – Razzia bei voller Akte: riskantester eigener Standort versiegelt, Bestand und Schwarzgeld
## (Buchung) teilweise beschlagnahmt, Akte 0, zurück zur Beobachtung, Hitze runter; Ereignis mit Werten im Text;
## Warnung ab 80 %; einmal je Tag; Speichern/Laden; Migration v32 → v33.

const AppScript := preload("res://scripts/ui/app.gd")
const Helpers := preload("res://tests/helpers.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PoliceSystemScript := preload("res://scripts/systems/police_system.gd")

const SAVE_PATH := "user://test_raid_save.json"


## Ermittlung mit voller Akte, Versteck und Hinterzimmer, 40 Einheiten Gras, 1.000 € Schwarzgeld, Hitze 80.
func _ready_game(progress: int = 100) -> GameStateScript:
	var game := Helpers.new_game()
	assert_eq(game.organisation.found("Los Lobos"), "")
	game.organisation.change({"heat": 80})
	game.ledger.post(100000, "test", "Start", "test", "t", "", false, LedgerSystemScript.BLACK)
	var sites := game.sites.to_dict()
	sites["owned"] = {"garage_san_pedro": 0, "backroom_store": 0}
	assert_eq(game.sites.restore(sites), "")
	var supply := game.supply.to_dict()
	supply["stock"] = {"weed": 40}
	game.supply.restore(supply)
	var police := game.police.to_dict()
	police.merge({"level": 2, "case": "MB-0001", "progress": progress, "since_day": 1}, true)
	assert_eq(game.police.restore(police), "")
	return game


func _next_morning(game: GameStateScript) -> void:
	game.time.advance(TimeSystemScript.at(game.time.get_day() + 1, 8) - game.time.get_minutes())


func test_raid_at_full_file() -> void:
	var game := _ready_game()
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var garage_rent := 2000
	_next_morning(game)
	assert_eq(game.sites.is_owned("backroom_store"), false, "Hinterzimmer (Risiko 30) versiegelt")
	assert_eq(game.sites.is_owned("garage_san_pedro"), true, "Garage (Risiko 10) bleibt")
	var raid := game.police.get_last_raid()
	assert_eq([raid["site"], raid["case"]], ["Hinterzimmer", "MB-0001"])
	assert_eq(game.police.get_level(), 1, "zurück zur Beobachtung")
	assert_eq(game.police.get_progress(), 0)
	var confiscations := game.ledger.get_entries_by_category(PoliceSystemScript.RAID_CATEGORY)
	assert_eq(confiscations.size(), 1, "eine Buchung")
	assert_eq(confiscations[0].account, LedgerSystemScript.BLACK)
	assert_true(raid["stock"] > 0 and raid["money_cents"] > 0)
	assert_true(game.events.get_text(game.events.get_next_pending_id()).contains("Hinterzimmer"), "Text nennt den Standort")


func test_raid_values() -> void:
	var game := _ready_game()
	# Ohne die Tageswechsel-Schritte davor: Standorte nehmen Miete und verkaufen; daher Werte direkt am PoliceSystem.
	var black := game.ledger.get_balance(LedgerSystemScript.BLACK)
	var stock := game.supply.get_stock("weed")
	game.police.call("_raid", 2)
	assert_eq(game.supply.get_stock("weed"), stock - stock / 2)
	assert_eq(game.ledger.get_balance(LedgerSystemScript.BLACK), black - black * 30 / 100)
	assert_eq(game.organisation.get_value("heat"), 60, "Hitze −20")


func test_no_raid_below_full_and_warning() -> void:
	var game := _ready_game(79)
	assert_eq(game.police.is_raid_near(), false)
	game.police.restore(_with(game.police.to_dict(), {"progress": 80}))
	assert_eq(game.police.is_raid_near(), true)
	_next_morning(game)
	assert_eq(game.police.count_raids(), 0, "erst bei 100 %")


func _with(data: Dictionary, change: Dictionary) -> Dictionary:
	data.merge(change, true)
	return data


func test_raid_once_and_saved() -> void:
	var game := _ready_game()
	_next_morning(game)
	game.police.on_day_changed(game.time.get_day())
	assert_eq(game.police.count_raids(), 1, "nicht doppelt")
	assert_eq(SaveSystemScript.save(game, SAVE_PATH), "")
	var loaded: GameStateScript = SaveSystemScript.load_game(Helpers.game_data(), SAVE_PATH)["game"]
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(loaded.police.get_last_raid(), game.police.get_last_raid())
		assert_true(loaded.events.get_text(loaded.events.get_next_pending_id()).contains("MB-0001"))
	var bad := game.police.to_dict()
	bad["last_raid"] = {"site": 1}
	assert_true(not game.police.restore(bad).is_empty())
	var old := {"police": {}}
	assert_eq(SaveSystemScript._run_migration(32, old), "")
	assert_eq([old["police"]["raids"], old["police"]["last_raid"]], [0, {}])
	SaveSystemScript.delete_save(SAVE_PATH)


func test_raid_without_sites() -> void:
	var game := _ready_game()
	var sites := game.sites.to_dict()
	sites["owned"] = {}
	game.sites.restore(sites)
	_next_morning(game)
	assert_eq(game.police.get_last_raid()["site"], "nichts")


func test_ui_warning_and_last_raid() -> void:
	SaveSystemScript.delete_save(SAVE_PATH)
	var app := AppScript.new()
	app.save_path = SAVE_PATH
	app.settings_path = "user://test_raid_settings.cfg"
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	(app.find_child("NewGameButton", true, false) as Button).pressed.emit()
	var screen := app.find_child("CityMap", true, false).get_parent()
	screen.set("show_tutorials", false)
	screen.call("on_organisation_name_submitted", "Los Lobos")
	app.game.police.restore(_with(app.game.police.to_dict(), {"level": 2, "case": "MB-0042", "progress": 85}))
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true(app.find_child("PoliceRaidWarning", true, false) != null, "Warnung fehlt")
	screen.call("_close_window")
	app.game.police.restore(_with(app.game.police.to_dict(), {"level": 1, "progress": 0, "raids": 1,
			"last_raid": {"site": "Hinterzimmer", "stock": 20, "money_cents": 30000, "day": 3, "case": "MB-0042"}}))
	(app.find_child("OrganisationButton", true, false) as Button).pressed.emit()
	assert_true((app.find_child("PoliceDetail", true, false) as Label).text.contains(
			"Letzte Razzia Tag 3: Hinterzimmer versiegelt · 20 Einheiten · 300,00 € beschlagnahmt"))
	app.free()
	SaveSystemScript.delete_save(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_raid_settings.cfg"))
