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

## 051 – Ladebildschirm (G5.1b)
Messung auf dem Mac (Fensterlauf, Zeit seit Engine-Start): Engine bis zum ersten Skript 430–460 ms (kalt 1,2 s);
App-Szene laden 200–265 ms – das ist das Einlesen aller Skripte über die preload-Kette (App → Spielansicht → alle
Fenster, Systeme, Karte); Aufbau bis zum ersten Bild 35–75 ms; „Neues Spiel“ mit Karte und Texturatlas 19–55 ms.
Mit Ladebildschirm: erstes Bild des Ladebildschirms nach 616–650 ms, alle Schritte fertig nach 0,9–1,0 s, Übergabe an
die App nach der Blende (0,45 s) bei ~1,4 s. Was auf dem iPhone schwarz ist, kann ich auf dem Mac nicht sehen: Die
Zeit VOR dem ersten Skript (Engine-Start, Renderer) kann kein Spielskript überbrücken – dort zeigt iOS den
Launch-Screen bzw. Godot sein Startbild. Abgedeckt ist jetzt alles NACH dem ersten Skript (App-Szene, Daten, Karte);
die Zeitstempel „[Start] … ms“ in der Xcode-Konsole zeigen, wo die Sekunden auf dem iPhone liegen.
Fortschritt ehrlich: Im ersten Schritt meldet der ResourceLoader nur 0 → fertig (die App-Szene hängt an genau einer
Datei, dem App-Skript; das Einlesen der übrigen Skripte meldet er nicht schrittweise) – der Balken springt dort von
0 auf 45 %. Die Kartengrafiken (~40 Dateien) liefern feine Schritte. Kein geschätzter Balken.
Mögliche Beschleunigung (nicht umgesetzt, erst nach den iPhone-Zeiten entscheiden): die Fenster-Skripte und die Karte
nicht per `preload` in der App-Kette laden, sondern erst bei Bedarf (`load`) – das verkürzt den größten Mac-Posten.
Die Skripte werden bereits als komprimierte Binär-Tokens exportiert (`script_export_mode=2`).

## 052 – Schwarze Phase nach dem Ladebildschirm (G5.1c)
iPhone (A20 Pro, G5.1b): Ladebildschirm bereit 1116 ms, alles geladen 1292 ms, Übergabe 1753 ms – danach laut Game
Director noch schwarz. Bis dahin entstand die App erst NACH dem Ladebildschirm: Hauptmenü aufbauen, erstes Zeichnen
mit neuen Schriften/Größen, bei „Fortsetzen“ dann Spielbildschirm, Karte, Atlas packen (Bilder aus den Texturen lesen,
kopieren, neu hochladen) und das erste Zeichnen der Karte – alles ohne Ladebildschirm davor.
Lösung: Der Ladebildschirm baut die App (Hauptmenü) und einen Probe-Spielbildschirm mit Stadtkarte und HUD verdeckt
UNTER sich auf und lässt beide je 3 Bilder zeichnen; am Ende geht er nur noch weg – das Hauptmenü ist dann schon
gezeichnet. Die Karte teilt ihren gepackten Atlas statisch, also packt der echte Spielstart nicht noch einmal.
Gezeichnet wird in denselben Bildschirm (nicht in eine SubViewport), damit dieselben Zeichenwege vorbereitet werden.
Unsicher (nur auf dem iPhone prüfbar): ob das erste Zeichnen auf dem iPhone wirklich an Shadern hängt und ob
3 verdeckte Bilder genügen; ob der Grafiktreiber (Metal hinter dem Kompatibilitäts-Renderer) noch weitere Varianten
erst beim ersten sichtbaren Bild vorbereitet. Die „[Start]“-Zeilen zeigen es: Hauptmenü, Tipp, Spielstand geladen,
Spielbildschirm aufgebaut und die Dauer jedes Bildes danach, bis eines < 50 ms dauert.
Mac (zwei volle Starts mit „Fortsetzen“, Testspielstand v12): Hauptmenü verdeckt fertig ~0,3 s nach „bereit“,
Probe-Spielbildschirm 50 ms, Übergabe ~0,93 s nach „bereit“; nach dem Tipp erstes Kartenbild nach 36–46 ms
(Bild selbst 13–17 ms).
Keine Mindestdauer (Entscheidung des Game Directors): Der Ladebildschirm verschwindet so schnell wie möglich – nach
dem letzten Schritt nur noch die Blende (0,45 s), kein zusätzliches Warten. (Zwischenzeitlich gab es eine Mindestdauer
von 0,8 s gegen das Aufblitzen; sie wurde wieder entfernt.)

## 053 – Kalender als Tagesplan (G5.2)
Der Kalender zeigt nur HEUTE – als Zeitstrahl. Die Einträge berechnet `scripts/core/day_plan.gd` (reine Abfrage über
Termine, Fristen und Orte, ändert nichts): Termine des Tages mit Beginn, Ende, Ort und Fahrzeit vom aktuellen Ort;
Fristen, die heute fällig wurden (Mieten montags 00:00, bezahlt/offen/erlassen), und – nur für den heutigen Tag –
offene Fristen früherer Tage als „überfällig“, damit nichts Offenes aus dem Blick gerät. Sortierung: Uhrzeit, bei
Gleichstand Fristen vor Terminen, dann ID. Zustände: verpasst/erledigt/vorbei (grau), „als Nächstes“ für den ersten
anstehenden Termin, offen (rot) für Fristen. Die Jetzt-Linie steht hinter allen Einträgen mit Beginn ≤ jetzt
(`now_index`). Einen „laufenden“ Termin gibt es nicht: Verstreicht sein Beginn, gilt er als verpasst, und Wahrnehmen
verbraucht seine ganze Dauer – der Zustand wurde deshalb nicht eingebaut. Ist der Tag leer, steht dort „Heute keine
Termine und Fristen.“, und unter dem Plan ein Hinweis auf den nächsten späteren Termin. Der runde Button heißt schon
seit G4.4 „Kalender“ (Knotenname bleibt `AppointmentsButton`).

## 054 – Kalender bei Tagesbeginn (G5.3)
Eigenes kleines System `DayStartSystem` statt eines Schritts im DayCycle: Der DayCycle läuft mitten im Zeitfortschritt
(je übersprungenem Tag einmal), der Kalender soll aber erst danach und nur einmal für den aktuellen Tag erscheinen.
Das System merkt den zuletzt erledigten Tag; die Spielansicht fragt nach jeder Aktion (in `_refresh()`) mit
`take_calendar_due(auto_open)` – erst wenn kein Ereignis offen ist (Ereignisse zuerst, nie zwei Fenster übereinander:
der Kalender ersetzt ein offenes Fenster). Der Tag gilt auch bei ausgeschaltetem Schalter als erledigt, damit späteres
Einschalten keinen alten Tag nachholt. Neues Spiel: Tag 1 gilt als gezeigt (der Kalender kommt ab dem ersten
Tageswechsel). Spielstand Version 13 mit `day_start.calendar_shown_day`; Migration 12 → 13 setzt den gespeicherten Tag
(alte Stände öffnen den Kalender nicht sofort beim Laden). Testdatei v13 aus dem aktuellen Code (Tag 9, ohne
Oberfläche gespielt – dort ist der Kalender für Tag 9 noch nicht gezeigt und öffnet sich einmal beim ersten Anzeigen).

## 055 – Konflikt-Popup (G5.4)
Das „nochmal tippen“ (Warnung im Hinweis, zweiter Tipp führt aus) ist ersetzt durch ein Popup über allem
(`scripts/ui/conflict_popup.gd`): Titel „Termin verpassen?“, die Aktion mit Dauer und Ende, darunter jeder betroffene
Termin (voller Name, Tag und Uhrzeit, Ort) und die Kosten des Verpassens aus den Daten (`missed_effects`), Buttons
„Abbrechen“ (ändert nichts) und „Trotzdem starten“ (führt die Aktion genau einmal aus – der Button ist danach
wirkungslos, das Popup weg). Die Prüfung macht das AppointmentSystem (`get_conflicts`), die Spielansicht bündelt sie in
`_guard()` für alle Aktionen mit Spielzeit: Aktivitäten, Content, Fahrten, Gründung, Filiale, Termine (beim Wahrnehmen
zählt der Termin selbst nicht). Käufe kosten keine Zeit und fragen nicht. Solange das Popup offen ist, ist nichts
darunter tippbar. Der Hinweis „⚠ Verpasst: 14:00“ in den Kacheln (G4.5b) bleibt als Vorwarnung.

