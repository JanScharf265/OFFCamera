extends RefCounted

## Rivalen (U.14): erfundene Banden als Daten (data/underworld/rivals.json) mit Stärke, Aggression und Revier
## (Gebiets-IDs, je Gebiet höchstens eine Bande). Beziehung je Bande: neutral, Konflikt (bis Tag X) oder
## Waffenstillstand (bis Tag X). Wirkung auf die Gebiete: Der tägliche Druck der Rivalen (TerritorySystem) wird mit
## `pressure_percent` gewichtet – Waffenstillstand 0 %, Konflikt `conflict_pressure_percent`, dazu Stärke/50.
## Konflikt: Hast du Einfluss im Revier einer Bande (≥ `clash_min_influence`), löst der Tageswechsel mit einer Chance
## aus Aggression (Seed, deterministisch) ihr Ereignis „Ärger mit …“ aus (EventSystem, „scripted“). Die Antworten
## wirken über `apply_event_action`: dagegenhalten (Bande schwächer, Konflikt), verhandeln (Waffenstillstand gegen
## Geld), zurückziehen (Einfluss und Respekt −). Gewalt nur als Text und Folgen; reine Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

const DEFAULT_PATH := "res://data/underworld/rivals.json"
const CATEGORY := "underworld_rivals"
const SOURCE := "rivals"
const NEUTRAL := "neutral"
const CONFLICT := "conflict"
const TRUCE := "truce"
const RELATION_LABELS := {NEUTRAL: "Neutral", CONFLICT: "Konflikt", TRUCE: "Waffenstillstand"}
const RULE_FIELDS := ["clash_min_influence", "clash_chance_per_10_aggression", "conflict_days",
		"conflict_pressure_percent", "conflict_chance_percent", "fight_strength_loss", "strength_regen_per_day",
		"truce_days", "truce_cost_per_strength", "retreat_influence_loss", "retreat_respect_loss", "broke_respect_loss"]
const GANG_FIELDS := ["id", "display_name", "description", "strength", "aggression", "districts", "clash_event", "order"]
## Stärke, bei der der Druck genau dem Gebietswert entspricht
const BASE_STRENGTH := 50


## Eine Bande (nur Daten).
class Gang extends RefCounted:
	var id: String
	var display_name: String
	var description: String
	var strength: int
	var aggression: int
	var districts: PackedStringArray
	var clash_event: String
	var order: int


