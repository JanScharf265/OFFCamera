class_name EventSystem
extends RefCounted

## Zentrale Ereignisverarbeitung.
##
## Feste Ereignisse: Bei jedem time_advanced(from, to) werden alle noch nie ausgelösten
## Ereignisse mit Fälligkeit in (from, to] ausgelöst – sortiert nach Zeit,
## dann Priorität (höher zuerst), dann ID. Jedes wird höchstens einmal ausgelöst.
##
## Zufallsereignisse (Phase 3): Bei jedem day_changed(tag) wird gewürfelt – zufällig, aber
## regelbasiert und deterministisch: Wurf = FNV-1a("<seed>|<tag>|<id>") % 100, ausgelöst wenn
## Wurf < chance_percent. Vorher geprüft: from_day, Kanal-Bedingungen, Abklingzeit, max_times.
## Kandidaten in der Reihenfolge Priorität (höher zuerst), dann ID; höchstens ein
## Zufallsereignis pro Tag. Instanz-ID "<id>@<tag>". Gleicher Seed = gleicher Verlauf;
## es gibt keinen Würfel-Zustand außer dem gespeicherten Seed.
##
## Entscheiden: resolve(instanz_id, option_id) wendet die Folgen an
## (Geld -> LedgerSystem mit idempotency_key "event:<instanz>", Werte -> PlayerStats,
## Kanal -> ChannelSystem mit Begründung) und schließt das Ereignis. Keine Spielzeit.
##
## Weil nur time_advanced/day_changed auslösen, wird beim Laden nichts erneut ausgelöst;
## die Schutzschlüssel verhindern zusätzlich Doppelbuchungen.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const EventDefinitionScript := preload("res://scripts/models/event_definition.gd")
const EventOptionScript := preload("res://scripts/models/event_option.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal event_triggered(event_id: String)
signal event_resolved(event_id: String, option_id: String)

const INSTANCE_SEPARATOR := "@"

var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _channel: ChannelSystemScript
var _catalog: EventCatalogScript
var _seed: int
## Instanz-ID -> true für alle jemals ausgelösten Ereignisse (offen oder entschieden).
var _triggered := {}
## Offene Ereignisse (Instanz-IDs) in Auslösereihenfolge.
var _pending := PackedStringArray()
## Instanz-ID -> gewählte option_id
var _resolved := {}


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		channel: ChannelSystemScript, catalog: EventCatalogScript, p_seed: int) -> void:
	_ledger = ledger
	_stats = stats
	_channel = channel
	_catalog = catalog
	_seed = p_seed
	time.time_advanced.connect(_on_time_advanced)


func get_seed() -> int:
	return _seed


func has_pending() -> bool:
	return not _pending.is_empty()


## Instanz-ID des nächsten offenen Ereignisses oder "".
func get_next_pending_id() -> String:
	return _pending[0] if not _pending.is_empty() else ""


## Das nächste offene Ereignis oder null.
func get_next_pending() -> EventDefinitionScript:
	return get_definition_for(get_next_pending_id())


## Definition zu einer Instanz-ID ("brand_deal@4" -> brand_deal) oder null.
func get_definition_for(instance_id: String) -> EventDefinitionScript:
	if instance_id.is_empty():
		return null
	return _catalog.get_definition(instance_id.get_slice(INSTANCE_SEPARATOR, 0))


func is_triggered(instance_id: String) -> bool:
	return _triggered.has(instance_id)


func is_resolved(instance_id: String) -> bool:
	return _resolved.has(instance_id)


## Alle ausgelösten Instanzen (sortiert), z. B. für Tests und Anzeige.
func get_triggered_ids() -> PackedStringArray:
	var ids := PackedStringArray(_triggered.keys())
	ids.sort()
	return ids


## Kanaländerung einer Option beim aktuellen Stand, Follower nach Wachstumsbremse
## (für Anzeige und resolve). {} bei unbekannter Option.
func option_channel_deltas(instance_id: String, option_id: String) -> Dictionary:
	var definition := get_definition_for(instance_id)
	var option := definition.get_option(option_id) if definition != null else null
	if option == null:
		return {}
	var raw := _raw_channel_deltas(option)
	if raw.has("followers"):
		raw["followers"] = _channel.damped_follower_gain(raw["followers"])
	return raw


## "" wenn erfolgreich, sonst ein Anzeigetext. Bei Ablehnung ändert sich nichts.
func resolve(instance_id: String, option_id: String) -> String:
	if not _pending.has(instance_id):
		return "Dieses Ereignis ist nicht offen."
	var definition := get_definition_for(instance_id)
	var option := definition.get_option(option_id)
	if option == null:
		return "Unbekannte Auswahl: %s" % option_id
	if option.money_cents < 0 and not _ledger.can_afford(-option.money_cents):
		return "Nicht genug Geld (kostet %s)." % LedgerSystemScript.format_cents(-option.money_cents)

	var key := "event:%s" % instance_id
	var reason := "%s: %s" % [definition.title, option.label]
	if option.money_cents != 0:
		var entry := _ledger.post(option.money_cents, option.category, reason, "event", instance_id, key)
		if entry == null:
			push_error("EventSystem: Buchung für Ereignis '%s' abgelehnt (Grund %d)." % [instance_id, _ledger.last_rejection])
			return "Die Buchung ist fehlgeschlagen."
	_stats.apply(option.effects)
	var deltas := _raw_channel_deltas(option)
	if not deltas.is_empty():
		_channel.apply(deltas, "event", reason, instance_id, key)

	_pending.remove_at(_pending.find(instance_id))
	_resolved[instance_id] = option_id
	event_resolved.emit(instance_id, option_id)
	return ""


