extends RefCounted

## Anzeigetexte für Aktivitäten, Content und Beträge – reine Formatierung, keine Regeln.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityDefinitionScript := preload("res://scripts/models/activity_definition.gd")

const CHANNEL_SHORT_LABELS := {"community": "Community", "reputation": "Ruf"}


## Betrag mit Vorzeichen, z. B. "+25,00 €" / "-15,00 €".
static func signed_money(cents: int) -> String:
	var text := LedgerSystemScript.format_cents(cents)
	return "+" + text if cents > 0 else text


## Entfernung in 100-m-Schritten, z. B. 36 -> "3,6 km".
@warning_ignore("integer_division")
static func km(tenths: int) -> String:
	return "%d,%d km" % [tenths / 10, tenths % 10]


## z. B. "2 h · Energie -20 · Stimmung +5 · +25,00 €"
static func summary(definition: ActivityDefinitionScript) -> String:
	var parts := PackedStringArray([TimeSystemScript.format_duration(definition.duration_minutes)])
	parts.append_array(effect_parts(definition.effects, definition.money_cents))
	return " · ".join(parts)


## Folgen einer Ereignis-Option, z. B. "Stimmung +5 · +30,00 €" oder "Keine Folgen".
## channel = bereits berechnete Kanaländerung (EventSystem.option_channel_deltas()).
static func option_summary(effects: Dictionary, money_cents: int, channel: Dictionary = {}) -> String:
	var parts := effect_parts(effects, 0)
	parts.append_array(channel_parts(channel))
	if money_cents != 0:
		parts.append(signed_money(money_cents))
	return " · ".join(parts) if not parts.is_empty() else "Keine Folgen"


## Werte in fester Reihenfolge (PlayerStats.KEYS), Geld zuletzt.
static func effect_parts(effects: Dictionary, money_cents: int) -> PackedStringArray:
	var parts := PackedStringArray()
	for key in PlayerStatsScript.KEYS:
		var change: int = effects.get(key, 0)
		if change != 0:
			parts.append("%s %+d" % [PlayerStatsScript.LABELS[key], change])
	if money_cents != 0:
		parts.append(signed_money(money_cents))
	return parts


## Erwartete Wirkung eines Content-Formats, z. B.
## "2 h · Energie -20 · Stimmung +5 · +17 Follower · Community +2 · +25,00 €"
static func content_summary(duration_minutes: int, outcome: Dictionary) -> String:
	var parts := PackedStringArray([TimeSystemScript.format_duration(duration_minutes)])
	parts.append_array(effect_parts(outcome["effects"], 0))
	parts.append_array(channel_parts({"followers": outcome["followers"], "community": outcome["community"],
			"reputation": outcome["reputation"]}))
	if outcome["income_cents"] != 0:
		parts.append(signed_money(outcome["income_cents"]))
	return " · ".join(parts)


## Kanaländerungen in fester Reihenfolge, z. B. "+17 Follower · Community +2 · Ruf -1".
static func channel_parts(deltas: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	var followers: int = deltas.get("followers", 0)
	if followers != 0:
		parts.append("%+d Follower" % followers)
	for key in ["community", "reputation"]:
		var change: int = deltas.get(key, 0)
		if change != 0:
			parts.append("%s %+d" % [CHANNEL_SHORT_LABELS[key], change])
	return parts
