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

## Phase 3 – Streamer-/Creator-Karriere ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme im gebündelten Test 7.5 ✅)
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
- [x] iPhone-Abnahme – gebündelter iPhone-Test (Ticket 7.5) ok, 13.10.2026 (die frühere Meldung „ok“ war falsch)

Abnahme auf dem iPhone (ersetzt durch den gebündelten iPhone-Test, Phase 7 / Ticket 7.5; Logik durch automatische Tests abgedeckt):
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

## Phase 4 – Fiktionales Unternehmen und zweiter Standort ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme im gebündelten Test 7.5 ✅)
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
- [x] iPhone-Abnahme – gebündelter iPhone-Test (Ticket 7.5) ok, 13.10.2026

Abnahme auf dem iPhone (ersetzt durch den gebündelten iPhone-Test, Phase 7 / Ticket 7.5; Logik durch automatische Tests abgedeckt):
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

## Grafik-Ticket G2 – Querformat, Karte als Hauptbildschirm ✅ (Tests + Mac-Fensterlauf; iPhone-Abnahme im gebündelten Test 7.5 ✅)
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
- [x] iPhone-Abnahme – gebündelter iPhone-Test (Ticket 7.5) ok, 13.10.2026

Abnahme auf dem iPhone (G2; ersetzt durch den gebündelten iPhone-Test, Phase 7 / Ticket 7.5):
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

## Phase 5 – Finanzen, Fristen, Behördenereignisse ✅ (12.10.2026, Tests + Mac-Fensterlauf; iPhone-Abnahme im gebündelten Test 7.5 ✅)
Fiktive, abstrakte Spielwerte – keine realen Steuer- oder Rechtsregeln. Wertstellung je Buchung, Spielwoche Mo–So,
wöchentliche Fristen (Miete Wohnung 80 €, Miete Studio 40 € vom Privatkonto; Stadtabgabe 15 % vom positiven
Wochengewinn vom Firmenkonto), automatisch bezahlt wenn gedeckt, sonst überfällig; Mahngebühr erhöht den offenen
Betrag (gebucht erst beim Bezahlen), Kulanz 2 Tage, Stimmung/Ruf −5; Behördenereignisse zufällig mit Seed plus festes
Ereignis nach 3 überfälligen Fristen; erste Fälligkeit Tag 8; kein Game Over.

- [x] Ticket 5.1: Wertstellung je Buchung, Wochenauswertung, fester Tageswechsel-Ablauf (DayCycle), Spielstand Version 10 (264/264 Tests grün)
- [x] Ticket 5.2: Fristen als Daten (ObligationSystem), automatisch bezahlen; Spielstand Version 11 (275/275 Tests grün)
- [x] Ticket 5.3: Überfällig, Mahngebühr im offenen Betrag (gebucht erst beim Bezahlen), Bezahlen von Hand (283/283 Tests grün)
- [x] Ticket 5.4: Behördenereignisse (6 fiktive Ereignisse, neue Bedingungen, Optionen mit Konto/Zeit/Unternehmen, festes Ereignis nach 3 überfälligen Fristen) (294/294 Tests grün)
- [x] Ticket 5.5: Finanz-UI: Fristen-Fenster (offen, Mahngebühr, Bezahlen, nächste Fälligkeiten), Seitenbutton „Fristen (n)“ rot bei offenen Fristen, Wochenübersicht im Buchungen-Fenster (298/298 Tests grün)
- [x] Test-Runner erkennt Skriptfehler (abgebrochene Tests zählen jetzt als fehlgeschlagen)
- [x] Fensterlauf auf dem Mac mit Screenshots geprüft (Karte mit „Fristen (1)“, Fristen-Fenster, Mahnung 90 € offen, Wochenübersicht, Prüfungstermin-Ereignis); dabei gefunden und behoben: linke Seitenleiste ragte mit 4 Buttons aus dem Bild
- [ ] Im Editor durchgespielt – offen
- [x] iPhone-Abnahme – gebündelter iPhone-Test (Ticket 7.5) ok, 13.10.2026

Abnahme auf dem iPhone (ersetzt durch den gebündelten iPhone-Test, Phase 7 / Ticket 7.5; Logik durch automatische Tests abgedeckt):
- [ ] In Woche 1 keine Fristen; am ersten Montag (Tag 8) Mieten automatisch bezahlt, Hinweis in der Rückmeldung
- [ ] Bei zu wenig Geld: „Fristen (n)“ rot, Fristen-Fenster zeigt offenen Betrag und Grund; nach 2 Tagen Mahnung (offener Betrag steigt, Konto unverändert)
- [ ] „Bezahlen“ bucht Grundbetrag und Mahngebühr; Button danach weg
- [ ] Stadtabgabe nur mit Unternehmen und nur bei Gewinn der Vorwoche; vom Firmenkonto
- [ ] Wochenübersicht im Buchungen-Fenster passt zu den Buchungen (Tagesabschluss zählt zum abgerechneten Tag)
- [ ] Behördenereignisse erscheinen als Fenster mit Dauer/Ruf/Firmenkonto in den Folgen; ab 3 offenen Fristen sicher die Vollstreckungsankündigung
- [ ] Seitenleisten mit 4 Buttons vollständig sichtbar, in beiden Querformat-Richtungen

