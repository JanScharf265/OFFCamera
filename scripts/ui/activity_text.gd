extends RefCounted

## Anzeigetexte für Aktivitäten und Beträge – reine Formatierung, keine Regeln.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityDefinitionScript := preload("res://scripts/models/activity_definition.gd")


## Betrag mit Vorzeichen, z. B. "+25,00 €" / "-15,00 €".
static func signed_money(cents: int) -> String:
	var text := LedgerSystemScript.format_cents(cents)
	return "+" + text if cents > 0 else text


## z. B. "2 h · Energie -20 · Stimmung +5 · +25,00 €"
static func summary(definition: ActivityDefinitionScript) -> String:
	var parts := PackedStringArray([TimeSystemScript.format_duration(definition.duration_minutes)])
	parts.append_array(effect_parts(definition.effects, definition.money_cents))
	return " · ".join(parts)


## Folgen einer Ereignis-Option, z. B. "Stimmung +5 · +30,00 €" oder "Keine Folgen".
static func option_summary(effects: Dictionary, money_cents: int) -> String:
	var parts := effect_parts(effects, money_cents)
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
