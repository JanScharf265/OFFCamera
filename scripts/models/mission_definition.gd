extends RefCounted

## Ein Story-Auftrag aus data/underworld/missions.json (U.4) – nur Daten, Ablauf im MissionSystem.

var id: String
## Kapitel der Story, z. B. „Erster Deal“ (mehrere Aufträge bilden eine Kette)
var chapter: String
var title: String
## Wer den Auftrag gibt (erfundene Figur)
var giver: String
## Text beim Erscheinen
var briefing: String
## Ziel: {"type": GOAL_*, …} – siehe MissionCatalog.GOAL_TYPES
var goal: Dictionary
## Kurzer Satz, was zu tun ist
var goal_text: String
## Text nach dem Abschluss
var debrief: String
## Belohnung: Organisationswerte, z. B. {"respect": 5}
var reward: Dictionary
## Reihenfolge in der Liste (kleiner zuerst)
var order: int
## Aufträge, die vorher erledigt sein müssen
var requires: PackedStringArray
