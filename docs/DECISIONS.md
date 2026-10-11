# Entscheidungen

## 001 – Renderer: GL Compatibility
Für eine 2D-Management-UI auf dem iPhone ist der Compatibility-Renderer die einfachste und robusteste Wahl.
Keine aufwendigen Effekte nötig. Kann später geändert werden, falls es einen konkreten Grund gibt.

## 002 – Hochformat, 720×1280 Basisauflösung
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

## 015 – Zufallsereignisse mit festem Seed
Gewürfelt wird nur beim Tageswechsel (`day_changed`), nicht pro Aktion – so hängt der Verlauf nicht davon ab,
wie man den Tag in Aktionen aufteilt. Wurf = FNV-1a 32 Bit von "<seed>|<tag>|<id>" modulo 100: zustandslos,
plattformunabhängig, selbst implementiert (nicht `String.hash()`, das sich mit der Engine ändern könnte).
Gespeichert wird nur der Seed; Abklingzeit und Anzahl ergeben sich aus den ausgelösten Instanzen (`<id>@<tag>`).
Höchstens ein Zufallsereignis pro Tag (Priorität, dann ID), damit es nicht stapelt. Alle Zufallsereignisse
frühestens ab Tag 3 – die ersten Tage bleiben ruhig. Neues Spiel: zufälliger Seed; alte Spielstände: Seed 1.
Prozentuale Follower-Änderungen werden beim Entscheiden vom aktuellen Stand berechnet; Zuwächse laufen durch
die Wachstumsbremse. Bedingungen prüfen den Kanal zum Zeitpunkt des Würfelns.

## 014 – Ausrüstung
Drei Teile (Kamera, Mikrofon, Licht) mit je drei Stufen, Kauf nur im Studio und nur Stufe für Stufe, ohne
Spielzeit. Der Qualitätsbonus gilt für die erreichte Stufe (nicht aufsummiert) und nur für die Formate des Teils.
Jede Stufe wird höchstens einmal bezahlt (Schutzschlüssel `equipment:<id>:<stufe>`). Kein Verschleiß, kein
Wiederverkauf. Preise und Boni sind Platzhalter fürs Balancing. Fehlt ein Teil später in den Daten, wird es beim
Laden ignoriert; eine zu hohe Stufe wird auf das Maximum gesetzt, statt den Spielstand abzulehnen.

## 013 – Content-Formate exakt berechnet
Zufall nur bei Ereignissen (Entscheidung des Game Directors); Content-Ergebnisse sind exakt und werden vor dem
Produzieren angezeigt. Qualität = 100 % + Ausrüstung (014) + (Community − 50) / 2, mindestens 10 %.
Follower-Zuwachs und Einnahme haben einen Grundwert plus einen Anteil je 1.000 Follower, beides × Qualität;
der Follower-Anteil wächst also mit der Reichweite, die Wachstumsbremse (012) begrenzt ihn. Community und Ruf
ändern sich um feste Werte des Formats. Ganzzahlig, abgerundet. Ein Livestream bringt zu Spielbeginn exakt
25,00 € wie früher der „Kurze Stream“. Das ContentSystem hat keinen eigenen Spielstand: Der Schutzschlüssel
`content:<format>:<startminute>` ist eindeutig, weil jede Produktion Zeit kostet.
Formate sind eigene Daten (nicht Aktivitäten), weil sie zusätzlich Kanal und reichweitenabhängige Einnahmen haben.

## 012 – Kanalprofil und Wachstumsbremse
Reichweite ist eine Followerzahl (Entscheidung des Game Directors), Community-Stimmung und Ruf sind 0–100.
Wachstumsbremse: Follower-Zuwächse × (1.000.000 − aktuell) / 1.000.000, kaufmännisch gerundet; harte Grenze
1.000.000. Damit flacht Wachstum ab (logistisch, sobald Zuwächse mit der Reichweite steigen) und endet am Maximum.
Verluste wirken ungebremst. Jede Änderung ist ein Protokolleintrag mit gewünschter und tatsächlicher Änderung,
Quelle und Begründung – so kann die UI erklären, warum sich ein Wert geändert hat. Gespeichert werden die
letzten 200 Einträge; IDs zählen weiter. Optionaler Schutzschlüssel gegen doppelte Anwendung wie im Ledger.
Startwerte (120 Follower, 50, 50) sind Platzhalter fürs Balancing (Phase 8).

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

## 010 – Migration Version 1 → 2
Ein Spielstand aus Phase 1 beginnt in der Wohnung; `since_minutes` = gespeicherte Spielzeit.
Ein gespeicherter Ort, den es in den Daten nicht mehr gibt, fällt auf die Wohnung zurück statt den
Spielstand abzulehnen.