## 056 – Warten bis Terminbeginn (G5.5)
Die Regel liegt im AppointmentSystem (`offers_wait`, `check_wait`, `wait_until_start`): Warten ist nur ein
Zeitfortschritt bis genau zum Beginn – kein Geld, keine Werte, keine neue Spielstand-Version. Angeboten wird es für
offene Termine von heute, die noch nicht begonnen haben; frei nur vor Ort („Erst hinfahren: Studio“ sonst). Da ein
Termin erst als verpasst gilt, wenn die Zeit über seinen Beginn hinausgeht, ist er danach frei zum Wahrnehmen. Fiele
ein anderer Termin in die Wartezeit, fragt wie bei jeder Aktion das Konflikt-Popup (G5.4). Ereignisse in der
Wartezeit laufen über das EventSystem wie sonst – genau einmal.
Anzeige: im Kalender bei jedem solchen Termin („Warten bis 14:00“, gesperrt mit Grund darunter). Im Ortsfenster nur vor
Ort, an der Stelle von „Hinfahren“ in der Titelzeile, nach Beginn als „Wahrnehmen“. Aus der Ferne steht dort schon
„Hinfahren“; ein zweiter, gesperrter Button „Erst hinfahren: Studio“ passte im „Grenzfall“ (1280 px mit Reitern) nicht
mehr in die Titelzeile – die Infozeilen wurden abgeschnitten. Der Grund steht dann im Kalender.

## 057 – Erinnerung vor Terminen (G5.6)
Eigenes kleines `ReminderSystem` (wie das DayStartSystem): Fällig ist ein offener Termin, der in 1–30 Spielminuten
beginnt und noch nicht erinnert wurde; die Spielansicht fragt nach jeder Aktion. Genau auf dem Beginn (z. B. nach
„Warten“) kommt keine Erinnerung mehr. Springt eine Aktion über das Fenster, ist der Termin verpasst und es kommt
keine – das Konflikt-Popup (G5.4) hat vorher gefragt. „Schaffst du es“ rechnet das System (jetzt + Fahrzeit ≤ Beginn),
die UI zeigt nur an. Reihenfolge Ereignis → Kalender → Erinnerung: Die Erinnerung wartet, solange ein Ereignis offen
ist oder der Kalender steht, und kommt beim Schließen; andere Fenster (z. B. das Ortsfenster nach einer Aktivität)
ersetzt sie wie der Kalender – nie zwei Fenster übereinander. Als kleines Fenster mittig statt eines Popups, damit es
dieselbe Ein-Fenster-Regel nutzt. „Hinfahren“/„Warten“ schließen die Erinnerung und laufen über die normalen Handler
(mit Konflikt-Popup). Gespeichert: erinnerte IDs plus `reminded_until_minutes` (Termine bis zu diesem Beginn gelten
als erinnert) – nötig, weil die Migration 13 → 14 die Termin-Daten nicht kennt: Sie setzt den Wert auf gespeicherte
Zeit + 30, damit ein alter Stand keine nachträgliche Erinnerung zeigt. Spielstand Version 14, Testdatei
`tests/fixtures/saves/v14.json` aus dem aktuellen Code (Tag 9, ohne Oberfläche gespielt).

## 058 – „Hinfahren und starten“ (G5.7)
Eigenes zustandsloses `TripSystem`, das nur die vorhandenen Systeme verkettet: Fahrt über `LocationSystem.travel`,
Aktion über `ActivitySystem.start`, `ContentSystem.produce`, `CompanySystem.found`/`open_branch`. Damit keine Regel
doppelt entsteht, haben die Prüfungen eine Variante „bei Ankunft“ (`check_on_arrival(id, start)`): dieselben
Gründe wie `check()` in derselben Reihenfolge, nur ohne „Nur vor Ort“ und mit den Öffnungszeiten ab der Ankunft.
Die Fahrt selbst kostet weder Geld noch Energie, also genügt die Prüfung bei Ankunft. `check()` vor Ort bleibt
unverändert. Ein Grund, den Hinfahren nicht löst, steht im Button (keine Kombi). Konflikte prüft wie überall die
Spielansicht mit dem Konflikt-Popup, hier für Fahrt + Aktion. Scheitert die Aktion nach der Fahrt doch (z. B. weil
während der Fahrt etwas passiert), bleibt man angekommen, die Meldung sagt es („Angekommen: Studio – aber
Livestream: …“), und der Stand wird gespeichert. Gilt für Aktivitäten, Content, Gründung und Filiale; Käufe nur vor
Ort. Kachel: „20 min + 2 h · Ende 15:00“ passte auf dem iPhone SE nicht in eine Zeile – daher Auto + „20 min + 2 h“
in der Zeitzeile und „Ende 15:00“ in der Hinweiszeile (droht ein Konflikt, steht dort „⚠ Verpasst: 14:00“, das Ende
nennt dann das Popup). Das Emoji 🚗 wird durch ein eigenes Auto-Symbol (`assets/icons/car.svg`) ersetzt, weil die
Spielschrift keine Emojis hat. „Hinfahren“ in der Titelzeile: dunkle Fläche mit Akzent-Rahmen und Auto statt der
gefüllten Akzent-Pille des aktiven Reiters.

## 059 – Zählerpunkte und Warnfarben (G5.8)
Zählungen kommen aus den Systemen: Kalender = `DayPlan.count_upcoming_today()` (dieselben Zustände, die der Kalender als
„als Nächstes“/„anstehend“ zeigt – ein Termin, dessen Beginn gerade erreicht ist, zählt mit, weil er noch
wahrgenommen werden kann), Fristen = `ObligationSystem.count_open()` (Instanzen entstehen erst bei Fälligkeit, offen
heißt also fällig oder überfällig). Offene Ereignisse bekommen keinen Punkt: Sie öffnen sofort ihr eigenes, nicht
schließbares Fenster, ein Zähler wäre nie zu sehen. Ab 10 „9+“, damit der Punkt klein bleibt (breitere Pille, 36 px).
Der Punkt sitzt oben rechts über den Kreis hinaus, damit das Symbol frei bleibt (Test prüft: keine Überlappung).
Warnfarben: gelb unter 40, rot unter 20 (`PlayerStats.LOW_BELOW`/`CRITICAL_BELOW`). Begründung: Die meisten Aktionen
kosten 5–20 Energie (Livestream 20, Training 15) – unter 40 sind noch etwa zwei Aktionen möglich, Zeit zum Planen
(Pause, Schlafen); unter 20 scheitert schon ein Livestream („Zu wenig Energie“). Für die Stimmung gelten dieselben
Grenzen, damit man sich nur ein Muster merken muss. Die Stimmung war im Normalfall gelb – sie ist jetzt blau, sonst
wäre „niedrig“ nicht zu erkennen. Die Stufen sind reine Anzeige, keine Spielregel.

## 060 – Vibration (G5.9)
Ein kleiner Dienst `scripts/core/haptics.gd` (kein Autoload, gehört der App) entscheidet. Geld, verpasste Termine,
Fristen und Ereignisse kommen über die Signale der Systeme, nicht aus der UI; nur die rein visuellen Warnungen
(Konflikt-Popup, Erinnerung) meldet die Spielansicht selbst. Dauer 60 ms (kurz, aber spürbar), Schwellwert ±100 €
(typische Aktionen bewegen 3,50–37,20 €; Miete, Gründung, Ausrüstung ab 100 € fallen auf). Umbuchungen privat ↔ Firma
zählen nicht – sie sind weder Einnahme noch Ausgabe und kommen paarweise. „Neue fällige Frist“ ist das Signal
`obligation_due`; es kommt auch, wenn die Frist sofort automatisch bezahlt wird (z. B. Miete) – das ist gewollt, die
Frist ist trotzdem fällig geworden. Gegen Doppelungen gilt eine Sperre von 1,5 s echter Zeit: Eine Aktion läuft in
einem Bild ab, alle ihre Auslöser fallen in die Sperre (Konflikt-Popup + „Trotzdem starten“ eingeschlossen). Beim
Laden und beim Aufbau der Spielansicht ist der Dienst still (`quiet`), damit sich öffnende Ereignis-, Kalender- oder
Erinnerungsfenster nicht vibrieren. Prüfbar ohne Gerät nur über Zähler und Gründe; ob die Vibration spürbar und
nicht zu häufig ist, steht in der iPhone-Liste.

