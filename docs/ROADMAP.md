# Roadmap

Eine Phase gilt erst als abgeschlossen, wenn ihre Abnahmekriterien erfüllt und committet sind.

**Abnahme ab 12.10.2026 (DECISIONS 021):** alle automatischen Tests grün + Fensterlauf auf dem Mac mit
Screenshots, die Claude selbst prüft. Die iPhone-Abnahme wird gesammelt in Phase 7 (Mobile Politur) nachgeholt.
Die Checklisten „Abnahme auf dem iPhone“ bleiben bis dahin offen.

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

## Phase 3 – Streamer-/Creator-Karriere ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme offen – gesammelt in Phase 7)
Kanalprofil (Follower, Community-Stimmung, Ruf) mit Grenzen und Wachstumsbremse, Content-Formate als Daten,
Einnahmen nur über das Ledger, Equipment-Upgrades, zufällige regelbasierte Karriere-Ereignisse mit festem Seed,
in der UI nachvollziehbar, warum sich Werte geändert haben.

- [x] Ticket 3.1: ChannelSystem mit Kanal-Protokoll, Wachstumsbremse, Spielstand Version 3 + Migration (152/152 Tests grün)
- [x] Ticket 3.2: Content-Formate als Daten, ContentSystem; „Kurzer Stream“ wird zum Format „Livestream“ (165/165 Tests grün)
- [x] Ticket 3.3: Equipment-Upgrades (Kamera, Mikrofon, Licht, je 3 Stufen; Spielstand Version 4) (177/177 Tests grün)
- [x] Ticket 3.4: Zufällige Karriere-Ereignisse mit festem Seed (5 Ereignisse; Spielstand Version 5) (193/193 Tests grün)
- [x] Ticket 3.5: Karriere-UI: Kanal im HUD, Kanal-Karte mit Wachstumsbremse, Kanal-Verlauf mit Begründungen (196/196 Tests grün)
- [x] Fensterlauf auf dem Mac mit Screenshots geprüft (Content-Karten, Kanal-Karte, Kanal-Verlauf; damals Hochformat)
- [ ] Im Editor durchgespielt – offen
- [ ] iPhone-Abnahme – offen, gesammelt in Phase 7 (die frühere Meldung „ok“ war falsch)

Abnahme auf dem iPhone (offen – gesammelt in Phase 7):
- [ ] Neues Spiel: HUD zeigt „Kanal: 120 Follower · Community 50 · Ruf 50“
- [ ] Zu Hause gibt es „Kurzvideo“, im Studio „Livestream“, „Langes Video“, „Q&A mit der Community“; „Kurzer Stream“ ist weg
- [ ] Jede Content-Karte zeigt vorher die Wirkung (Zeit, Energie, Stimmung, Follower, Community, Ruf, Geld) und die Qualität mit Anteilen
- [ ] Livestream am Start: genau 2 h, +17 Follower, Community +2, +25,00 € in den Buchungen
- [ ] Kanal-Verlauf zeigt nach jeder Produktion Zeit, Begründung (Format · Qualität) und die Änderung
- [ ] Ausrüstung im Studio: Kamera Stufe 1 kaufen → -120,00 € in den Buchungen, Qualität beim Livestream steigt auf 105 %
- [ ] Höchste Ausrüstungsstufe: Kaufen-Button verschwindet
- [ ] Ab Tag 3 können Karriere-Ereignisse erscheinen; Optionen zeigen Kanal-Folgen; nach der Wahl steht der Grund im Kanal-Verlauf
- [ ] App beenden, „Fortsetzen“: Kanal, Verlauf, Ausrüstung, Buchungen unverändert; kein Ereignis kommt doppelt
- [ ] Spielstand aus Phase 2 lässt sich fortsetzen (Kanal mit Startwerten, keine Ausrüstung)
- [ ] Alles per Touch bedienbar und scrollbar, nichts verdeckt

## Phase 4 – Fiktionales Unternehmen und zweiter Standort ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme offen – gesammelt in Phase 7)
Merch- und Lifestyle-Label (Follower treiben den Umsatz), getrennte Konten privat/Firma im einen Ledger,
Tagesabschluss beim Tageswechsel, zweiter Standort als Filiale in Marbella, Management vor Ort (ohne Pflege sinkt
die Auslastung langsam), Firmenkonto nie negativ (unbezahlte Tage kosten Ruf), noch keine Mitarbeitenden.

- [x] Ticket 4.1: Konten „privat“/„Firma“ im LedgerSystem, Umbuchungen als zwei verknüpfte Buchungen, Spielstand Version 6 + Migration (211/211 Tests grün)
- [x] Ticket 4.2: Unternehmen gründen (CompanySystem, Unternehmens-Protokoll, Einlage/Entnahme; Spielstand Version 7) (225/225 Tests grün)
- [x] Ticket 4.3: Tagesabschluss beim Tageswechsel (Spielstand Version 8) (235/235 Tests grün)
- [x] Ticket 4.4: Zweiter Standort (Ladenlokal, Filiale „Merch-Laden“) und Management-Aktivitäten; Spielstand Version 9 (243/243 Tests grün)
- [x] Ticket 4.5: Unternehmens-UI: Firmenkonto im HUD, Unternehmens-Karte mit Prognose, Einlage/Entnahme, Tagesabschlüsse und Unternehmens-Verlauf (246/246 Tests grün)
- [x] Fensterlauf auf dem Mac mit Screenshots geprüft (Gründung, Unternehmens-Karte, Tagesabschluss, Ladenlokal; Hochformat, Fenster seit G2)
- [ ] Im Editor durchgespielt – offen
- [ ] iPhone-Abnahme – offen, gesammelt in Phase 7

