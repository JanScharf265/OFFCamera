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

## 031 – Spielstand im Hauptmenü
Unter „Fortsetzen“ steht eine Kurzinfo aus dem Spielstand-Kopf (`SaveSystem.read_meta()`, ohne zu laden): Spieltag,
Uhrzeit, Privatkonto, Speicherzeit in Ortszeit des Geräts (nur Anzeige, keine Spielzeit). Ältere Stände ohne Kopf zeigen
nur „Fortsetzen“. Defekte Stände: Das Laden nimmt automatisch das nächste gültige Backup („Backup laden“ ist damit
implizit) und sagt, dass die defekte Datei aufbewahrt wurde; ist gar nichts ladbar, verweist das Menü auf „Neues Spiel“,
das dann einen zweiten Tipp braucht, und die aufbewahrten Kopien bleiben unberührt. „Spielstand löschen“ entfernt auch
die aufbewahrten Kopien. `read_meta()` liest mit `JSON.new().parse()`, damit kaputte Dateien keine Engine-Fehler loggen.

## 032 – ObjectDB-Warnung am Testende
„124 ObjectDB instances were leaked at exit“ stammt nicht aus dem Spiel: Gemessen mit `Performance.OBJECT_COUNT`
(nach Aufwärmen) hinterlassen neues Spiel (auch 9 Spieltage mit Unternehmen), Laden (gültig, kaputt, ungültig) und ein
App-Durchgang (Fenster, Fahrt, Aktivität, Freigeben) 0 Objekte. Die Reste entstehen in Tests, die anonyme Funktionen
mit Bezug auf das Spiel an dessen eigene Signale hängen (Kreisverweis RefCounted ↔ Callable). Entscheidung des Game
Directors: nur dokumentieren, nicht umbauen. `tests/test_memory.gd` wacht darüber, dass das Spiel frei bleibt.
Ein vermuteter Fix (Tweens der Karte beim Verlassen beenden) zeigte keine Wirkung und wurde verworfen.

## 033 – Layout-Tests mit nachgestellten Geräten
Headless ist das Fenster 64 × 64 und es gibt kein „nächstes Bild“; Layout-Tests stellen deshalb Größe und Safe Area
selbst ein (`tests/layout_helper.gd`, `App.apply_margins()`): iPhone SE 16:9 ohne Notch (1280 × 720), iPhone 13/14 mit
Notch (1558 × 720, seitlich 47 pt, unten 21 pt), iPhone 15/16 Pro Max mit Dynamic Island (1560 × 720, 59 pt / 21 pt),
Grenzfall schmal + große Ränder. Punktmaße umgerechnet mit 720 / Bildschirmhöhe in Punkten.
Umbrechende Labels melden ihre Mindesthöhe für die Breite, die sie gerade haben (anfangs ~1 px → tausende Pixel), bis
ein Container sie im nächsten Bild sortiert. Abhilfe ohne Zusatzbild: Breite setzen, `get_line_count()` (erzwingt den
Umbruch), `update_minimum_size()`. Die Hinweis-Leiste macht das jetzt immer; Tests nutzen `settle_labels()`.
Gefunden: Das Hauptmenü brauchte mit Spielstand-Info ~690 px, mit Fehlermeldung ~807 px – auf Notch-iPhones sind nur
~633 px verfügbar. Lösung: kompakter (Titel 56, Abstände 12, Buttons 84 px ≈ 46 pt) und Menüs in einem Scrollbereich
als Sicherheitsnetz (Normalfall passt ohne Scrollen, Test prüft beides).