## Phase 6 – Save/Load-Stabilisierung und Migration ✅ (12.10.2026, Tests + lange Tests + Mac-Fensterlauf; iPhone-Abnahme im gebündelten Test 7.5 ✅)
Echte Altstände aller Versionen als Testdateien, robustes Schreiben (Kopf, 3 Backups, gültige .tmp übernehmen, defekte
Stände aufbewahren), Konsistenzprüfung und einheitliche Regel für entfernte Daten, Rundlauf-/Störungs-/Lasttests
(langer Lauf getrennt), Spielstand-Info im Hauptmenü. Spiellogik unverändert.

- [x] Ticket 6.1: Echte Spielstände v1–v11 aus den damaligen Commits, Migrationen als Einzelschritte, Testdatei-Pflicht je Version (303/303 Tests grün, Suite ~1 s)
- [x] Ticket 6.2: Robustes Schreiben (Kopf, 3 Backups, gültige .tmp, defekte Stände aufbewahren) (315/315 Tests grün)
- [x] Ticket 6.3: Konsistenzprüfung über System-Grenzen, einheitliche Regel für entfernte Daten mit Hinweis, Spielstand Version 12 (Fristen speichern Konto/Kategorie/Bezeichnung) (326/326 Tests grün)
- [x] Ticket 6.4: Rundlauf-, Störungs- und Lasttests (langer Lauf `-- --long`, ~5 s); 3 Stellen gehärtet, die bei beschädigten Dateien Skriptfehler auslösten (329/329 + 3/3 lange Tests grün)
- [x] Ticket 6.5: Spielstand-Info im Hauptmenü, Hinweise zu defekten Ständen, Anzeige in den Einstellungen (332/332 Tests grün)
- [x] Lange Tests am Ende der Phase: 3/3 grün (Rundlauf 30 × 30 Tage, Störungstest, Messung Tag 180: 397 KB, Laden 15 ms)
- [x] Fensterlauf auf dem Mac mit Screenshots geprüft (Hauptmenü mit Spielstand-Info, Backup nach defektem Stand, Einstellungen mit aufbewahrter Kopie)
- [ ] Im Editor durchgespielt – offen
- [x] iPhone-Abnahme – gebündelter iPhone-Test (Ticket 7.5) ok, 13.10.2026

Abnahme auf dem iPhone (ersetzt durch den gebündelten iPhone-Test, Phase 7 / Ticket 7.5; Logik durch automatische Tests abgedeckt):
- [ ] Hauptmenü zeigt unter „Fortsetzen“ Tag, Uhrzeit, Konto und „gespeichert …“ mit richtiger Ortszeit
- [ ] App mitten im Spiel beenden (wegwischen), neu öffnen: Fortsetzen lädt den letzten Stand ohne Hinweis
- [ ] Ein Spielstand aus einem früheren Build (Phase 5) lässt sich fortsetzen
- [ ] Speichern bei wenig freiem Speicher bzw. im Flugmodus funktioniert (alles lokal)

## Phase 7 – Mobile Politur und Performance ✅ (13.10.2026, Tests + Mac-Fensterlauf + iPhone-Test)
Teil A ohne iPhone (Aufräumen, Layout-Tests, Performance auf dem Mac, iOS-Build vorbereiten), dann EIN gebündelter
iPhone-Test, der die offenen iPhone-Abnahmen von Phase 3–6 und G2 ersetzt, dann Korrekturen.

- [x] Ticket 7.1: Aufräumen, ObjectDB-Warnung untersucht – im Spiel kein Leck (gemessen), Ursache sind Kreisverweise in Tests; Wächter-Tests gegen Lecks (334/334 Tests grün)
- [x] Ticket 7.2: Layout-Tests für 4 Geräteklassen (16:9 bis 19,5:9, mit/ohne Notch); gefunden und behoben: Hauptmenü zu hoch auf Notch-iPhones, Hinweis-Höhe erst ein Bild später korrekt (336/336 Tests grün)
- [x] Ticket 7.3: Performance auf dem Mac: Ruhezustand 120 → 0 Bilder/s (Stromsparmodus + Markierung wippt nur kurz), Zeichenaufrufe 963 → 206 (Texturatlas), 60 FPS (338/338 Tests grün)
- [x] Ticket 7.4: iOS-Build vorbereiten: Version 0.7.0 (Build 7), App-Symbol, Export nach Xcode headless geprüft (Querformat links/rechts, Daten und Grafiken im Paket, Tests/Werkzeuge nicht) (338/338 Tests grün)
- [x] Ticket 7.5: Gebündelter iPhone-Test (Game Director, 13.10.2026): alle 9 Punkte ok
- [x] Ticket 7.6: entfällt – keine Fehler gemeldet; die Layout-Wünsche vom iPhone gehen in G4/G5 auf
- [x] Nachtrag: Code-Signatur „Apple Development“ im Export-Preset; `.gdignore` in `exports/` und `tools/` und `exports/*` vom Export ausgeschlossen (der Export hatte Dateien aus `exports/` ins .pck gepackt; jetzt 0)

