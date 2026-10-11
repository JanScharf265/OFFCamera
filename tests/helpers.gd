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


## Neues Spiel mit echten Daten (Tag 1, 08:00, Wohnung).
static func new_game(data: GameDataScript = null) -> GameStateScript:
	return GameStateScript.new(data if data != null else game_data())