## 061 – Datenformat für Tutorials (T.1)
Auslöser sind eine feste, kleine Liste im Katalog (`TutorialCatalog.TRIGGERS`) statt freier Texte: Ein Tippfehler in
den Daten fällt beim Laden auf, und das TutorialSystem (T.2) meldet genau diese IDs. Neue Auslöser kommen mit dem
Ticket, das sie braucht, in die Liste. Alle Felder sind Pflicht, auch `ui_target` (leer erlaubt) und `requires`
(leere Liste) – so ist jeder Eintrag vollständig lesbar; unbekannte Felder sind ein Fehler, damit sich keine
vertippten Felder („requieres“) still einschleichen. `requires` darf nicht auf sich selbst oder doppelt verweisen;
Zyklen werden per Tiefensuche gefunden und mit ihrem Weg gemeldet. Der Text ist auf 240 Zeichen begrenzt (≈ 2–3 kurze
Sätze), damit er in die Anzeige (T.3) passt; der Layout-Test der Texte folgt in T.7. `ui_target` ist ein Knotenname
(stabile UI-ID, wie ihn die Tests schon nutzen); ob es den Knoten gibt, prüft erst T.3/T.7, weil viele Knoten nur
zur Laufzeit entstehen. Der Katalog ist noch nicht in `GameData` eingebunden, damit sich in T.1 weder Fingerabdruck
noch Spielstand ändern.

## 062 – TutorialSystem und Spielstand 15 (T.2)
Gespeichert werden die gemeldeten Auslöser (`fired`), die bestätigten Tutorials (`seen`) und `seen_triggers`. Weil die
gemeldeten Auslöser im Spielstand stehen, bleibt ein Tutorial fällig, bis es bestätigt ist – auch wenn zwischen
Auslöser und Bestätigung gespeichert und geladen wird, und auch, wenn seine `requires` erst später gesehen werden
(z. B. „Hinfahren“ nach „Gebäude antippen“). Fällig wird erst entschieden, wenn gefragt wird (`get_due()`), nicht
beim Melden – so wirken neue Tutorials in den Daten auch für schon gemeldete Auslöser.
Migration 14 → 15: Wer einen alten Spielstand hat, spielt schon und braucht keine Spielstart-Erklärung („So sieht
die Karte aus“). Alle anderen Tutorials (Hinfahren, Kalender, Ereignis …) kommen normal, weil die Mechaniken teils
neu sind. Die Migration kennt die Tutorial-Daten nicht (sie arbeitet nur auf dem gespeicherten Dictionary) – daher
merkt sie den Auslöser `first_game_start` in `seen_triggers` statt einzelner IDs; das gilt dann auch für
Spielstart-Tutorials, die später dazukommen. Unbekannte IDs in `seen` (Tutorial aus den Daten entfernt) bleiben
stehen, damit es nach einer Rückkehr nicht erneut kommt. `first_game_start` meldet die App bei „Neues Spiel“, nicht
der GameState-Konstruktor (der auch beim Laden läuft).

## 063 – Tutorial-Anzeige (T.3)
Das Overlay ist kein Fenster der Ein-Fenster-Regel, sondern liegt darüber: Es muss auf Elemente IN Fenstern zeigen
können (z. B. „Hinfahren“ im Ortsfenster). Über einem Ortsfenster darf es immer liegen. Bei den vorrangigen Fenstern
(Ereignis, Kalender, Erinnerung) und beim Konflikt-Popup wartet es – außer es erklärt genau dieses Fenster, d. h. sein
Ziel liegt darin (geändert in T.5 auf Wunsch des Game Directors: das Kalender-Tutorial liegt über dem offenen Kalender
und zeigt auf die Jetzt-Linie; ebenso Erinnerung, Konflikt-Popup, Ereignis). Ein Tutorial ohne Ziel oder mit Ziel
anderswo wartet weiter, bis diese Fenster zu sind. Das Platzhalter-Tutorial „Karte“ zeigt auf nichts
(`ui_target` leer statt `CityMap`): Die Karte füllt den ganzen Bildschirm, eine Aussparung ließe keinen Platz für die
Sprechblase. Die Lage der Sprechblase: unter, über, rechts, links vom Ziel – die erste, die ganz in der Safe Area liegt
und das Ziel nicht verdeckt (Test auf allen 4 Geräteklassen). „Verstanden“ speichert sofort (gesehen bleibt gesehen,
auch wenn die App danach beendet wird). Der feste Starthinweis „Tippe auf ein Gebäude …“ entfällt; der
Hinweiskasten ist bis zur ersten Meldung verborgen (vorher stand er leer da).

## 064 – Tutorial-Einstellungen und Lexikon (T.4)
„Tutorials anzeigen“ ist eine Geräte-Einstellung (wie Vibration), nicht Teil des Spielstands. Aus heißt nur „nicht
anzeigen“: Das TutorialSystem merkt Auslöser weiter, fällige Tutorials kommen nach dem Einschalten (beim nächsten
Öffnen der Spielansicht). „Tutorials zurücksetzen“ wirkt auf den aktuellen Spielstand (die gesehenen IDs liegen dort)
und läuft über `TutorialSystem.reset_seen()`: gesehen und `seen_triggers` werden geleert, gemeldete Auslöser bleiben –
deren Tutorials sind sofort wieder fällig, die übrigen kommen beim nächsten passenden Auslöser. Der Spielstart gilt
dabei als gemeldet: Wer zurücksetzt, ist in einem Spiel, und in einem migrierten Stand (v14 → v15) wurde
`first_game_start` nie gemeldet – ohne diese Regel kämen dort die Spielstart-Erklärungen nie wieder. Rückfrage wie
beim Löschen (zweimal tippen); ohne Spielstand ist der Button gesperrt. Das Lexikon zeigt nur Gesehenes (keine
Spoiler), auch Tutorials, die per Migration als gesehen gelten; sortiert nach Bereich (`mechanic`), dann Reihenfolge.
Erreichbar über Zahnrad → Einstellungen → „Hilfe / Lexikon“. Die Einstellungsseite wurde mit dem dritten Schalter
und zwei Buttons zu hoch fürs Querformat (719 statt höchstens 632 px) – Buttons stehen jetzt paarweise in Zeilen,
Abstände 8 statt 12 px. Kein neues Spielstand-Format: Die gesehenen IDs aus T.2 reichen.

## 065 – Tutorial-Texte Grundlagen (T.5)
13 Tutorials, eines je Grundlagen-Mechanik. Zum Spielstart nur zwei („Willkommen in Marbella“, „Orte antippen“), der
Rest kommt beim ersten Benutzen. Dafür sechs neue Auslöser: `first_window_closed` (erstes Schließen eines Fensters →
„Karte bewegen“, dann ist man zurück auf der Karte), `first_action` (erste erfolgreiche Aktion → Energie/Stimmung),
`first_conflict_popup`, `first_wait_offered` und `first_trip_offered` (erst wenn der Button wirklich frei angeboten
wird), `first_new_day` (ab Tag 2 → Speichern/Fortsetzen; kommt nach Ereignis und Kalender des Tages). Wer ein Ortsfenster
aus der Ferne zuerst öffnet, sieht dort nacheinander bis zu drei Erklärungen (Kacheln, Hinfahren, Hinfahren und
starten) – sie gehören zu genau diesem Bildschirm. `ui_target` darf „*“ enthalten (erstes sichtbares passendes
Element, z. B. `Tile_*`, `TileTripIcon_*`, `WaitButton*`), weil Kacheln und Buttons je Ort anders heißen. Konflikt-
und Ereignis-Tutorial zeigen auf den Titel des Popups bzw. Fensters: Die Konfliktkarte und die Ereignis-Optionen sind
so breit und mittig, dass auf keinem Gerät Platz für eine Sprechblase daneben bleibt. Jedes Tutorial wird in seiner
echten Situation auf allen 4 Geräteklassen geprüft (`tests/test_tutorial_texts.gd`). Lexikon (Korrektur): eigener
Bildschirm mit festem rundem Schließen-Button oben rechts, Liste in Spielreihenfolge. Einstellungen (Korrektur): nur
„Hilfe / Lexikon“ voll rot, „Spielstand löschen“ mit rotem Rahmen (Gefahr), „Tutorials zurücksetzen“ und „Zurück“ grau.

