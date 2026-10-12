# Entscheidungen

## 001 – Renderer: GL Compatibility
Für eine 2D-Management-UI auf dem iPhone ist der Compatibility-Renderer die einfachste und robusteste Wahl.
Keine aufwendigen Effekte nötig. Kann später geändert werden, falls es einen konkreten Grund gibt.

## 002 – Hochformat, 720×1280 Basisauflösung (abgelöst durch 020)
`display/window/handheld/orientation = portrait`, Stretch-Modus `canvas_items` mit Aspect `expand`,
damit sich die UI an verschiedene iPhone-Seitenverhältnisse anpasst. Die Editor-Fenstergröße ist auf
405×720 verkleinert, damit das Testfenster auf den Mac-Bildschirm passt.

## 003 – Godot-Version
Festgelegt auf **Godot 4.7.2.stable** (Standard-Version, nicht .NET), bestätigt über „Über Godot“ und installierte iOS-Exportvorlagen.
Xcode 27.0. Nicht mitten in einer Phase aktualisieren.

## 004 – Systeme als RefCounted, eigener Test-Runner
Spielsysteme sind `RefCounted`-Klassen statt Autoloads, damit sie ohne Szene testbar sind und es
keine versteckten globalen Zustände gibt. Tests laufen mit einem eigenen kleinen Runner
(`tests/run_tests.gd`) statt eines Addons wie GUT – keine zusätzliche Abhängigkeit.

## 005 – UI im Code statt handgeschriebener Szenen
Bildschirme werden in GDScript aus Containern aufgebaut, nur die Hauptszene ist eine `.tscn`.
Grund: Ohne Editor in der Entwicklungsumgebung sind handgeschriebene Szenendateien fehleranfällig;
Code ist prüfbar und per Test durchklickbar. Kann später für einzelne Bildschirme geändert werden.

## 006 – Spielstand als JSON mit Backup
Ein Spielstand, lokal unter `user://savegame.json`, als lesbares JSON mit Versionsnummer.
Atomar über `.tmp` + Umbenennen, der vorherige Stand bleibt als `.bak`. Kein Cloud-Sync.
JSON statt Godot-Ressourcen, weil es lesbar, robust gegen Code-Änderungen und leicht zu prüfen ist.
Mehrere Spielstände sind (noch) nicht vorgesehen.

## 007 – Karte und Reisezeit
Kartenpositionen sind 0–1; die Karte steht für 8 km × 8 km (`LocationSystem.MAP_SIZE_KM`).
Entfernung = Luftlinie, gerundet auf 100 m; danach wird nur mit ganzen Zahlen gerechnet, damit
Reisezeiten auf jedem Gerät identisch sind. Fahrten kosten (noch) kein Geld und keine Energie.
Fahren ist jederzeit möglich, auch zu geschlossenen Orten; Aktivitäten dort sind dann gesperrt.

## 008 – Öffnungszeiten
Volle Stunden, `open < close ≤ 24`, keine Öffnung über Mitternacht. Eine Aktivität muss im Öffnungsfenster
beginnen und bis Ladenschluss enden. Orte ohne `opening_hours` sind immer geöffnet.

## 009 – Termine
Wahrnehmen nur vor Ort, frühestens 1 h vor Beginn, spätestens zum Beginn; wer früher da ist, wartet bis
zum Beginn. Nach Beginn gilt ein Termin beim nächsten Zeitfortschritt als verpasst (Strafe genau einmal,
gespeichert). Jeder Termin braucht in den Daten einen negativen `missed_effects.mood`.
Kollision = eine Aktion würde über den Beginn eines offenen Termins hinauslaufen → Warnung, zweiter Tipp
führt aus. Termine vor `since_minutes` (Spielbeginn bzw. Migration) entfallen ohne Strafe – so bestraft die
Migration eines alten Spielstands keine Termine, die es damals noch nicht gab.

## 010 – Migration Version 1 → 2
Ein Spielstand aus Phase 1 beginnt in der Wohnung; `since_minutes` = gespeicherte Spielzeit.
Ein gespeicherter Ort, den es in den Daten nicht mehr gibt, fällt auf die Wohnung zurück statt den
Spielstand abzulehnen.

