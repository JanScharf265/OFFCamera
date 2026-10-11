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