## 066 – Tutorial-Texte Karriere/Firma, höchstens 3 hintereinander, Ortsbeschreibung (T.6, T.6b)
Zehn weitere Tutorials mit neun neuen Auslösern; „angeboten“-Auslöser (Content, Ausrüstung, Firma, Ladenlokal,
Symbole) meldet das Ortsfenster, sobald es das Erklärte zeigt. Zwei Regeln für die Anzeige, damit es nicht zu viel wird
und nichts ins Leere zeigt: (1) Höchstens drei Tutorials hintereinander per „Verstanden“; weitere fällige kommen bei
der nächsten Gelegenheit (Fenster öffnen/schließen, Aktion). (2) Ein fälliges Tutorial mit Ziel erscheint erst, wenn
sein Ziel sichtbar ist (z. B. „Was die Symbole heißen“ erst, wenn ein Follower-Symbol auf einer Kachel zu sehen ist,
auch nach Reiterwechsel); andere fällige Tutorials dürfen vorgehen. Das ändert T.3: Dort stand ein Tutorial mit
fehlendem Ziel sofort mittig – das zeigte sonst z. B. die Symbol-Erklärung über der Karte. Die mittige Sprechblase
bleibt als Rückfall, wenn das Ziel eines offenen Overlays verschwindet. Auf schmalen Geräten (Grenzfall) darf die
Sprechblase seitlich schmaler werden (ab 280 px), wenn sie in voller Breite nirgends neben das Ziel passt. Die
Wirkungs-Symbole bekommen feste Namen (`TileChip_singleplayer` usw.). T.6b: Die Ortsbeschreibung war seit G4.5b nur
im Tooltip (auf dem iPhone unerreichbar); jetzt öffnet ein Tipp auf den Ortsnamen eine Info-Blase unter dem Titel,
ein Tipp irgendwo schließt sie wieder; das Tutorial „Aktivitäten“ weist darauf hin.

## 067 – Mechanik-Liste und Abdeckungstest (T.7)
Die Mechanik-IDs stehen als Konstante in `scripts/models/mechanics.gd` (nicht als Daten-Datei): Sie sind Teil des
Codes – eine neue Mechanik entsteht mit Code, und der Name dient nur den Fehlermeldungen. Der Abdeckungstest prüft beide
Richtungen (Mechanik ohne Tutorial, Tutorial ohne bekannte Mechanik) und, ob jeder Auslöser der festen Liste im
Spielcode gemeldet wird – als Textsuche nach `report("…")` bzw. `report.bind("…")` in `scripts/`; dass die Meldung im
richtigen Moment kommt, prüfen die Szenarien in `test_tutorial_texts.gd` (jedes Tutorial erscheint wirklich, auf
4 Geräteklassen). Absicherung der Nutzerdaten: In T.6 hatte ein Test den echten Schalter „Tutorials anzeigen“
ausgeschaltet. Jetzt hat die App umlenkbare Standardpfade (`App.default_save_path`/`default_settings_path`); der
Test-Runner setzt sie vor allen Tests auf `user://test_default_…` und vergleicht `user://settings.cfg` und
`user://savegame.json` (+ .tmp, Backups) vor und nach dem Lauf – jede Änderung ist ein roter Test.

## 068 – Schwarzgeld als drittes Konto (U.1)
Konto-ID `black`, Anzeige „Schwarzgeld“ bzw. kurz „Schwarz“ (HUD, Filter). Gleiche Ledger-Regeln wie die anderen Konten
(jede Änderung eine Buchung, nicht ins Minus, Schutz gegen Doppelbuchung). Umbuchungen von oder zu Schwarzgeld sind
gesperrt: Der Weg vom Schwarz- aufs Privat- oder Firmenkonto ist das spätere „Waschen“ (U.16, Gebühr, Limit, Risiko);
eine freie Umbuchung würde das unterlaufen. Sichtbar wird Schwarzgeld erst, wenn es welches gibt (`is_account_used`) –
vor dem Einstieg in die Unterwelt (U.3) bleibt das Spiel so aufgeräumt wie bisher; verdient wird es frühestens mit dem
ersten Verkauf (U.9). Ereignisse und Fristen können noch nicht auf Schwarzgeld buchen (kommt mit Lieferant/Schulden).
HUD-Leiste (vgl. 044): Auf den drei echten Geräten passen Privat, Firma und Schwarzgeld (je bis 99.999,99 €) in voller
Form; wird es zu eng (Grenzfall-Gerät, später zusätzlich Hitze), verdichtet sich die Leiste stufenweise: ohne Datum
(steht im Kalender), Beträge ab 1.000 € ohne Cent, zuletzt ohne die kleinen Beschriftungen. Spielstand Version 16,
Migration setzt den Startwert 0.

## 069 – iPhone SE wird nicht mehr berücksichtigt
Entscheidung des Game Directors am 23.10.2026: Das iPhone SE (16:9, ohne Notch) wird für Layout und Tests nicht
mehr berücksichtigt. Die Geräteklasse ist aus `tests/layout_helper.gd` entfernt; geprüft werden iPhone 13/14,
iPhone 15/16 Pro Max und der rechnerische „Grenzfall schmal + Notch“ (1280 px breit mit großen Rändern – noch enger als
das SE). Nachtrag (U.3): Auf Wunsch des Game Directors ist auch der Grenzfall gestrichen – geprüft werden nur noch die
echten Geräte iPhone 13/14 und iPhone 15/16 Pro Max. Die Anpassungen für schmale Geräte (z. B. Verdichtung der
HUD-Leiste, schmalere Sprechblase) bleiben als Sicherheitsnetz im Code.

## 070 – Organisation und Hitze (U.2)
Die Organisation ist ein eigenes System mit vier Werten: Name, Respekt, Hitze, Stabilität (je 0–100, reine Spielwerte).
Sie existiert erst nach der Gründung im Einstiegs-Ereignis (U.3); vorher ist nichts sichtbar und `change()` wirkungslos –
so bleibt Tag 1 den Grundlagen. Hitze sinkt an „ruhigen“ Tagen: ein Tag, an dem keine Hitze dazukam; der Abbau läuft als
Schritt im DayCycle direkt nach dem Tagesabschluss (Reihenfolge laut U.24: Abrechnung → Hitze → Fristen → Ereignisse).
Vorläufige Werte in `data/underworld/organisation.json` (Abbau 3 je ruhigem Tag, Start: Respekt 0, Hitze 0,
Stabilität 50) – sie wirken erst, wenn ab U.9 etwas Hitze erzeugt; Feinschliff in Phase 8, Rückfrage an den Game
Director. Anzeige: Flamme + Zahl ohne Beschriftung (wie Energie/Stimmung), ab 30 gelb, ab 60 rot (nur Farbe). Die
Organisation mit Respekt und Stabilität bekommt ihr Fenster und ihr Tutorial in U.3, wenn sie sichtbar wird; in U.2 ist
nur die Hitze zu sehen (Tutorial „Hitze“). Migration 16 → 17: noch nicht gegründet, Standard-Startwerte.

## 071 – Einstieg in die Unterwelt (U.3)
Ein Code-Pfad für neue und alte Spielstände (Entscheidung 037): Nicht ein festes Datum löst den Einstieg aus, sondern
der Tageswechsel – sobald der Tag ≥ 2 ist und noch nichts angeboten wurde. Ein neues Spiel bekommt ihn am Morgen von
Tag 2, ein alter Stand (z. B. Tag 9) beim nächsten Tageswechsel. Dafür gibt es Ereignisse mit dem Auslöser „scripted“,
die nur ein System auslösen kann (`EventSystem.trigger_scripted`) – deterministisch, je Tag höchstens einmal, mit den
üblichen Regeln (zentral, nie doppelt). Ablauf (Empfehlung, vom Game Director zu bestätigen): „Zuhören“ führt zur
Namenseingabe, „Nicht heute“ verschiebt um zwei Tage – die Unterwelt ist das Hauptspiel, ein endgültiges Nein gibt es
nicht. Die Namenseingabe ist nicht schließbar und kommt nach dem Laden wieder, solange der Name fehlt; erst danach
kommen Kalender, Erinnerung und Tutorials. Bei einem Sprung über Mitternacht steht der Einstieg vor einem Ereignis vom
Vorabend (Tageswechsel vor Zeitereignissen, wie schon bei Zufallsereignissen) – bewusst unverändert. Der Kontakt „El
Capitán“ ist eine erfundene Figur. Ereignis-Optionen können eine `note` haben, damit eine Antwort ohne Zahlen nicht
„Keine Folgen“ anzeigt.