Gebündelter iPhone-Test (Build 0.7.0, ersetzt die einzelnen iPhone-Abnahmen von Phase 3–6 und G2):
- [x] 1. Starten: App öffnen – das Bild ist quer. iPhone um 180° drehen – das Bild dreht mit, nichts wird von Notch oder Rand verdeckt.
- [x] 2. Fortsetzen: Den alten Spielstand vorher NICHT löschen – er ist der Migrationstest. „Fortsetzen“ tippen – das Spiel lädt; oben links Tag und Uhrzeit, oben rechts das Geld.
- [x] 3. Karte: Mit einem Finger wischen – die Karte bewegt sich flüssig. Mit zwei Fingern zoomen – dabei öffnet sich kein Fenster.
- [x] 4. Fahren: Auf das Gebäude „Studio“ tippen – ein Fenster öffnet sich. „Hinfahren“ tippen – das Taxi fährt, die Uhr springt vor.
- [x] 5. Fenster: Im Studio-Fenster die Liste mit dem Finger rauf und runter schieben – dabei startet nichts. Dann bei „Livestream“ auf „Produzieren“ tippen – das Geld oben rechts steigt.
- [x] 6. Seitenbuttons: Termine, Fristen, Kanal, Buchungen, Menü nacheinander antippen – jedes Fenster geht auf und mit „Schließen“ wieder zu; alle Buttons sind ganz zu sehen.
- [x] 7. Beenden: App ganz schließen (hochwischen, wegschieben), neu öffnen – das Hauptmenü zeigt unter „Fortsetzen“ Tag, Uhrzeit und Geld; nach „Fortsetzen“ ist alles wie vorher.
- [x] 8. Flugmodus: einschalten – alles funktioniert gleich.
- [x] 9. Gefühl: Ruckelt etwas? Wird das iPhone nach 5 Minuten spürbar warm?

## Neue Ausrichtung – Pakete G3, G4, G5, T, U ← in Arbeit (G3, G4, G5 und T fertig, U läuft – als Nächstes U.11)
Freigegeben vom Game Director am 13.10.2026, Entscheidungen in `docs/DECISIONS.md` 036–038.
Grundlage: `docs/VISION.md` und `docs/LEITFADEN.md`. Die Unterwelt wird das Hauptspiel, die Streamer-Karriere das Nebenspiel,
das Merch-Label wird Tarnfirma. Reihenfolge: G3 → G4 → G5 → T → U → Phase 8.
Jedes Ticket = eine Sitzung: Tests grün, Mac-Fensterlauf mit Screenshots, Doku, Commit.
Ab T bekommt jede neue Mechanik im selben Ticket ihr Tutorial. Jede neue Spielstand-Version bekommt eine
echte Testdatei und eine Migration.

### G3 – App-Icon und Logo ✅ (13.10.2026)
- [x] G3.1 Drei Icon-Entwürfe als SVG + Vorschau-PNG (1024 px und 60 px, heller und dunkler Homescreen) in `tools/icon/drafts/`, Erzeuger `tools/icon/make_previews.gd` (A Halbes Objektiv, B REC im Schatten, C OC-Monogramm) → Wahl des Game Directors offen
- [x] G3.2 Icon „Halbes Objektiv“: Quellen `assets/icon/app_icon.svg` + vereinfacht `app_icon_small.svg` (bis 87 px), 15 iOS-Größen erzeugt, alle 17 Icon-Plätze im Export-Preset belegt; Export headless geprüft (Xcode-Projekt enthält genau diese Dateien); Test `test_app_icon.gd` (340/340 Tests grün)
- [x] G3.3 Schriftzug „OFF CAMERA“ (Variante 1 „Kino“): Bebas Neue (OFL, `assets/fonts/bebas_neue/`), Baustein `scripts/ui/logo.gd` im Hauptmenü, Startbild `assets/splash/splash.png` (Erzeuger `tools/splash/make_splash.gd`) als Boot-Splash und iOS-Launch-Screen; Export geprüft; Mac-Fensterlauf mit Screenshot (341/341 Tests grün)