Abnahme auf dem iPhone (offen – gesammelt in Phase 7):
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

## Grafik-Ticket G2 – Querformat, Karte als Hauptbildschirm ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme offen – gesammelt in Phase 7)
Grundsatzentscheidung des Game Directors (12.10.2026), vor Phase 5: Querformat (beide Richtungen), isometrische
Stadtkarte im Vollbild, HUD in den oberen Ecken, Icon-Buttons an den Seiten öffnen Fenster, Gebäude antippen öffnet
das Fenster des Orts. Safe Area (Notch seitlich, Home-Balken unten). Nur Darstellung – Spiellogik, Daten und Spielstand
bleiben unverändert (siehe DECISIONS 020).

- [x] G2.1: Querformat und Grundgerüst (Projekteinstellungen, Safe Area je Bildschirm, Hauptmenü/Einstellungen) (248/248 Tests grün; Spielansicht bis G2.2 noch als schmale Spalte)
- [x] G2.2 + G2.3 (zusammen umgesetzt, damit jeder Stand spielbar bleibt): Karte als Vollbild, HUD, Seitenleisten,
  Hinweise, Zoom; Fenster für Ort, Termine, Kanal, Unternehmen, Buchungen, Ereignis (255/255 Tests grün)
- [x] G2.4: Icons (Kenney „Game Icons“ + Erweiterung, CC0), Tests, Doku (255/255 Tests grün)
- [x] Fensterlauf auf dem Mac mit Screenshots geprüft (Start, Ortsfenster, Kanal-Fenster, Hinweis, Icons; 1280×720)
- [ ] Im Editor durchgespielt – offen
- [ ] iPhone-Abnahme – offen, gesammelt in Phase 7

Abnahme auf dem iPhone (G2, offen – gesammelt in Phase 7):
- [ ] App startet im Querformat, in beiden Richtungen; Drehen des iPhones dreht das Bild mit
- [ ] Karte füllt den ganzen Bildschirm (auch hinter Notch/Dynamic Island und Home-Balken)
- [ ] HUD links oben (Tag, Uhrzeit, Ort) und rechts oben (Konto, Firmenkonto, Energie, Stimmung) – nichts von der Notch verdeckt, in beiden Richtungen
- [ ] Seitenbuttons mit Icon und Text (Termine, Kanal, Buchungen, Menü, Hier; Firma erst nach der Gründung) gut treffbar
- [ ] Gebäude oder Schild antippen öffnet das Fenster des Orts; an fremden Orten sind Aktionen sichtbar, aber gesperrt mit Grund; „Hinfahren“ fährt hin und das Fenster zeigt danach die Aktionen frei
- [ ] Wischen verschiebt die Karte; Zwei-Finger-Geste zoomt (0,5–1,0) ohne versehentlich einen Ort zu öffnen
- [ ] Fenster: Liste im Fenster scrollt per Wischen, ohne versehentlich etwas auszulösen; „Schließen“ und Tipp neben das Fenster schließen
- [ ] Ereignis erscheint als Fenster ohne „Schließen“; Karte reagiert erst nach der Entscheidung wieder
- [ ] Hinweise unten: kurze verschwinden nach ein paar Sekunden, lange (z. B. Tagesabschluss) bleiben bis zum Antippen
- [ ] Hauptmenü und Einstellungen im Querformat bedienbar
- [ ] „Fortsetzen“ nach Neustart: Spielstand unverändert (Spiellogik/Spielstand wurden nicht geändert)

## Phase 5 – Finanzen, Fristen, Behördenereignisse ← in Arbeit
Fiktive, abstrakte Spielwerte – keine realen Steuer- oder Rechtsregeln. Wertstellung je Buchung, Spielwoche Mo–So,
wöchentliche Fristen (Miete Wohnung 80 €, Miete Studio 40 € vom Privatkonto; Stadtabgabe 15 % vom positiven
Wochengewinn vom Firmenkonto), automatisch bezahlt wenn gedeckt, sonst überfällig; Mahngebühr erhöht den offenen
Betrag (gebucht erst beim Bezahlen), Kulanz 2 Tage, Stimmung/Ruf −5; Behördenereignisse zufällig mit Seed plus festes
Ereignis nach 3 überfälligen Fristen; erste Fälligkeit Tag 8; kein Game Over.

- [x] Ticket 5.1: Wertstellung je Buchung, Wochenauswertung, fester Tageswechsel-Ablauf (DayCycle), Spielstand Version 10 (264/264 Tests grün)
- [ ] Ticket 5.2: Fristen als Daten (ObligationSystem), automatisch bezahlen
- [ ] Ticket 5.3: Überfällig, Mahngebühr im offenen Betrag, Bezahlen von Hand
- [ ] Ticket 5.4: Behördenereignisse (Zufall mit Bedingungen + festes Ereignis nach 3 überfälligen Fristen)
- [ ] Ticket 5.5: Finanz-UI (Fristen, Wochenübersicht, HUD-Hinweis), Abnahme per Tests + Mac-Fensterlauf

## Spätere Phasen
6. Save/Load-Stabilisierung und Migration
7. Mobile Politur und Performance – inklusive der gesammelten iPhone-Abnahmen von Phase 3, Phase 4 und G2
   (Checklisten oben) und aller folgenden Phasen
8. Balancing und mehr Inhalte
