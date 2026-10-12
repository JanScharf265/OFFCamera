extends RefCounted

## Spiel-Bot für lange Tests (Phase 6): wählt per Zufallsgenerator (fester Seed) unter den gerade
## erlaubten Aktionen. Gleicher Stand + gleiche Zufallsfolge = gleiche Aktion – deshalb können zwei
## Spiele parallel laufen, von denen eines zwischendurch gespeichert und neu geladen wird.
## Nutzt nur die öffentlichen Funktionen der Systeme (wie die UI).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const TRANSFER_CENTS := 5000


## Führt einen Schritt aus und gibt eine kurze Beschreibung zurück.
static func step(game, rng: RandomNumberGenerator) -> String:
	if game.events.has_pending():
		return _resolve_event(game, rng)
	var actions := _candidates(game)
	var action: Array = actions[rng.randi_range(0, actions.size() - 1)]
	match action[0]:
		"activity":
			return "activity %s: %s" % [action[1], game.activities.start(action[1])]
		"content":
			return "content %s: %s" % [action[1], game.content.produce(action[1])]
		"travel":
			return "travel %s: %s" % [action[1], game.locations.travel(action[1])]
		"equipment":
			return "equipment %s: %s" % [action[1], game.equipment.buy(action[1])]
		"found":
			return "found %s: %s" % [action[1], game.company.found(action[1])]
		"branch":
			return "branch: %s" % game.company.open_branch()
		"deposit":
			return "deposit: %s" % game.company.deposit(TRANSFER_CENTS)
		"withdraw":
			return "withdraw: %s" % game.company.withdraw(TRANSFER_CENTS)
		"pay":
			return "pay %s: %s" % [action[1], game.obligations.pay(action[1])]
		"attend":
			return "attend %s: %s" % [action[1], game.appointments.attend(action[1])]
		_:
			var minutes: int = action[1]
			game.time.advance(minutes)
			return "wait %d" % minutes


static func _candidates(game) -> Array:
	var actions := []
	var here: String = game.locations.get_current()
	for id in game.activities.get_catalog().get_ids_at(here):
		if game.activities.check(id).is_empty():
			actions.append(["activity", id])
	for id in game.content.get_catalog().get_ids_at(here):
		if game.content.check(id).is_empty():
			actions.append(["content", id])
	for id in game.equipment.get_catalog().get_ids_at(here):
		if game.equipment.check_buy(id).is_empty():
			actions.append(["equipment", id])
	for id in game.company.get_catalog().get_ids_at(here):
		if game.company.check_found(id).is_empty():
			actions.append(["found", id])
	if game.company.is_founded() and game.company.check_open_branch().is_empty():
		actions.append(["branch"])
	if game.company.check_deposit(TRANSFER_CENTS).is_empty():
		actions.append(["deposit"])
	if game.company.check_withdraw(TRANSFER_CENTS).is_empty():
		actions.append(["withdraw"])
	for instance in game.obligations.get_open():
		if game.obligations.check_pay(instance["id"]).is_empty():
			actions.append(["pay", instance["id"]])
	for definition in game.appointments.get_upcoming():
		if game.appointments.check(definition.id).is_empty():
			actions.append(["attend", definition.id])
	for id in game.locations.get_catalog().get_ids():
		if id != here and game.locations.check_travel(id).is_empty():
			actions.append(["travel", id])
	# Warten sorgt dafür, dass immer etwas geht und Tage vergehen (Schlafen ist auch eine Aktivität).
	actions.append(["wait", 180])
	actions.append(["wait", 600])
	return actions


static func _resolve_event(game, rng: RandomNumberGenerator) -> String:
	var instance: String = game.events.get_next_pending_id()
	var options: Array = game.events.get_definition_for(instance).options.duplicate()
	var start := rng.randi_range(0, options.size() - 1)
	for i in options.size():
		var option = options[(start + i) % options.size()]
		if game.events.resolve(instance, option.id).is_empty():
			return "event %s: %s" % [instance, option.id]
	return "event %s: keine Option möglich" % instance