### G4 – UI-Layout (mehr Karte) ✅ (22.10.2026)
- [x] G4.1 Layout-Mockup (`tools/mockup/g4_1_karte.png`, `g4_1_ortsfenster.png`, Erzeuger `tools/mockup/g4_mockup.gd`) – freigegeben 13.10.2026 inkl. 2 Button-Spalten rechts, mit 5 Änderungen (in G4.3–G4.5 eingetragen)
- [x] G4.2 Querformat fest auf EINE Richtung: `display/window/handheld/orientation = 2` („umgekehrt“) → im Export nur `UIInterfaceOrientationLandscapeRight` (Home-Seite rechts = Insel links); rechter Rand: Safe Area wie von iOS gemeldet (keine Sonderregel), offen für den nächsten iPhone-Test (341/341 Tests grün)
- [x] G4.3 HUD als schmale Leiste oben (neu `scripts/ui/hud_bar.gd`, `game_screen.gd`); Plätze für Schwarzgeld/Hitze, sichtbar erst wenn es sie gibt; Energie und Stimmung als Balken MIT Zahl, Stimmung mit Smiley-Icon (kein Stern) – umgesetzt, Seitenleisten beginnen jetzt unter der Leiste; Layout-Test: volle Breite, ≤ 64 px hoch, Inhalt passt auf allen 4 Geräteklassen (341/341 Tests grün)
- [x] G4.4 7 runde Seitenbuttons + Menü, alle rechts (Leben: Kalender, Fristen, Kanal; Geschäft: Organisation, Aufträge, Firma, Buchungen; Buttons ohne Funktion bleiben bis U verborgen), in 2 Spalten (Leben | Geschäft) auf dezentem Gruppen-Hintergrund, Kreis 64 px, unsichtbare Tippfläche mind. 84 px, Mini-Beschriftung, Zählerpunkt als Bauteil, Menü als Zahnrad in der HUD-Leiste; links nur „Hier“; Kalender-Icon = echtes Kalender-Symbol (Kenney, sonst eigenes einfaches Symbol) – umgesetzt mit eigenem Kalender-Symbol (Kenney hat keins), Energie als Blitz, kurze Hinweise lassen Tipps auf die Karte durch; Layout-Tests für Tippflächen, Kreisgröße, Lage rechts/links auf allen 4 Geräteklassen (343/343 Tests grün) (neu `scripts/ui/side_button.gd`, `game_screen.gd`)
- [x] G4.5 Ortsfenster als Kachel-Raster, 3–4 Spalten, ca. 85 % Breite; jede Kachel mit fest reservierter Hinweiszeile (Start-Buttons auf einer Höhe); Käufe (sofort, ohne Spielzeit) mit eigenem Button-Stil (z. B. Rahmen-Button) – umgesetzt (`activity_tile.gd`): Kachel mit Name, „2 h · Ende HH:MM“, Wirkungen als Symbol + Zahl, Hinweiszeile (Terminkonflikt gelb, sonst Qualität/nächste Stufe grau), Sperrgrund im Button, Käufe mit Rahmen-Button; Infos und „Hinfahren“ in der Titelzeile; runder Schließen-Button in allen Fenstern; Layout-Test: alle Orte ohne Scrollen auf den 3 echten Geräteklassen (Grenzfall/Studio erst mit G4.6) (344/344 Tests grün) (neu `scripts/ui/activity_tile.gd`, `windows/location_window.gd`, `activity_text.gd`)
- [x] G4.5b Lesbarkeit der Kacheln: Kachel-Buttons sichtbar 56 px, Tippfläche 84 px (reicht unsichtbar über die Hinweiszeile); Lesetext in Kacheln und Ortsfenster ≥ 21 px (≈ 11 pt), Kachel-Namen 23 px; Wirkungen höchstens 2 Zeilen, alle als Symbol + Zahl; kürzere Namen „Community-Q&A“, „Merch zeigen“; Konflikt-Hinweis „⚠ Verpasst: 14:00“; Tests für Tippfläche, Mindestschrift, nichts abgeschnitten (344/344 Tests grün)
- [x] G4.6 Reiter statt Scrollen: Pflichtfeld "tab" (alltag, content, geschaeft, unterwelt) in Aktivitäten, Formaten, Ausrüstung, Unternehmensarten, vom Loader geprüft; Reiter nur, wenn die Kacheln eines Orts nicht ohne Scrollen passen (gemessen), in der Titelzeile, leere Reiter fehlen, Fenster öffnet auf dem ersten; Tippfläche 84 px, Schrift 21 px; heute nur Studio im „Grenzfall“; Test-Ort mit 15 Aktivitäten in 3 Reitern; Layout-Tests ohne Ausnahmen (352/352 Tests grün)
- [x] G4.7 Layout-Tests aufgeräumt, ohne Ausnahmen: neuer Test (`tests/test_touch_and_fonts.gd`) prüft auf allen 4 Geräteklassen JEDEN sichtbaren Button (Karte, HUD-Leiste, runde Buttons, alle Fenster inkl. jedes Reiters und des Ereignis-Fensters): Tippfläche ≥ 84 px, Lesetext ≥ 21 px, Mini-Beschriftungen ≥ 19 px, nichts abgeschnitten; zu klein waren Kartenschilder (64 px), Buchungen-Filter (64 px) und alle Mini-Beschriftungen (15 px) – jetzt unsichtbar größere Tippflächen bzw. 19 px; Spalten so breit wie ihre Beschriftung; HUD-Leiste voll deckend; Ortsfenster in voller Breite (Entscheidung 049) (355/355 Tests grün)

Für den nächsten iPhone-Build (sammeln, kein eigener Test-Termin):
- [ ] Dynamic Island liegt links, App dreht beim Umdrehen des iPhones NICHT mit (G4.2)
- [ ] Rechter Rand: Wie viel Abstand hält die Bedienung rechts ein (gleich wie links = iOS meldet die Safe Area symmetrisch)? Nichts in den abgerundeten Ecken (G4.2)
- [ ] Startbild: Springt der Schriftzug beim Übergang vom iOS-Launch-Screen zum Godot-Startbild in der Größe? (G3.3)
- [ ] App-Symbol auf dem Homescreen gut erkennbar, auch in der Suche/Einstellungen (G3.2)
- [ ] Schrift in Kacheln, Seitenbuttons und Leiste gut lesbar? (G4.5b, G4.7)
- [ ] Kacheln und Reiter gut tippbar? (G4.5b, G4.6, G4.7)
- [ ] Kein schwarzer Bildschirm mehr beim Start? Ladebildschirm flüssig? Dazu in der Xcode-Konsole die Zeilen „[Start] … ms“ ablesen und mir schicken (G5.1b)
- [ ] Vibration spürbar? Nicht zu oft (z. B. bei jeder Miete, mehreren Warnungen hintereinander)? Schalter „Vibration“ aus → keine (G5.9)
- [ ] „[Start]“-Zeilen bis zum ersten Kartenbild schicken: einmal „Fortsetzen“ tippen, dann alle Zeilen bis „Stadtkarte: Bild … gezeichnet“ mit einem Wert unter 50 ms (G5.1c)

