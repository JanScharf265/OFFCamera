class_name AppointmentDefinition
extends RefCounted

## Ein fester Termin aus data/appointments/*.json.

var id: String
var title: String
var description: String
## ID des Ortes, an dem der Termin stattfindet.
var location: String
## Beginn in kanonischer Spielzeit (Minuten seit Spielbeginn).
var start_minutes: int
var duration_minutes: int
## Folgen beim Wahrnehmen.
var money_cents: int
var category: String
var effects: Dictionary
## Folgen, wenn der Termin verpasst wird (nur Spielerwerte).
var missed_effects: Dictionary