func to_dict() -> Dictionary:
	return {
		"seed": _seed,
		"triggered": _triggered.keys(),
		"pending": Array(_pending),
		"resolved": _resolved.duplicate(),
	}


## Stellt einen gespeicherten Zustand her, ohne etwas auszulösen oder zu buchen.
## Offene Ereignisse, die es in den Daten nicht mehr gibt, werden verworfen.
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var triggered := {}
	var pending := PackedStringArray()
	var resolved := {}

	var raw_seed: Variant = data.get("seed")
	if not DataReaderScript.is_whole_number(raw_seed) or int(raw_seed) < 0:
		return "Ereignisse: 'seed' fehlt oder ist ungültig."
	var raw_triggered: Variant = data.get("triggered", [])
	var raw_pending: Variant = data.get("pending", [])
	var raw_resolved: Variant = data.get("resolved", {})
	if typeof(raw_triggered) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY] \
			or typeof(raw_pending) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY] \
			or typeof(raw_resolved) != TYPE_DICTIONARY:
		return "Ereignisse: Format ungültig."

	for id in raw_triggered:
		if typeof(id) != TYPE_STRING:
			return "Ereignisse: ungültige ID in 'triggered'."
		triggered[id] = true
	for id in raw_resolved:
		if typeof(id) != TYPE_STRING or typeof(raw_resolved[id]) != TYPE_STRING or not triggered.has(id):
			return "Ereignisse: 'resolved' passt nicht zu 'triggered'."
		resolved[id] = raw_resolved[id]
	for id in raw_pending:
		if typeof(id) != TYPE_STRING or not triggered.has(id) or resolved.has(id) or pending.has(id):
			return "Ereignisse: 'pending' passt nicht zu 'triggered'/'resolved'."
		if get_definition_for(id) != null:
			pending.append(id)

	_seed = int(raw_seed)
	_triggered = triggered
	_pending = pending
	_resolved = resolved
	return ""


## Würfelwert 0–99 für ein Ereignis an einem Tag (öffentlich für Tests und Balancing).
func roll(day: int, event_id: String) -> int:
	return fnv1a("%d|%d|%s" % [_seed, day, event_id]) % 100


## FNV-1a, 32 Bit – bewusst selbst implementiert, damit der Wert nicht von der Engine-Version abhängt.
static func fnv1a(text: String) -> int:
	var hash_value := 2166136261
	for byte in text.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF
	return hash_value


func _raw_channel_deltas(option: EventOptionScript) -> Dictionary:
	var deltas := {}
	@warning_ignore("integer_division")
	var followers: int = option.channel.get("followers", 0) \
			+ _channel.followers * int(option.channel.get("followers_percent", 0)) / 100
	if followers != 0:
		deltas["followers"] = followers
	for key in ["community", "reputation"]:
		if option.channel.get(key, 0) != 0:
			deltas[key] = option.channel[key]
	return deltas


## Vom DayCycle aufgerufen (nach Tagesabschluss und Fristen): würfelt die Zufallsereignisse des Tages.
func on_day_changed(day: int) -> void:
	var candidates: Array[EventDefinitionScript] = []
	for definition in _catalog.get_all():
		if definition.is_random:
			candidates.append(definition)
	candidates.sort_custom(func(a: EventDefinitionScript, b: EventDefinitionScript) -> bool:
		return a.priority > b.priority if a.priority != b.priority else a.id < b.id)
	for definition in candidates:
		if _is_eligible(definition, day) and roll(day, definition.id) < definition.chance_percent:
			_trigger("%s%s%d" % [definition.id, INSTANCE_SEPARATOR, day])
			return


func _is_eligible(definition: EventDefinitionScript, day: int) -> bool:
	if day < definition.from_day:
		return false
	var values := {"followers": _channel.followers, "community": _channel.community,
			"reputation": _channel.reputation}
	for key in definition.conditions:
		var limit: int = definition.conditions[key]
		var value: int = values[key.substr(4)]
		if key.begins_with("min_") and value < limit:
			return false
		if key.begins_with("max_") and value > limit:
			return false
	var times := 0
	var last_day := -1
	var prefix := definition.id + INSTANCE_SEPARATOR
	for instance_id in _triggered:
		if instance_id.begins_with(prefix):
			times += 1
			last_day = maxi(last_day, int(instance_id.substr(prefix.length())))
	if definition.max_times > 0 and times >= definition.max_times:
		return false
	return last_day < 0 or day - last_day >= definition.cooldown_days


func _on_time_advanced(from_minutes: int, to_minutes: int) -> void:
	var due: Array[EventDefinitionScript] = []
	for definition in _catalog.get_all():
		if not definition.is_random and not _triggered.has(definition.id) \
				and definition.due_minutes > from_minutes and definition.due_minutes <= to_minutes:
			due.append(definition)
	due.sort_custom(_comes_before)
	for definition in due:
		_trigger(definition.id)


func _trigger(instance_id: String) -> void:
	_triggered[instance_id] = true
	_pending.append(instance_id)
	event_triggered.emit(instance_id)


func _comes_before(a: EventDefinitionScript, b: EventDefinitionScript) -> bool:
	if a.due_minutes != b.due_minutes:
		return a.due_minutes < b.due_minutes
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.id < b.id
