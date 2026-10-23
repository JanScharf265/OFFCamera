extends RefCounted

## Prüft nach dem Laden, ob die Systeme zueinander passen (Phase 6). Jedes System prüft beim
## restore() nur sich selbst; hier geht es um Regeln über System-Grenzen hinweg. Eine Verletzung
## heißt: Der Spielstand ist unstimmig (Geld, Zeit oder Schutzschlüssel) – er wird abgelehnt und
## das nächste Backup versucht. Entfernte Daten sind KEINE Verletzung (die regeln die Systeme tolerant).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")


## Liste der Verletzungen (leer = stimmig). `game` ist ein GameState.
static func check(game) -> PackedStringArray:
	var problems := PackedStringArray()
	var now: int = game.time.get_minutes()
	var today := TimeSystemScript.day_of(now)
	var ledger: Dictionary = game.ledger.to_dict()
	var entry_ids := {}
	var highest := 0

	for entry in game.ledger.get_entries():
		entry_ids[entry.id] = true
		if entry.time_minutes > now or entry.effective_minutes > now:
			problems.append("Buchung %s liegt nach der Spielzeit." % entry.id)
		if entry.id.begins_with("tx_") and entry.id.substr(3).is_valid_int():
			highest = maxi(highest, int(entry.id.substr(3)))
	if int(ledger["next_number"]) <= highest:
		problems.append("Nächste Buchungsnummer (%d) ist schon vergeben." % int(ledger["next_number"]))
	var keys: Dictionary = ledger["used_keys"]
	for key in keys:
		if not entry_ids.has(keys[key]):
			problems.append("Schutzschlüssel „%s“ zeigt auf fehlende Buchung %s." % [key, keys[key]])

	for change in game.channel.get_history() + game.company.get_history():
		if change.time_minutes > now:
			problems.append("Protokolleintrag %s liegt nach der Spielzeit." % change.id)

	var company: Dictionary = game.company.to_dict()
	if company.get("founded") == true:
		if int(company["founded_minutes"]) > now:
			problems.append("Unternehmen wurde nach der Spielzeit gegründet.")
		if int(company["last_settled_day"]) >= today:
			problems.append("Tagesabschluss für einen Tag, der noch nicht vorbei ist.")
		for pair in [["deposit", int(company["deposits"])], ["withdraw", int(company["withdrawals"])]]:
			var count: int = pair[1]
			if count > 0 and not keys.has("company:%s:%d|out" % [pair[0], count]):
				problems.append("Zähler %s (%d) passt nicht zu den Buchungen." % [pair[0], count])
			if keys.has("company:%s:%d|out" % [pair[0], count + 1]):
				problems.append("Umbuchung %s %d ohne passenden Zähler." % [pair[0], count + 1])

	var obligations: Dictionary = game.obligations.to_dict()
	if int(obligations["last_processed_day"]) > today:
		problems.append("Fristen wurden für einen Tag in der Zukunft verarbeitet.")
	for instance in obligations["instances"]:
		var booked := keys.has("obligation:%s" % instance["id"])
		if instance["status"] == "paid" and int(instance["amount_cents"]) > 0 and not booked:
			problems.append("Frist %s ist bezahlt, aber nicht gebucht." % instance["id"])
		if instance["status"] == "open" and booked:
			problems.append("Frist %s ist offen, aber schon gebucht." % instance["id"])
		if int(instance["due_minutes"]) > now:
			problems.append("Frist %s ist erst in der Zukunft fällig." % instance["id"])

	# U.24: Unterwelt
	if game.ledger.get_balance("black") < 0:
		problems.append("Schwarzgeld ist negativ.")
	for product in game.supply.get_products().get_all():
		if game.supply.get_stock(product.id) < 0:
			problems.append("Bestand von %s ist negativ." % product.id)
	if game.crew.get_members().size() > game.crew.get_catalog().max_members:
		problems.append("Mehr Crew als erlaubt.")
	for member in game.crew.get_members():
		if int(member["hired_day"]) > today:
			problems.append("Crew-Mitglied %s wurde in der Zukunft eingestellt." % member["id"])
	for district in game.territory.get_districts().get_all():
		if game.territory.is_controlled(district.id) and game.territory.controlled_since(district.id) > today:
			problems.append("Gebiet %s gehört dir erst in der Zukunft." % district.id)
	for system in [game.organisation, game.supply, game.sites, game.crew, game.territory, game.rivals, game.police,
			game.justice, game.relationships]:
		var state: Dictionary = system.to_dict()
		if int(state.get("last_processed_day", 0)) > today:
			problems.append("Ein Tageswechsel wurde für einen Tag in der Zukunft verarbeitet.")
	if game.justice.is_locked_up() and game.locations.get_current() != "prison":
		problems.append("In Haft, aber nicht in der Haftanstalt.")
	if game.organisation.to_dict()["last_cooled_day"] > today:
		problems.append("Abkühlung für einen Tag in der Zukunft.")
	return problems
