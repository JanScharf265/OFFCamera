extends RefCounted

## Gemeinsame Hilfen für Tests (kein test_*-Name, wird vom Runner nicht ausgeführt).

const GameDataScript := preload("res://scripts/core/game_data.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")


## Echte Spieldaten aus data/. Bricht nicht ab, aber meldet Fehler im Log.
static func game_data() -> GameDataScript:
	var data := GameDataScript.new()
	if not data.load_all():
		push_error("Testdaten konnten nicht geladen werden: %s" % "; ".join(data.errors))
	return data


## Fester Seed für Tests – Zufallsereignisse laufen damit immer gleich.
const TEST_SEED := 12345


## Neues Spiel mit echten Daten (Tag 1, 08:00, Wohnung) und festem Seed.
static func new_game(data: GameDataScript = null, p_seed: int = TEST_SEED) -> GameStateScript:
	return GameStateScript.new(data if data != null else game_data(), p_seed)


## Wandelt GameState.to_dict() in das Ledger-Format vor Spielstand-Version 6 zurück
## (ein Konto, Buchungen ohne "account") – für Migrationstests alter Spielstände.
static func with_single_account_ledger(game: Dictionary) -> Dictionary:
	var ledger: Dictionary = game["ledger"]
	ledger["opening_balance_cents"] = ledger["opening_balances"]["private"]
	ledger.erase("opening_balances")
	for entry in ledger["entries"]:
		entry.erase("account")
	return game
