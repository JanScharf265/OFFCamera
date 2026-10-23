extends RefCounted

## Crew 1 (U.10): Rollen als Daten (data/underworld/crew.json). Jeden Tag gibt es einige Bewerber – bestimmt aus
## Spiel-Seed und Tag, also nach dem Laden gleich. Einstellen und Feuern sofort (ein Anruf, keine Spielzeit). Jedes
## Mitglied hat Rolle, Können, Loyalität, Gier (0–100) und einen Tageslohn; die Löhne zahlt der DayCycle beim
## Tageswechsel als eine Buchung (Schwarzgeld, ersatzweise Privatkonto, sonst Frist).
## U.11: Dealer verkaufen beim Tageswechsel für den vergangenen Tag aus dem Bestand (Unterwelt-Abrechnung, eine
## Buchung aufs Schwarzgeld): Einheiten wachsen mit dem Können, Gier zweigt einen Teil der Einnahme ab, Können senkt
## die Hitze. Bezahlte Löhne heben die Loyalität, unbezahlte senken sie. Befördern (Rang 1–3) kostet einmalig und
## hebt Können, Loyalität und Lohn. Reine Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

signal hired(member_id: String, role_id: String)
## U.11: Unterwelt-Abrechnung (Einheiten der Dealer am vergangenen Tag)
signal dealers_sold(units: int)

const DEFAULT_PATH := "res://data/underworld/crew.json"
const CATEGORY := "underworld_wages"
const SOURCE := "crew"
const FIELDS := ["unlocked_by_mission", "max_members", "applicants_per_day", "dealing", "promotion", "first_names",
		"last_initials", "roles"]
## U.11: Regeln für den täglichen Straßenverkauf und das Befördern (alles ganze Zahlen ≥ 0, `role` eine Rollen-ID).
const DEALING_FIELDS := ["base_units", "skill_per_extra_unit", "skim_percent_per_10_greed", "heat_skill_percent",
		"loyalty_paid", "loyalty_unpaid"]
const PROMOTION_FIELDS := ["max_rank", "min_days", "cost_wage_days", "skill_bonus", "loyalty_bonus", "wage_percent"]
const SALES_CATEGORY := "underworld_street_sales"
const ROLE_FIELDS := ["id", "display_name", "description", "wage_min_cents", "wage_max_cents", "order", "offered"]
const VALUE_KEYS := ["skill", "loyalty", "greed"]
const VALUE_LABELS := {"skill": "Können", "loyalty": "Loyalität", "greed": "Gier"}
## Bewerberwerte liegen in diesem Bereich (keine Extreme am Anfang).
const VALUE_MIN := 20
const VALUE_MAX := 80


## Eine Rolle (nur Daten).
class Role extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	var wage_min_cents: int
	var wage_max_cents: int
	var order: int
	## Wird als Bewerber angeboten (GD nach U.10: nur Rollen mit echter Wirkung)
	var offered: bool


