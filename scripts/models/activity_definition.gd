class_name ActivityDefinition
extends RefCounted

## Beschreibung einer Aktivität aus data/activities/*.json.
## Wird vom ActivityCatalog erzeugt und geprüft, danach nicht verändert.

var id: String
var display_name: String
var description: String
## ID des Ortes, an dem die Aktivität stattfindet.
var location: String
## Reiter im Ortsfenster (G4.6), siehe location_tab.gd.
var tab: String
var duration_minutes: int
## Einnahme > 0, Ausgabe < 0, 0 = keine Buchung.
var money_cents: int
## Ledger-Kategorie, Pflicht wenn money_cents != 0.
var category: String
## Änderungen an PlayerStats, z. B. {"energy": -20, "mood": 5}.
var effects: Dictionary
## Voraussetzung (Phase 4): "" (keine), "company" (Unternehmen gegründet), "branch" (Filiale eröffnet).
var requires: String
## Änderungen am Unternehmen (Phase 4), z. B. {"utilization": 6, "reputation": 2}.
var company_effects: Dictionary


func get_effect(key: String) -> int:
	return effects.get(key, 0)