### G5 – Hinweise und Komfort ✅ (22.10.2026)
- [x] G5.1 Dauerhafte Geräte-Einstellungen (`user://settings.cfg`, `scripts/core/settings.gd`): Schalter „Kalender bei Tagesbeginn automatisch öffnen“ und „Vibration“ (beide an), robust bei fehlender/kaputter Datei, atomar geschrieben, „Spielstand löschen“ lässt sie stehen; Einstellungsseite mit großen Schaltern (Tippfläche 84 px, Schrift 24 px) (362/362 Tests grün)
- [x] G5.1b Ladebildschirm statt schwarzem Bildschirm: neue erste Szene `scenes/boot/loading.tscn` (Kamera-Sucher, „● REC“, Aufnahmeleiste mit echtem Fortschritt aus 4 Schritten: App-Szene im Hintergrund, Spieldaten, Kartengrafiken im Hintergrund, Spielstand-Kopf), Blende aus dem „Halben Objektiv“ bei 100 %, Fehlermeldung statt Hänger, Zeitstempel „[Start] …“ im Log (366/366 Tests grün)
- [x] G5.1c Schwarze Phase finden und abdecken: „[Start]“-Zeilen bis zum ersten Kartenbild (Hauptmenü, Tipp, Spielstand geladen, Spielbildschirm, Bildzeiten bis < 50 ms); App (Hauptmenü) und ein Probe-Spielbildschirm mit Karte werden verdeckt unter dem Ladebildschirm aufgebaut und gezeichnet, Kartenatlas wird geteilt statt je Karte neu gepackt; keine Mindestdauer – der Ladebildschirm verschwindet so schnell wie möglich (Entscheidung Game Director) (367/367 Tests grün)
- [x] G5.2 „Termine“ wird „Kalender“: Tagesplan als Zeitstrahl für heute (Termine mit Uhrzeit, Ort, Fahrzeit; Fristen des Tages und überfällige offene Fristen; Vergangenes grau, der nächste Termin hervorgehoben, Jetzt-Linie, Hinweis auf den nächsten späteren Termin); Daten aus `scripts/core/day_plan.gd`, Fenster `windows/calendar_window.gd` ersetzt `appointments_window.gd` (374/374 Tests grün)
- [x] G5.3 Kalender öffnet sich bei Tagesbeginn genau einmal (abschaltbar, auch über übersprungene Tage nur einmal); Reihenfolge Ereignis → Kalender; `DayStartSystem`; Spielstand Version 13 + Migration + Testdatei v13 (381/381 Tests + 3/3 lange grün)
- [x] G5.4 Konflikt-Popup statt „zweimal tippen“ (Aktion mit Ende, alle betroffenen Termine mit Uhrzeit, Ort und Kosten, „Trotzdem starten“/„Abbrechen“) für Aktivitäten, Content, Fahrten, Gründung, Filiale und Termine (nutzt `AppointmentSystem.get_conflicts`) (385/385 Tests grün)
- [x] G5.5 Aktion „Warten bis Terminbeginn“ (über das TimeSystem, `AppointmentSystem.wait_until_start`): „Warten bis 14:00“ im Kalender (gesperrt mit Grund, z. B. „Erst hinfahren: Studio“) und vor Ort im Ortsfenster, danach „Wahrnehmen“; kostet nichts, Ereignisse in der Wartezeit genau einmal – die Kachel-Vorschau „Ende HH:MM“ + Wirkungen kam schon mit G4.5 (393/393 Tests grün)
- [x] G5.6 Erinnerung ≤ 30 Spielminuten vor einem Termin (Termin, Ort, Fahrzeit, „Du schaffst es noch“/„Du kommst zu spät“, „Hinfahren“/„Warten“/„Später“), genau einmal je Termin, Reihenfolge Ereignis → Kalender → Erinnerung (`ReminderSystem`); Spielstand Version 14 + Migration + Testdatei (406/406 Tests + 3/3 lange Tests grün)
- [x] G5.7 Kombi-Button „Hinfahren und starten“ (`TripSystem`: Fahrt + Aktion über die normalen Systeme, Prüfung bei Ankunft – Firma/Geld/Energie/Öffnungszeiten vor „Nur vor Ort“; Konflikt-Popup mit Gesamtzeit; scheitert die Aktion nach der Fahrt, ist man angekommen) für Aktivitäten, Content, Gründung, Filiale – Käufe nur vor Ort; Kachel mit Auto „20 min + 2 h“ und „Ende HH:MM“; „Hinfahren“ mit Auto und eigenem Stil (Rahmen statt Akzent-Fläche) (419/419 Tests grün)
- [x] G5.8 Rote Zählerpunkte mit Zahl (Kalender: Termine heute, die noch kommen – `DayPlan.count_upcoming_today`; Fristen: offene – `ObligationSystem.count_open`; „9+“ ab 10; Ereignisse ohne Punkt, sie öffnen sofort ihr Fenster); Balken für Energie und Stimmung unter 40 gelb, unter 20 rot (`PlayerStats.level_of`), Stimmung normal blau (427/427 Tests grün)
- [x] G5.9 Vibration (`Input.vibrate_handheld`, 60 ms) bei Konflikt-Popup, Erinnerung, Termin verpasst, neuer fälliger Frist/Mahnung, Ereignis und Geldänderungen ab ±100 € (ohne Umbuchungen), nur mit Schalter, höchstens einmal je 1,5 s, nicht beim Laden (`scripts/core/haptics.gd`, liest Geld über `LedgerSystem.entry_posted`); am Mac nichts spürbar – Wirkung nur auf dem iPhone prüfbar (435/435 Tests grün)