## Regeln und Banden. Alles-oder-nichts.
class Catalog extends RefCounted:
	var errors: PackedStringArray = []
	var unlocked_by_mission := ""
	var rules := {}
	var _gangs: Array = []

	func load_file(path: String = "res://data/underworld/rivals.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			_gangs.clear()
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		var reader := DataReaderScript.new()
		_gangs.clear()
		if typeof(data) != TYPE_DICTIONARY:
			errors = PackedStringArray(["Rivalen müssen ein Objekt sein."])
			return false
		for key in data:
			if String(key) not in RULE_FIELDS + ["unlocked_by_mission", "gangs"]:
				reader.errors.append("Rivalen: unbekanntes Feld '%s'." % key)
		var mission := reader.string_field(data, "unlocked_by_mission", "Rivalen", true)
		var rule_values := {}
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				reader.errors.append("Rivalen: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				rule_values[key] = int(data[key])
		var gangs: Array = []
		var raw: Variant = data.get("gangs")
		if typeof(raw) != TYPE_ARRAY or raw.is_empty():
			reader.errors.append("Rivalen: 'gangs' muss eine nicht leere Liste sein.")
		else:
			var seen := {}
			var taken := {}
			for i in raw.size():
				var entry: Variant = raw[i]
				var where := "Bande #%d" % (i + 1)
				if typeof(entry) != TYPE_DICTIONARY:
					reader.errors.append("%s: muss ein Objekt sein." % where)
					continue
				var error_count := reader.errors.size()
				var id := reader.id_field(entry, where)
				if id.is_empty():
					continue
				where = "Bande '%s'" % id
				for key in entry:
					if String(key) not in GANG_FIELDS:
						reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
				var gang := Gang.new()
				gang.id = id
				for field in ["display_name", "description", "clash_event"]:
					gang.set(field, reader.string_field(entry, field, where, true))
				for field in ["strength", "aggression", "order"]:
					gang.set(field, reader.int_field(entry, field, where, true))
				if gang.strength < 0 or gang.strength > 100 or gang.aggression < 0 or gang.aggression > 100:
					reader.errors.append("%s: Stärke und Aggression 0–100." % where)
				var districts: Variant = entry.get("districts")
				if typeof(districts) != TYPE_ARRAY or districts.is_empty() \
						or districts.any(func(value) -> bool: return typeof(value) != TYPE_STRING):
					reader.errors.append("%s: 'districts' muss eine Liste von Gebiets-IDs sein." % where)
				else:
					gang.districts = PackedStringArray(districts)
					for district in districts:
						if taken.has(district):
							reader.errors.append("%s: Gebiet '%s' gehört schon zu '%s'." % [where, district, taken[district]])
						taken[district] = id
				if seen.has(id):
					reader.errors.append("%s: ID kommt doppelt vor." % where)
				if reader.errors.size() == error_count:
					seen[id] = true
					gangs.append(gang)
		errors = reader.errors
		if not errors.is_empty():
			return false
		gangs.sort_custom(func(a, b) -> bool: return a.order < b.order)
		unlocked_by_mission = mission
		rules = rule_values
		_gangs = gangs
		return true

	func get_all() -> Array:
		return _gangs.duplicate()

	func get_definition(id: String):
		for gang in _gangs:
			if gang.id == id:
				return gang
		return null

	## Bande, deren Revier dieses Gebiet ist (oder null).
	func get_for_district(district_id: String):
		for gang in _gangs:
			if district_id in gang.districts:
				return gang
		return null

	func rule(key: String) -> int:
		return rules.get(key, 0)


var _time
var _ledger: LedgerSystemScript
var _catalog: Catalog
var _organisation
var _territory
var _is_mission_completed: Callable
var _get_seed: Callable
var _trigger_scripted: Callable
## gang_id -> {strength, relation, until_day}
var _state := {}
## Ereignis-Instanz -> {gang, district} (offene und entschiedene „Ärger“-Ereignisse)
var _clashes := {}
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, catalog: Catalog, organisation, territory, is_mission_completed: Callable,
		get_seed: Callable, trigger_scripted: Callable) -> void:
	_time = time
	_ledger = ledger
	_catalog = catalog
	_organisation = organisation
	_territory = territory
	_is_mission_completed = is_mission_completed
	_get_seed = get_seed
	_trigger_scripted = trigger_scripted
	_last_processed_day = time.get_day()


func get_catalog() -> Catalog:
	return _catalog


## Fenster „Rivalen“ sichtbar (Organisation steht, Freischalt-Auftrag erledigt).
func is_available() -> bool:
	return _organisation.is_founded() and _is_mission_completed.call(_catalog.unlocked_by_mission)


func get_strength(gang_id: String) -> int:
	if _state.has(gang_id):
		return int(_state[gang_id]["strength"])
	var gang = _catalog.get_definition(gang_id)
	return gang.strength if gang != null else 0


func get_relation(gang_id: String) -> String:
	return String(_state.get(gang_id, {}).get("relation", NEUTRAL))


## Letzter Tag von Konflikt oder Waffenstillstand (−1 = neutral).
func get_until_day(gang_id: String) -> int:
	return int(_state.get(gang_id, {}).get("until_day", -1))


## Gewicht des Rivalen-Drucks in einem Gebiet (Prozent) – vom TerritorySystem.
@warning_ignore("integer_division")
func pressure_percent(district_id: String) -> int:
	var gang = _catalog.get_for_district(district_id)
	if gang == null:
		return 100
	match get_relation(gang.id):
		TRUCE:
			return 0
		CONFLICT:
			return _catalog.rule("conflict_pressure_percent") * get_strength(gang.id) / BASE_STRENGTH
	return 100 * get_strength(gang.id) / BASE_STRENGTH


## Kosten eines Waffenstillstands (Cent).
func truce_cost(gang_id: String) -> int:
	return get_strength(gang_id) * _catalog.rule("truce_cost_per_strength")


## Konto: Schwarzgeld, wenn es reicht, sonst Privatkonto.
func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## "" wenn ein Waffenstillstand jetzt angeboten werden kann, sonst ein Grund.
func check_truce(gang_id: String) -> String:
	if _catalog.get_definition(gang_id) == null:
		return "Unbekannte Bande: %s" % gang_id
	if not is_available():
		return "Noch kein Kontakt zu den Rivalen."
	if get_relation(gang_id) == TRUCE:
		return "Waffenstillstand bis Tag %d." % get_until_day(gang_id)
	var cost := truce_cost(gang_id)
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Waffenstillstand: Buchung → Beziehung. "" = vereinbart.
func offer_truce(gang_id: String) -> String:
	var reason := check_truce(gang_id)
	if not reason.is_empty():
		return reason
	return _buy_truce(gang_id)


func _buy_truce(gang_id: String) -> String:
	var gang = _catalog.get_definition(gang_id)
	var cost := truce_cost(gang_id)
	if cost > 0:
		var entry := _ledger.post(-cost, CATEGORY, "Waffenstillstand mit %s" % gang.display_name, SOURCE, gang_id,
				"rivals:truce:%s:%d" % [gang_id, _time.get_day()], false, payment_account(cost))
		if entry == null:
			return "Die Buchung ist fehlgeschlagen."
	_set_relation(gang_id, TRUCE, _time.get_day() + _catalog.rule("truce_days"))
	return ""


func _set_relation(gang_id: String, relation: String, until_day: int) -> void:
	var state: Dictionary = _state.get(gang_id, {"strength": get_strength(gang_id)})
	state["relation"] = relation
	state["until_day"] = until_day if relation != NEUTRAL else -1
	_state[gang_id] = state


## Vom EventSystem: Antwort auf ein „Ärger“-Ereignis.
func apply_event_action(action: String, instance_id: String) -> void:
	var clash: Dictionary = _clashes.get(instance_id, {})
	var gang = _catalog.get_definition(String(clash.get("gang", "")))
	if gang == null:
		push_error("RivalSystem: Ereignis '%s' ohne Bande." % instance_id)
		return
	var district := String(clash.get("district", ""))
	match action:
		"fight":
			var state: Dictionary = _state.get(gang.id, {"strength": get_strength(gang.id)})
			state["strength"] = maxi(0, int(state["strength"]) - _catalog.rule("fight_strength_loss"))
			_state[gang.id] = state
			_set_relation(gang.id, CONFLICT, _time.get_day() + _catalog.rule("conflict_days"))
			_notices.append("%s sind geschwächt (Stärke %d) – Konflikt bis Tag %d." % [gang.display_name,
					get_strength(gang.id), get_until_day(gang.id)])
		"negotiate":
			var cost := truce_cost(gang.id)
			if _ledger.can_afford(cost, payment_account(cost)) and _buy_truce(gang.id).is_empty():
				_notices.append("Waffenstillstand mit %s bis Tag %d (%s)." % [gang.display_name, get_until_day(gang.id),
						LedgerSystemScript.format_cents(-cost)])
			else:
				_organisation.change({"respect": -_catalog.rule("broke_respect_loss")})
				_notices.append("%s lachen dich aus – kein Geld, kein Frieden (Respekt −%d)." % [gang.display_name,
						_catalog.rule("broke_respect_loss")])
		"retreat":
			_territory.reduce_influence(district, _catalog.rule("retreat_influence_loss"))
			_organisation.change({"respect": -_catalog.rule("retreat_respect_loss")})
			_notices.append("Rückzug: Einfluss −%d, Respekt −%d." % [_catalog.rule("retreat_influence_loss"),
					_catalog.rule("retreat_respect_loss")])


## Hinweise seit dem letzten Aufruf.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle (vor den Gebieten): Beziehungen laufen ab, Stärke erholt sich, dann ggf. ein „Ärger“-Ereignis.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	for gang in _catalog.get_all():
		if not _state.has(gang.id):
			continue
		var state: Dictionary = _state[gang.id]
		state["strength"] = mini(gang.strength, int(state["strength"]) + _catalog.rule("strength_regen_per_day"))
		if state.get("relation", NEUTRAL) != NEUTRAL and day > int(state.get("until_day", -1)):
			if state["relation"] == TRUCE:
				_notices.append("Der Waffenstillstand mit %s ist abgelaufen." % gang.display_name)
			state["relation"] = NEUTRAL
			state["until_day"] = -1
	if not is_available():
		return
	for gang in _catalog.get_all():
		if get_relation(gang.id) == TRUCE:
			continue
		var district := _contested_district(gang)
		if district.is_empty():
			continue
		@warning_ignore("integer_division")
		var chance: int = gang.aggression * _catalog.rule("clash_chance_per_10_aggression") / 10
		if get_relation(gang.id) == CONFLICT:
			@warning_ignore("integer_division")
			chance = chance * _catalog.rule("conflict_chance_percent") / 100
		var roll := EventSystemScript.fnv1a("%d:rival:%s:%d" % [_get_seed.call(), gang.id, day]) % 100
		if roll < chance:
			var instance: String = _trigger_scripted.call(gang.clash_event, day)
			if not instance.is_empty():
				_clashes[instance] = {"gang": gang.id, "district": district}
				return  # höchstens ein Ärger je Tag


## Gebiet im Revier der Bande mit dem meisten eigenen Einfluss (mindestens `clash_min_influence`), sonst "".
func _contested_district(gang) -> String:
	var best := ""
	var best_influence := _catalog.rule("clash_min_influence") - 1
	for district in gang.districts:
		var influence: int = _territory.get_influence(district)
		if influence > best_influence:
			best = district
			best_influence = influence
	return best


func to_dict() -> Dictionary:
	return {"gangs": _state.duplicate(true), "clashes": _clashes.duplicate(true), "last_processed_day": _last_processed_day}


## "" = ok, sonst Fehlertext (nichts geändert). Unbekannte Banden bleiben erhalten.
func restore(data: Dictionary) -> String:
	var gangs: Variant = data.get("gangs")
	var clashes: Variant = data.get("clashes")
	if typeof(gangs) != TYPE_DICTIONARY or typeof(clashes) != TYPE_DICTIONARY:
		return "Rivalen: 'gangs' oder 'clashes' fehlt."
	var state := {}
	for id in gangs:
		var entry: Variant = gangs[id]
		if typeof(entry) != TYPE_DICTIONARY or not DataReaderScript.is_whole_number(entry.get("strength")) \
				or int(entry["strength"]) < 0 or int(entry["strength"]) > 100 \
				or entry.get("relation") not in [NEUTRAL, CONFLICT, TRUCE] \
				or not DataReaderScript.is_whole_number(entry.get("until_day")):
			return "Rivalen: ungültiger Zustand für '%s'." % id
		state[id] = {"strength": int(entry["strength"]), "relation": entry["relation"], "until_day": int(entry["until_day"])}
	var clash_state := {}
	for id in clashes:
		var entry: Variant = clashes[id]
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("gang")) != TYPE_STRING \
				or typeof(entry.get("district")) != TYPE_STRING:
			return "Rivalen: ungültiges Ereignis '%s'." % id
		clash_state[id] = {"gang": entry["gang"], "district": entry["district"]}
	if not DataReaderScript.is_whole_number(data.get("last_processed_day")) or int(data["last_processed_day"]) < 0:
		return "Rivalen: 'last_processed_day' fehlt oder ist ungültig."
	_state = state
	_clashes = clash_state
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