## 072 – Story-Aufträge als Kette (U.4)
Aufträge sind Daten mit `requires` statt einer festen Liste von Schritten: Ein Auftrag startet, sobald die Organisation
steht und seine Voraussetzungen erledigt sind. So hängen spätere Tickets einfach Aufträge an die Kette (Kapitel
„Erster Deal“: Ware besorgen in U.6, Versteck in U.8, erster Verkauf in U.9), und auch alte Spielstände bekommen sie
beim Laden – ohne neue Spielstand-Version für jeden neuen Auftrag. Der erste Auftrag „Treffen am Hafen“ nutzt nur, was
es schon gibt (Ankunft im Café am Hafen, auch über „Hinfahren und starten“), damit die Kette nicht mit einem unlösbaren
Ziel beginnt. Belohnungen sind vorerst Organisationswerte (Respekt); Geld kommt mit den Zielen, die Geld bewegen.
Aufträge starten automatisch (Story), es gibt kein Ablehnen. Der rote Punkt zählt Neues und Erledigtes, bis das Fenster
geöffnet wird.

## 073 – Produkte als Spielwerte je „Einheit“ (U.5)
Die vier Produkte tragen ihre echten Namen (Vision), aber alle Zahlen sind reine Spielwerte je abstrakter „Einheit“ –
ohne Gewicht oder Menge aus der echten Welt, damit keine realen Mengen- oder Preisbezüge entstehen (harte
Inhaltsgrenze). Beschreibungen sprechen nur über Spielgefühl (Marge, Aufsehen), nicht über Herkunft, Wege oder
Verarbeitung. Vorläufige Werte (Einkauf/Verkauf je Einheit): Gras 40/70 €, Haschisch 60/110 €, Pillen 50/100 €,
Koks 200/380 €; Hitze je Einheit 1/2/2/4; Qualität 60/55/50/65 – Feinschliff in Phase 8, Bestätigung durch den Game
Director offen. Die „Nachfrage je Gebiet“ kommt mit den Gebieten (U.12). Produkte haben noch keine Anzeige; das
Tutorial dazu kommt mit dem Lieferanten (U.6), wenn der Spieler die Ware zum ersten Mal sieht – erst dann wird es eine
Mechanik im Sinne des Abdeckungstests.

## 074 – Rückmeldungen des Game Directors zu U.3–U.5
- El Capitán ist nicht dauerhaft ablehnbar; „Nicht heute“ (kommt nach zwei Tagen wieder) bleibt (bestätigt 071).
- Die vorläufigen Produktwerte aus U.5 bleiben (bestätigt 073).
- Ein Treffen-Auftrag („visit_location“) zählt nur, wenn der Ort bei der Ankunft offen ist; kommt man bei
  geschlossenem Ort an, gibt es einen Hinweis, und wer dort bleibt, bis geöffnet ist, erfüllt den Auftrag dann.
- Roter Punkt an „Aufträge“ nach einem erledigten Auftrag: gewollt (072) – Abschlusstext und Belohnung sollen gesehen
  werden; der Punkt verschwindet beim Öffnen des Fensters.

## 075 – Lieferant auf Vorkasse (U.6)
Der erste Lieferant „El Rubio“ (erfunden) ist erreichbar, sobald „Treffen am Hafen“ erledigt ist (die Nummer auf der
Serviette) – über einen Button im Fenster „Organisation“, ohne eigenen Ort, weil man ihn anruft. Vorkasse ist eine
Buchung im Moment der Bestellung: aus dem Schwarzgeld, wenn es den ganzen Betrag deckt, sonst vom Privatkonto (vor dem
ersten Verkauf gibt es kein Schwarzgeld; geteilte Zahlungen gibt es nicht). Das Firmenkonto bleibt sauber. Die
Lieferung kommt nach `delivery_days` am Morgen (Schritt im DayCycle nach der Hitze, vor den Fristen) und platzt mit
`failure_percent` (15 %) – entschieden über FNV-1a aus Spiel-Seed und Bestell-ID, also gleich bei gleichem Seed und nach
dem Laden. Geplatzt heißt: Geld weg, keine Ware. Ware ist eine abstrakte Zahl von Einheiten je Produkt (073), noch ohne
Ort – das Versteck kommt mit U.8. Ein bisher übersehener Fehler fiel dabei auf: Die Rückmeldung unten lag hinter jedem
offenen Fenster; sie liegt jetzt darüber (Popup, Info-Blase und Tutorial bleiben darüber).

## 076 – Kredit, Schulden und Druck (U.7)
Kredit gibt es erst nach einer angekommenen Lieferung (Vertrauen), höchstens 10 Einheiten, 25 % Aufschlag, fällig nach
3 Tagen, nur eine laufende Schuld je Lieferant (vorläufige Werte als Daten am Lieferanten). Die Schuld wird erst am
Fälligkeitstag eine Frist im ObligationSystem („einmalige Frist“, eigene Mahnregel: nach 1 Tag 10 % Aufschlag) – so
erscheint sie wie Miete im Fristen-Fenster, im Kalender und am roten Punkt, ohne dass das System neue Zustände für „noch
nicht fällig“ braucht; vorher steht sie im Fenster „Organisation“ und beim Lieferanten. Bezahlt wird aus Schwarzgeld,
ersatzweise vom Privatkonto (vor dem ersten Verkauf in U.9 gibt es kein Schwarzgeld). Platzt eine Kreditlieferung,
entfällt die Schuld (keine Ware, kein Geld). Druck: Ist die Schuld über die Mahnfrist hinaus offen, kommt alle zwei Tage
das Ereignis „Besuch“ (zwei Männer vor der Haustür) – Gewalt nur angedeutet, Folgen als Werte (Stimmung, Respekt,
Stabilität). Dafür können Ereignis-Antworten jetzt die Organisation verändern. Gefunden und behoben bei der
Selbstprüfung: Fälligkeitsdatum bei Sprüngen über mehrere Tage, falscher Satz „auf dem Schwarzgeld“, ein Absturz beim
Laden beschädigter Fristen (langer Störungstest), und Tutorial-Ziele unterhalb des sichtbaren Fensterbereichs (werden
jetzt ins Bild gescrollt). Nachtrag (GD bestätigt die Empfehlung): Über einem offenen Fenster zeigt die Rückmeldung höchstens 3 Zeilen und
„… alle anzeigen (+N)“; ein Tipp zeigt alles, ein weiterer schließt sie. Ohne offenes Fenster bleibt sie vollständig.

## 077 – Standorte und erstes Versteck (U.8)
Standorte der Unterwelt sind Daten mit den Feldern aus Leitfaden 9.3; Personal, Produktivität und Aktivitäten sind
schon da, wirken aber erst mit Crew (U.10/U.11) und weiteren Standorten (U.18). Das erste Versteck ist ein neuer Ort
auf der Karte („Garage in San Pedro“), damit man hinfährt und es vor Ort anmietet – wie die Firmengründung im Büro.
Bis zum Freischalt-Auftrag („Die erste Ware“) ist der Ort unbekannt: kein Schild, an seiner Stelle ein gewöhnliches
Haus, nicht anfahrbar (`unlocked_by_mission` in den Ortsdaten). Platz: Ohne Versteck passen 20 Einheiten (Kofferraum,
Wohnung), die Garage fasst 100 dazu; Bestellungen über den Platz hinaus werden mit Grund gesperrt (Bestand +
unterwegs). Kosten: 300 € beim Anmieten, 20 € je Tag – bezahlt aus Schwarzgeld, ersatzweise vom Privatkonto; reicht
beides nicht, wird der Tag eine einmalige Frist. Vorläufige Werte, Bestätigung durch den Game Director offen.

## 078 – Verkaufen als Aktion (U.9)
Verkaufen ist eine Aktion an einem Verkaufsort (Daten), nicht ein Knopf im Organisations-Fenster: man fährt hin,
verkauft vor Ort, es kostet Spielzeit (1 h) und zeigt das Konflikt-Popup wie Aktivitäten. Der erste Ort „Kaimauer am
Abend“ liegt beim Café am Hafen (Reiter „Unterwelt“), erscheint aber erst nach „Ein sicherer Ort“ – vorher soll das
Café nichts über die Unterwelt verraten. Der Verkaufsort hat keine eigenen Öffnungszeiten (auch nachts möglich).
Einnahme = Einheiten × Verkaufspreis des Produkts (U.5) × Prozent des Orts, immer als Buchung aufs Schwarzgeld;
Hitze = Einheiten × Hitze je Einheit × Prozent. Höchstens 10 Einheiten je Verkauf. Auftrag „Der erste Verkauf“ zählt
alle verkauften Einheiten (5) und schließt das Kapitel „Erster Deal“. Der Ort hieß zuerst „Am Hafen nach Feierabend“;
der Name war in der Kachel abgeschnitten. Vorläufige Werte, Bestätigung durch den Game Director offen.
GD (nach U.9, „weiter“): Empfehlungen angenommen – der Verkaufsort hat vorerst keine Tageszeit-Regel, die Werte bleiben.