## Katalog: Regeln und Rollen. Alles-oder-nichts.
class Catalog extends RefCounted:
	var errors: PackedStringArray = []
	var unlocked_by_mission := ""
	var max_members := 0
	var applicants_per_day := 0
	var first_names: PackedStringArray = []
	var last_initials: PackedStringArray = []
	## U.11: {role, base_units, …} und {max_rank, …}
	var dealing := {}
	var promotion := {}
	var _roles: Array = []

	func load_file(path: String = "res://data/underworld/crew.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			_roles.clear()
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		var reader := DataReaderScript.new()
		_roles.clear()
		if typeof(data) != TYPE_DICTIONARY:
			errors = PackedStringArray(["Crew-Regeln müssen ein Objekt sein."])
			return false
		var where := "Crew"
		for key in data:
			if String(key) not in FIELDS:
				reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
		var mission := reader.string_field(data, "unlocked_by_mission", where, true)
		var max_count := reader.int_field(data, "max_members", where, true)
		var per_day := reader.int_field(data, "applicants_per_day", where, true)
		if max_count < 1 or per_day < 1:
			reader.errors.append("%s: max_members und applicants_per_day müssen ≥ 1 sein." % where)
		var dealing_rules := _rules(data, "dealing", DEALING_FIELDS, ["role"], reader)
		var promotion_rules := _rules(data, "promotion", PROMOTION_FIELDS, [], reader)
		if dealing_rules.get("skill_per_extra_unit", 1) < 1 or promotion_rules.get("max_rank", 1) < 1 \
				or promotion_rules.get("wage_percent", 100) < 100:
			reader.errors.append("Crew: skill_per_extra_unit und max_rank ≥ 1, wage_percent ≥ 100.")
		var names := _names(data, "first_names", reader)
		var initials := _names(data, "last_initials", reader)
		var roles: Array = []
		var raw: Variant = data.get("roles")
		if typeof(raw) != TYPE_ARRAY or raw.is_empty():
			reader.errors.append("%s: 'roles' muss eine nicht leere Liste sein." % where)
		else:
			var seen := {}
			for i in raw.size():
				var entry: Variant = raw[i]
				var role_where := "Rolle #%d" % (i + 1)
				if typeof(entry) != TYPE_DICTIONARY:
					reader.errors.append("%s: muss ein Objekt sein." % role_where)
					continue
				var error_count := reader.errors.size()
				var id := reader.id_field(entry, role_where)
				if id.is_empty():
					continue
				role_where = "Rolle '%s'" % id
				for key in entry:
					if String(key) not in ROLE_FIELDS:
						reader.errors.append("%s: unbekanntes Feld '%s'." % [role_where, key])
				var role := Role.new()
				role.id = id
				role.display_name = reader.string_field(entry, "display_name", role_where, true)
				role.description = reader.string_field(entry, "description", role_where, true)
				role.wage_min_cents = reader.int_field(entry, "wage_min_cents", role_where, true)
				role.wage_max_cents = reader.int_field(entry, "wage_max_cents", role_where, true)
				role.order = reader.int_field(entry, "order", role_where, true)
				if typeof(entry.get("offered")) != TYPE_BOOL:
					reader.errors.append("%s: 'offered' muss true oder false sein." % role_where)
				else:
					role.offered = entry["offered"]
				if role.wage_min_cents < 0 or role.wage_max_cents < role.wage_min_cents:
					reader.errors.append("%s: Lohnspanne ungültig." % role_where)
				if seen.has(id):
					reader.errors.append("%s: ID kommt doppelt vor." % role_where)
				if reader.errors.size() == error_count:
					seen[id] = true
					roles.append(role)
		if reader.errors.is_empty() and not roles.any(func(role) -> bool: return role.id == dealing_rules["role"]):
			reader.errors.append("Crew: 'dealing.role' ist keine bekannte Rolle.")
		if reader.errors.is_empty() and not roles.any(func(role) -> bool: return role.offered):
			reader.errors.append("Crew: mindestens eine Rolle muss angeboten werden ('offered').")
		errors = reader.errors
		if not errors.is_empty():
			return false
		roles.sort_custom(func(a, b) -> bool: return a.order < b.order)
		unlocked_by_mission = mission
		max_members = max_count
		applicants_per_day = per_day
		first_names = names
		last_initials = initials
		dealing = dealing_rules
		promotion = promotion_rules
		_roles = roles
		return true

	static func _rules(data: Dictionary, field: String, int_fields: Array, string_fields: Array, reader) -> Dictionary:
		var raw: Variant = data.get(field)
		if typeof(raw) != TYPE_DICTIONARY:
			reader.errors.append("Crew: '%s' muss ein Objekt sein." % field)
			return {}
		var result := {}
		for key in raw:
			if String(key) not in int_fields + string_fields:
				reader.errors.append("Crew: '%s' hat unbekanntes Feld '%s'." % [field, key])
		for key in int_fields:
			if not DataReaderScript.is_whole_number(raw.get(key)) or int(raw[key]) < 0:
				reader.errors.append("Crew: '%s.%s' muss eine ganze Zahl ≥ 0 sein." % [field, key])
			else:
				result[key] = int(raw[key])
		for key in string_fields:
			if typeof(raw.get(key)) != TYPE_STRING or String(raw[key]).is_empty():
				reader.errors.append("Crew: '%s.%s' fehlt." % [field, key])
			else:
				result[key] = raw[key]
		return result

	static func _names(data: Dictionary, field: String, reader) -> PackedStringArray:
		var raw: Variant = data.get(field)
		var result := PackedStringArray()
		if typeof(raw) != TYPE_ARRAY or raw.is_empty():
			reader.errors.append("Crew: '%s' muss eine nicht leere Liste sein." % field)
			return result
		for value in raw:
			if typeof(value) != TYPE_STRING or String(value).strip_edges().is_empty():
				reader.errors.append("Crew: '%s' enthält einen ungültigen Namen." % field)
				return PackedStringArray()
			result.append(value)
		return result

	func get_roles() -> Array:
		return _roles.duplicate()

	func get_role(id: String):
		for role in _roles:
			if role.id == id:
				return role
		return null

	## Rollen, die als Bewerber kommen.
	func get_offered_roles() -> Array:
		return _roles.filter(func(role) -> bool: return role.offered)

	func has_role(id: String) -> bool:
		return get_role(id) != null


var _time
var _ledger: LedgerSystemScript
var _catalog: Catalog
var _organisation
var _supply
var _obligations
var _is_mission_completed: Callable
var _get_seed: Callable
## U.13: Gebiete (Callables auf das TerritorySystem – keine gegenseitige Referenz)
var _add_influence: Callable
var _unit_bonus: Callable
var _influence_for_skill: Callable
var _district_definition: Callable
## Mitglieder in Einstellungsreihenfolge: {id, name, role, skill, loyalty, greed, wage_cents, hired_day}
var _members: Array = []
## Heute gefeuerte Bewerber-IDs (sonst stünden sie gleich wieder unter „Bewerber“)
var _gone_today: PackedStringArray = []
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, catalog: Catalog, organisation, supply, obligations,
		is_mission_completed: Callable, get_seed: Callable) -> void:
	_time = time
	_ledger = ledger
	_catalog = catalog
	_organisation = organisation
	_supply = supply
	_obligations = obligations
	_is_mission_completed = is_mission_completed
	_get_seed = get_seed
	_last_processed_day = time.get_day()


