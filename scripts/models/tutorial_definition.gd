extends RefCounted

## Ein Tutorial aus data/tutorials/tutorials.json (T.1). Nur Daten – Auslösen und Anzeige kommen in T.2/T.3.

var id: String
## ID der erklärten Mechanik (für den Abdeckungstest in T.7).
var mechanic: String
## Wann es kommt: eine ID aus TutorialCatalog.TRIGGERS.
var trigger: String
var title: String
var text: String
## Stabile UI-ID (Knotenname, z. B. "TravelButton") des hervorgehobenen Elements; "" = keins.
var ui_target: String
## Reihenfolge, wenn mehrere gleichzeitig fällig sind (kleiner zuerst).
var order: int
## Tutorial-IDs, die vorher gesehen sein müssen.
var requires: PackedStringArray
