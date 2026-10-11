class_name ChannelSystem
extends RefCounted

## Einzige Autorität für das Kanalprofil (Phase 3). Abstrakte Spielwerte:
##   followers   Reichweite, 0 .. MAX_FOLLOWERS
##   community   Community-Stimmung, 0–100
##   reputation  Ruf, 0–100
##
## Jede Änderung läuft über apply() und landet mit Begründung im Kanal-Protokoll
## (wie Buchungen im Ledger), damit die UI erklären kann, warum sich ein Wert geändert hat.
##
## Wachstumsbremse: Follower-Zuwächse werden mit (MAX − aktuell) / MAX skaliert
## (kaufmännisch gerundet). Bei 0 Followern wirkt der volle Zuwachs, bei der Hälfte des Maximums
## noch die Hälfte, am Maximum nichts mehr – das Wachstum flacht ab und endet bei MAX.
## Verluste wirken ungebremst (bis 0).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ChannelChangeScript := preload("res://scripts/models/channel_change.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal channel_changed(change: ChannelChangeScript)

const KEYS := ["followers", "community", "reputation"]
const LABELS := {"followers": "Follower", "community": "Community-Stimmung", "reputation": "Ruf"}
const MAX_FOLLOWERS := 1000000
const MAX_SCORE := 100
## So viele Protokolleinträge bleiben erhalten (ältere fallen weg, IDs zählen weiter).
const HISTORY_LIMIT := 200

var followers: int
var community: int
var reputation: int

var _time: TimeSystemScript
var _history: Array[ChannelChangeScript] = []
var _next_number := 1
var _used_keys := {}


func _init(time: TimeSystemScript, p_followers: int = 0, p_community: int = 50, p_reputation: int = 50) -> void:
	_time = time
	followers = clampi(p_followers, 0, MAX_FOLLOWERS)
	community = clampi(p_community, 0, MAX_SCORE)
	reputation = clampi(p_reputation, 0, MAX_SCORE)


func get_value(key: String) -> int:
	assert(key in KEYS)
	return get(key)


static func max_value(key: String) -> int:
	return MAX_FOLLOWERS if key == "followers" else MAX_SCORE


## Follower-Zuwachs nach der Wachstumsbremse beim aktuellen Stand (für Vorschau und apply).
func damped_follower_gain(raw_gain: int) -> int:
	if raw_gain <= 0:
		return raw_gain
	@warning_ignore("integer_division")
	var gain := (raw_gain * (MAX_FOLLOWERS - followers) + MAX_FOLLOWERS / 2) / MAX_FOLLOWERS
	return mini(gain, MAX_FOLLOWERS - followers)


## Wendet Änderungen wie {"followers": 80, "community": -5} an und protokolliert sie.
## Gibt den Protokolleintrag zurück oder null bei Ablehnung (dann keine Änderung):
## unbekannter Schlüssel, keine ganze Zahl, leere Quelle/Begründung, alles 0,
## oder idempotency_key schon verwendet.
func apply(deltas: Dictionary, source: String, reason: String, reference: String = "",
		idempotency_key: String = "") -> ChannelChangeScript:
	if source.is_empty() or reason.is_empty():
		push_error("ChannelSystem: Quelle und Begründung sind Pflicht.")
		return null
	var requested := {}
	for key in deltas:
		if key not in KEYS or not DataReaderScript.is_whole_number(deltas[key]):
			push_error("ChannelSystem: ungültige Änderung '%s' = %s." % [key, deltas[key]])
			return null
		if int(deltas[key]) != 0:
			requested[key] = int(deltas[key])
	if requested.is_empty():
		return null
	if not idempotency_key.is_empty() and _used_keys.has(idempotency_key):
		return null

	var applied := {}
	for key in KEYS:
		if not requested.has(key):
			continue
		var delta: int = requested[key]
		if key == "followers":
			delta = damped_follower_gain(delta)
		var new_value := clampi(get(key) + delta, 0, max_value(key))
		if new_value != get(key):
			applied[key] = new_value - get(key)
			set(key, new_value)

	var change := ChannelChangeScript.new("ch_%06d" % _next_number, _time.get_minutes(), source, reason,
			reference, requested, applied)
	_next_number += 1
	_history.append(change)
	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)
	if not idempotency_key.is_empty():
		_used_keys[idempotency_key] = change.id
	channel_changed.emit(change)
	return change