func get_catalog() -> Catalog:
	return _catalog


## Vom GameState (U.13): Anbindung an die Gebiete.
func set_territory(add_influence: Callable, unit_bonus: Callable, influence_for_skill: Callable,
		district_definition: Callable) -> void:
	_add_influence = add_influence
	_unit_bonus = unit_bonus
	_influence_for_skill = influence_for_skill
	_district_definition = district_definition


## U.13: Teilt ein Mitglied (Dealer) einem Gebiet zu ("" = keinem). "" = zugeteilt.
func assign(member_id: String, district_id: String) -> String:
	if not district_id.is_empty() and (not _district_definition.is_valid() or _district_definition.call(district_id) == null):
		return "Unbekanntes Gebiet: %s" % district_id
	for member in _members:
		if member["id"] == member_id:
			if not is_dealer(member):
				return "Nur Dealer arbeiten in einem Gebiet."
			member["district"] = district_id
			return ""
	return "Dieses Mitglied gibt es nicht."


## Dealer in einem Gebiet.
func count_in_district(district_id: String) -> int:
	return _members.filter(func(member) -> bool: return is_dealer(member) and member.get("district", "") == district_id).size()


## Crew verfügbar (Organisation steht, Freischalt-Auftrag erledigt).
func is_available() -> bool:
	return _organisation.is_founded() and _is_mission_completed.call(_catalog.unlocked_by_mission)


func get_members() -> Array:
	return _members.duplicate(true)


func get_member(member_id: String) -> Dictionary:
	for member in _members:
		if member["id"] == member_id:
			return member.duplicate()
	return {}


func count_role(role_id: String) -> int:
	return _members.filter(func(member) -> bool: return member["role"] == role_id).size()


## Summe der Tageslöhne (Cent).
func wages_per_day() -> int:
	var total := 0
	for member in _members:
		total += int(member["wage_cents"])
	return total


