class_name EventCatalog
extends RefCounted

## Lädt und prüft Ereignisdaten (JSON). Alles-oder-nichts wie beim ActivityCatalog.
##
## Format je Ereignis:
##   id, title, text, priority (optional, Standard 0),
##   trigger {day >= 1, hour 0–23, minute 0–59 (optional)}
##     oder Zufall (Phase 3): trigger {"random": {chance_percent 1–100, from_day ≥ 2 (optional, Standard 2),
##       cooldown_days ≥ 0 (optional), max_times ≥ 0 (optional, 0 = unbegrenzt),
##       conditions (optional) {min_/max_ followers|community|reputation, min_/max_open_obligations,
##         company_founded (1/0), min_last_week_profit_cents, min_/max_police_level (U.19, 0–2),
##         min_/max_heat, min_/max_locked_up (U.22, 1 = in Haft)}}},
##     oder vom Spiel ausgelöst (U.3): trigger {"scripted": true} – kommt nur, wenn ein System es auslöst
##       (EventSystem.trigger_scripted, z. B. der Einstieg in die Unterwelt).
##   options [ {id, label, note? (Hinweis auf eine Folge ohne Zahl, U.3), organisation? {respect|heat|stability} (U.7),
##     rival? ("fight" | "negotiate" | "retreat", U.14 – nur bei Ereignissen, die das RivalSystem auslöst),
##     crew? (Aktion zu einem Crew-Vorfall, U.15 – nur bei Ereignissen, die das CrewSystem auslöst), money_cents?, category?, effects?, channel?, account?, minutes?, company?}, … ]
##     (mindestens eine, davon mindestens eine ohne Kosten)
##     channel {followers?, followers_percent?, community?, reputation?} – ganze Zahlen