## 079 – Crew 1 (U.10)
Vier Rollen zum Start (Dealer, Läufer, Fahrer, Schutz) – Produktion, Buchhalter und Anwalt kommen mit ihren Mechaniken
(Produktion U.18, Waschen U.16, Justiz U.21) als weitere Datensätze. Was die Rollen tun, folgt ab U.11 (Dealer
verkaufen täglich); bis dahin kosten sie nur Lohn. Bewerber: 3 je Tag, aus Seed und Tag berechnet statt gespeichert –
deterministisch, nach dem Laden gleich, ohne Zufallszustand im Spielstand. Werte 20–80 (keine Extreme am Anfang), Lohn
wächst mit dem Können innerhalb der Rollen-Spanne. Einstellen und Feuern sind ein Anruf: sofort, ohne Spielzeit und
ohne Kosten; der erste Lohn fällt am nächsten Morgen an. Feuern hat noch keine Folgen (Verrat, Abwerbung mit U.15).
Löhne als eine Buchung je Tag (übersichtlicher als eine je Person), bezahlt wie die Versteck-Miete. Höchstens 6
Leute. Fenster „Crew“ über einen Button im Organisations-Fenster; ein eigener Seitenbutton folgt mit U.25.
Namen: erfundene Vornamen mit Initiale. Vorläufige Werte, Bestätigung durch den Game Director offen.

## 080 – Antworten des Game Directors nach U.10 (23.10.2026)
- U.6: Bezahlung erst aus Schwarzgeld, dann vom Privatkonto – bleibt so.
- U.8: Werte des Verstecks (300 €, 20 €/Tag, Platz 20/120) – bleiben so.
- U.10: Vorerst werden nur Dealer als Bewerber angeboten. Läufer, Fahrer und Schutz bleiben in `crew.json`
  (Feld `offered` = false) und kommen erst, wenn sie eine echte Wirkung haben. Test: `test_only_dealers_are_offered`.
- U.10: Löhne werden mit U.11 abgestimmt, sobald Dealer Geld bringen; Folgen beim Feuern erst mit U.15.
- Korrektur U.7: Die Screenshots 3 (Ereignis „Besuch“) und 4 (Schulden als Frist) zeigten das Falsche. Ursache war
  das Screenshot-Skript: Der Kalender legte sich nach dem Zeitsprung über das Ereignisfenster, das Skript schloss ihn
  und damit das Ereignis. Neu aufgenommen, geprüft und in `~/Desktop/u7/` ersetzt; das Spiel selbst war korrekt.
- U.12 wird die „Unterwelt-Ansicht“ (Variante B): gleiche Stadt und Karte, zwei Ansichten mit einem Schalter
  „Tag / Unterwelt“ auf der Karte (Safe Area, rechts, ≥ 84 px), erst nach El Capitán. Unterwelt-Ansicht dunkler,
  nächtlich, Neon-Akzente im Rot/Magenta der App; Unterwelt-Orte hervorgehoben, Streamer-Orte abgedunkelt, aber
  antippbar; Gebiete aus U.12 nur in dieser Ansicht als farbige Fläche. Nur Optik: kein Spielzeit-Verbrauch, keine
  zweite Uhr, keine Spielregel in der UI. Gewählte Ansicht wird gespeichert. Tutorial „Zwei Gesichter der Stadt“ mit
  eigener Mechanik-ID. Vorher Ist-Zustand prüfen; bei großem Umbau anhalten und Optionen vorlegen.

## 081 – Dealer-Abrechnung und Befördern (U.11)
Dealer verkaufen ohne eigene Aktion des Spielers: Beim Tageswechsel wird der Vortag abgerechnet (Schritt im DayCycle
im CrewSystem, vor den Löhnen, damit die Einnahme die Löhne decken kann). Einheiten je Dealer = 2 + Können/20 (+0/+1
je Tag aus dem Seed), begrenzt durch den Bestand; verkauft wird zum Verkaufspreis des Produkts (wie an der Kaimauer),
die Gier zweigt Gier/5 % ab (20 → 4 %, 80 → 16 %), Können senkt die Hitze (Können 80 → 60 %). Eine Buchung je Tag.
Wer am Tag X eingestellt wird, arbeitet ab Tag X und wird am Morgen X+1 abgerechnet (wie der Lohn).
Loyalität: +1 je bezahltem Lohntag, −10 bei unbezahltem (Folgen niedriger Loyalität mit U.15).
Befördern: frühestens nach 3 Tagen, kostet 5 Tageslöhne (Schwarzgeld, sonst privat), Rang höchstens 3; +10 Können,
+10 Loyalität, Lohn +25 %. Löhne (Dealer 30–70 €/Tag) bleiben vorerst: Ein Dealer mit Können 50 bringt bei Gras
etwa 4–5 Einheiten × 70 € abzüglich Abzweigung ≈ 300 € am Tag gegen ~50 € Lohn – plus Einkauf (40 €/Einheit).
Bekannte Folge: Solange Dealer verkaufen, steigt die Hitze täglich, also sinkt sie an keinem Tag (ruhiger Tag = ohne
Hitze-Anstieg). Vorläufige Werte, Bestätigung durch den Game Director offen.

## 082 – Unterwelt-Ansicht und Gebiete (U.12)
Ist-Zustand: Die Karte zeichnet alles selbst (`_draw`, Kenney-Grafiken aus einem Atlas). `draw_texture` nimmt eine
Farbmodulation – die Unterwelt-Ansicht braucht deshalb keine neuen Grafiken: Boden, Häuser und Bäume bläulich-dunkel,
Meer nachtblau, Unterwelt-Orte hell mit Neon-Rand (Magenta der App), Streamer-Gebäude dunkler, ihre Schilder
halbtransparent (weiter antippbar). Kleiner bis mittlerer Umbau, daher direkt gebaut.
Gespeichert wird die Ansicht in den Geräte-Einstellungen (`underworld_view`), nicht im Spielstand: Sie ist reine Optik
ohne Spielregel; so braucht es keine Spielstand-Version, und „Spielstand löschen“ setzt sie nicht zurück. Vor El
Capitán gibt es den Schalter nicht, die Karte zeigt dann immer „Tag“.
Der Schalter liegt in einer eigenen Gruppe „ANSICHT“ unten rechts (dunkler Grund wie „Leben“/„Geschäft“ – ohne ihn
war die Beschriftung auf der hellen Karte kaum lesbar); er zeigt die Ansicht, zu der er wechselt (Mond „Unterwelt“ /
Sonne „Tag“, eigene SVG-Symbole).
Gebiete: vier Viertel als Rechtecke auf dem Kartenraster (San Pedro, Altstadt, Nueva Andalucía, Puerto Banús – reale
Ortsnamen, Werte erfunden), mit eigener Schildzelle, damit Gebietsnamen keine Ortsschilder verdecken (beim ersten
Versuch mittig – San Pedro lag auf „Fitnessstudio“, Puerto Banús auf „Ladenlokal“). Tipp auf den Namen zeigt die
Werte als Rückmeldung. Vorläufige Werte, Bestätigung durch den Game Director offen.

## 083 – Gebiete übernehmen, halten, verlieren (U.13)
Einfluss entsteht nur durch Arbeit vor Ort: Dealer werden einem Gebiet zugeteilt (im Crew-Fenster, Tipp wechselt
reihum, „keins“ bleibt möglich – dann verkaufen sie wie in U.11 ohne Einfluss). Wer am Tag verkauft hat, bringt
2 + Können/20 Einfluss. Die Rivalen drücken jeden Tag um Rivalen/20 (San Pedro −2, Puerto Banús −2,5 → −2); im
eigenen Gebiet nur halb. Beanspruchen ist eine bewusste Entscheidung (Gebietsfenster, ab 60 Einfluss, 500 €, Respekt
+5), kein Automatismus. Eigene Gebiete lohnen sich (+1 Einheit je Dealer) und müssen gehalten werden: unter 30
Einfluss sind sie weg (Respekt −5, Stabilität −5, Hinweis). Bis die Rivalen in U.14 handeln, ist ihr Druck ein fester
Wert aus den Gebietsdaten. Nachfrage und Polizei wirken noch nicht auf den Verkauf (Polizei mit U.19). Keine Gewalt –
nur Zahlen und Folgen. Vorläufige Werte, Bestätigung durch den Game Director offen.
Das Gebietsfenster ersetzt die Rückmeldung beim Tipp auf den Gebietsnamen (U.12). Das Tutorial zeigt auf
„Beanspruchen“ (die Einfluss-Zeile ist fensterbreit, die Sprechblase hätte sie verdeckt).

