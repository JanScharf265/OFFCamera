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
## Fälligkeit in kanonischer Spielzeit (Minuten seit Spielbeginn).
var due_minutes: int
var options: Array[EventOptionScript] = []


## null, wenn es die Option nicht gibt.
func get_option(option_id: String) -> EventOptionScript:
	for option in options:
		if option.id == option_id:
			return option
	return null