const EventDefinitionScript := preload("res://scripts/models/event_definition.gd")
const EventOptionScript := preload("res://scripts/models/event_option.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

const DEFAULT_PATH := "res://data/events/events.json"
## Kanal (Phase 3) und Welt (Phase 5): offene Fristen, Unternehmen gegründet (company_founded 1/0),
## Gewinn der Vorwoche auf dem Firmenkonto.
const CONDITION_KEYS := ["min_open_obligations", "max_open_obligations", "company_founded",
		"min_last_week_profit_cents", "min_followers", "max_followers", "min_community", "max_community",
		"min_reputation", "max_reputation", "min_police_level", "max_police_level", "min_heat", "max_heat",
		"min_locked_up", "max_locked_up"]
const OPTION_CHANNEL_KEYS := ["followers", "followers_percent", "community", "reputation"]
const OPTION_COMPANY_KEYS := ["utilization", "reputation"]
## U.7: Folgen für die Organisation (wirken nur, wenn sie gegründet ist)
const OPTION_ORGANISATION_KEYS := ["respect", "heat", "stability"]
## U.14: Aktionen gegenüber Rivalen (Feld „rival“ einer Option)
const OPTION_RIVAL_ACTIONS := ["fight", "negotiate", "retreat"]
## U.15: Aktionen zu Crew-Vorfällen (Feld „crew“ einer Option)
## U.21: Aktionen im Verfahren (Feld „justice“ einer Option)
const OPTION_JUSTICE_ACTIONS := ["lawyer", "bribe", "silent", "sacrifice", "cooperate", "await"]
const OPTION_CREW_ACTIONS := ["lawyer", "drop", "betray_hunt", "betray_let_go", "inform_fire", "inform_keep", "raise",
		"release"]
const ACCOUNTS := ["private", "company"]

var errors: PackedStringArray = []

var _definitions: Array[EventDefinitionScript] = []


func load_file(path: String = DEFAULT_PATH) -> bool:
	var reader := DataReaderScript.new()
	var data: Variant = reader.read_json_file(path)
	if data == null:
		_definitions.clear()
		errors = reader.errors
		return false
	return load_data(data)


func load_data(data: Variant) -> bool:
	var reader := DataReaderScript.new()
	_definitions.clear()
	if typeof(data) != TYPE_ARRAY:
		errors = PackedStringArray(["Ereignisdaten müssen eine Liste sein."])
		return false

	var definitions: Array[EventDefinitionScript] = []
	var seen := {}
	for i in data.size():
		var definition = _parse(reader, data[i], i)
		if definition == null:
			continue
		if seen.has(definition.id):
			reader.errors.append("Ereignis '%s': ID kommt doppelt vor." % definition.id)
			continue
		seen[definition.id] = true
		definitions.append(definition)

	errors = reader.errors
	if not errors.is_empty():
		return false
	_definitions = definitions
	return true


## Alle Ereignisse in der Reihenfolge der Datei (Kopie der Liste).
func get_all() -> Array[EventDefinitionScript]:
	return _definitions.duplicate()


## null, wenn es die ID nicht gibt.
func get_definition(id: String) -> EventDefinitionScript:
	for definition in _definitions:
		if definition.id == id:
			return definition
	return null


func _parse(reader: DataReaderScript, entry: Variant, index: int) -> EventDefinitionScript:
	var where := "Ereignis #%d" % (index + 1)
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null

	var error_count := reader.errors.size()
	var id := reader.id_field(entry, where)
	if id.is_empty():
		return null
	where = "Ereignis '%s'" % id

	var definition := EventDefinitionScript.new()
	definition.id = id
	definition.title = reader.string_field(entry, "title", where, true)
	definition.text = reader.string_field(entry, "text", where, true)
	definition.priority = reader.int_field(entry, "priority", where, false)
	var trigger: Variant = entry.get("trigger")
	if typeof(trigger) == TYPE_DICTIONARY and trigger.has("random"):
		definition.due_minutes = -1
		_parse_random(reader, definition, trigger["random"], where)
	elif typeof(trigger) == TYPE_DICTIONARY and trigger.has("scripted"):
		definition.due_minutes = -1
		definition.is_scripted = true
		if trigger.size() != 1 or trigger["scripted"] != true:
			reader.errors.append("%s: 'trigger.scripted' muss allein stehen und true sein." % where)
	else:
		definition.due_minutes = reader.time_point_field(entry, "trigger", where)

	var options: Variant = entry.get("options")
	if typeof(options) != TYPE_ARRAY or options.is_empty():
		reader.errors.append("%s: 'options' muss eine nicht-leere Liste sein." % where)
	else:
		for j in options.size():
			var option = _parse_option(reader, options[j], "%s, Option #%d" % [where, j + 1])
			if option == null:
				continue
			if definition.get_option(option.id) != null:
				reader.errors.append("%s: Option '%s' kommt doppelt vor." % [where, option.id])
				continue
			definition.options.append(option)

	var has_free_option := false
	for option in definition.options:
		has_free_option = has_free_option or option.money_cents >= 0
	if not definition.options.is_empty() and not has_free_option:
		reader.errors.append("%s: braucht mindestens eine Option ohne Kosten (sonst nicht entscheidbar ohne Geld)." % where)
	return definition if reader.errors.size() == error_count else null


func _parse_option(reader: DataReaderScript, entry: Variant, where: String) -> EventOptionScript:
	if typeof(entry) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % where)
		return null
	var error_count := reader.errors.size()
	var option := EventOptionScript.new()
	option.id = reader.id_field(entry, where)
	option.label = reader.string_field(entry, "label", where, true)
	option.money_cents = reader.int_field(entry, "money_cents", where, false)
	option.category = reader.string_field(entry, "category", where, false)
	option.effects = reader.effects_field(entry, where)
	option.note = reader.string_field(entry, "note", where, false)
	reader.check_money_category(option.money_cents, option.category, where)
	option.channel = {}
	var channel: Variant = entry.get("channel", {})
	if typeof(channel) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'channel' muss ein Objekt sein." % where)
	else:
		for key in channel:
			if key not in OPTION_CHANNEL_KEYS or not DataReaderScript.is_whole_number(channel[key]):
				reader.errors.append("%s: 'channel' enthält ungültigen Wert '%s'." % [where, key])
			elif int(channel[key]) != 0:
				option.channel[key] = int(channel[key])
	option.account = reader.string_field(entry, "account", where, false)
	if option.account.is_empty():
		option.account = "private"
	elif option.account not in ACCOUNTS:
		reader.errors.append("%s: 'account' muss \"private\" oder \"company\" sein." % where)
	option.minutes = reader.int_field(entry, "minutes", where, false)
	if option.minutes < 0:
		reader.errors.append("%s: 'minutes' darf nicht negativ sein." % where)
	option.organisation = {}
	var organisation: Variant = entry.get("organisation", {})
	if typeof(organisation) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'organisation' muss ein Objekt sein." % where)
	else:
		for key in organisation:
			if key not in OPTION_ORGANISATION_KEYS or not DataReaderScript.is_whole_number(organisation[key]):
				reader.errors.append("%s: 'organisation' enthält ungültigen Wert '%s'." % [where, key])
			elif int(organisation[key]) != 0:
				option.organisation[key] = int(organisation[key])
	option.rival = reader.string_field(entry, "rival", where, false)
	if not option.rival.is_empty() and option.rival not in OPTION_RIVAL_ACTIONS:
		reader.errors.append("%s: 'rival' muss fight, negotiate oder retreat sein." % where)
	option.justice = reader.string_field(entry, "justice", where, false)
	if not option.justice.is_empty() and option.justice not in OPTION_JUSTICE_ACTIONS:
		reader.errors.append("%s: 'justice' ist keine bekannte Aktion." % where)
	option.crew = reader.string_field(entry, "crew", where, false)
	if not option.crew.is_empty() and option.crew not in OPTION_CREW_ACTIONS:
		reader.errors.append("%s: 'crew' ist keine bekannte Crew-Aktion." % where)
	option.company = {}
	var company: Variant = entry.get("company", {})
	if typeof(company) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'company' muss ein Objekt sein." % where)
	else:
		for key in company:
			if key not in OPTION_COMPANY_KEYS or not DataReaderScript.is_whole_number(company[key]):
				reader.errors.append("%s: 'company' enthält ungültigen Wert '%s'." % [where, key])
			elif int(company[key]) != 0:
				option.company[key] = int(company[key])
	return option if reader.errors.size() == error_count else null