## Bewerber des Tages (aus Seed und Tag) – ohne eingestellte und heute gefeuerte.
func get_applicants() -> Array:
	var result: Array = []
	if not is_available():
		return result
	var day: int = _time.get_day()
	for slot in _catalog.applicants_per_day:
		var applicant := _applicant(day, slot)
		if applicant.is_empty() or not get_member(applicant["id"]).is_empty() or applicant["id"] in _gone_today:
			continue
		result.append(applicant)
	return result


@warning_ignore("integer_division")
func _applicant(day: int, slot: int) -> Dictionary:
	var roles := _catalog.get_offered_roles()
	if roles.is_empty():
		return {}
	var base := "%d:crew:%d:%d" % [_get_seed.call(), day, slot]
	var role = roles[_roll(base, "role") % roles.size()]
	var applicant := {"id": "a%d_%d" % [day, slot], "role": role.id,
			"name": "%s %s" % [_catalog.first_names[_roll(base, "first") % _catalog.first_names.size()],
					_catalog.last_initials[_roll(base, "last") % _catalog.last_initials.size()]]}
	for key in VALUE_KEYS:
		applicant[key] = VALUE_MIN + _roll(base, key) % (VALUE_MAX - VALUE_MIN + 1)
	# Lohn wächst mit dem Können, auf volle Euro.
	var wage: int = role.wage_min_cents + (role.wage_max_cents - role.wage_min_cents) * (applicant["skill"] - VALUE_MIN) \
			/ (VALUE_MAX - VALUE_MIN)
	applicant["wage_cents"] = wage / 100 * 100
	return applicant


func _roll(base: String, key: String) -> int:
	return EventSystemScript.fnv1a("%s:%s" % [base, key])


## "" wenn der Bewerber jetzt eingestellt werden kann, sonst ein Grund.
func check_hire(applicant_id: String) -> String:
	if not is_available():
		return "Noch keine Crew möglich."
	if _find_applicant(applicant_id).is_empty():
		return "Diesen Bewerber gibt es heute nicht."
	if _members.size() >= _catalog.max_members:
		return "Crew ist voll (%d)." % _catalog.max_members
	return ""


func _find_applicant(applicant_id: String) -> Dictionary:
	for applicant in get_applicants():
		if applicant["id"] == applicant_id:
			return applicant
	return {}


## Stellt ein (sofort, ohne Spielzeit). "" = eingestellt.
func hire(applicant_id: String) -> String:
	var reason := check_hire(applicant_id)
	if not reason.is_empty():
		return reason
	var member := _find_applicant(applicant_id)
	member["hired_day"] = _time.get_day()
	member["rank"] = 1
	member["district"] = ""
	_members.append(member)
	hired.emit(member["id"], member["role"])
	return ""


## Feuert (sofort). "" = gefeuert.
func fire(member_id: String) -> String:
	for i in _members.size():
		if _members[i]["id"] == member_id:
			_members.remove_at(i)
			if String(member_id).begins_with("a%d_" % _time.get_day()):
				_gone_today.append(member_id)
			return ""
	return "Dieses Mitglied gibt es nicht."


## Hinweise (Löhne) seit dem letzten Aufruf.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Konto für eine Zahlung: Schwarzgeld, wenn es reicht, sonst Privatkonto.
func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


# --- U.11: Dealer und Befördern ---------------------------------------------------

func is_dealer(member: Dictionary) -> bool:
	return member.get("role", "") == _catalog.dealing.get("role", "")


## Einheiten, die ein Dealer an einem Tag verkauft (ohne Bestandsgrenze); mit `day` je nach Tag +0 oder +1 (Seed).
@warning_ignore("integer_division")
func dealer_units(member: Dictionary, day: int = -1) -> int:
	var rules: Dictionary = _catalog.dealing
	var units: int = rules["base_units"] + int(member["skill"]) / rules["skill_per_extra_unit"]
	if day >= 0:
		units += _roll("%d:deal:%d:%s" % [_get_seed.call(), day, member["id"]], "extra") % 2
	return units


