extends RefCounted

## Feste Liste aller Spielmechaniken (T.7). Jede Mechanik braucht mindestens ein Tutorial in
## data/tutorials/tutorials.json (Feld "mechanic"), und jedes Tutorial gehört zu einer Mechanik von hier –
## das prüft tests/test_tutorial_coverage.gd. Neue Mechanik (z. B. in Paket U): ID hier eintragen UND im selben
## Ticket ihr Tutorial liefern, sonst ist der Abdeckungstest rot.

## Mechanik-ID -> kurzer Name (für Fehlermeldungen und Doku).
const NAMES := {
	# Grundlagen (T.5)
	"map": "Karte (Marbella)",
	"location_open": "Gebäude antippen",
	"map_navigation": "Karte wischen und zoomen",
	"activities": "Aktivitäten und Kacheln",
	"travel": "Hinfahren",
	"trip": "Hinfahren und starten",
	"player_stats": "Energie und Stimmung",
	"calendar": "Kalender",
	"reminder": "Erinnerung vor Terminen",
	"conflict": "Konflikt-Popup",
	"wait": "Warten bis Terminbeginn",
	"events": "Ereignisse",
	"saving": "Speichern und Fortsetzen",
	# Karriere und Firma (T.6)
	"channel": "Kanal (Follower, Community, Ruf)",
	"content_quality": "Content und Qualität",
	"equipment": "Ausrüstung",
	"effect_symbols": "Wirkungs-Symbole auf den Kacheln",
	"company_found": "Firma gründen",
	"company_money": "Einlage und Entnahme",
	"branch": "Filiale (Ladenlokal)",
	"settlement": "Tagesabschluss",
	"obligations": "Fristen und Mahnung",
	"ledger": "Buchungen und Wochenübersicht",
	# Unterwelt (Paket U)
	"black_money": "Schwarzgeld",
	"heat": "Hitze (Aufmerksamkeit der Polizei)",
	"organisation": "Organisation (Respekt, Stabilität, Fenster)",
	"missions": "Story-Aufträge",
	"products": "Ware (Produkte und ihre Werte)",
	"supplier": "Lieferant, Vorkasse und Bestand",
	"credit": "Kredit beim Lieferanten, Schulden und Druck",
	"sites": "Standorte der Unterwelt (Versteck, Kosten, Platz)",
	"selling": "Verkaufen (Zeit, Schwarzgeld, Hitze)",
	"crew": "Crew (Rollen, Bewerber, Löhne)",
	"dealer_sales": "Dealer verkaufen täglich (Unterwelt-Abrechnung, Können, Gier, Loyalität)",
	"promotion": "Crew befördern (Rang, Kosten, Lohn)",
	"underworld_view": "Unterwelt-Ansicht der Karte (Schalter Tag/Unterwelt)",
	"districts": "Gebiete (Nachfrage, Polizei, Rivalen)",
	"district_control": "Gebiete übernehmen, halten, verlieren (Einfluss, Dealer zuteilen)",
	"rivals": "Rivalen-Banden (Stärke, Aggression, Konflikt, Verhandlung, Waffenstillstand)",
}


static func ids() -> PackedStringArray:
	return PackedStringArray(NAMES.keys())
