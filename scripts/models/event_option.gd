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
## Konto für money_cents (Phase 5): "private" (Standard) oder "company".
var account := "private"
## Spielzeit, die die Entscheidung kostet (Phase 5, z. B. ein Prüfungstermin); 0 = keine.
var minutes := 0
## Änderungen am Unternehmen (Phase 5): utilization, reputation – wirken nur mit Unternehmen.
var company: Dictionary
## Kurzer Hinweis auf eine Folge, die keine Zahl ist (U.3, z. B. „Er meldet sich in zwei Tagen wieder“); "" = keiner.
var note := ""
## Änderungen an der Organisation (U.7): respect, heat, stability – wirken nur mit gegründeter Organisation.
var organisation: Dictionary = {}
## U.14: Aktion gegenüber einer Rivalen-Bande ("fight", "negotiate", "retreat"); die Bande und das Gebiet kennt das
## RivalSystem zur Ereignis-Instanz. "" = keine.
var rival := ""
