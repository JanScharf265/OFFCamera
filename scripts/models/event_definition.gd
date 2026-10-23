class_name EventDefinition
extends RefCounted

## Ein Ereignis aus data/events/*.json. Wird vom EventCatalog erzeugt und
## geprüft, danach nicht verändert.

const EventOptionScript := preload("res://scripts/models/event_option.gd")

var id: String
var title: String
var text: String
## Höhere Priorität zuerst, wenn mehrere Ereignisse gleichzeitig fällig sind.
var priority: int
## Fälligkeit in kanonischer Spielzeit (Minuten seit Spielbeginn); -1 bei Zufallsereignissen.
var due_minutes: int
## Zufallsereignis (Phase 3): wird an jedem neuen Tag deterministisch gewürfelt.
var is_random := false
## U.3: nur von einem System ausgelöst (EventSystem.trigger_scripted), nie zeit- oder zufallsgesteuert
var is_scripted := false
## Chance pro Tag in Prozent (1–100).
var chance_percent := 0
## Frühestens an diesem Tag (≥ 2).
var from_day := 2
## Mindestabstand in Tagen zum letzten Auslösen desselben Ereignisses.
var cooldown_days := 0
## Höchstens so oft insgesamt; 0 = unbegrenzt.
var max_times := 0
## Bedingungen an den Kanal, z. B. {"min_reputation": 60, "max_community": 35}.
var conditions := {}
var options: Array[EventOptionScript] = []


## null, wenn es die Option nicht gibt.
func get_option(option_id: String) -> EventOptionScript:
	for option in options:
		if option.id == option_id:
			return option
	return null