## Protokoll, älteste zuerst (Kopie).
func get_history() -> Array[ChannelChangeScript]:
	return _history.duplicate()


func to_dict() -> Dictionary:
	var entries := []
	for change in _history:
		entries.append({
			"id": change.id, "time_minutes": change.time_minutes, "source": change.source,
			"reason": change.reason, "reference": change.reference,
			"requested": change.requested.duplicate(), "applied": change.applied.duplicate(),
		})
	return {
		"followers": followers,
		"community": community,
		"reputation": reputation,
		"next_number": _next_number,
		"history": entries,
		"used_keys": _used_keys.duplicate(),
	}


## Werte für einen neuen Kanal (auch für die Migration alter Spielstände).
static func initial_dict(p_followers: int, p_community: int, p_reputation: int) -> Dictionary:
	return {
		"followers": p_followers, "community": p_community, "reputation": p_reputation,
		"next_number": 1, "history": [], "used_keys": {},
	}


## Stellt einen gespeicherten Zustand her, ohne Signale zu senden.
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var reader := DataReaderScript.new()
	var values := {}
	for key in KEYS:
		var value := reader.int_field(data, key, "Kanal", true)
		if value < 0 or value > max_value(key):
			reader.errors.append("Kanal: '%s' liegt nicht zwischen 0 und %d." % [key, max_value(key)])
		values[key] = value
	var next_number := reader.int_field(data, "next_number", "Kanal", true)

	var history: Array[ChannelChangeScript] = []
	var raw_history: Variant = data.get("history")
	if typeof(raw_history) != TYPE_ARRAY:
		reader.errors.append("Kanal: 'history' fehlt oder ist keine Liste.")
	else:
		for i in raw_history.size():
			var raw: Variant = raw_history[i]
			var where := "Kanal-Eintrag #%d" % (i + 1)
			if typeof(raw) != TYPE_DICTIONARY:
				reader.errors.append("%s: muss ein Objekt sein." % where)
				continue
			var error_count := reader.errors.size()
			var id := reader.string_field(raw, "id", where, true)
			var time_minutes := reader.int_field(raw, "time_minutes", where, true)
			var source := reader.string_field(raw, "source", where, true)
			var reason := reader.string_field(raw, "reason", where, true)
			var reference := reader.string_field(raw, "reference", where, false)
			var requested := _read_deltas(reader, raw, "requested", where)
			var applied := _read_deltas(reader, raw, "applied", where)
			if reader.errors.size() == error_count:
				history.append(ChannelChangeScript.new(id, time_minutes, source, reason, reference, requested, applied))

	var used_keys := {}
	var raw_keys: Variant = data.get("used_keys", {})
	if typeof(raw_keys) != TYPE_DICTIONARY:
		reader.errors.append("Kanal: 'used_keys' muss ein Objekt sein.")
	else:
		for key in raw_keys:
			if typeof(key) != TYPE_STRING or typeof(raw_keys[key]) != TYPE_STRING:
				reader.errors.append("Kanal: 'used_keys' enthält ungültige Einträge.")
				break
			used_keys[key] = raw_keys[key]

	if reader.errors.is_empty() and next_number < 1:
		reader.errors.append("Kanal: 'next_number' muss mindestens 1 sein.")
	if not reader.errors.is_empty():
		return "; ".join(reader.errors)

	for key in values:
		set(key, values[key])
	_history = history
	_next_number = next_number
	_used_keys = used_keys
	return ""


static func _read_deltas(reader: DataReaderScript, entry: Dictionary, field: String, where: String) -> Dictionary:
	var raw: Variant = entry.get(field)
	var result := {}
	if typeof(raw) != TYPE_DICTIONARY:
		reader.errors.append("%s: '%s' muss ein Objekt sein." % [where, field])
		return result
	for key in raw:
		if key not in KEYS or not DataReaderScript.is_whole_number(raw[key]):
			reader.errors.append("%s: '%s' enthält ungültige Werte." % [where, field])
			return result
		result[key] = int(raw[key])
	return result
