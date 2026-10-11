class_name ActivityDefinition
extends RefCounted

## Beschreibung einer Aktivität aus data/activities/*.json.
## Wird vom ActivityCatalog erzeugt und geprüft, danach nicht verändert.

var id: String
var display_name: String
var description: String
var duration_minutes: int
## Einnahme > 0, Ausgabe < 0, 0 = keine Buchung.
var money_cents: int
## Ledger-Kategorie, Pflicht wenn money_cents != 0.
var category: String
## Änderungen an PlayerStats, z. B. {"energy": -20, "mood": 5}.
var effects: Dictionary


func get_effect(key: String) -> int:
	return effects.get(key, 0)
