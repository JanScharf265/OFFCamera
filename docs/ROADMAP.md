# Roadmap

Eine Phase gilt erst als abgeschlossen, wenn ihre Abnahmekriterien erfüllt und committet sind.

## Phase 0 – Projektgrundlage und iPhone-Export ✅ (11.10.2026)
- [x] Godot-Projekt, `.gitignore`, README, Roadmap, Architektur-Notizen
- [x] Minimaler Startbildschirm
- [x] Projekt öffnet in Godot ohne Fehler, Startszene läuft (Godot 4.7.2, Mac)
- [x] iOS-Exportvorlagen (4.7.2)
- [x] iOS-Export-Preset
- [x] Export nach Xcode, Build erfolgreich
- [x] App startet auf dem iPhone (iOS 27.0)
- [x] Commit markiert funktionierenden Ausgangsstand (`bac525c`), Versionen im README eingetragen
- [x] App startet auch ohne Xcode vom Homescreen

## Phase 1 – Spielbares Grundgerüst ✅ (11.10.2026)
Hauptmenü (Neues Spiel / Fortsetzen / Einstellungen), HUD (Tag, Uhrzeit, Geld, Energie, Stimmung),
2–4 Aktivitäten, zentrales TimeSystem, zentrales Ledger, ein Ereignis, Speichern/Laden, Fehler- und Leerzustände.

- [x] Ticket 1: TimeSystem + Test-Runner (12/12 Tests grün auf dem Mac)
- [x] Ticket 2: LedgerSystem (27/27 Tests grün auf dem Mac)
- [x] Ticket 3: GameState + ActivitySystem (Aktivitäten als Daten) (48/48 Tests grün)
- [x] Ticket 4: Hauptmenü + HUD (53/53 Tests grün, auf dem iPhone bedienbar inkl. Scrollen)
- [x] Ticket 5: EventSystem (ein Ereignis, genau einmal) (Tests grün, im Editor geprüft)
- [x] Ticket 6: SaveSystem, „Fortsetzen“, Einstellungen (Tests grün, iPhone-Abnahme ok)

Abnahme auf dem iPhone (gemeinsam mit Phase 2 durchgespielt, alles ok):
- [x] Neues Spiel startet: Tag 1 · Mo, 08:00, 500,00 €, Energie 80, Stimmung 60
- [x] Aktivität ändert Zeit exakt wie auf der Karte angegeben
- [x] Eine Ausgabe (Essen gehen) und eine Einnahme (Kurzer Stream) stehen in den letzten Buchungen
- [x] Gesperrte Aktivität zeigt den Grund (z. B. zu wenig Energie)
- [x] Ereignis um 20:00 erscheint genau einmal; nach „Zusagen“ +30,00 € in den Buchungen
- [x] App komplett beenden (wegwischen), neu öffnen, „Fortsetzen“: gleiche Zeit, gleiches Geld, gleiche Buchungen
- [x] Ereignis kommt nach dem Laden nicht erneut
- [x] „Neues Spiel“ fragt nach, bevor es den Spielstand überschreibt
- [x] Einstellungen → Spielstand löschen (mit Rückfrage) → „Fortsetzen“ ist weg
- [x] Alles per Touch bedienbar, nichts von Notch/Home-Balken verdeckt, Liste scrollbar
- [x] Flugmodus an: App funktioniert unverändert

## Phase 2 – Alltag und Marbella ✅ (11.10.2026)
Orte als Daten mit Kartenposition und Öffnungszeiten, 2D-Stadtkarte, Reisezeit über das TimeSystem,
ortsgebundene Aktivitäten, feste Termine, Speicherstand Version 2 mit Migration.
Auf Wunsch des Game Directors begonnen, bevor die iPhone-Abnahme von Phase 1 durch war.

- [x] Orte als Daten (`data/locations/locations.json`): Wohnung, Studio, Café am Hafen, Fitnessstudio, Büro
- [x] Stadtkarte mit antippbaren Orten, Ortsdetails und „Hinfahren“
- [x] Reisezeit 5 min + 3 min/km, aufgerundet auf 5 min, über das TimeSystem
- [x] Aktivitäten an Orte gebunden, Öffnungszeiten geprüft; neu: Schlafen, Kaffee, Training, Woche planen
- [x] Feste Termine aus Daten: vor Ort ab 1 h vorher wahrnehmen, verpasst kostet Stimmung, Warnung bei Kollision
- [x] Speicherstand Version 2, Migration von Version 1
- [x] Automatische Tests (127/127 grün auf dem Mac, Godot 4.7.2 headless)
- [x] Im Editor durchgespielt
- [x] iPhone-Abnahme