### T – Tutorial-System ✅ (23.10.2026)
- [x] T.1 Datenformat `data/tutorials/tutorials.json` (id, mechanic, trigger, title, text, ui_target, order, requires) + Modell `scripts/models/tutorial_definition.gd` + Katalog `scripts/systems/tutorial_catalog.gd` mit Prüfung (fehlende/unbekannte Felder, doppelte IDs, unbekannter Auslöser aus fester Liste, unbekannte/eigene/doppelte `requires`, Zyklen, Text ≤ 240 Zeichen) – alles oder nichts; 3 Platzhalter (Karte, Gebäude antippen, Hinfahren) (441/441 Tests grün)
- [x] T.2 TutorialSystem (`scripts/systems/tutorial_system.gd`): Auslöser melden (Spielansicht: Spielstart, Ort öffnen, Ort aus der Ferne, Kalender, Erinnerung; Systeme: Ereignis, fällige Frist), fällig = Auslöser gemeldet + nicht gesehen + `requires` gesehen, nach `order`; gesehen erst mit `mark_seen`, bis dahin fällig auch nach Laden; kostet keine Spielzeit; Spielstand Version 15 + Migration (Spielstart-Tutorials gelten als gesehen) + Testdatei v15; noch keine Anzeige (451/451 Tests + 3/3 lange Tests grün)
- [x] T.3 Anzeige (`scripts/ui/tutorial_overlay.gd`): abdunkeln, Ziel (`ui_target` = Knotenname) ausgespart mit pulsierendem Rahmen und Pfeil, Sprechblase (Titel, Text, „Verstanden“) in der Safe Area ohne das Ziel zu verdecken; ohne/fehlendes Ziel mittig (Warnung im Log); „Verstanden“ → `mark_seen`, dann das nächste; Reihenfolge Ereignis → Kalender → Erinnerung → Tutorial, über dem Ortsfenster erlaubt; darunter nichts tippbar; fester Starthinweis „Tippe auf ein Gebäude …“ entfällt (459/459 Tests grün)
- [x] T.4 Einstellungen: Schalter „Tutorials anzeigen“ (Gerät, Standard an; aus = keine Anzeige, fällige bleiben fällig) und „Tutorials zurücksetzen“ (mit Rückfrage, `TutorialSystem.reset_seen()` im aktuellen Spielstand); Seite in Zeilen umgebaut, damit sie ins Querformat passt; neuer Bildschirm „Hilfe / Lexikon“ (`scripts/ui/lexicon_screen.gd`, über die Einstellungen): nur gesehene Tutorials, nach Bereich, Antippen klappt den Text auf; kein neues Spielstand-Format (467/467 Tests grün)
- [x] T.5 Texte Grundlagen: 13 Tutorials (Karte, Karte bewegen, Orte antippen, Kacheln, Hinfahren, Hinfahren und starten, Energie/Stimmung, Kalender, Erinnerung, Konflikt, Warten, Ereignisse, Speichern), zum Start höchstens 2; 6 neue Auslöser; `ui_target` mit „*“; Test jedes Tutorials auf 4 Geräteklassen. Korrekturen: Tutorial darf über dem Fenster liegen, das es erklärt (DECISIONS 063); Lexikon mit festem Schließen-Button und in Spielreihenfolge; Einstellungs-Buttons: Löschen mit rotem Rahmen, Zurück/Zurücksetzen grau (474/474 Tests grün)
- [x] T.6 Texte Karriere und Firma: 10 Tutorials (Kanal, Content und Qualität, Ausrüstung, Wirkungs-Symbole, Firma gründen, Privat und Firma, Ladenlokal, Tagesabschluss, Fristen, Buchungen), 9 neue Auslöser; höchstens 3 Tutorials hintereinander; ein Tutorial wartet, bis sein Ziel sichtbar ist; Test jedes Tutorials auf 4 Geräteklassen (476/476 Tests grün)
- [x] T.6b Ortsbeschreibung: Tipp auf den Ortsnamen im Ortsfenster öffnet eine Info-Blase (Tippfläche ≥ 84 px, 24 px Schrift, Safe Area, Tipp irgendwo schließt); Tooltip entfernt; Hinweis im Tutorial „Aktivitäten“
- [x] T.7 Feste Mechanik-Liste `scripts/models/mechanics.gd` (23 IDs); Abdeckungstest `tests/test_tutorial_coverage.gd` (jede Mechanik hat ein Tutorial, jedes Tutorial eine bekannte Mechanik, jeder Auslöser wird im Spielcode gemeldet und genutzt); Layout jedes Tutorials auf 4 Geräteklassen (seit T.5/T.6 in `test_tutorial_texts.gd`); Regel in `CLAUDE.md`; Test-Runner schützt echten Spielstand und Einstellungen (481/481 Tests grün)

