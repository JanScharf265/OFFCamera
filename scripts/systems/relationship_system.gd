extends RefCounted

## Beziehungen (U.23): erfundene Kontakte als Daten (data/underworld/relationships.json) – Kontakt am Hafen,
## Partnerschaft, käuflicher Beamter – je mit Vertrauen und Wissen (0–100). Eine Aktion je Kontakt (Spielzeit über das
## TimeSystem, Kosten als Buchung, Wirkung auf Vertrauen, Wissen, Stimmung, Hitze, Respekt, Akte der Polizei),
## mit Wartezeit in Tagen. Vertrauen sinkt ohne Kontakt alle `trust_decay_every_days` Tage um 1. Erfüllt ein Kontakt
## die Bedingung seines Ereignisses (Wissen/Vertrauen), löst der Tageswechsel es aus („scripted“, Abstand
## `event_cooldown_days`); die Antworten wirken über das Optionsfeld „contact“. Reine Spielwerte.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

const DEFAULT_PATH := "res://data/underworld/relationships.json"
const CATEGORY := "underworld_contacts"
const SOURCE := "contact"
const CONTACT_FIELDS := ["id", "display_name", "role", "description", "unlocked_by_mission", "start_trust",
		"start_knowledge", "action", "event", "order"]
const ACTION_INTS := ["minutes", "cost_cents", "trust", "knowledge", "mood", "heat", "respect", "police_progress",
		"cooldown_days"]
const EVENT_INTS := ["min_knowledge", "max_trust", "min_trust"]


## Ein Kontakt (nur Daten).
class Contact extends RefCounted:
	var id: String
	var display_name: String
	var role: String
	var description: String
	var unlocked_by_mission: String
	var start_trust: int
	var start_knowledge: int
	## {label, minutes, cost_cents, trust, knowledge, mood, heat, respect, police_progress, cooldown_days}
	var action: Dictionary
	## {id, min_knowledge, max_trust, min_trust}
	var event: Dictionary
	var order: int


## Regeln und Kontakte. Alles-oder-nichts.
class Catalog extends RefCounted:
	var errors: PackedStringArray = []
	var trust_decay_every_days := 0
	var event_cooldown_days := 0
	var _contacts: Array = []

	func load_file(path: String = "res://data/underworld/relationships.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			_contacts.clear()
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		var reader := DataReaderScript.new()
		_contacts.clear()
		if typeof(data) != TYPE_DICTIONARY:
			errors = PackedStringArray(["Beziehungen müssen ein Objekt sein."])
			return false
		for key in data:
			if String(key) not in ["trust_decay_every_days", "event_cooldown_days", "contacts"]:
				reader.errors.append("Beziehungen: unbekanntes Feld '%s'." % key)
		var decay := reader.int_field(data, "trust_decay_every_days", "Beziehungen", true)
		var cooldown := reader.int_field(data, "event_cooldown_days", "Beziehungen", true)
		if decay < 1 or cooldown < 1:
			reader.errors.append("Beziehungen: Tage müssen ≥ 1 sein.")
		var contacts: Array = []
		var raw: Variant = data.get("contacts")
		if typeof(raw) != TYPE_ARRAY or raw.is_empty():
			reader.errors.append("Beziehungen: 'contacts' muss eine nicht leere Liste sein.")
		else:
			var seen := {}
			for i in raw.size():
				var entry: Variant = raw[i]
				var where := "Kontakt #%d" % (i + 1)
				if typeof(entry) != TYPE_DICTIONARY:
					reader.errors.append("%s: muss ein Objekt sein." % where)
					continue
				var error_count := reader.errors.size()
				var id := reader.id_field(entry, where)
				if id.is_empty():
					continue
				where = "Kontakt '%s'" % id
				for key in entry:
					if String(key) not in CONTACT_FIELDS:
						reader.errors.append("%s: unbekanntes Feld '%s'." % [where, key])
				var contact := Contact.new()
				contact.id = id
				for field in ["display_name", "role", "description"]:
					contact.set(field, reader.string_field(entry, field, where, true))
				contact.unlocked_by_mission = reader.string_field(entry, "unlocked_by_mission", where, false)
				for field in ["start_trust", "start_knowledge", "order"]:
					contact.set(field, reader.int_field(entry, field, where, true))
				if contact.start_trust < 0 or contact.start_trust > 100 or contact.start_knowledge < 0 \
						or contact.start_knowledge > 100:
					reader.errors.append("%s: Startwerte 0–100." % where)
				contact.action = _block(entry, "action", ACTION_INTS, ["label"], where, reader)
				contact.event = _block(entry, "event", EVENT_INTS, ["id"], where, reader)
				if contact.action.get("cooldown_days", 1) < 1 or contact.action.get("cost_cents", 0) < 0 \
						or contact.action.get("minutes", 0) < 0:
					reader.errors.append("%s: Aktion ungültig (cooldown_days ≥ 1, Kosten und Minuten ≥ 0)." % where)
				if seen.has(id):
					reader.errors.append("%s: ID kommt doppelt vor." % where)
				if reader.errors.size() == error_count:
					seen[id] = true
					contacts.append(contact)
		errors = reader.errors
		if not errors.is_empty():
			return false
		contacts.sort_custom(func(a, b) -> bool: return a.order < b.order)
		trust_decay_every_days = decay
		event_cooldown_days = cooldown
		_contacts = contacts
		return true

	## Unterobjekt mit ganzen Zahlen (dürfen negativ sein) und Texten; Fehler werden gesammelt.
	static func _block(entry: Dictionary, field: String, ints: Array, strings: Array, where: String, reader) -> Dictionary:
		var raw: Variant = entry.get(field)
		if typeof(raw) != TYPE_DICTIONARY:
			reader.errors.append("%s: '%s' muss ein Objekt sein." % [where, field])
			return {}
		var result := {}
		for key in raw:
			if String(key) not in ints + strings:
				reader.errors.append("%s: '%s' hat unbekanntes Feld '%s'." % [where, field, key])
		for key in ints:
			if not DataReaderScript.is_whole_number(raw.get(key)):
				reader.errors.append("%s: '%s.%s' muss eine ganze Zahl sein." % [where, field, key])
			else:
				result[key] = int(raw[key])
		for key in strings:
			if typeof(raw.get(key)) != TYPE_STRING or String(raw[key]).is_empty():
				reader.errors.append("%s: '%s.%s' fehlt." % [where, field, key])
			else:
				result[key] = raw[key]
		return result

	func get_all() -> Array:
		return _contacts.duplicate()

	func get_definition(id: String):
		for contact in _contacts:
			if contact.id == id:
				return contact
		return null


var _time
var _ledger: LedgerSystemScript
var _catalog: Catalog
var _organisation
var _stats
var _is_mission_completed: Callable
var _trigger_scripted: Callable
var _reduce_file: Callable
## contact_id -> {trust, knowledge, last_action_day, last_event_day}
var _state := {}
## Ereignis-Instanz -> contact_id
var _instances := {}
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, catalog: Catalog, organisation, stats, is_mission_completed: Callable,
		trigger_scripted: Callable, reduce_file: Callable) -> void:
	_time = time
	_ledger = ledger
	_catalog = catalog
	_organisation = organisation
	_stats = stats
	_is_mission_completed = is_mission_completed
	_trigger_scripted = trigger_scripted
	_reduce_file = reduce_file
	_last_processed_day = time.get_day()


