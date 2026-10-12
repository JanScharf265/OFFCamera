class_name ObligationDefinition
extends RefCounted

## Eine wiederkehrende Frist aus data/obligations/obligations.json (Phase 5), z. B. Miete oder
## die fiktive Stadtabgabe. Wird vom ObligationCatalog erzeugt und geprüft, danach nicht verändert.
## Alles abstrakte Spielwerte – keine realen Steuer- oder Rechtsregeln.

var id: String
var display_name: String
var description: String
## Konto, von dem bezahlt wird: "private" oder "company".
var account: String
## Ledger-Kategorie der Zahlung.
var category: String
## "" oder "company" (nur mit gegründetem Unternehmen).
var requires: String
## Fällig an diesem Wochentag um 00:00 (Index in TimeSystem.WEEKDAY_NAMES, 0 = Montag) …
var weekday: int
## … frühestens ab diesem Tag.
var first_day: int
## Betrag: entweder fest …
var fixed_cents: int
## … oder Prozent vom positiven Ergebnis der Vorwoche auf dem Konto (nach Wertstellung, ohne Umbuchungen).
var profit_percent: int
## Kulanzfrist in Tagen nach Fälligkeit; danach Mahngebühr und Folgen (Ticket 5.3).
var grace_days: int
## Mahngebühr – erhöht den offenen Betrag, wird erst beim Bezahlen gebucht.
var reminder_fee_cents: int
## Folgen nach der Kulanzfrist: Spielerwerte bzw. Unternehmenswerte.
var overdue_effects: Dictionary
var overdue_company_effects: Dictionary


func uses_profit() -> bool:
	return profit_percent > 0
