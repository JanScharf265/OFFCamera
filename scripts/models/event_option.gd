class_name EventOption
extends RefCounted

## Eine Antwortmöglichkeit eines Ereignisses.

var id: String
var label: String
## Einnahme > 0, Ausgabe < 0, 0 = keine Buchung.
var money_cents: int
## Ledger-Kategorie, Pflicht wenn money_cents != 0.
var category: String
## Änderungen an PlayerStats, z. B. {"mood": 5}.
var effects: Dictionary
## Änderungen am Kanal (Phase 3): followers (absolut), followers_percent (vom aktuellen Stand),
## community, reputation – z. B. {"followers_percent": -5, "reputation": -6}.
var channel: Dictionary
