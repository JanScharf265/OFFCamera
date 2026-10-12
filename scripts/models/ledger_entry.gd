class_name LedgerEntry
extends RefCounted

## Eine Buchung im Finanzjournal. Wird nur vom LedgerSystem erzeugt und
## danach nicht mehr verändert.
##
## Vorzeichen: amount_cents > 0 = Einnahme, < 0 = Ausgabe. Immer ganze Cent.

var id: String
var time_minutes: int
var amount_cents: int
## z. B. "creator", "food", "fine" – frei wählbar, aber nie leer.
var category: String
var description: String
## Auslösendes System, z. B. "activity", "event".
var source: String
## Optionale Referenz auf Aktivität, Ort oder Ereignis (ID).
var reference: String
## Konto (Phase 4): "private" oder "company" (LedgerSystem.ACCOUNTS).
var account: String
## Wertstellung (Phase 5): Spielzeit, zu der die Buchung fachlich gehört – für Fristen und
## Zeiträume. Meist = time_minutes; Tagesabschlüsse gehören z. B. zum abgerechneten Tag (23:59).
var effective_minutes: int


func _init(p_id: String, p_time_minutes: int, p_amount_cents: int, p_category: String,
		p_description: String, p_source: String, p_reference: String = "", p_account: String = "private",
		p_effective_minutes: int = -1) -> void:
	id = p_id
	time_minutes = p_time_minutes
	amount_cents = p_amount_cents
	category = p_category
	description = p_description
	source = p_source
	reference = p_reference
	account = p_account
	effective_minutes = p_effective_minutes if p_effective_minutes >= 0 else p_time_minutes


func is_income() -> bool:
	return amount_cents > 0