## 011 – Grafiken und isometrische Karte (G1)
Kenney „Isometric Tiles“ City, Buildings und Vehicles (CC0, kenney.nl): gleicher Stil und gleiche Kachelgröße,
Gebäude aus Etagen frei kombinierbar. „Isometric Roads“ (mit Strandkacheln) passt im Stil nicht dazu;
Strand und Meer werden deshalb als Flächen gezeichnet. Nur benutzte PNGs plus `License.txt` liegen im Repo.
Das Straßennetz ist ein festes Raster (`city_layout.gd`); Orte werden aus `map_position` auf das nächste freie
Grundstück an einer Straße gesetzt – neue Orte brauchen also keine Kartenarbeit. Das Aussehen der Gebäude je
Orts-ID steht als Tabelle in `city_map.gd` (Darstellung, keine Spielregel; unbekannte IDs bekommen ein Standardhaus).
Reisezeit und Entfernung bleiben Luftlinie aus dem LocationSystem; die Fahrstrecke auf der Karte ist nur Optik.
Die Fahranimation läuft erst nach der Buchung der Fahrzeit und ändert keinen Spielzustand.
Wischen auf der Karte verschiebt nur die Karte (Variante 1 des Game Directors); die Seite scrollt außerhalb.

## 012 – Kanalprofil und Wachstumsbremse
Reichweite ist eine Followerzahl (Entscheidung des Game Directors), Community-Stimmung und Ruf sind 0–100.
Wachstumsbremse: Follower-Zuwächse × (1.000.000 − aktuell) / 1.000.000, kaufmännisch gerundet; harte Grenze
1.000.000. Damit flacht Wachstum ab (logistisch, sobald Zuwächse mit der Reichweite steigen) und endet am Maximum.
Verluste wirken ungebremst. Jede Änderung ist ein Protokolleintrag mit gewünschter und tatsächlicher Änderung,
Quelle und Begründung – so kann die UI erklären, warum sich ein Wert geändert hat. Gespeichert werden die
letzten 200 Einträge; IDs zählen weiter. Optionaler Schutzschlüssel gegen doppelte Anwendung wie im Ledger.
Startwerte (120 Follower, 50, 50) sind Platzhalter fürs Balancing (Phase 8).

## 013 – Content-Formate exakt berechnet
Zufall nur bei Ereignissen (Entscheidung des Game Directors); Content-Ergebnisse sind exakt und werden vor dem
Produzieren angezeigt. Qualität = 100 % + Ausrüstung (014) + (Community − 50) / 2, mindestens 10 %.
Follower-Zuwachs und Einnahme haben einen Grundwert plus einen Anteil je 1.000 Follower, beides × Qualität;
der Follower-Anteil wächst also mit der Reichweite, die Wachstumsbremse (012) begrenzt ihn. Community und Ruf
ändern sich um feste Werte des Formats. Ganzzahlig, abgerundet. Ein Livestream bringt zu Spielbeginn exakt
25,00 € wie früher der „Kurze Stream“. Das ContentSystem hat keinen eigenen Spielstand: Der Schutzschlüssel
`content:<format>:<startminute>` ist eindeutig, weil jede Produktion Zeit kostet.
Formate sind eigene Daten (nicht Aktivitäten), weil sie zusätzlich Kanal und reichweitenabhängige Einnahmen haben.

## 014 – Ausrüstung
Drei Teile (Kamera, Mikrofon, Licht) mit je drei Stufen, Kauf nur im Studio und nur Stufe für Stufe, ohne
Spielzeit. Der Qualitätsbonus gilt für die erreichte Stufe (nicht aufsummiert) und nur für die Formate des Teils.
Jede Stufe wird höchstens einmal bezahlt (Schutzschlüssel `equipment:<id>:<stufe>`). Kein Verschleiß, kein
Wiederverkauf. Preise und Boni sind Platzhalter fürs Balancing. Fehlt ein Teil später in den Daten, wird es beim
Laden ignoriert; eine zu hohe Stufe wird auf das Maximum gesetzt, statt den Spielstand abzulehnen.

## 015 – Zufallsereignisse mit festem Seed
Gewürfelt wird nur beim Tageswechsel (`day_changed`), nicht pro Aktion – so hängt der Verlauf nicht davon ab,
wie man den Tag in Aktionen aufteilt. Wurf = FNV-1a 32 Bit von "<seed>|<tag>|<id>" modulo 100: zustandslos,
plattformunabhängig, selbst implementiert (nicht `String.hash()`, das sich mit der Engine ändern könnte).
Gespeichert wird nur der Seed; Abklingzeit und Anzahl ergeben sich aus den ausgelösten Instanzen (`<id>@<tag>`).
Höchstens ein Zufallsereignis pro Tag (Priorität, dann ID), damit es nicht stapelt. Alle Zufallsereignisse
frühestens ab Tag 3 – die ersten Tage bleiben ruhig. Neues Spiel: zufälliger Seed; alte Spielstände: Seed 1.
Prozentuale Follower-Änderungen werden beim Entscheiden vom aktuellen Stand berechnet; Zuwächse laufen durch
die Wachstumsbremse. Bedingungen prüfen den Kanal zum Zeitpunkt des Würfelns.