## 034 – Performance und Akku
Messung im Fensterlauf auf dem Mac (1560 × 720, 12.10.2026), vorher → nachher:
Ruhezustand 120 → 0 gezeichnete Bilder/s (mit Stromsparmodus); Zeichenaufrufe je Bild 963 → 206 (herausgezoomt);
Wischen ohne VSync 169 → 206 FPS (Zoom 0,75) bzw. 133 → 179 FPS (Zoom 0,5); Aktion mit Neuaufbau 1,4–1,9 ms;
Fenster öffnen 0,8–3,8 ms (unkritisch). Maßnahmen: `application/run/low_processor_mode = true` und `max_fps = 60`
(Entscheidung des Game Directors). Die Standortmarkierung wippte endlos und zwang Godot so, jedes Bild neu zu zeichnen –
jetzt nur 3 s nach Ankunft, Auswahl oder Laden. Alle Kartengrafiken werden beim Start in einen Texturatlas gepackt
(`AtlasTexture`-Ausschnitte), damit Godot Zeichenaufrufe bündeln kann; scheitert das Packen (headless gibt es keine
Bilddaten), bleiben die Einzeltexturen. Die übrigen ~200 Aufrufe kommen v. a. von gezeichneten Flächen (Strand, Wellen,
Route) zwischen den Kacheln – vorerst ausreichend; Werte auf dem iPhone prüft der gebündelte Test (Gefühl, Wärme).

## 035 – iOS-Build 0.7.0 und gebündelter iPhone-Test
Version 0.7.0, Build 7 (danach zählt jede Phase hoch). App-Symbol: eigenes Platzhalter-Symbol (durchgestrichene Kamera,
„OFF CAMERA“, Akzentfarbe), 1024 × 1024 ohne Transparenz, erzeugt mit `tools/icon/make_icon.gd` (eigenes Mini-Projekt,
vom Export ausgeschlossen). Den Godot-Export nach Xcode führt Claude headless aus (nur Projekt, kein Signieren);
geprüft: `UISupportedInterfaceOrientations` = Landscape links/rechts, `MARKETING_VERSION` 0.7.0, Daten und Grafiken
im .pck, `tests/` und `tools/` nicht. Bauen, Signieren, Installieren: Game Director in Xcode.
Die einzelnen iPhone-Checklisten von Phase 3–6 und G2 (~47 Punkte) sind durch EINEN gebündelten Test mit 9 Punkten
ersetzt (Entscheidung des Game Directors): Er prüft nur Gerät, Touch, Darstellung und Gefühl; Spiellogik und Beträge
decken die automatischen Tests ab. Der alte Spielstand auf dem iPhone wird vorher nicht gelöscht – er ist der
Migrationstest (voraussichtlich ein Stand aus dem G1-Build, Spielstand-Version 2 – der letzte Build, der auf dem iPhone lief).

## 036 – Neue Ausrichtung: Unterwelt als Hauptspiel
Der Game Director hat am 13.10.2026 die Spielvision aus dem Leitfaden (1.1, 1.3 C, 9.3, ursprüngliche Phase 4)
wieder in den Mittelpunkt gestellt (Text unverändert in `docs/VISION.md`, Leitfaden als `docs/LEITFADEN.md`):
Die Unterwelt ist das Hauptspiel, die Streamer-Karriere das Nebenspiel, das Merch-Label wird Tarnfirma.
Reihenfolge der Pakete: G3 Icon/Logo → G4 UI-Layout → G5 Hinweise & Komfort → T Tutorial-System → U Unterwelt →
Phase 8 Balancing. In U zuerst Schwarzgeld und Organisation, früh die Story-Aufträge, damit jeder weitere Schritt
eine Aufgabe in der Kette bekommt. Ab T bekommt jede neue Mechanik im selben Ticket ihr Tutorial.
Die vier Architekturregeln bleiben: Schwarzgeld wird das dritte Konto im einen Ledger, Unterwelt-Abrechnung ein
Schritt im DayCycle, Ereignisse weiter zentral und deterministisch. Harte Inhaltsgrenze siehe `CLAUDE.md`.

## 037 – Spielentscheidungen für die Unterwelt
- Festnahme führt nicht zum Game Over: Kaution, Prozess und Haft sind Spieltage mit Einschränkungen und
  Verlusten, danach geht es weiter. Ein „harter Modus“ mit Game Over wird evtl. in Phase 8 geprüft.
- Die Unterwelt startet über ein Einstiegs-Ereignis an Tag 2 (Kontakt am Hafen) – ein Code-Pfad für neue und
  alte Spielstände; Tag 1 bleibt den Grundlagen-Tutorials.
- Kanal-Einnahmen werden nicht gekürzt; die Unterwelt verdient ein Vielfaches. Der Kanal zählt als Tarnung und
  legales Geld. Die Verhältnisse werden in Phase 8 eingestellt.