func get_catalog() -> Catalog:
	return _catalog


func is_known(contact_id: String) -> bool:
	var contact = _catalog.get_definition(contact_id)
	if contact == null:
		return false
	return contact.unlocked_by_mission.is_empty() or (_organisation.is_founded()
			and _is_mission_completed.call(contact.unlocked_by_mission))


func get_known() -> Array:
	return _catalog.get_all().filter(func(contact) -> bool: return is_known(contact.id))


## Fenster „Kontakte“ sichtbar: Organisation gegründet (die Partnerschaft gibt es immer, sie wird erst mit der
## Unterwelt zum Thema).
func is_available() -> bool:
	return _organisation.is_founded()


func _entry(contact_id: String) -> Dictionary:
	if not _state.has(contact_id):
		var contact = _catalog.get_definition(contact_id)
		_state[contact_id] = {"trust": contact.start_trust, "knowledge": contact.start_knowledge,
				"last_action_day": -100, "last_event_day": -100}
	return _state[contact_id]


func get_trust(contact_id: String) -> int:
	return int(_entry(contact_id)["trust"]) if _catalog.get_definition(contact_id) != null else 0


func get_knowledge(contact_id: String) -> int:
	return int(_entry(contact_id)["knowledge"]) if _catalog.get_definition(contact_id) != null else 0


func _change(contact_id: String, trust: int, knowledge: int) -> void:
	var entry := _entry(contact_id)
	entry["trust"] = clampi(int(entry["trust"]) + trust, 0, 100)
	entry["knowledge"] = clampi(int(entry["knowledge"]) + knowledge, 0, 100)


func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## "" wenn die Aktion jetzt möglich ist, sonst ein Grund.
func check_action(contact_id: String) -> String:
	var contact = _catalog.get_definition(contact_id)
	if contact == null:
		return "Unbekannter Kontakt: %s" % contact_id
	if not is_known(contact_id):
		return "Diese Person kennst du noch nicht."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var wait: int = int(_entry(contact_id)["last_action_day"]) + int(contact.action["cooldown_days"]) - _time.get_day()
	if wait > 0:
		return "Erst wieder in %d Tag%s." % [wait, "" if wait == 1 else "en"]
	var cost: int = contact.action["cost_cents"]
	if cost > 0 and not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Aktion: Buchung → Werte → Spielzeit. "" = erledigt.
