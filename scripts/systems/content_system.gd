class_name ContentSystem
extends RefCounted

## Prüft und produziert Content (Phase 3). Das Ergebnis ist exakt berechenbar
## (kein Zufall) und wird vorher per preview() angezeigt:
##
##   Qualität (%)  = 100 + Community-Bonus [+ Equipment ab Ticket 3.3], mindestens MIN_QUALITY
##                   Community-Bonus = (Community-Stimmung − 50) / 2  → −25 … +25 %
##   Follower roh  = (followers_base + Follower × followers_per_mille / 1000) × Qualität / 100
##   Follower      = Follower roh nach der Wachstumsbremse des ChannelSystems
##   Einnahme      = (income_base + Follower × income_per_1000 / 1000) × Qualität / 100
##   Community, Ruf: feste Werte des Formats
## Alle Divisionen sind ganzzahlig (abgerundet), damit jedes Gerät dasselbe rechnet.
##
## produce() ist alles-oder-nichts: erst alle Prüfungen, dann in fester Reihenfolge
##   1. Buchung der Einnahme im Ledger (Zeitstempel = Beginn, Quelle "content")
##   2. Effekte auf Spielerwerte
##   3. Kanaländerung mit Begründung (Kanal-Protokoll)
##   4. Zeitfortschritt um die Dauer
##   5. Signal content_produced
## Schutzschlüssel "content:<format>:<startminute>" – zwei Produktionen können nie
## zur selben Minute beginnen, daher braucht das System keinen eigenen Spielstand.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const ContentFormatCatalogScript := preload("res://scripts/systems/content_format_catalog.gd")
const ContentFormatScript := preload("res://scripts/models/content_format.gd")

signal content_produced(format_id: String)

const MIN_QUALITY := 10
const INCOME_CATEGORY := "creator"

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _stats: PlayerStatsScript
var _locations: LocationSystemScript
var _channel: ChannelSystemScript
var _catalog: ContentFormatCatalogScript


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		locations: LocationSystemScript, channel: ChannelSystemScript,
		catalog: ContentFormatCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_stats = stats
	_locations = locations
	_channel = channel
	_catalog = catalog


func get_catalog() -> ContentFormatCatalogScript:
	return _catalog


## Qualitätsanteile mit Bezeichnung, z. B. [{"label": "Community-Stimmung", "percent": 5}].
## Nur Anteile ≠ 0.
func quality_parts(_format_id: String) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	@warning_ignore("integer_division")
	var community_bonus := (_channel.community - 50) / 2
	if community_bonus != 0:
		parts.append({"label": ChannelSystemScript.LABELS["community"], "percent": community_bonus})
	return parts


func quality_percent(format_id: String) -> int:
	var total := 100
	for part in quality_parts(format_id):
		total += int(part["percent"])
	return maxi(total, MIN_QUALITY)


## Erwartetes Ergebnis beim aktuellen Stand (leer bei unbekanntem Format):
## {quality_percent, quality_parts, followers_raw, followers, community, reputation, income_cents, effects}
@warning_ignore("integer_division")
func preview(format_id: String) -> Dictionary:
	var format := _catalog.get_definition(format_id)
	if format == null:
		return {}
	var quality := quality_percent(format_id)
	var followers := _channel.followers
	var raw := (format.followers_base + followers * format.followers_per_mille / 1000) * quality / 100
	var income := (format.income_base_cents + followers * format.income_per_1000_cents / 1000) * quality / 100
	return {
		"quality_percent": quality,
		"quality_parts": quality_parts(format_id),
		"followers_raw": raw,
		"followers": _channel.damped_follower_gain(raw),
		"community": format.community,
		"reputation": format.reputation,
		"income_cents": income,
		"effects": format.effects.duplicate(),
	}


## "" wenn das Format jetzt produziert werden kann, sonst ein Grund für die Anzeige.
func check(format_id: String) -> String:
	var format := _catalog.get_definition(format_id)
	if format == null:
		return "Unbekanntes Format: %s" % format_id
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	if format.location != _locations.get_current():
		var location := _locations.get_catalog().get_definition(format.location)
		return "Nur vor Ort möglich: %s." % (location.display_name if location != null else format.location)
	var closed_reason := _locations.check_open_during(format.location, _time.get_minutes(), format.duration_minutes)
	if not closed_reason.is_empty():
		return closed_reason
	var energy_change := format.get_effect("energy")
	if energy_change < 0 and _stats.energy + energy_change < 0:
		return "Zu wenig Energie (benötigt %d)." % -energy_change
	return ""


## Begründung fürs Kanal-Protokoll, z. B. "Livestream · Qualität 105 % (Community-Stimmung +5 %)".
func explain(format_id: String) -> String:
	var format := _catalog.get_definition(format_id)
	if format == null:
		return ""
	return "%s · %s" % [format.display_name, quality_text(format_id)]


## z. B. "Qualität 105 % (Community-Stimmung +5 %)"
func quality_text(format_id: String) -> String:
	var text := "Qualität %d %%" % quality_percent(format_id)
	var parts := PackedStringArray()
	for part in quality_parts(format_id):
		parts.append("%s %+d %%" % [part["label"], part["percent"]])
	if not parts.is_empty():
		text += " (%s)" % ", ".join(parts)
	return text


## Produziert das Format. Rückgabe wie check(): "" = erfolgreich.
func produce(format_id: String) -> String:
	var reason := check(format_id)
	if not reason.is_empty():
		return reason

	var format := _catalog.get_definition(format_id)
	var outcome := preview(format_id)
	var explanation := explain(format_id)
	var key := "content:%s:%d" % [format.id, _time.get_minutes()]
	if outcome["income_cents"] > 0:
		var entry := _ledger.post(outcome["income_cents"], INCOME_CATEGORY, format.display_name, "content",
				format.id, key)
		if entry == null:
			push_error("ContentSystem: Buchung für '%s' abgelehnt." % format_id)
			return "Die Buchung ist fehlgeschlagen."
	_stats.apply(format.effects)
	var deltas := {"followers": outcome["followers_raw"], "community": format.community,
			"reputation": format.reputation}
	_channel.apply(deltas, "content", explanation, format.id, key)
	_time.advance(format.duration_minutes)
	content_produced.emit(format.id)
	return ""
