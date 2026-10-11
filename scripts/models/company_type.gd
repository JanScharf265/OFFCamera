class_name CompanyType
extends RefCounted

## Eine Unternehmensart aus data/company/company_types.json (Phase 4).
## Wird vom CompanyTypeCatalog erzeugt und geprüft, danach nicht verändert.
## Alle Werte sind abstrakte Spielwerte (Platzhalter fürs Balancing).

var id: String
var display_name: String
var description: String
## Ort, an dem gegründet wird.
var found_location: String
## Spielzeit für die Gründung (> 0).
var founding_minutes: int
## Gründungsgebühr (Ausgabe vom Privatkonto, > 0).
var founding_fee_cents: int
## Mindesteinlage bei der Gründung (Umbuchung privat -> Firma, > 0).
var min_deposit_cents: int
## Startwerte 0–100.
var start_utilization: int
var start_reputation: int
## Für den Tagesabschluss (Ticket 4.3).
var fixed_costs_per_day_cents: int
var base_revenue_per_day_cents: int
var revenue_per_1000_followers_cents: int
var utilization_decay_per_day: int
