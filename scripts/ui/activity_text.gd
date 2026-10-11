extends RefCounted

## Anzeigetexte für Aktivitäten, Content und Beträge – reine Formatierung, keine Regeln.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityDefinitionScript := preload("res://scripts/models/activity_definition.gd")

const CHANNEL_SHORT_LABELS := {"community": "Community", "reputation": "Ruf"}
const COMPANY_SHORT_LABELS := {"utilization": "Auslastung", "reputation": "Ruf (Firma)"}


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
	parts.append_array(effect_parts(definition.effects, 0))
	parts.append_array(company_parts(definition.company_effects))
	if definition.money_cents != 0:
		parts.append(signed_money(definition.money_cents))
	return " · ".join(parts)


## Änderungen am Unternehmen, z. B. "Auslastung +6 · Ruf (Firma) +2".
static func company_parts(deltas: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	for key in ["utilization", "reputation"]:
		var change: int = deltas.get(key, 0)
		if change != 0:
			parts.append("%s %+d" % [COMPANY_SHORT_LABELS[key], change])
	return parts


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
		parts.append("%s Follower" % signed_int(followers))
	for key in ["community", "reputation"]:
		var change: int = deltas.get(key, 0)
		if change != 0:
			parts.append("%s %+d" % [CHANNEL_SHORT_LABELS[key], change])
	return parts


## Ganze Zahl mit Tausenderpunkten, z. B. 12345 -> "12.345".
static func format_int(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += "."
		grouped += digits[i]
	return ("-" if value < 0 else "") + grouped


## Mit Vorzeichen, z. B. "+1.200" / "-35".
static func signed_int(value: int) -> String:
	return ("+" if value > 0 else "") + format_int(value)


## Eine Zeile im Unternehmens-Protokoll, z. B. ["Tag 2 · 09:20  Ware nachbestellen", "Auslastung +6"].
static func company_change_text(change) -> Array[String]:
	var head := "%s  %s" % [TimeSystemScript.format_stamp(change.time_minutes), change.reason]
	var applied := company_parts(change.applied)
	var detail := " · ".join(applied)
	if change.requested.is_empty():
		detail = ""
	elif applied.is_empty():
		detail = "keine Änderung"
	if change.was_limited():
		detail += " (gewünscht: %s · Grenze erreicht)" % " · ".join(company_parts(change.requested))
	return [head, detail]


## Eine Zeile im Kanal-Verlauf: "Tag 1 · 08:20  Livestream · Qualität 100 %" und die Änderung,
## z. B. "+17 Follower · Community +2" oder mit Hinweis, wenn Bremse/Grenze gekürzt hat.
static func channel_change_text(change) -> Array[String]:
	var head := "%s  %s" % [TimeSystemScript.format_stamp(change.time_minutes), change.reason]
	var applied := channel_parts(change.applied)
	var detail := " · ".join(applied) if not applied.is_empty() else "keine Änderung"
	if change.was_limited():
		var causes := PackedStringArray()
		for key in change.requested:
			if int(change.applied.get(key, 0)) != int(change.requested[key]):
				var cause := "Wachstumsbremse" if key == "followers" and change.requested[key] > 0 else "Grenze erreicht"
				if cause not in causes:
					causes.append(cause)
		detail += " (gewünscht: %s · %s)" % [" · ".join(channel_parts(change.requested)), ", ".join(causes)]
	return [head, detail]
