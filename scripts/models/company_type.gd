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
## Reiter im Ortsfenster (G4.6), siehe location_tab.gd.
var tab: String
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
## Ruf-Verlust, wenn die Fixkosten eines Tages nicht bezahlt werden können.
var unpaid_reputation_penalty: int
## Filiale (Ticket 4.4, optional): zweiter Standort mit eigenem Umsatz und eigenen Fixkosten.
var has_branch := false
var branch_location: String
var branch_display_name: String
var branch_opening_minutes: int
## Eröffnungskosten (vom Firmenkonto, > 0).
var branch_opening_fee_cents: int
var branch_base_revenue_per_day_cents: int
var branch_fixed_costs_per_day_cents: int