- Gewalt nur als Text und Folgen (Crew verletzt/weg, Standort verloren), keine ausführlichen Schilderungen.
- Beziehungsfiguren in U: Kontakt am Hafen, Partner/in, bestechlicher Beamter. In Phase 8: bester Freund, Manager.
  Der Rivalenboss ist in U zunächst ein Wert der Gang.

## 038 – Bedienung: Seitenbuttons, Tippflächen, Ausrichtung, Speicherorte
- 7 Seitenbuttons + Menü: Leben (Kalender, Fristen, Kanal), Geschäft (Organisation mit Reitern für Crew, Gebiete,
  Standorte, Bestand; Aufträge; Firma; Buchungen); Menü klein in einer Ecke. Gebiete als Schalter auf der Karte.
- Runde Buttons: Kreis 64 px, unsichtbare Tippfläche mindestens 84 px. Grund: 44 pt sind auf iPhones im
  Querformat 74–84 px der Basisauflösung (720 px Höhe), 56–64 px wären nur ~34–38 pt.
- Ausrichtung: Statt die Dynamic Island zu erkennen (iOS meldet die Safe Area im Querformat auf beiden Seiten
  gleich, ob Godot die Drehrichtung zuverlässig meldet, ist unklar) wird das Spiel auf EINE Querformat-Richtung
  festgelegt – die mit der Insel links. Button-Leisten rechts, links nur schmale Elemente. Die Richtung prüft der
  Game Director beim nächsten iPhone-Build mit einem Blick (Ticket G4.2).
- Speicherorte: Schalter (Tutorials an/aus, Kalender automatisch, Vibration) sind Geräte-Einstellungen in
  `user://settings.cfg`; gesehene Tutorials, gezeigte Erinnerungen und der automatisch gezeigte Kalender je Tag
  gehören zum Spielstand (neue Versionen mit Migration und Testdatei).

## 039 – Abschluss Phase 7
Der gebündelte iPhone-Test (7.5, Build 0.7.0) ist vom Game Director am 13.10.2026 bestanden: alle 9 Punkte ok,
der alte Spielstand vom iPhone lädt. Damit sind auch die iPhone-Abnahmen von Phase 3–6 und G2 erledigt. Ticket 7.6
entfällt (keine Fehler); die Layout-Wünsche vom iPhone gehen in G4/G5 auf. Nachtrag Export: Der Export hatte
Dateien aus `exports/` ins .pck gepackt. Jetzt liegt eine `.gdignore` in `exports/` und `tools/`, und `exports/*`
steht zusätzlich im `exclude_filter` (geprüft: 0 Einträge aus `exports/` im neuen .pck). Code-Signatur im Preset:
„Apple Development“ (Team-ID nur in den lokalen Export-Zugangsdaten, nicht im Repo).

## 040 – App-Symbol „Halbes Objektiv“
Wahl des Game Directors aus drei Entwürfen (G3.1): Entwurf A, ein Objektiv – links im Licht (magenta), rechts im
Schatten. Zwei SVG-Quellen: `app_icon.svg` mit allen Details für Größen ab 114 px, `app_icon_small.svg` vereinfacht
für 40–87 px (Ring 96 statt 60 px dick und größer, kein Glanzlicht und kein Hintergrund-Leuchten, Glas einfarbig,
Pupille größer, Schattenhälfte heller – im Vergleich bei 40/60 px auf schwarzem Homescreen sonst kaum sichtbar).
Jede Größe wird direkt aus dem SVG gerendert (`Image.load_svg_from_string` mit Skalierung) statt verkleinert, ohne
Alpha gespeichert. Varianten für dunkles/getöntes iOS-Erscheinungsbild (`_dark`, `_tinted`) bleiben vorerst leer.

