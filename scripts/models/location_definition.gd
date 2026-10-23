class_name LocationDefinition
extends RefCounted

## Ein Ort aus data/locations/*.json. Wird vom LocationCatalog erzeugt und
## geprüft, danach nicht verändert.

var id: String
var display_name: String
var description: String
## Position auf der Stadtkarte, jeweils 0–1 (x nach rechts, y nach unten).
var map_position: Vector2
## Öffnungszeiten in vollen Stunden (open < close, close bis 24).
## has_hours == false bedeutet: immer geöffnet.
## U.8: Auftrag, der den Ort bekannt macht ("" = von Anfang an bekannt)
var unlocked_by_mission := ""
var has_hours := false
var open_hour := 0
var close_hour := 24
