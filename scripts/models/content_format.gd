class_name ContentFormat
extends RefCounted

## Ein Content-Format aus data/content/formats.json (Phase 3).
## Wird vom ContentFormatCatalog erzeugt und geprüft, danach nicht verändert.
## Die Wirkung berechnet das ContentSystem aus diesen Werten.

var id: String
var display_name: String
var description: String
## ID des Ortes, an dem produziert wird.
var location: String
## Reiter im Ortsfenster (G4.6), siehe location_tab.gd.
var tab: String
var duration_minutes: int
## Änderungen an PlayerStats, z. B. {"energy": -20, "mood": 5}.
var effects: Dictionary
## Follower-Zuwachs = followers_base + Follower × followers_per_mille / 1000 (vor Qualität und Bremse).
var followers_base: int
var followers_per_mille: int
## Feste Änderungen an Community-Stimmung und Ruf.
var community: int
var reputation: int
## Einnahme = income_base_cents + Follower × income_per_1000_cents / 1000 (vor Qualität).
var income_base_cents: int
var income_per_1000_cents: int


func get_effect(key: String) -> int:
	return effects.get(key, 0)