## 016 – Konten im einen Ledger
Privat- und Firmenkonto liegen im selben LedgerSystem (Entscheidung des Game Directors): jede Buchung hat ein
Feld `account`, Kontostände und Überziehungsschutz gelten je Konto, Buchungs-IDs und Schutzschlüssel sind
gemeinsam. Bestehende Aufrufe buchen ohne Angabe auf das Privatkonto. Umbuchung = genau zwei Buchungen
(Kategorie `transfer`, gemeinsame Referenz = Schlüssel, Schutzschlüssel `<schlüssel>|out` und `<schlüssel>|in`);
alles wird vorher geprüft, danach können beide Hälften nicht mehr scheitern. Beim Laden wird abgelehnt, wenn
von einer Umbuchung nur eine Hälfte da ist. `|` statt `:`, weil `:` und `@` in anderen Schlüsseln vorkommen
und z. B. ein Ereignis mit der ID `in` sonst wie eine Umbuchungshälfte aussähe.
Migration auf Version 6: alter Startwert wird Startwert des Privatkontos, Firmenkonto beginnt bei 0, alle
bisherigen Buchungen gehören zum Privatkonto.

## 017 – Unternehmen gründen
Das Merch-Label wird im Büro (Coworking) gegründet und verkauft zunächst online; die Filiale (Ticket 4.4) ist der
physische zweite Standort. Gründung kostet Spielzeit (1 h), eine Gebühr vom Privatkonto und eine Mindesteinlage
(Umbuchung). Es gibt höchstens ein Unternehmen. Auslastung und Ruf des Unternehmens sind 0–100 und ändern sich
nur mit Begründung im Unternehmens-Protokoll (gleiches Eintragsmodell wie das Kanal-Protokoll). Einlage und
Entnahme kosten keine Spielzeit; ihre Schutzschlüssel zählen fortlaufend (Zähler im Spielstand), damit jede
Umbuchung eindeutig ist. Alle Zahlen sind Platzhalter fürs Balancing.

## 018 – Tagesabschluss
Abgerechnet wird der Vortag beim Tageswechsel (`day_changed`) – kein Zeitfortschritt im Hintergrund, der Gründungstag
zählt als erster (Teil-)Tag. Umsatz = (Grundumsatz + Follower × Anteil / 1000) × Auslastung % × (100 + (Ruf − 50) / 2) %,
ganzzahlig abgerundet; Fixkosten fest je Art. Das Firmenkonto wird nie negativ (Entscheidung des Game Directors):
reicht es nicht, entfallen die Fixkosten dieses Tages und der Ruf des Unternehmens sinkt (Platzhalter: 5). Ohne Pflege
sinkt die Auslastung täglich (Platzhalter: 3); Pflege vor Ort kommt mit Ticket 4.4. Zeitstempel der Buchungen ist der
Zeitpunkt der Abrechnung (Ende des Zeitfortschritts), wie bei Ereignissen. Jeder Tag höchstens einmal
(`last_settled_day` + Schutzschlüssel `company:day:<tag>:…`). Migration von Version 7: frühere Tage werden nicht
nachträglich abgerechnet. Zu Spielbeginn macht das Label ohne Pflege leicht Verlust (Platzhalterzahlen, Phase 8).

## 019 – Zweiter Standort und Management
Der zweite Standort ist ein neuer Ort „Ladenlokal“ an der Promenade (Entscheidung 2a). Er ist von Anfang an auf
der Karte; die Filiale „Merch-Laden“ wird dort eröffnet (Kosten vom Firmenkonto, Spielzeit) und bringt danach
eigenen Grundumsatz und eigene Fixkosten in den Tagesabschluss – dieselbe Formel, keine Sonderlogik.
Pflege vor Ort sind normale Aktivitäten mit `requires` („company“/„branch“) und `company`-Effekten, damit neue
Management-Aktionen nur Daten brauchen. Die Wirkung steht mit Begründung (Name der Aktivität) im
Unternehmens-Protokoll. „Merch im Stream zeigen“ ist die Verbindung Kanal → Unternehmen (Entscheidung 7).
Gebäude der Filiale: Kenney `buildingTiles_020` (grüne Markise, zur Unterscheidung vom Café mit roter Markise).