## 041 – Schriftzug und Startbild
Wahl des Game Directors aus zwei Varianten (G3.3): „Kino“ – Bebas Neue (SIL OFL 1.1, Lizenz in
`assets/fonts/bebas_neue/OFL.txt`), „OFF“ Neon-Magenta mit weichem radialem Leuchten, „CAMERA“ hell. Verworfen:
„Marke“ (Objektiv + Archivo Black); Unbounded schied vorher aus, weil sein „E“ eine gewollte Kerbe hat, die neben
dem „M“ wie ein Fehler aussah. Der Schriftzug ist ein UI-Baustein (`scripts/ui/logo.gd`), nicht ein Bild, damit er
in jeder Größe scharf bleibt; nur die übrige UI behält die Standardschrift. Das Startbild wird aus genau diesem
Baustein gerendert (`tools/splash/make_splash.gd`, 2560 × 1440, Hintergrund = `UiStyle.BACKGROUND`), damit der
Übergang Startbild → Menü ruhig ist. Eingetragen als `application/boot_splash/image` (Godot-Startbild, Stretch
„Keep“) und über `storyboard/image_scale_mode = 0` („wie Startbild“) automatisch als iOS-Launch-Screen
(Export geprüft: SplashImage = splash.png, Hintergrundfarbe 0,07/0,07/0,09). Offen fürs iPhone: Der Launch-Screen
zeigt das Bild zentriert in Originalgröße (@2x/@3x), der Schriftzug kann daher kurz anders groß sein als im
Godot-Startbild – beim nächsten iPhone-Build ansehen.

## 042 – Layout-Mockup freigegeben (G4.1)
Freigegeben am 13.10.2026: schmale HUD-Leiste oben, 7 runde Buttons rechts in ZWEI Spalten (Leben | Geschäft;
7 × 84 px untereinander passen nicht unter die Leiste), Menü als Zahnrad in der Leiste, links nur „Hier“,
Ortsfenster mit Reitern und 4-spaltigem Kachel-Raster zwischen Insel und Button-Spalten. Änderungen des Game
Directors für den Umbau: (1) Energie/Stimmung mit Zahl neben dem Balken, (2) Stimmung mit Smiley statt Stern
(Stern ist mit Ruf/Qualität verwechselbar), (3) feste Hinweiszeile in jeder Kachel, damit alle Start-Buttons auf
einer Höhe liegen, (4) Käufe (sofort, keine Spielzeit) mit eigenem Button-Stil, (5) echtes Kalender-Symbol.

## 043 – Feste Querformat-Richtung und rechter Rand (G4.2)
`display/window/handheld/orientation = 2` (SCREEN_REVERSE_LANDSCAPE). Geprüft im headless-Export: Die Info.plist
erlaubt auf dem iPhone nur `UIInterfaceOrientationLandscapeRight` (mit 0 = „Querformat“ wäre es LandscapeLeft).
Laut Apple liegt bei LandscapeRight die Home-Seite rechts, die Oberkante des Geräts – und damit die Dynamic
Island – links. (Für iPad trägt Godot die Gegenrichtung ein; irrelevant, wir zielen nur auf iPhone.) Ob das auf
dem Gerät stimmt, prüft der Game Director beim nächsten iPhone-Build mit einem Blick.
Rechter Rand: keine Sonderregel. Das Spiel hält die Safe Area je Seite genau so ein, wie iOS sie meldet
(`App.safe_margins`, war schon für ungleiche Seiten getestet). Meldet iOS rechts denselben Abstand wie links,
bleibt rechts ungenutzter Platz, dafür nichts in den abgerundeten Ecken. Ob wir rechts weniger Abstand nehmen
dürfen, entscheiden wir nach dem iPhone-Test (Punkt in der ROADMAP). Das Mockup rechnete rechts mit 48 px; mit
symmetrischer Safe Area rücken die Button-Spalten etwa 75 px nach links (Ortsfenster entsprechend schmaler).