## 084 – Rivalen (U.14)
Drei erfundene Banden mit eigenem Revier (je Gebiet höchstens eine): Los Halcones (Puerto Banús, aggressiv), La Marea
(Nueva Andalucía, ruhig), Los Grises (San Pedro und Altstadt). Konflikte sind Ereignisse im EventSystem (Regel 4):
Hat man im Revier einer Bande mindestens 20 Einfluss, löst der Tageswechsel mit Aggression/5 % Chance (Konflikt
doppelt; Seed, deterministisch, höchstens ein Ärger je Tag) „Ärger mit …“ aus. Antworten: dagegenhalten (Respekt +5,
Hitze +5, Stabilität −5; Bande −10 Stärke, Konflikt 5 Tage – Druck 150 % × Stärke/50), verhandeln (Waffenstillstand
gegen Stärke × 8 €, aus Schwarzgeld sonst privat; ohne Geld: Respekt −3), zurückziehen (Einfluss −20, Respekt −5).
Waffenstillstand gibt es auch ohne Ärger im Fenster „Rivalen“ (7 Tage, kein Druck, kein Ärger). Stärke erholt sich um
1 je Tag. Die Rivalen handeln noch nicht selbst (keine eigenen Übernahmen) – das wäre ein späteres Ticket. Gewalt
nur angedeutet (umgeworfener Tisch, versperrter Weg) mit Zahlen als Folge. Vorläufige Werte, Bestätigung durch den
Game Director offen.

## 085 – Crew-Folgen (U.15)
Vier Vorfälle als Ereignisse (Regel 4), je mit zwei Antworten: Festnahme (Dealer; Chance = Hitze/20 + Polizei des
Gebiets/20 − Können/40 %; Anwalt 300 € oder fallen lassen – dann sinkt die Loyalität aller um 5), Verrat (Gier −
Loyalität ≥ 20; die Person verschwindet mit 10 Einheiten Ware – suchen lassen bringt Respekt und Hitze, abschreiben
kostet Respekt), Spitzel-Verdacht (Loyalität ≤ 30 bei Hitze ≥ 40; rauswerfen oder behalten mit Hitze +10 – keine
„Gegenmaßnahmen“ gegen Ermittlungen, Inhaltsgrenze), Abwerbung (Bande im Gebiet der Person, Loyalität < 50; mehr
Lohn +25 % oder gehen lassen). Höchstens ein Vorfall je Tag, neue Leute erst nach 2 Tagen, deterministisch (Seed).
Das Crew-Fenster zeigt das Risiko je Person; das Tutorial erklärt diese Zeile (auf die Ereignis-Buttons zu zeigen,
ging nicht – sie sind fensterbreit). Feuern (GD: „Folgen beim Feuern in U.15“): Stabilität −2, bei Loyalität < 30
zusätzlich Hitze +5 („redet“).
Texte nennen die Person beim Namen (Platzhalter `{name}`) und kommen ohne „er/sie“ aus, weil die Crew Frauen- und
Männernamen hat; dabei auch den Abschlusstext von „Der erste Dealer“ und einen Ärger-Text der Grises angepasst.
Vorläufige Werte, Bestätigung durch den Game Director offen.

## 086 – Antworten des Game Directors nach U.15 (23.10.2026)
- Hitze sinkt jetzt an jedem Tag um 3 (`heat_decay_per_day`, vorher nur an ruhigen Tagen). Rechnung: Ein Dealer mit
  Können 50 verkauft 4–5 Einheiten Gras (Hitze je Einheit 1) bei 75 % Hitze → 3 Hitze am Tag, minus 3 Abkühlung = ±0;
  drei solche Dealer → 9 − 3 = +6 am Tag. Test `test_heat_with_one_and_three_dealers`: 1 Dealer bleibt in 14 Tagen
  ≤ 60, 3 Dealer steigen. Hitze-Tutorial: „… jeder Tag kühlt ein wenig ab.“ `heat_raised_day` bleibt im Spielstand,
  entscheidet aber nichts mehr (keine neue Version nötig).
- Ereignisfenster: Jede Antwort ist eine Zeile – Folgen links, Button rechts (430 px breit, 84 px hoch), damit auch
  drei Antworten ohne Scrollen passen. Test `test_all_event_buttons_visible_without_scrolling` prüft jedes Ereignis
  aus den Daten auf iPhone 13/14 und 15/16 Pro Max (mit dem alten Fenster schlug er bei den Rivalen-Ereignissen fehl).
  Kein Text gekürzt.
- Angenommen: Werte bleiben (Balancing in Phase 8), Befördern bleibt, 4 Gebiete bleiben, Zuteilen per Tipp bleibt,
  Schalter „Ansicht“ bleibt unten rechts, Rivalen übernehmen selbst erst nach Paket U.
- Sicherheit: Vor jedem Commit `git diff --stat` prüfen; schrumpft eine Datei unerwartet stark, steht es im Bericht.
- U.16 Waschen: nur Spielwert (Gebühr %, Tageslimit, Risiko), ein Button und Zahlen – keine realen Abläufe.

## 087 – Waschen über die Tarnfirma (U.16)
Reine Spielmechanik (GD 086): ein Betrag in Schritten von 100 €, ein Button, Zahlen. Gebühr 15 %, höchstens 1.000 €
am Tag (gespeichert je Tag), Risiko als Hitze (+5 je 1.000 €, abgerundet). Zwei Buchungen im einen Ledger
(Schwarzgeld − Betrag, Firmenkonto + Betrag − Gebühr) – kein Ablauf, keine Konstruktion, keine Spielzeit. Nur mit
Organisation und gegründetem Unternehmen (Merch-Label); der Abschnitt steht im Fenster „Organisation“ (Unterwelt-Seite),
nicht im Firmenfenster. Das Gewaschene zählt als Umsatz auf dem Firmenkonto (damit auch in Abgaben, die sich am
Firmengewinn bemessen). Waschen ohne genug Schwarzgeld oder über dem Limit ist mit Grund gesperrt.
Nebenbei: Die Gruppe „Ansicht“ (U.12) hat keine Überschrift mehr – mit gegründeter Firma ist „Geschäft“ einen Button
länger, und auf dem iPhone 13/14 lagen die Gruppen 1 px übereinander (Layout-Test jetzt mit Firma). Die Erklärung der
Hitze im Organisations-Fenster folgt der neuen Regel („Jeder Tag kühlt ein wenig ab.“).
Vorläufige Werte, Balancing in Phase 8.

## 088 – Schwarzgeld ausgeben (U.17)
„Eingeschränkt bzw. erhöht Hitze“ als ein Schalter statt einer Kontowahl bei jedem Kauf: Ist „Mit Schwarzgeld
bezahlen“ an, zahlen nur Alltagsausgaben (Aktivitäten, Ausrüstung) aus Schwarzgeld – solange es reicht und höchstens
300 € am Tag; sonst automatisch privat (nie gesperrt wegen des Schalters). Miete, Fristen, Firma, Termine und
Ereignisse zahlen nie aus Schwarzgeld (Firmengeld nur über das Waschen, U.16). Jede Zahlung aus Schwarzgeld: Hitze
+2 je 100 €, mindestens +1; die Rückmeldung nennt sie („Bezahlt mit Schwarzgeld: … (Hitze +1)“). Der Schalter ist ein
Spielzustand (bestimmt Geldflüsse) und steht deshalb im Spielstand, nicht in den Geräte-Einstellungen. Unterwelt-
Ausgaben (Lieferant, Versteck, Löhne, Rivalen) zahlten schon vorher Schwarzgeld zuerst. Vorläufige Werte, Phase 8.
GD nach U.17 („mach deine Empfehlung“): Kosten-Chip „· bar“ in den Kacheln kommt mit U.25 (in der ROADMAP vermerkt).
Zu U.16 (offene Frage): Gewaschenes Geld zählt weiter als Firmenumsatz (Empfehlung angenommen).

