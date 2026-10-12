extends "res://tests/base_test.gd"

## Lange Tests zu Speichern/Laden (Phase 6, Ticket 6.4) – eigener Lauf:
##   timeout 900 …/Godot --headless --path . -s res://tests/run_tests.gd -- --long
## 1. Rundlauf: zufällige, per Seed feste Spielverläufe; Speichern → Laden → Weiterspielen ergibt
##    exakt denselben Stand wie ohne Speichern; jeden Tag gelten die Konsistenzregeln.
## 2. Störungen: jede echte Testdatei wird vielfach beschädigt; Laden stürzt nie ab und liefert nie
##    einen unstimmigen Stand (Skriptfehler fängt der Runner ab).
## 3. Messung: Größe und Lade-/Speicherzeit nach 60 und 180 Spieltagen.

const Helpers := preload("res://tests/helpers.gd")
const Bot := preload("res://tests/long/bot.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ConsistencyCheckScript := preload("res://scripts/core/consistency_check.gd")

const PATH := "user://test_long_save.json"
const ROUNDTRIP_SEEDS := 30
const ROUNDTRIP_DAYS := 30
const FUZZ_PER_FILE := 60
## Grobe Notbremsen – die eigentlichen Budgets entscheidet der Game Director nach der Messung.
const HARD_SIZE_LIMIT := 5 * 1024 * 1024
const HARD_LOAD_LIMIT_MS := 1000


func _check_invariants(game: GameStateScript, label: String) -> bool:
	var problems := ConsistencyCheckScript.check(game)
	for account in ["private", "company"]:
		if game.ledger.get_balance(account) < 0:
			problems.append("%s negativ" % account)
	assert_true(problems.is_empty(), "%s: %s" % [label, "; ".join(problems)])
	return problems.is_empty()


func test_roundtrip_matches_uninterrupted_play() -> void:
	var data := Helpers.game_data()
	for game_seed in range(1, ROUNDTRIP_SEEDS + 1):
		var plain := GameStateScript.new(data, game_seed)
		var saved := GameStateScript.new(data, game_seed)
		var plain_rng := RandomNumberGenerator.new()
		plain_rng.seed = game_seed
		var saved_rng := RandomNumberGenerator.new()
		saved_rng.seed = game_seed
		var save_points := RandomNumberGenerator.new()
		save_points.seed = game_seed * 7919
		var end := TimeSystemScript.at(ROUNDTRIP_DAYS + 1, 0)
		var steps := 0
		var last_day := 0
		var ok := true
		while plain.time.get_minutes() < end and steps < 5000 and ok:
			steps += 1
			var a := Bot.step(plain, plain_rng)
			var b := Bot.step(saved, saved_rng)
			if a != b:
				assert_eq(b, a, "Seed %d, Schritt %d: Verläufe auseinander" % [game_seed, steps])
				ok = false
				break
			if not saved.events.has_pending() and save_points.randf() < 0.15:
				SaveSystemScript.delete_save(PATH)
				assert_eq(SaveSystemScript.save(saved, PATH), "")
				var result := SaveSystemScript.load_game(data, PATH)
				if result["game"] == null:
					assert_true(false, "Seed %d, Schritt %d: Laden fehlgeschlagen: %s" % [game_seed, steps, result["error"]])
					ok = false
					break
				saved = result["game"]
			var day := TimeSystemScript.day_of(plain.time.get_minutes())
			if day != last_day:
				last_day = day
				ok = _check_invariants(plain, "Seed %d, Tag %d" % [game_seed, day])
		if ok:
			assert_eq(JSON.stringify(saved.to_dict()), JSON.stringify(plain.to_dict()),
					"Seed %d: Stand nach Speichern/Laden weicht ab" % game_seed)
	SaveSystemScript.delete_save(PATH)


# --- Störungen ------------------------------------------------------------------------

func _paths(value: Variant, prefix: Array, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			out.append(prefix + [key])
			_paths(value[key], prefix + [key], out, limit)
	elif typeof(value) == TYPE_ARRAY:
		for i in mini(value.size(), 5):
			out.append(prefix + [i])
			_paths(value[i], prefix + [i], out, limit)


func _mutate(text: String, rng: RandomNumberGenerator) -> String:
	var kind := rng.randi_range(0, 4)
	if kind == 0:
		return text.substr(0, rng.randi_range(0, text.length() - 1))
	if kind == 1:
		var index := rng.randi_range(0, text.length() - 1)
		return text.substr(0, index) + char(rng.randi_range(32, 126)) + text.substr(index + 1)
	var data: Variant = JSON.parse_string(text)
	var paths := []
	_paths(data, [], paths, 4000)
	if paths.is_empty():
		return text
	var path: Array = paths[rng.randi_range(0, paths.size() - 1)]
	var parent: Variant = data
	for i in path.size() - 1:
		parent = parent[path[i]]
	var last: Variant = path[path.size() - 1]
	var replacements := ["x", -1, 1.5, 1e15, [], {}, null, true]
	if kind == 2 and typeof(parent) == TYPE_DICTIONARY:
		parent.erase(last)
	elif kind == 3 or typeof(parent) != TYPE_DICTIONARY:
		parent[last] = replacements[rng.randi_range(0, replacements.size() - 1)]
	else:
		parent[last] = parent[last] if typeof(parent[last]) != TYPE_ARRAY else parent[last] + parent[last]
	return JSON.stringify(data)


func test_damaged_files_never_crash_or_load_inconsistent() -> void:
	var data := Helpers.game_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var loaded := 0
	var rejected := 0
	for version in range(1, SaveSystemScript.SAVE_VERSION + 1):
		var original := FileAccess.get_file_as_string("res://tests/fixtures/saves/v%d.json" % version)
		for i in FUZZ_PER_FILE:
			SaveSystemScript.delete_save(PATH)
			var file := FileAccess.open(PATH, FileAccess.WRITE)
			file.store_string(_mutate(original, rng))
			file.close()
			var result := SaveSystemScript.load_game(data, PATH)
			if result["game"] == null:
				rejected += 1
				assert_true(not String(result["error"]).is_empty(), "v%d #%d: abgelehnt ohne Meldung" % [version, i])
			else:
				loaded += 1
				_check_invariants(result["game"], "v%d #%d" % [version, i])
	print("          Störungen: %d geladen, %d abgelehnt" % [loaded, rejected])
	SaveSystemScript.delete_save(PATH)


# --- Messung --------------------------------------------------------------------------

func test_measure_size_and_speed() -> void:
	var data := Helpers.game_data()
	var game := GameStateScript.new(data, 77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for checkpoint in [60, 180]:
		var end := TimeSystemScript.at(checkpoint + 1, 0)
		var guard := 0
		while game.time.get_minutes() < end and guard < 50000:
			guard += 1
			Bot.step(game, rng)
		while game.events.has_pending():
			Bot.step(game, rng)
		SaveSystemScript.delete_save(PATH)
		var t0 := Time.get_ticks_usec()
		assert_eq(SaveSystemScript.save(game, PATH), "")
		var save_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var size := FileAccess.get_file_as_string(PATH).length()
		t0 = Time.get_ticks_usec()
		var result := SaveSystemScript.load_game(data, PATH)
		var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
		assert_true(result["game"] != null, "Tag %d: Laden fehlgeschlagen" % checkpoint)
		print("          Tag %d: %d Buchungen, %.0f KB, speichern %.1f ms, laden %.1f ms" % [checkpoint,
				game.ledger.get_entries().size(), size / 1024.0, save_ms, load_ms])
		assert_true(size < HARD_SIZE_LIMIT, "Spielstand größer als %d Byte" % HARD_SIZE_LIMIT)
		assert_true(load_ms < HARD_LOAD_LIMIT_MS, "Laden dauert länger als %d ms" % HARD_LOAD_LIMIT_MS)
	SaveSystemScript.delete_save(PATH)