Abnahme auf dem iPhone:
- [x] Neues Spiel startet in der Wohnung; Karte zeigt alle fünf Orte, alles antippbar
- [x] Ort antippen zeigt Öffnungszeiten, Entfernung und Fahrzeit (Wohnung → Studio: 3,6 km · 20 min)
- [x] „Hinfahren“ stellt die Uhr exakt um die Fahrzeit vor, Ort im HUD wechselt
- [x] Nur Aktivitäten des aktuellen Orts sind sichtbar; geschlossener Ort zeigt den Grund
- [x] Schlafen: +8 h, Energie +60
- [x] Termin „Treffen mit der Kamerafrau“ (Tag 1, 14:00, Studio) ab 13:00 vor Ort wahrnehmbar
- [x] Aktion, die den Termin überschneidet, zeigt erst eine Warnung; zweiter Tipp führt sie aus
- [x] Verpasster Termin: Hinweis und Stimmung −10, genau einmal (auch nach Neustart nicht erneut)
- [x] Spielstand aus Phase 1 lässt sich fortsetzen (Ort Wohnung, gleiche Zeit/Geld/Buchungen)
- [x] Karte und Listen per Touch scrollbar, nichts verdeckt

## Grafik-Ticket G1 – Isometrische Stadtansicht ✅ (11.10.2026)
Auf Wunsch des Game Directors vor Phase 3: Stadtkarte im Stil eines Städtebauspiels
(isometrisch, schräg von oben) mit Meer, Straßen und erkennbaren Gebäuden für die fünf Orte,
Standortmarkierung und Fahrzeug beim Reisen. Nur Darstellung – Spiellogik und Tests bleiben unverändert.
Grafiken aus frei nutzbaren (CC0) Asset-Paketen, später austauschbar.

- [x] Kenney „Isometric Tiles“ City/Buildings/Vehicles (CC0), nur benutzte Dateien unter `assets/kenney/`
- [x] Isometrische Karte: Straßennetz, Promenade, Strand, Meer, Bäume, Füllbebauung
- [x] Fünf erkennbare Gebäude mit antippbarem Namensschild; Gebäude selbst auch antippbar
- [x] Wippende Markierung am aktuellen Ort, Route zum ausgewählten Ort
- [x] Taxi fährt nach „Hinfahren“ über die Straßen zum Ziel (nur Animation)
- [x] Wischen auf der Karte verschiebt nur die Karte (520 px hoch); Seite scrollt außerhalb
- [x] Automatische Tests (137/137 grün, Godot 4.7.2 headless); Spiellogik unverändert
- [x] Screenshots aus einem Fensterlauf auf dem Mac geprüft (Karte, Route, Fahrt, Strand)
- [x] Im Editor durchgespielt (Wischen mit der Maus, Tippen auf Gebäude/Schilder)
- [x] iPhone-Abnahme: Wischen flüssig, Tippen trifft, Seite scrollt außerhalb der Karte, Notch/Home-Balken frei

## Phase 3 – Streamer-/Creator-Karriere ✅ (11.10.2026)
Kanalprofil (Follower, Community-Stimmung, Ruf) mit Grenzen und Wachstumsbremse, Content-Formate als Daten,
Einnahmen nur über das Ledger, Equipment-Upgrades, zufällige regelbasierte Karriere-Ereignisse mit festem Seed,
in der UI nachvollziehbar, warum sich Werte geändert haben.

- [x] Ticket 3.1: ChannelSystem mit Kanal-Protokoll, Wachstumsbremse, Spielstand Version 3 + Migration (152/152 Tests grün)
- [x] Ticket 3.2: Content-Formate als Daten, ContentSystem; „Kurzer Stream“ wird zum Format „Livestream“ (165/165 Tests grün)
- [x] Ticket 3.3: Equipment-Upgrades (Kamera, Mikrofon, Licht, je 3 Stufen; Spielstand Version 4) (177/177 Tests grün)
- [x] Ticket 3.4: Zufällige Karriere-Ereignisse mit festem Seed (5 Ereignisse; Spielstand Version 5) (193/193 Tests grün)
- [x] Ticket 3.5: Karriere-UI: Kanal im HUD, Kanal-Karte mit Wachstumsbremse, Kanal-Verlauf mit Begründungen (196/196 Tests grün)
- [x] Im Editor durchgespielt – entfällt, durch die iPhone-Abnahme abgedeckt
- [x] iPhone-Abnahme