## 044 – HUD-Leiste (G4.3)
Eine Zeile, höchstens 64 px hoch (gemessen ~62 px), über die volle Breite der Safe Area: links Tag (klein,
gedämpft), Uhrzeit, Ort mit Symbol; rechts Energie (Kenney „power“) und Stimmung (eigenes Smiley-SVG
`assets/icons/smiley.svg`) je als Symbol + Balken + Zahl, dann „Privat“ und „Firma“ (erst nach der Gründung) als
kleine Beschriftung über dem Betrag. Die Texte „Konto:“, „Ort:“, „Energie 80/100“ entfallen – Symbole und
Beschriftungen ersetzen sie. Schwarzgeld und Hitze kommen in Paket U an dieselbe Stelle; dann reicht die Breite auf
dem iPhone SE (1280 px) evtl. nicht mehr für alles in einer Zeile – Prüfung durch den Layout-Test (Inhalt ≤ Breite),
dann kürzere Beschriftungen oder kleinere Schrift. Die Seitenleisten (noch alte Form bis G4.4) beginnen unter der Leiste.

## 045 – Runde Buttons (G4.4)
Baustein `scripts/ui/round_button.gd`: ein unsichtbarer Button mit 84 × 84 px Tippfläche, darin der sichtbare Kreis
(64 px, beim Zahnrad 44 px) mit Symbol, optional eine kleine Beschriftung und ein roter Zählerpunkt (`set_badge`).
Rechts zwei Gruppen auf dezentem Hintergrund, „Geschäft“ außen am Rand, „Leben“ daneben; beide beginnen unter der
Tippfläche des Zahnrads. Das Zahnrad sitzt mittig in der HUD-Leiste, seine Tippfläche reicht unsichtbar darunter;
die Leiste hält dafür Platz frei (`MenuSpace`). „Organisation“ und „Aufträge“ werden erst in Paket U angelegt
(keine Buttons ohne Funktion). Der Kalender-Button heißt schon „Kalender“; das Fenster dahinter bleibt bis G5.2 die
Terminliste. Symbole: eigenes Kalender- und Blitz-SVG (`assets/icons/`, Kenney hat beides nicht), Zahnrad,
Ausrufezeichen und Liste aus Kenney „Game Icons“ (CC0). Statt „Fristen (1)“ und roter Buttonfarbe zeigt ein roter
Punkt die Zahl der offenen Fristen; die übrigen Zähler (Termine heute usw.) kommen in G5.8.
Hinweis unten: Kurze Hinweise haben `mouse_filter = IGNORE`, damit Tipps durch sie auf die Karte gehen
(z. B. auf ein verdecktes Kartenschild); lange/mehrzeilige behalten STOP, weil man sie zum Schließen antippt. Der
Hinweis liegt zwischen „Hier“ und den Button-Spalten (vorher konnte er auf schmalen Geräten die Spalte überdecken –
vom Layout-Test gefunden).

## 046 – Ortsfenster als Kachel-Raster (G4.5)
Das Ortsfenster liegt unter der HUD-Leiste und reicht vom linken Rand der Safe Area bis vor die Button-Spalten
(Pro Max ~1100 px ≈ 84 % der nutzbaren Breite); „Hier“ liegt dabei unter dem abgedunkelten Hintergrund wie bisher
alles außer dem Fenster. Spalten: so viele Kacheln à mind. 220 px wie passen, höchstens 4 (echte Geräte: 4,
„Grenzfall“: 3). Damit das Studio (7 Kacheln = 2 Reihen) ohne Scrollen passt, gemessen und angepasst: Infos und
„Hinfahren“ stehen in der Titelzeile; Schließen ist rund (Kreis 56, Tippfläche 84) – in allen Fenstern einheitlich;
das Ortsfenster hat 12 statt 24 px Innenabstand und nutzt unten den Grundabstand (nicht den Home-Balken-Bereich).
Schriften: Kachel-Titel 20 px, Text 16 px – kleiner wollten wir nicht gehen. Die Hinweiszeile ist immer reserviert:
gelb bei Terminkonflikt („⚠ Verpasst: …“), sonst grau (Qualität bei Content, nächste Stufe bei Ausrüstung), damit
alle Buttons einer Reihe auf einer Höhe liegen. Sperrgründe stehen im Button. Käufe (Ausrüstung) haben einen
Rahmen-Button statt der vollen Akzentfarbe. Die Gründungs-Kachel zeigt Gebühr und Einlage als Text (zu lang für Chips).
Offen: (1) Im „Grenzfall“ (kein echtes Gerät) braucht das Studio mit 3 Spalten 3 Reihen und scrollt – die Reiter aus
G4.6 lösen das. (2) Die Kachel-Buttons sind 74 px hoch, wie im Mockup: ≈ 44 pt nur auf dem Pro Max, ≈ 40 pt auf
13/14 und ≈ 38 pt auf dem SE – klären in G4.7 (84 px kostet eine Reihe oder Reiter).