## Anteil der Einnahme, den der Dealer abzweigt (Prozent, aus der Gier).
@warning_ignore("integer_division")
func skim_percent(member: Dictionary) -> int:
	return clampi(int(member["greed"]) * _catalog.dealing["skim_percent_per_10_greed"] / 10, 0, 100)


## Hitze des Dealers in Prozent der Hitze je Einheit (Können senkt sie).
@warning_ignore("integer_division")
func heat_percent(member: Dictionary) -> int:
	return clampi(100 - int(member["skill"]) * _catalog.dealing["heat_skill_percent"] / 100, 0, 100)


## Einmalige Kosten fürs Befördern (Cent).
func promotion_cost(member: Dictionary) -> int:
	return int(member["wage_cents"]) * _catalog.promotion["cost_wage_days"]


## "" wenn das Mitglied jetzt befördert werden kann, sonst ein Grund.
func check_promote(member_id: String) -> String:
	var member := get_member(member_id)
	if member.is_empty():
		return "Dieses Mitglied gibt es nicht."
	var rules: Dictionary = _catalog.promotion
	if int(member.get("rank", 1)) >= rules["max_rank"]:
		return "Höchster Rang erreicht."
	var days: int = _time.get_day() - int(member["hired_day"])
	if days < rules["min_days"]:
		return "Erst nach %d Tagen (noch %d)." % [rules["min_days"], rules["min_days"] - days]
	var cost := promotion_cost(member)
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Befördert: Buchung (Schwarzgeld, sonst privat) → Rang, Können, Loyalität, Lohn. "" = befördert.
@warning_ignore("integer_division")
func promote(member_id: String) -> String:
	var reason := check_promote(member_id)
	if not reason.is_empty():
		return reason
	var rules: Dictionary = _catalog.promotion
	for member in _members:
		if member["id"] != member_id:
			continue
		var cost := promotion_cost(member)
		var rank := int(member.get("rank", 1)) + 1
		var entry := _ledger.post(-cost, CATEGORY, "Beförderung: %s (Rang %d)" % [member["name"], rank], SOURCE,
				member_id, "crew:promote:%s:%d" % [member_id, rank], false, payment_account(cost))
		if entry == null:
			return "Die Buchung ist fehlgeschlagen."
		member["rank"] = rank
		member["skill"] = mini(100, int(member["skill"]) + rules["skill_bonus"])
		member["loyalty"] = mini(100, int(member["loyalty"]) + rules["loyalty_bonus"])
		member["wage_cents"] = int(member["wage_cents"]) * rules["wage_percent"] / 100 / 100 * 100
		return ""
	return "Dieses Mitglied gibt es nicht."


## Unterwelt-Abrechnung für den Vortag: Dealer (vor dem neuen Tag eingestellt) verkaufen aus dem Bestand.
@warning_ignore("integer_division")
func _settle_dealers(day: int) -> void:
	var units_total := 0
	var income := 0
	var skimmed := 0
	var heat := 0
	var dealers := 0
	for member in _members:
		if not is_dealer(member) or int(member["hired_day"]) >= day:
			continue
		dealers += 1
		var district_id: String = member.get("district", "")
		var wanted := dealer_units(member, day)
		if not district_id.is_empty() and _unit_bonus.is_valid():
			wanted += int(_unit_bonus.call(district_id))
		var sold_before := units_total
		for product in _supply.get_products().get_all():
			if wanted <= 0:
				break
			var units := mini(wanted, _supply.get_stock(product.id))
			if units <= 0 or not _supply.remove_stock(product.id, units):
				continue
			wanted -= units
			units_total += units
			var gross: int = product.sell_price_cents * units
			var skim := gross * skim_percent(member) / 100
			income += gross - skim
			skimmed += skim
			heat += product.heat_per_unit * units * heat_percent(member) / 100
		if units_total > sold_before and not district_id.is_empty() and _add_influence.is_valid():
			_add_influence.call(district_id, int(_influence_for_skill.call(int(member["skill"]))))
	if dealers == 0:
		return
	if units_total == 0:
		_notices.append("Abrechnung: Deine Dealer hatten keine Ware.")
		return
	if income > 0:
		_ledger.post(income, SALES_CATEGORY, "Abrechnung Straße (Tag %d, %d Einheiten)" % [day - 1, units_total], SOURCE,
				"dealers", "crew:sales:day:%d" % day, false, LedgerSystemScript.BLACK, TimeSystemScript.at(day, 0))
	if heat > 0:
		_organisation.change({"heat": heat})
	var text := "Abrechnung: Deine Dealer haben %d Einheiten verkauft (+%s Schwarzgeld, Hitze +%d)" % [units_total,
			LedgerSystemScript.format_cents(income), heat]
	if skimmed > 0:
		text += " – abgezweigt: %s" % LedgerSystemScript.format_cents(skimmed)
	_notices.append(text + ".")
	dealers_sold.emit(units_total)