## 089 – Weitere Standorte und Ausbau (U.18)
Fünf neue Standorte, je mit einer klaren Wirkung als Datenfeld: Lager „Hinterhof“ (Garage, braucht das Versteck,
+300 Platz), „Hinterzimmer“ (Ladenlokal, verkauft 4 Einheiten am Tag), „Club Medusa“ (neuer Ort in Puerto Banús,
verkauft 3 am Tag und erhöht als Tarnfirma das Waschlimit um 1.000 €), „Gewächshäuser“ (neuer Ort Finca, 5 Einheiten
Gras am Tag – nur eine Zahl, keine Herstellungsschritte) und „Liegeplatz 14“ (Café am Hafen, 10 % billiger beim
Lieferanten). Club und Finca sind erst nach „Ein Stück Stadt“ bekannt (wie die Garage in U.8). Verkaufspunkte verkaufen
ohne Crew zum Verkaufspreis, ohne Abzweigen, mit voller Hitze. Produktion füllt nur bis zur Kapazität.
Ausbauen: jede Stufe + `upgrade_percent` Wirkung **und** Miete (Liegeplatz +100 %, sonst +50 %), Kosten
`upgrade_cost_cents` × aktuelle Stufe, dauert wie das Anmieten (Konflikt-Popup). Die Kachel zeigt „Gehört dir · Stufe
1/3“ und „Ausbauen · …“.
Selbstprüfung: Die Finca lag zuerst am rechten Stadtrand – dort begrenzt die Karte das Verschieben, das Schild blieb
immer unter den Seitenbuttons. Sie liegt jetzt oben am Stadtrand; neuer Layout-Test „jedes Ortsschild erreichbar“ (mit
der alten Position schlug er an). Namen gekürzt („Hinterzimmer“, „Gewächshäuser“), weil sie in der Kachel abgeschnitten
waren. Vorläufige Werte, Phase 8.

## 090 – Polizei 1 (U.19)
Die Polizei reagiert auf anhaltende Hitze, nicht auf einzelne Spitzen: Beobachtung nach 3 Tagen in Folge mit Hitze
≥ 40, Ermittlung nach weiteren 3 Tagen ≥ 70; nach 5 ruhigen Tagen (< 30) geht es eine Stufe zurück (die Akte bleibt
und ruht). In der Ermittlung wächst eine Akte (erfundenes Aktenzeichen „MB-…“ aus dem Seed) täglich um Hitze/10 %;
was bei 100 % passiert, kommt mit U.20 (Razzia) und U.21 (Festnahme). Gegenmittel nur als Spielwert: ein Anwalt
(1.000 €, Akte −20 %, alle 3 Tage) und „einen Gang zurückschalten“ (Hitze −5, Respekt −3) – keine Tricks gegen
Ermittlungen (Inhaltsgrenze). Jeder Stufenwechsel ist ein Ereignis (Regel 4).
Verbindung zu Phase 5: Ereignisse können `min_/max_police_level` als Bedingung haben; neues Behördenereignis
„Gemeinsame Kontrolle“ (Stadt und Polizei prüfen die Firma) nur unter Beobachtung; Festnahme-Risiko der Crew +2
Prozentpunkte je Stufe. Behörden sind Institutionen, Beamte und Fälle erfunden. Vorläufige Werte, Phase 8.
GD nach U.19: Fenster „Organisation“ wird in U.25 in Reiter aufgeteilt (Empfehlung angenommen); Polizei-Werte bleiben.

## 091 – Razzia (U.20)
Die Razzia ist die Folge einer vollen Akte (U.19), kein Zufall: beim ersten Tageswechsel mit 100 %. So kann man sie
kommen sehen (Warnung „Zugriff droht“ ab 80 %) und mit Anwalt oder weniger Hitze aufschieben. Folgen, alle als
Spielwerte: Der eigene Standort mit dem höchsten Risiko (Datenfeld `risk`, U.18) wird versiegelt (kann neu angemietet
werden), die Hälfte jeder Ware und 30 % des Schwarzgelds werden beschlagnahmt (eine Buchung). Danach ruht die Sache:
Akte 0, zurück zur Beobachtung, Hitze −20. Die Antworten im Ereignis ändern nur Respekt, Stabilität, Hitze. Eine
Festnahme der Spielfigur kommt mit U.21. Vorläufige Werte, Phase 8.

## 092 – Antworten des Game Directors nach U.20 (23.10.2026)
- Alle Empfehlungen aus U.16–U.20 angenommen: Gewaschenes Geld zählt als Firmenumsatz; „· bar“ in den Kacheln kommt
  mit U.25; Standort-Werte bleiben (Balancing Phase 8); `risk` wirkt bei der Razzia, `staff_slots` erst nach Paket U;
  Organisation bekommt Reiter in U.25; Polizei-Werte bleiben; Razzia-Folgen bleiben (50 % Ware, 30 % Schwarzgeld,
  ein Standort).
- Club Medusa lag auf der Karte fast in Nueva Andalucía – verschoben, sodass Gebäude und Schild klar in Puerto Banús
  liegen. Gebiete nennen ihre Orte (`districts.json` → `locations`); Test: jeder zugeordnete Ort liegt in der Fläche.
- U.21 Justiz: kein Game Over; Haft sind Spieltage mit eingeschränkten Aktionen; Optionen nur als Entscheidungen mit
  Zahlen (Anwalt, Bestechung teuer und riskant, stillhalten, Crew-Mitglied opfern, kooperieren); Gerichte, Richter,
  Beamte erfunden; keine realen Verfahrenstricks; Zeit nur über das TimeSystem; jede Zahlung eine Buchung.
- U.25 ergänzt: Reiter im Fenster „Organisation“, „· bar“ in den Aktivitäts-Kacheln, Checkliste für einen echten
  iPhone-Test (`~/Desktop/u25/iphone_test.md`); Paket U erst nach bestätigtem iPhone-Test als ✅.

## 093 – Justiz (U.21)
Kein Game Over (GD 092): Eine Festnahme ist eine Phase mit Spieltagen. Ablauf: Nach einer Razzia folgt mit 50 % (Seed)
die Festnahme → Untersuchungshaft am Ort „Haftanstalt“ (nur auf der Karte, solange man dort ist; Reisen gesperrt;
Hofgang und Lesen möglich; Organisation, Crew, Telefon laufen weiter) → optional Kaution (Beweislage × 50 €, eine
Buchung) → Prozess nach 5 Tagen → Urteil: Beweislage < 40 % Freispruch, sonst Beweislage/10 × 2 Tage Haft →
Entlassung nach Hause. Warten geht nur über das TimeSystem („Warten bis Tag X“), keine zweite Uhr.
Entscheidungen als Zahlen: bei der Festnahme Anwalt (2.000 €, −25), Bestechung (5.000 €, 50 % Erfolg = Verfahren
eingestellt, sonst +30 und Hitze +20) oder schweigen (−10); im Prozess ein Crew-Mitglied belasten (das am wenigsten
loyale ist raus, −40, Stabilität −15, Loyalität aller −10), kooperieren (−50, Respekt −20, Stabilität −10) oder
warten. Fehlt Geld, wird automatisch geschwiegen. Gericht („Bezirksgericht an der Küste“), Richterin Vidal und Akte
sind erfunden; keine realen Verfahrenstricks. Texte ohne Annahme über das Geschlecht der Spielfigur („die Szene
spricht von Verrat“).
Nachtrag U.20 (GD): Club Medusa lag mit seinem Schild fast in Nueva Andalucía und danach auf dem Café-Schild – jetzt
Raster 11/12. Gebiete nennen ihre Orte (`locations`); Tests: jeder Ort liegt in seinem Gebiet (beim Club auch das
Schild), keine zwei Ortsschilder überlappen sich (beide schlagen mit der alten Position an).

## 094 – Doppelleben (U.22)
Der Kanal wirkt als Faktor auf jeden Hitze-Anstieg, nicht als eigene Hitzequelle: Ruf über 50 tarnt (−1 % je 5 Punkte,
höchstens −10 %), Follower über 5.000 ziehen Blicke an (+1 % je 1.000, höchstens +30 %). Am Spielanfang (Ruf 50, wenige
Follower) ändert sich nichts. Abkühlung bleibt unverändert; ein Anstieg um 1 bleibt mindestens 1. Fünf Ereignisse als
Daten: Paparazzi (ab 2.000 Follower, Hitze ≥ 15), Leak (Hitze ≥ 40), Gerüchte (Hitze ≥ 25), Skandal (ab 5.000
Follower und nur in der Ermittlung), „Wo bist du?“ (nur in Haft – Antwort auf die offene Frage aus U.21). Folgen nur
für Kanal und Hitze. Die Zeile steht am Ende des Organisations-Fensters (weiter oben schob sie „Waschen“ aus dem
Bereich, den das Tutorial erreicht – Reiter kommen mit U.25). Vorläufige Werte, Phase 8.
