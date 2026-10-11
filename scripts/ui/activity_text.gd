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
	for key in PlayerStatsScript.KEYS:
		var change := definition.get_effect(key)
		if change != 0:
			parts.append("%s %+d" % [PlayerStatsScript.LABELS[key], change])
	if definition.money_cents != 0:
		parts.append(signed_money(definition.money_cents))
	return " · ".join(parts)