## Vom DayCycle: erst die Abrechnung der Dealer (Vortag), dann die Löhne für den neuen Tag – je eine Buchung.
## Bezahlte Löhne heben die Loyalität aller, unbezahlte senken sie.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	_gone_today.clear()
	_settle_dealers(day)
	var total := wages_per_day()
	if total <= 0:
		return
	var account := payment_account(total)
	var label := "Löhne Crew (Tag %d, %s)" % [day, "1 Person" if _members.size() == 1 else "%d Leute" % _members.size()]
	var paid := _ledger.can_afford(total, account)
	if paid:
		_ledger.post(-total, CATEGORY, label, SOURCE, "wages", "crew:wages:day:%d" % day, false, account,
				TimeSystemScript.at(day, 0))
	elif _obligations != null:
		_obligations.add_one_off("crew_wages@%d" % day, label, total, LedgerSystemScript.BLACK, CATEGORY, 2, 0,
				TimeSystemScript.at(day, 0))
		_notices.append("%s: Das Geld reicht nicht – offen unter „Fristen“. Die Loyalität sinkt." % label)
	var delta: int = _catalog.dealing["loyalty_paid"] if paid else -_catalog.dealing["loyalty_unpaid"]
	for member in _members:
		member["loyalty"] = clampi(int(member["loyalty"]) + delta, 0, 100)


func to_dict() -> Dictionary:
	return {"members": _members.duplicate(true), "gone_today": Array(_gone_today),
			"last_processed_day": _last_processed_day}


## Unbekannte Rollen (aus den Daten entfernt) bleiben erhalten. "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	var raw: Variant = data.get("members")
	if typeof(raw) != TYPE_ARRAY:
		return "Crew: 'members' fehlt oder ist keine Liste."
	var members: Array = []
	var ids := {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return "Crew: ungültiges Mitglied."
		for key in ["id", "name", "role"]:
			if typeof(entry.get(key)) != TYPE_STRING or String(entry[key]).is_empty():
				return "Crew: Mitglied ohne gültiges '%s'." % key
		var member := {"id": entry["id"], "name": entry["name"], "role": entry["role"]}
		if typeof(entry.get("district")) != TYPE_STRING:
			return "Crew: Mitglied '%s' ohne gültiges 'district'." % entry["id"]
		member["district"] = entry["district"]
		for key in VALUE_KEYS + ["wage_cents", "hired_day", "rank"]:
			var value: Variant = entry.get(key)
			if not DataReaderScript.is_whole_number(value) or int(value) < 0 or (key in VALUE_KEYS and int(value) > 100) \
					or (key == "rank" and int(value) < 1):
				return "Crew: Mitglied '%s' mit ungültigem '%s'." % [entry["id"], key]
			member[key] = int(value)
		if ids.has(member["id"]):
			return "Crew: Mitglied '%s' doppelt." % member["id"]
		ids[member["id"]] = true
		members.append(member)
	var gone: Variant = data.get("gone_today")
	if typeof(gone) != TYPE_ARRAY or gone.any(func(value) -> bool: return typeof(value) != TYPE_STRING):
		return "Crew: 'gone_today' fehlt oder ist ungültig."
	if not DataReaderScript.is_whole_number(data.get("last_processed_day")) or int(data["last_processed_day"]) < 0:
		return "Crew: 'last_processed_day' fehlt oder ist ungültig."
	_members = members
	_gone_today = PackedStringArray(gone)
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
