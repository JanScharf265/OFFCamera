extends SceneTree
## Erzeugt einen Spielstand mit dem Code des jeweiligen (alten) Commits.
## Aufruf: Godot --headless --path <alter Stand> -s make_save.gd -- <ausgabeordner>

const MINUTES_PER_DAY := 1440


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var SS = load("res://scripts/systems/save_system.gd")
	var GS = load("res://scripts/core/game_state.gd")
	var version: int = SS.SAVE_VERSION
	var game
	if version == 1:
		var activities = load("res://scripts/systems/activity_catalog.gd").new()
		activities.load_file()
		var events = load("res://scripts/systems/event_catalog.gd").new()
		events.load_file()
		game = GS.new(activities, events)
	else:
		var data = load("res://scripts/core/game_data.gd").new()
		if not data.load_all():
			print("DATENFEHLER ", data.errors)
		game = GS.new(data, 12345) if version >= 5 else GS.new(data)
	var steps := PackedStringArray()

	if game.get("locations") != null:
		steps.append("travel studio: %s" % game.locations.travel("studio"))
	if game.get("content") != null:
		steps.append("livestream: %s" % game.content.produce("livestream"))
	else:
		steps.append("stream_short: %s" % game.activities.start("stream_short"))
	if game.get("equipment") != null:
		steps.append("camera: %s" % game.equipment.buy("camera"))
	if game.get("company") != null:
		steps.append("travel office: %s" % game.locations.travel("office"))
		steps.append("found: %s" % game.company.found("merch_label"))
		if game.activities.get_catalog().has("order_stock"):
			steps.append("order_stock: %s" % game.activities.start("order_stock"))
	# Abend: festes Ereignis um 20:00 entscheiden
	var evening := 19 * 60 + 60  # Tag 1, 20:00
	if game.time.get_minutes() < evening:
		game.time.advance(evening - game.time.get_minutes())
	if game.events.has_method("is_triggered") and game.events.is_triggered("first_brand_request"):
		steps.append("brand: %s" % game.events.resolve("first_brand_request", "accept"))
	# Ein paar Tage weiter (Tagesabschlüsse, Zufallsereignisse); aktuelle Version bis in Woche 2 (Fristen)
	var target_day := 9 if version >= 11 else 3
	var target := (target_day - 1) * MINUTES_PER_DAY + 8 * 60
	game.time.advance(target - game.time.get_minutes())
	var error: String = SS.save(game, out + "/save.json")
	steps.append("save: %s" % error)

	var expect := {
		"version": version,
		"time_minutes": game.time.get_minutes(),
		"private_balance_cents": game.ledger.get_balance(),
		"entry_count": game.ledger.get_entries().size(),
		"location": game.locations.get_current() if game.get("locations") != null else "",
		"followers": game.channel.followers if game.get("channel") != null else -1,
		"camera_level": game.equipment.get_level("camera") if game.get("equipment") != null else -1,
		"company_founded": game.company.is_founded() if game.get("company") != null else false,
		"steps": steps,
	}
	var file := FileAccess.open(out + "/expect.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expect, "\t"))
	file.close()
	print("OK v%d %s" % [version, steps])
	quit()