## 020 – Querformat, Karte als Hauptbildschirm (G2)
Grundsatzentscheidung des Game Directors (12.10.2026), löst 002 ab: Das Spiel läuft im Querformat (beide Richtungen,
`display/window/handheld/orientation = 4` = Sensor-Querformat), Basisauflösung 1280×720, Stretch `canvas_items`/`expand`.
Die isometrische Stadtkarte ist der Hauptbildschirm im Vollbild (auch unter Notch und Home-Balken); HUD und Buttons
liegen innerhalb der Safe Area. HUD wie in Aufbauspielen: Zeit/Tag/Ort links oben, Geld (privat, Firma), Energie und
Stimmung rechts oben. Icon-Buttons an den Seiten (links Termine, Kanal, Unternehmen; rechts Buchungen, Menü, „Hier“)
öffnen Fenster; Gebäude antippen öffnet das Fenster des Orts (Aktionen sichtbar, aber gesperrt mit Grund, wenn man
woanders ist; „Hinfahren“ oben). Immer nur ein Fenster, mittig, Karte abgedunkelt. Ereignisse als Fenster, die zuerst
entschieden werden müssen. Rückmeldungen als Hinweis unten (ca. 4 s; lange Texte bleiben bis zum Antippen).
Zwei-Finger-Zoom begrenzt auf 0,5–1,0. Icons: Kenney „Game Icons“ und „Game Icons Expansion“ (CC0) mit kurzem Text;
für „Termine“ gibt es kein Kalender-Icon, daher eine Fahne. G2.2 und G2.3 wurden zusammen umgesetzt, damit jeder
Commit spielbar bleibt (ohne Fenster wären Aktivitäten nach dem Vollbild-Umbau nicht erreichbar gewesen). Spiellogik, Daten und
Spielstand bleiben unverändert. Phase-4-Abnahme bleibt offen und wird nach G2 im neuen Layout nachgeholt.

## 021 – Abnahme ohne iPhone, iPhone-Abnahme gesammelt in Phase 7
Korrektur des Game Directors (12.10.2026): Die gemeldeten iPhone-Abnahmen von Phase 3, Phase 4 und G2 haben nicht
stattgefunden; sie sind in der ROADMAP wieder offen. Ab jetzt gilt als Abnahme einer Phase: alle automatischen Tests
grün **und** ein Fensterlauf auf dem Mac (Godot, nicht headless) mit Screenshots, die Claude selbst ansieht und prüft.
Die iPhone-Abnahme (Touch, Safe Area, Ausrichtung, Export) wird gesammelt in Phase 7 (Mobile Politur) nachgeholt;
die Checklisten „Abnahme auf dem iPhone“ bleiben bis dahin offen. Nie eine iPhone- oder Editor-Prüfung als erledigt
eintragen, die nicht gemeldet wurde.

## 022 – Wertstellung und fester Tageswechsel-Ablauf
Tagesabschluss-Buchungen tragen als Buchungszeit das Ende des Zeitfortschritts (z. B. Tag 8, 07:00 nach dem
Schlafen). Für Fristen und Zeiträume wäre das falsch: Der Abschluss von Tag 7 landete in Woche 2. Deshalb hat jede
Buchung zusätzlich `effective_minutes` (Wertstellung; Standard = Buchungszeit, nie in der Zukunft); Tagesabschlüsse
werden auf den abgerechneten Tag, 23:59 gestellt. Fristen und Auswertungen (`LedgerSystem.summarize()`) rechnen nur
mit der Wertstellung; die Buchungszeit zeigt weiter, wann etwas verbucht wurde. Spielwoche = Mo–So (Tag 1 ist Montag).
Umbuchungen zählen nicht als Gewinn/Verlust. Am Tageswechsel ruft der `DayCycle` die Systeme in fester, getesteter
Reihenfolge auf (Tagesabschluss → Fristen → Ereignisse), statt sich auf die Reihenfolge von Signal-Verbindungen zu
verlassen. Migration auf Version 10 trägt die Wertstellung nach (Tagesabschlüsse über ihre Referenz `day:<t>`).