## 047 – Lesbarkeit der Kacheln (G4.5b)
Mindestschrift für Lesetext 21 px ≈ 11 pt auf allen iPhones (720 / Bildschirmhöhe in Punkten: SE 1,92 px/pt, Pro Max
1,67 px/pt). Kachel-Namen 23 px, Lesetext und Sperrgründe 21 px, Button-Text 22 px; Ortsname im Ortsfenster 34 px.
Kachel-Buttons: sichtbar 56 px, Tippfläche 84 px – der Button ist 84 px hoch, die Styleboxen zeichnen mit negativer
`expand_margin_top` nur den unteren Teil; der unsichtbare Teil liegt über der Hinweiszeile (Tipps dort starten die
Aktion). Gesperrte Buttons zeigen die volle Höhe für den Sperrgrund (bis 2–3 Zeilen); die Hinweiszeile tritt dann
zurück. Wirkungen alle als Symbol + Zahl (Follower: Person, Community: Gruppe, Ruf: Stern, Auslastung: Balken; Kenney
„Game Icons“, CC0) – erklärt werden sie im Tutorial (Paket T). Platz ohne kleinere Schrift: Öffnungszeiten und
Entfernung in 2 Zeilen, Ortsbeschreibung nur noch im Tooltip (später Lexikon), Innenabstände 8 px, Reihenabstand 8 px,
Chip-Abstand 8 px. Abweichungen vom Auftrag: (1) Konflikt-Hinweis „⚠ Verpasst: 14:00“ statt „… Termin 14:00“ –
gemessen 257 px, die Kacheln sind 222–248 px breit. (2) „Q&A mit der Community“ stand in `data/content/formats.json`
(nicht activities.json) – dort umbenannt. Bekannt offen: Im „Grenzfall“ (3 Spalten, kein echtes Gerät) passen Studio
und Büro nicht ohne Scrollen und die Titelzeile zeigt „…“ – kommt mit den Reitern in G4.6.

## 048 – Reiter im Ortsfenster (G4.6)
Zuordnung als Daten: Pflichtfeld `tab` in activities.json, formats.json, equipment.json und company_types.json
(gilt für Gründung und Filiale). Alltag: Ausruhen, Schlafen, Essen gehen, Kaffee, Training, Woche planen (alles
Persönliche ohne Firma). Content: Kurzvideo, Livestream, Langes Video, Community-Q&A, Kamera, Mikrofon, Licht.
Geschäft: Ware nachbestellen, Kampagne planen, Merch zeigen, Laden führen, Merch-Label (Gründung/Filiale) – alles,
was eine Firma voraussetzt oder betrifft. Unterwelt: noch leer.
Platz, gemessen (G4.5b-Stand): Eine eigene Reiter-Zeile über dem Raster kostet ≥ 44 px Höhe, das Studio hat in zwei
Reihen aber nur 1–40 px Reserve (13/14: 468 von 469 px). Eine Spalte links kostet ~120 px Breite (Text „Unterwelt“
in 21 px + Rand) – im „Grenzfall“ fiele das Raster dann auf 2 Spalten und das Studio bräuchte 3 Reihen. Die
Titelzeile ist ohnehin 84 px hoch (Tippflächen), dort kosten Reiter nur Breite: Reiter stehen zwischen Infos und
„Hinfahren“; die Infos (Öffnungszeiten, Entfernung) weichen auf „…“ aus, wenn es eng wird (nur im „Grenzfall“).
Ob Reiter nötig sind, misst das Fenster selbst beim Layout (synchron, gleiche Methode wie die Layout-Tests). Heute
zeigt nur das Studio im „Grenzfall“ Reiter (Content: 6 Kacheln, 468 von 468 px; Geschäft: 1 Kachel).
Korrektur zu 047: (1) „Büro im Grenzfall braucht 508 px“ war ein Messfehler des Tests – die Hilfsfunktion
`settle_labels()` setzte alle umbrechenden Labels auf 200 px Breite. Mit echter Breite gemessen: 442 von 468 px, das
Büro passt ohne Reiter. Die Layout-Tests messen jetzt wie das Spiel (`Layout.settle_in_place`). (2) „Nichts
abgeschnitten“ stimmte nicht ganz: Im Studio vor Ort (Buttons frei) war „Nächste: USB-Mikrofon“ auf dem SE 12 px zu
breit – der Test prüfte das Studio nur von woanders (dann ist die Hinweiszeile ausgeblendet). Jetzt „→ USB-Mikrofon“
und ein eigener Test vor Ort.

