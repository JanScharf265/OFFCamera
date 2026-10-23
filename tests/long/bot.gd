extends RefCounted

## Spiel-Bot für lange Tests (Phase 6): wählt per Zufallsgenerator (fester Seed) unter den gerade
## erlaubten Aktionen. Gleicher Stand + gleiche Zufallsfolge = gleiche Aktion – deshalb können zwei
## Spiele parallel laufen, von denen eines zwischendurch gespeichert und neu geladen wird.
## Nutzt nur die öffentlichen Funktionen der Systeme (wie die UI). Seit U.24 auch die Unterwelt: Organisation
## gründen, Ware bestellen (auch auf Kredit), verkaufen, Standorte anmieten und ausbauen, Crew einstellen, befördern,
## zuteilen, feuern, Gebiete beanspruchen, Waffenstillstand, waschen, Schwarzgeld im Alltag, Anwalt, Kaution, warten,
## Kontakte.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const TRANSFER_CENTS := 5000
const ORDER_UNITS := 5
const LAUNDER_CENTS := 10000


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
		"name_org":
			return "name_org: %s" % game.organisation.found("Los Bots")
		"order":
			return "order %s: %s" % [action[2], game.supply.order(action[1], action[2], ORDER_UNITS)]
		"credit":
			return "credit %s: %s" % [action[2], game.supply.order_on_credit(action[1], action[2], ORDER_UNITS)]
		"sell":
			return "sell %s: %s" % [action[2], game.sales.sell(action[1], action[2], action[3])]
		"site":
			return "site %s: %s" % [action[1], game.sites.acquire(action[1])]
		"upgrade":
			return "upgrade %s: %s" % [action[1], game.sites.upgrade(action[1])]
		"hire":
			return "hire %s: %s" % [action[1], game.crew.hire(action[1])]
		"fire":
			return "fire %s: %s" % [action[1], game.crew.fire(action[1])]
		"promote":
			return "promote %s: %s" % [action[1], game.crew.promote(action[1])]
		"assign":
			return "assign %s %s: %s" % [action[1], action[2], game.crew.assign(action[1], action[2])]
		"claim":
			return "claim %s: %s" % [action[1], game.territory.claim(action[1])]
		"truce":
			return "truce %s: %s" % [action[1], game.rivals.offer_truce(action[1])]
		"launder":
			return "launder: %s" % game.laundering.launder(LAUNDER_CENTS)
		"black_spending":
			game.black_spending.set_enabled(not game.black_spending.is_enabled())
			return "black_spending %s" % game.black_spending.is_enabled()
		"lawyer":
			return "lawyer: %s" % game.police.hire_lawyer()
		"bail":
			return "bail: %s" % game.justice.pay_bail()
		"justice_wait":
			return "justice_wait: %s" % game.justice.wait()
		"contact":
			return "contact %s: %s" % [action[1], game.relationships.act(action[1])]
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
	_underworld_candidates(game, actions, here)
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


## U.24: erlaubte Unterwelt-Aktionen (Reihenfolge fest, damit gespeicherte und ungestörte Spiele gleich wählen).
static func _underworld_candidates(game, actions: Array, here: String) -> void:
	if game.organisation.needs_name():
		actions.append(["name_org"])
		return
	if not game.organisation.is_founded():
		return
	for supplier in game.supply.get_unlocked():
		for product_id in supplier.products:
			if game.supply.check_order(supplier.id, product_id, ORDER_UNITS).is_empty():
				actions.append(["order", supplier.id, product_id])
			if game.supply.check_credit_order(supplier.id, product_id, ORDER_UNITS).is_empty():
				actions.append(["credit", supplier.id, product_id])
	for spot in game.sales.get_catalog().get_at(here):
		for product in game.supply.get_products().get_all():
			var units: int = mini(5, game.supply.get_stock(product.id))
			if units > 0 and game.sales.check_sale(spot.id, product.id, units).is_empty():
				actions.append(["sell", spot.id, product.id, units])
	for site in game.sites.get_catalog().get_at(here):
		if game.sites.check_acquire(site.id).is_empty():
			actions.append(["site", site.id])
		if game.sites.check_upgrade(site.id).is_empty():
			actions.append(["upgrade", site.id])
	var applicants: Array = game.crew.get_applicants()
	if not applicants.is_empty() and game.crew.check_hire(applicants[0]["id"]).is_empty():
		actions.append(["hire", applicants[0]["id"]])
	var districts: Array = game.territory.get_districts().get_all()
	for member in game.crew.get_members():
		if game.crew.check_promote(member["id"]).is_empty():
			actions.append(["promote", member["id"]])
		if game.crew.is_dealer(member) and String(member.get("district", "")).is_empty():
			actions.append(["assign", member["id"], districts[0].id])
	if game.crew.get_members().size() > 2:
		actions.append(["fire", game.crew.get_members()[0]["id"]])
	for district in districts:
		if game.territory.check_claim(district.id).is_empty():
			actions.append(["claim", district.id])
	for gang in game.rivals.get_catalog().get_all():
		if game.rivals.get_relation(gang.id) == "conflict" and game.rivals.check_truce(gang.id).is_empty():
			actions.append(["truce", gang.id])
	if game.laundering.is_available() and game.laundering.check(LAUNDER_CENTS).is_empty():
		actions.append(["launder"])
	if game.black_spending.is_available() and not game.black_spending.is_enabled():
		actions.append(["black_spending"])
	if game.police.check_lawyer().is_empty():
		actions.append(["lawyer"])
	if game.justice.check_bail().is_empty():
		actions.append(["bail"])
	if game.justice.wait_target_day() > 0:
		actions.append(["justice_wait"])
	for contact in game.relationships.get_known():
		if game.relationships.check_action(contact.id).is_empty():
			actions.append(["contact", contact.id])