## 023 – Fristen
Entscheidungen des Game Directors (12.10.2026): wöchentliche Fristen, fällig montags 00:00, erste Fälligkeit Tag 8.
Miete Wohnung 80 € und Miete Studio 40 € vom Privatkonto; „Stadtabgabe“ (fiktiv) 15 % vom positiven Ergebnis der
Vorwoche auf dem Firmenkonto (nach Wertstellung, ohne Umbuchungen), nur mit Unternehmen; ohne Gewinn entfällt sie.
Automatisch bezahlt, wenn das Konto reicht (Wertstellung = Fälligkeit); sonst bleibt die Frist offen. Fristen sind
Daten (`data/obligations/`); jede Fälligkeit ist eine Instanz `<frist>@<tag>` und entsteht genau einmal
(`last_processed_day`). Migration auf Version 11: vergangene Wochen werden nicht nachberechnet.
Alles abstrakte Spielwerte – keine realen Steuer- oder Rechtsregeln.

## 024 – Überfällige Fristen und Mahngebühr
Entscheidung des Game Directors: Die Mahngebühr wird nicht sofort gebucht, sondern erhöht den offenen Betrag der
Frist; gebucht wird erst beim Bezahlen, damit kein Konto negativ wird (Regressionstest
`test_reminder_fee_raises_open_amount_without_booking`). Gemahnt wird einmal, sobald eine Frist länger als ihre
Kulanz (2 Tage) nach dem Fälligkeitstag offen ist; Folgen Stimmung −5 (privat) bzw. Ruf des Unternehmens −5 (Firma,
mit Begründung im Unternehmens-Protokoll). Offene Fristen werden nicht später automatisch abgebucht, sondern von Hand
bezahlt – nur mit dem ganzen offenen Betrag. Beim Bezahlen entstehen zwei Buchungen: Grundbetrag (Wertstellung =
Fälligkeit, zählt zur Woche der Frist) und Mahngebühr (Wertstellung = Zahltag). Kein Game Over.

## 025 – Behördenereignisse
Fiktive Ereignisse ohne reale Rechtslogik; Folgen nur als abstrakte Spielwerte (Gebühren, Spielzeit, Stimmung, Ruf).
Sie nutzen die bestehenden Zufallsereignisse (Seed, Abklingzeit, höchstens eins pro Tag) mit neuen Bedingungen:
`min_/max_open_obligations`, `company_founded` (1/0), `min_last_week_profit_cents`. Das feste, regelbasierte Ereignis
„Vollstreckungsankündigung“ (Entscheidung des Game Directors) ist ein Datensatz mit Chance 100 %, Bedingung
≥ 3 offene Fristen, höchster Priorität und 7 Tagen Abklingzeit – dadurch sicher und ohne Sonderlogik. Weil der
DayCycle Fristen vor Ereignissen verarbeitet, zählen am selben Tageswechsel neu offene Fristen schon mit.
Optionen können jetzt `account` (Firmenkonto), `minutes` (Spielzeit, wird nach dem Schließen des Ereignisses
vorgestellt) und `company` (Auslastung/Ruf) haben. Jedes Ereignis braucht mindestens eine Option ohne Kosten, damit es
auch ohne Geld entscheidbar ist (Katalog lehnt es sonst ab).

## 026 – Finanz-UI und Test-Runner
Fristen bekommen einen eigenen Seitenbutton (links, unter „Termine“), rot mit Anzahl bei offenen Fristen; die
Wochenübersicht steht im Buchungen-Fenster statt in einem eigenen Fenster, damit die Seitenleisten nicht überladen
werden. Knotennamen mit Instanz-IDs ersetzen „@“ durch „_“ (Godot erlaubt kein „@“ in Knotennamen).
Der Test-Runner registriert einen Logger (`OS.add_logger`, `ERROR_TYPE_SCRIPT`): Ein Skriptfehler während eines Tests
(z. B. Zugriff auf null) lässt den Test fehlschlagen – vorher zählte er als bestanden, sobald vorher eine Prüfung lief.
Layout-Tests setzen die Bildschirmgröße selbst (headless ist das Fenster nur 64 × 64).
Godot-Läufe immer mit Zeitlimit (`--quit-after` und `timeout`), nachdem ein Fensterlauf hängen geblieben war.

## 027 – Echte Altstände als Testdateien
Entscheidung des Game Directors: Migrationen werden mit echten Spielständen geprüft, nicht mit aus dem heutigen
Format nachgebauten. Für jede Version N wird der Commit, in dem N aktuell war, per `git archive` in einen temporären
Ordner entpackt (kein Worktree, keine Änderung am Repo) und dort mit `tests/fixtures/make_save.gd` headless eine kurze
Spielsitzung gespeichert. Die Dateien liegen in `tests/fixtures/saves/` (je ca. 10 KB). Wer `SAVE_VERSION` erhöht,
legt eine Testdatei der neuen Version an – ein Test verlangt sie. Migrationen sind Einzelschritte n → n + 1
(`SaveSystem._run_migration()`). In Version 1 hieß der Aufruf noch `GameState.new(Kataloge)`; der Erzeuger kennt das.
Die normale Testsuite soll schnell bleiben (Ziel < 1 Minute, derzeit ~1 s); lange Läufe kommen in 6.4 getrennt.