Abnahme auf dem iPhone:
- [x] Neues Spiel: HUD zeigt „Kanal: 120 Follower · Community 50 · Ruf 50“
- [x] Zu Hause gibt es „Kurzvideo“, im Studio „Livestream“, „Langes Video“, „Q&A mit der Community“; „Kurzer Stream“ ist weg
- [x] Jede Content-Karte zeigt vorher die Wirkung (Zeit, Energie, Stimmung, Follower, Community, Ruf, Geld) und die Qualität mit Anteilen
- [x] Livestream am Start: genau 2 h, +17 Follower, Community +2, +25,00 € in den Buchungen
- [x] Kanal-Verlauf zeigt nach jeder Produktion Zeit, Begründung (Format · Qualität) und die Änderung
- [x] Ausrüstung im Studio: Kamera Stufe 1 kaufen → -120,00 € in den Buchungen, Qualität beim Livestream steigt auf 105 %
- [x] Höchste Ausrüstungsstufe: Kaufen-Button verschwindet
- [x] Ab Tag 3 können Karriere-Ereignisse erscheinen; Optionen zeigen Kanal-Folgen; nach der Wahl steht der Grund im Kanal-Verlauf
- [x] App beenden, „Fortsetzen“: Kanal, Verlauf, Ausrüstung, Buchungen unverändert; kein Ereignis kommt doppelt
- [x] Spielstand aus Phase 2 lässt sich fortsetzen (Kanal mit Startwerten, keine Ausrüstung)
- [x] Alles per Touch bedienbar und scrollbar, nichts verdeckt

## Phase 4 – Fiktionales Unternehmen und zweiter Standort ← in Abnahme
Merch- und Lifestyle-Label (Follower treiben den Umsatz), getrennte Konten privat/Firma im einen Ledger,
Tagesabschluss beim Tageswechsel, zweiter Standort als Filiale in Marbella, Management vor Ort (ohne Pflege sinkt
die Auslastung langsam), Firmenkonto nie negativ (unbezahlte Tage kosten Ruf), noch keine Mitarbeitenden.

- [x] Ticket 4.1: Konten „privat“/„Firma“ im LedgerSystem, Umbuchungen als zwei verknüpfte Buchungen, Spielstand Version 6 + Migration (211/211 Tests grün)
- [x] Ticket 4.2: Unternehmen gründen (CompanySystem, Unternehmens-Protokoll, Einlage/Entnahme; Spielstand Version 7) (225/225 Tests grün)
- [x] Ticket 4.3: Tagesabschluss beim Tageswechsel (Spielstand Version 8) (235/235 Tests grün)
- [x] Ticket 4.4: Zweiter Standort (Ladenlokal, Filiale „Merch-Laden“) und Management-Aktivitäten; Spielstand Version 9 (243/243 Tests grün)
- [x] Ticket 4.5: Unternehmens-UI: Firmenkonto im HUD, Unternehmens-Karte mit Prognose, Einlage/Entnahme, Tagesabschlüsse und Unternehmens-Verlauf (246/246 Tests grün)
- [ ] Im Editor durchgespielt
- [ ] iPhone-Abnahme

Abnahme auf dem iPhone:
- [ ] Neues Spiel: kein Firmenkonto im HUD; Abschnitt „Unternehmen“ zeigt „Noch kein Unternehmen. Gründen möglich: Merch-Label (Büro).“
- [ ] Im Büro „Merch-Label gründen“: 1 h, Privatkonto −350 € (150 € Gebühr + 200 € Einlage), HUD zeigt „Firmenkonto: 200,00 €“
- [ ] Buchungen: Gründung und Einlage sichtbar, Firmenbuchungen mit „(Firma)“ markiert
- [ ] Unternehmens-Karte: Auslastung 50, Ruf 50, „Heute erwartet: Umsatz +15,90 € · Fixkosten -20,00 € · Ergebnis -4,10 €“
- [ ] „Ware nachbestellen“ (Büro) erhöht die Auslastung um 6; im Unternehmens-Verlauf steht der Grund
- [ ] Über Mitternacht (z. B. Schlafen): Rückmeldung „Tagesabschluss Tag …“ mit Erklärung; Firmenkonto ändert sich genau um das Ergebnis; Auslastung −3
- [ ] Einlage/Entnahme 100 € verschieben Geld zwischen den Konten; Buttons gesperrt, wenn ein Konto nicht reicht
- [ ] Firmenkonto leer (alles entnehmen) und Tageswechsel: keine Fixkosten abgebucht, Ruf −5, Abschluss rot markiert; kein Konto wird negativ
- [ ] Ladenlokal auf der Karte (grüne Markise, Promenade); „Filiale eröffnen“ braucht 300 € auf dem Firmenkonto, dauert 2 h
- [ ] Nach Eröffnung: „Laden führen“ möglich; Tagesabschluss enthält „+ 40,00 € Filiale“ und höhere Fixkosten
- [ ] „Merch im Stream zeigen“ im Studio erhöht die Auslastung
- [ ] App beenden, „Fortsetzen“: beide Konten, Unternehmen, Filiale, Verlauf unverändert; kein Tag doppelt abgerechnet
- [ ] Spielstand aus Phase 3 lässt sich fortsetzen (alle Buchungen auf dem Privatkonto, kein Unternehmen)
- [ ] Alles per Touch bedienbar und scrollbar, nichts verdeckt oder abgeschnitten

## Spätere Phasen
5. Finanzen, Fristen, Behördenereignisse
6. Save/Load-Stabilisierung und Migration
7. Mobile Politur und Performance
8. Balancing und mehr Inhalte