### U – Unterwelt (Hauptspiel; jedes Ticket mit Tutorial, Daten unter `data/underworld/`)
- [x] U.1 Schwarzgeld als drittes Konto „black“ im einen Ledger (keine Umbuchung von/zu Schwarzgeld), HUD-Block „Schwarz“ und Buchungen-Fenster (Stand, Filter, Wochenübersicht) erst, wenn es welches gibt; HUD-Leiste verdichtet sich bei Platzmangel stufenweise; Tutorial „Schwarzgeld“ (Mechanik `black_money`); Spielstand Version 16 + Migration + Testdatei (488/488 Tests + 3/3 lange Tests grün)
- [x] U.2 Organisation (`scripts/systems/organisation_system.gd`, Regeln `data/underworld/organisation.json`): Name, Respekt, Hitze, Stabilität 0–100, gegründet erst ab U.3; Hitze sinkt an ruhigen Tagen um 3 (Schritt im DayCycle nach dem Tagesabschluss); HUD „Flamme + Zahl“ (ab 30 gelb, ab 60 rot); Tutorial „Hitze“ (Mechanik `heat`); Spielstand Version 17 + Migration + Testdatei; iPhone SE aus den Geräteklassen entfernt (498/498 Tests + 3/3 lange Tests grün)
- [x] U.3 Einstiegs-Ereignis „Liegeplatz 14“ (El Capitán, Puerto Banús) ab Tag 2 über den Tageswechsel (ein Code-Pfad für neue und alte Spielstände; Ereignisse mit Auslöser „scripted“), „Zuhören“ → Namenseingabe (nicht schließbar) → Organisation gegründet, „Nicht heute“ → nach 2 Tagen wieder; Fenster „Organisation“ + Seitenbutton (Geschäft); Tutorial „Deine Organisation“; Ereignis-Optionen mit `note`; Spielstand Version 18 + Migration + Testdatei; Grenzfall-Gerät gestrichen (510/510 Tests + 3/3 lange Tests grün)
- [x] U.4 Story-Aufträge als Datenkette (`data/underworld/missions.json`, `MissionCatalog`, `MissionSystem`): aktiv, sobald Organisation + Voraussetzungen; Ziel „visit_location“; Belohnung als Organisationswerte; Fenster „Aufträge“ + Button mit rotem Punkt (Neues/Erledigtes); Kapitel „Erster Deal“, Auftrag 1 „Treffen am Hafen“ (Café am Hafen, Respekt +5) – die weiteren Schritte (Ware, Versteck, Verkauf) folgen mit U.6/U.8/U.9; Tutorial „Aufträge“; Spielstand Version 19 + Migration + Testdatei (520/520 Tests + 3/3 lange Tests grün)
- [x] U.5 Produkte als Daten (`data/underworld/products.json`, `ProductCatalog`, in `GameData.products`): Gras, Haschisch, Pillen, Koks mit Einkaufs-/Verkaufspreis je abstrakter Einheit, Qualität, Hitze je Einheit – nur Spielwerte, vorläufig; noch ohne Anzeige (Tutorial zur Ware mit U.6), Nachfrage je Gebiet mit U.12 (523/523 Tests + 3/3 lange Tests grün)
- [x] U.6 Erfundener Lieferant „El Rubio“ (`data/underworld/suppliers.json`, `SupplySystem`): erreichbar nach „Treffen am Hafen“ über „Organisation“; Einkauf auf Vorkasse als Buchung (Schwarzgeld, wenn es reicht, sonst Privatkonto); Lieferung am nächsten Morgen (Schritt im DayCycle), platzt mit 15 % (Seed, deterministisch); Bestand; Auftrag „Die erste Ware“; Tutorials „Die Ware“ und „Vorkasse“; Rückmeldung liegt jetzt über offenen Fenstern; Spielstand Version 20 + Migration + Testdatei (537/537 Tests + 3/3 lange Tests grün)
- [x] U.7 Lieferant auf Kredit (nach einer angekommenen Lieferung, +25 %, fällig nach 3 Tagen, eine laufende Schuld je Lieferant): Schulden werden am Fälligkeitstag einmalige Fristen im ObligationSystem (Schwarzgeld, ersatzweise Privatkonto; Mahnaufschlag 10 % nach 1 Tag); platzt die Lieferung, entfällt die Schuld; überfällig → Druck-Ereignis „Besuch“ alle 2 Tage (Folgen für Stimmung/Organisation); Ereignis-Optionen mit Organisations-Folgen; Tutorial-Ziele werden ins Bild gescrollt; Tutorial „Auf Kredit“; Spielstand Version 21 + Migration + Testdatei (547/547 Tests + 3/3 lange Tests grün)
- [x] U.8 Standorte als Daten (`data/underworld/sites.json`, `SiteCatalog`, `SiteSystem`; Felder nach Leitfaden 9.3); erstes Versteck „Garage in San Pedro“ als neuer Ort (unbekannt bis „Die erste Ware“, dann auf der Karte, Kenney-Gebäude); vor Ort anmieten (300 €, 30 min), laufende Kosten 20 €/Tag (Schwarzgeld, ersatzweise privat, sonst Frist); Kapazität (20 ohne Versteck, +100) begrenzt Bestellungen; Auftrag „Ein sicherer Ort“; Tutorial „Ein Versteck“; Spielstand Version 22 + Migration + Testdatei (559/559 Tests + 3/3 lange Tests grün)
- [x] U.9 Verkaufen als Aktion (Zeit, Schwarzgeld, Hitze) – erster Deal abgeschlossen: Verkaufsorte als Daten (`data/underworld/sale_spots.json`, `SaleSystem`); erster Ort „Kaimauer am Abend“ beim Café am Hafen (ab „Ein sicherer Ort“); Kachel „Ware verkaufen“ (Reiter „Unterwelt“) öffnet das Verkaufsfenster (Ware, Menge 1–10, 1 h Spielzeit, Konflikt-Popup); Einnahme als Schwarzgeld-Buchung, Hitze je Einheit; Auftrag „Der erste Verkauf“ (5 Einheiten, Respekt +10) schließt das Kapitel „Erster Deal“; Tutorial „Verkaufen“; Spielstand Version 23 + Migration + Testdatei (569/569 Tests + 3/3 lange Tests grün)
- [x] U.10 Crew 1: Rollen als Daten (`data/underworld/crew.json`, `CrewSystem`: Dealer, Läufer, Fahrer, Schutz mit Lohnspanne), täglich 3 Bewerber aus Seed und Tag (Können/Loyalität/Gier 20–80, Lohn wächst mit Können), einstellen/feuern sofort im Fenster „Crew“ (Button unter „Organisation“, ab „Der erste Verkauf“, höchstens 6 Leute), Löhne als eine Buchung im Tageswechsel (Schwarzgeld, ersatzweise privat, sonst Frist); Auftrag „Der erste Dealer“ (Kapitel „Die Crew“); Tutorial „Deine Crew“; Spielstand Version 24 + Migration + Testdatei (581/581 Tests + 3/3 lange Tests grün)
- [ ] U.11 Crew 2: Dealer verkaufen täglich (Unterwelt-Abrechnung im DayCycle), Können/Loyalität/Gier, befördern
- [ ] U.12 Gebiete als Daten (Viertel mit Nachfrage, Polizeipräsenz, Rivaleneinfluss) + Karten-Overlay, ein- und ausschaltbar per Schalter auf der Karte
- [ ] U.13 Gebiete übernehmen, halten, verlieren
- [ ] U.14 2–3 erfundene Rivalen-Gangs: Stärke, Aggression, Gebiete; Konflikt, Verhandlung, Waffenstillstand (Gewalt nur als Text und Folgen)
- [ ] U.15 Crew-Folgen: Verhaftung, Verrat, Spitzel, Abwerbung (Ereignisse)
- [ ] U.16 Waschen über Tarnfirmen als reine Spielmechanik (Gebühr %, Tageslimit, Risiko) – Merch-Label
- [ ] U.17 Schwarzgeld ausgeben: eingeschränkt bzw. erhöht Hitze
- [ ] U.18 Weitere Standorte: Verkaufspunkt, Lager, Club (auch Tarnfirma), Produktion („X Einheiten/Tag“), Liegeplatz am Hafen; ausbauen
- [ ] U.19 Polizei 1: Beobachtung → Ermittlung nach Hitze, verbunden mit den Behördenereignissen aus Phase 5
- [ ] U.20 Polizei 2: Razzia (Folgen für Standorte, Bestand, Schwarzgeld – als Buchung)
- [ ] U.21 Justiz: Festnahme, Optionen (Anwalt, Bestechung, stillhalten, Crew opfern, kooperieren), Kaution, Prozess, Haft als Spieltage mit Weiterspielen (kein Game Over)
- [ ] U.22 Doppelleben: Kanal senkt Hitze-Anstieg leicht, Bekanntheit erhöht Aufmerksamkeit, Ereignisse Paparazzi/Leak/Gerüchte/Skandal
- [ ] U.23 Beziehungen: Kontakt am Hafen, Partner/in, bestechlicher Beamter als Daten mit Vertrauen/Wissen und Ereignissen
- [ ] U.24 Tageswechsel komplett (Abrechnung → Hitze → Fristen → Ereignisse → Kalender), Bot und lange Tests um die Unterwelt erweitern
- [ ] U.25 HUD und Seitenbuttons final, Abnahme Paket U

## Spätere Phasen
8. Balancing und mehr Inhalte: Verhältnis Kanal-/Unterwelt-Einnahmen, evtl. „harter Modus“ mit Game Over, weitere Figuren (bester Freund, Manager)