## 028 – Robustes Speichern
Entscheidungen des Game Directors: 3 rotierende Backups; eine liegengebliebene `.tmp` (abgebrochenes Speichern) wird
nur übernommen, wenn sie vollständig lesbar ist und alle Prüfungen besteht – dann wird das Speichern zu Ende geführt;
sonst wird sie wie ein defekter Stand aufbewahrt (`test_half_written_tmp_is_ignored_and_kept`). Defekte Dateien
(Hauptdatei, Backup, .tmp) werden als `<name>.corrupt-<zeit>.json` aufbewahrt (höchstens 3, Zeit auf Mikrosekunden,
damit die Reihenfolge stimmt) und aus der Rotation genommen, damit sie nie ein gutes Backup verdrängen. Dateien einer
neueren Spielversion bleiben unberührt. Backups rotieren nur, wenn eine Hauptdatei existiert.
Der Kopf `meta` (App-Version, Speicherzeit, Spieltag, Uhrzeit, Privatkonto, Datenkennung = MD5 der Datendateien) ist
optional und wird beim Laden nicht gebraucht – deshalb keine neue Formatversion. Gespeichert wird nie während eines
Zeitfortschritts.

## 029 – Konsistenz und entfernte Daten
Entscheidungen des Game Directors: Daten, die es nicht mehr gibt, führen nicht zur Ablehnung, sondern zu einem Hinweis
beim Laden (Ort → Startort, Ausrüstung entfällt, Unternehmen ohne Art bleibt mit Werten und Konto, rechnet aber nicht
mehr ab – ohne Rückstau, wenn die Art zurückkommt; offene Frist ohne Definition bleibt offen und bezahlbar; offenes
Ereignis ohne Daten entfällt ohne Folgen). Abgelehnt (und das nächste Backup versucht) wird nur, was Geld, Zeit oder
Schutzschlüssel unstimmig macht: `ConsistencyCheck` prüft nach dem Laden über System-Grenzen (Zeitstempel ≤ Spielzeit,
Buchungsnummern, Schutzschlüssel → vorhandene Buchung, Einlage-/Entnahme-Zähler ↔ Umbuchungen, bezahlte Fristen
gebucht und offene nicht, Tagesabschluss/Fristen nicht in der Zukunft). Damit offene Fristen ohne Definition bezahlbar
bleiben, speichern Frist-Instanzen Konto, Kategorie und Bezeichnung – Formatversion 12 (erste Anwendung der Regel
„neue Version = neue echte Testdatei“). Alle echten Altstände v1–v12 bestehen die Prüfung.

## 030 – Lange Tests und Messung
Entscheidung des Game Directors: Die normale Suite bleibt schnell (Ziel < 1 Minute, derzeit ~2 s); Rundlauf-,
Störungs- und Lasttests liegen in `tests/long/` und laufen mit eigenem Befehl (`-- --long`, README) am Ende jedes
Tickets, das das Speichern betrifft, und am Ende jeder Phase. Der Rundlauf nutzt einen Spiel-Bot (`tests/long/bot.gd`),
der per Seed unter den erlaubten Aktionen wählt; zwei Spiele laufen parallel, eines wird zufällig gespeichert und
geladen – am Ende müssen beide Stände identisch sein. Der Störungstest beschädigt jede echte Testdatei 60-mal
(abschneiden, Zeichen ersetzen, Schlüssel löschen, falsche Typen, Listen verdoppeln); er fand 3 Stellen, an denen
Migrationen Typen nicht prüften (jetzt gehärtet, mit Regressionstests in der normalen Suite).
Messung (Mac, 12.10.2026): Tag 60 – 62 Buchungen, 46 KB, Speichern 1,2 ms, Laden 1,8 ms; Tag 180 – 750 Buchungen,
397 KB, Speichern 8 ms, Laden 15 ms. Weit unter dem vereinbarten Schwellwert (1 MB / 100 ms) – keine Verdichtung des
Ledgers nötig. Notbremse im Test: 5 MB / 1 s.