## 049 – Tippflächen, Mindestschrift, Ortsfenster in voller Breite (G4.7)
Ein Test prüft auf allen 4 Geräteklassen jeden sichtbaren Button und Text in Spielansicht und allen Fenstern (auch
jeden Reiter und das Ereignis-Fenster): Tippfläche ≥ 84 px (≈ 44 pt), Lesetext ≥ 21 px (≈ 11 pt),
Mini-Beschriftungen ≥ 19 px (≈ 10 pt; markiert über die Meta `mini_caption`), nichts abgeschnitten. Gefunden:
Kartenschilder 64 px hoch (Büro 80 px breit), Buchungen-Filter 64 px hoch, alle Mini-Beschriftungen 15 px, „1 h 30
min · Ende 10:50“ auf dem SE abgeschnitten, Titelzeile im „Grenzfall“ mit „…“. Lösungen: unsichtbar größere
Tippflächen (sichtbar unverändert); Mini-Beschriftungen 19 px, runde Buttons so breit wie ihre Beschriftung (Spalten
dadurch etwas breiter); „Privat“/„Firma“ neben statt über dem Betrag (Leiste bleibt ≤ 64 px), HUD-Abstände 12 px und
Balken 48 px, damit die Leiste auch im „Grenzfall“ passt; Kacheln mind. 252 px breit; Öffnungszeiten in Kurzform
(„07:00–20:00 · offen“, „immer geöffnet“). HUD-Leiste voll deckend (vorher 86 %, Schilder schienen durch).
Entscheidung des Game Directors (22.10.2026): Das Ortsfenster nutzt die volle Breite der Safe Area wie alle anderen
Fenster und liegt über den Button-Spalten. Grund: Mit 19-px-Beschriftungen wurden die Spalten breiter, die HUD-Leiste
anfangs höher, und im „Grenzfall“ blieben für Öffnungszeiten und Entfernung neben Reitern und „Hinfahren“ nur
~60–150 px. Die Spalten sind unter dem abgedunkelten Hintergrund ohnehin nicht tippbar, solange ein Fenster offen
ist. Abweichung vom Mockup (G4.1) und von G4.5 („zwischen Hier und den Spalten“). Heute zeigt nur das Studio im
„Grenzfall“ Reiter (3 Spalten); auf allen echten Geräten passt jeder Ort ohne Reiter.

## 050 – Geräte-Einstellungen (G5.1)
Schalter, die fürs Gerät gelten (nicht pro Spielstand), liegen in `user://settings.cfg` (ConfigFile) – getrennt vom
Spielstand, ohne Spielstand-Version, unberührt von „Spielstand löschen“. Kein Autoload: Die App lädt sie beim Start
und reicht sie weiter (wie die Spielsitzung). Robustheit: Fehlt die Datei oder ist sie unlesbar, gelten die
Standardwerte (beide Schalter an); die kaputte Datei wird nicht gelöscht, sondern beim nächsten Speichern ersetzt.
Unbekannte Schlüssel und Werte vom falschen Typ werden ignoriert (Wert = Standard). Gespeichert wird sofort beim
Umschalten, atomar über eine .tmp-Datei. Darstellung: CheckButton mit eigenen großen Schalter-Symbolen
(`assets/icons/toggle_on.svg` / `toggle_off.svg`, an = Akzentfarbe) – die Godot-Standardsymbole waren auf dem
Mac-Screenshot kaum als an/aus zu erkennen; Tippfläche 84 px, Schrift 24 px.