func act(contact_id: String) -> String:
	var reason := check_action(contact_id)
	if not reason.is_empty():
		return reason
	var contact = _catalog.get_definition(contact_id)
	var action: Dictionary = contact.action
	var day: int = _time.get_day()
	if int(action["cost_cents"]) > 0:
		var cost: int = action["cost_cents"]
		if _ledger.post(-cost, CATEGORY, "%s: %s" % [contact.display_name, action["label"]], SOURCE, contact_id,
				"contact:%s:%d" % [contact_id, day], false, payment_account(cost)) == null:
			return "Die Buchung ist fehlgeschlagen."
	_change(contact_id, action["trust"], action["knowledge"])
	_entry(contact_id)["last_action_day"] = day
	if int(action["mood"]) != 0:
		_stats.apply({"mood": action["mood"]})
	var org := {}
	if int(action["heat"]) != 0:
		org["heat"] = action["heat"]
	if int(action["respect"]) != 0:
		org["respect"] = action["respect"]
	if not org.is_empty() and _organisation.is_founded():
		_organisation.change(org)
	if int(action["police_progress"]) != 0 and _reduce_file.is_valid():
		_reduce_file.call(-int(action["police_progress"]))
	if int(action["minutes"]) > 0:
		_time.advance(action["minutes"])
	return ""


## Vom EventSystem: Antwort mit Optionsfeld „contact“ {trust?, knowledge?, cost_cents?}.
func apply_event_change(change: Dictionary, instance_id: String) -> void:
	var contact_id: String = _instances.get(instance_id, "")
	if _catalog.get_definition(contact_id) == null:
		push_error("RelationshipSystem: Ereignis '%s' ohne Kontakt." % instance_id)
		return
	var cost := int(change.get("cost_cents", 0))
	if cost > 0:
		var account := payment_account(cost)
		if not _ledger.can_afford(cost, account) or _ledger.post(-cost, CATEGORY, "%s: Forderung" % \
				_catalog.get_definition(contact_id).display_name, SOURCE, contact_id, "contact:event:%s" % instance_id,
				false, account) == null:
			_change(contact_id, -20, 0)
			if _organisation.is_founded():
				_organisation.change({"heat": 15})
			_notices.append("Das Geld reicht nicht – %s ist verärgert (Hitze +15)." % \
					_catalog.get_definition(contact_id).display_name)
			return
	_change(contact_id, int(change.get("trust", 0)), int(change.get("knowledge", 0)))


func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle: Vertrauen sinkt ohne Kontakt; Ereignisse bei passenden Werten (höchstens eins je Tag).
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	if not is_available():
		return
	for contact in get_known():
		var entry := _entry(contact.id)
		var idle: int = day - int(entry["last_action_day"])
		if idle > 0 and idle % _catalog.trust_decay_every_days == 0:
			_change(contact.id, -1, 0)
	for contact in get_known():
		var entry := _entry(contact.id)
		var event: Dictionary = contact.event
		if day - int(entry["last_event_day"]) < _catalog.event_cooldown_days:
			continue
		if int(entry["knowledge"]) >= event["min_knowledge"] and int(entry["trust"]) <= event["max_trust"] \
				and int(entry["trust"]) >= event["min_trust"]:
			var instance: String = _trigger_scripted.call(event["id"], day) if _trigger_scripted.is_valid() else ""
			if not instance.is_empty():
				_instances[instance] = contact.id
				entry["last_event_day"] = day
				return


func to_dict() -> Dictionary:
	return {"contacts": _state.duplicate(true), "instances": _instances.duplicate(),
			"last_processed_day": _last_processed_day}


## "" = ok, sonst Fehlertext (nichts geändert). Unbekannte Kontakte bleiben erhalten.
func restore(data: Dictionary) -> String:
	var raw: Variant = data.get("contacts")
	var instances: Variant = data.get("instances")
	if typeof(raw) != TYPE_DICTIONARY or typeof(instances) != TYPE_DICTIONARY:
		return "Beziehungen: 'contacts' oder 'instances' fehlt."
	var state := {}
	for id in raw:
		var entry: Variant = raw[id]
		if typeof(entry) != TYPE_DICTIONARY:
			return "Beziehungen: ungültiger Kontakt '%s'." % id
		for key in ["trust", "knowledge", "last_action_day", "last_event_day"]:
			if not DataReaderScript.is_whole_number(entry.get(key)):
				return "Beziehungen: Kontakt '%s' ohne gültiges '%s'." % [id, key]
		if int(entry["trust"]) < 0 or int(entry["trust"]) > 100 or int(entry["knowledge"]) < 0 or int(entry["knowledge"]) > 100:
			return "Beziehungen: Werte von '%s' außerhalb 0–100." % id
		state[id] = {"trust": int(entry["trust"]), "knowledge": int(entry["knowledge"]),
				"last_action_day": int(entry["last_action_day"]), "last_event_day": int(entry["last_event_day"])}
	for id in instances:
		if typeof(instances[id]) != TYPE_STRING:
			return "Beziehungen: ungültiges Ereignis '%s'." % id
	if not DataReaderScript.is_whole_number(data.get("last_processed_day")) or int(data["last_processed_day"]) < 0:
		return "Beziehungen: 'last_processed_day' fehlt oder ist ungültig."
	_state = state
	_instances = instances.duplicate()
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