func _parse_random(reader: DataReaderScript, definition: EventDefinitionScript, spec: Variant, where: String) -> void:
	var context := "%s (trigger.random)" % where
	if typeof(spec) != TYPE_DICTIONARY:
		reader.errors.append("%s: muss ein Objekt sein." % context)
		return
	definition.is_random = true
	definition.chance_percent = reader.int_field(spec, "chance_percent", context, true)
	definition.from_day = reader.int_field(spec, "from_day", context, false, 2)
	definition.cooldown_days = reader.int_field(spec, "cooldown_days", context, false)
	definition.max_times = reader.int_field(spec, "max_times", context, false)
	if definition.chance_percent < 1 or definition.chance_percent > 100:
		reader.errors.append("%s: 'chance_percent' muss zwischen 1 und 100 liegen." % context)
	if definition.from_day < 2:
		reader.errors.append("%s: 'from_day' muss mindestens 2 sein (gewürfelt wird bei Tageswechsel)." % context)
	if definition.cooldown_days < 0 or definition.max_times < 0:
		reader.errors.append("%s: 'cooldown_days' und 'max_times' dürfen nicht negativ sein." % context)
	var conditions: Variant = spec.get("conditions", {})
	if typeof(conditions) != TYPE_DICTIONARY:
		reader.errors.append("%s: 'conditions' muss ein Objekt sein." % context)
		return
	for key in conditions:
		if key not in CONDITION_KEYS or not DataReaderScript.is_whole_number(conditions[key]):
			reader.errors.append("%s: unbekannte oder ungültige Bedingung '%s'." % [context, key])
		else:
			definition.conditions[key] = int(conditions[key])
