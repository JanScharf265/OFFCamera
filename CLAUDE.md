# OFF CAMERA – Regeln für Claude Code

Godot 4 + GDScript, Ziel nur iOS/iPhone (Querformat, fest EINE Richtung mit der Dynamic Island links – Bedienung rechts; Touch, offline;
Stadtkarte als Hauptbildschirm, Safe Area beachten). Der Nutzer ist Game Director
und entscheidet über Umfang und Prioritäten. Spiel ist fiktional; illegale Aktivitäten bleiben
abstrakte Spielwerte – keine realen Anleitungen (Geldwäsche, Steuerhinterziehung, Ermittlungsumgehung).

## Spielvision (seit 13.10.2026, Details: `docs/VISION.md`, Grundlage: `docs/LEITFADEN.md`)
Eine Person in Marbella ist öffentlich Streamer und führt parallel eine fiktionale, kriminell geprägte
Organisation. Die **Unterwelt ist das Hauptspiel** (Großteil von Geld, Entscheidungen, Spannung), die
**Streamer-Karriere das Nebenspiel** (legales Einkommen, Tarnung, Image, Risiko des Auffliegens).
Das Merch-Label bleibt legale Firma und wird Tarnfirma.

**Harte Inhaltsgrenze:** Alles sind Spielmechaniken mit Zahlen und Entscheidungen. Keine realen Herstellungs-
oder Streckschritte, Chemikalien, Mengen, Schmuggelrouten oder -methoden, Verstecktechniken,
Geldwäsche-Konstruktionen oder Tricks gegen Ermittlungen. Keine echten kriminellen Organisationen oder realen
Personen (Behörden nur als Institutionen, Beamte und Fälle erfunden). Gewalt nur als Text und Folgen.

## Arbeitsweise
- Nur die aktuelle Phase aus `docs/ROADMAP.md` bearbeiten, keine späteren Phasen vorziehen.
- Pro Auftrag ein kleines Arbeitspaket: Ist-Zustand prüfen → kurzer Plan mit Dateien → umsetzen → Tests → Doku.
- Bei großen/riskanten Änderungen vorher Freigabe einholen.
- Keine Godot-APIs erfinden. Unsicherheit benennen und einen konkreten Test vorschlagen.
- Ehrlich unterscheiden: automatischer Test / Editor-Test / echter iPhone-Test. Nie einen Build oder Test
  als gelaufen melden, der nicht gelaufen ist. (In der Cloud-Umgebung gibt es kein Godot und kein Xcode.)
- Diffs statt ganzer Dateien, kurze Zusammenfassungen (Budget: max. 100 $ KI-Nutzung).
- Niemals Geheimnisse, Zertifikate oder Provisioning-Profile committen.
- **Tutorials (ab Paket T):** Jede neue Mechanik bekommt im selben Ticket ihr Tutorial (Daten in
  `data/tutorials/`), der Abdeckungstest muss grün bleiben.
- Jede neue Spielstand-Version bekommt eine Migration und eine echte Testdatei (`tests/fixtures/saves/`).

## Vier Architekturregeln (nie umgehen)
1. **Zeit:** genau eine kanonische Spielzeit (Minuten seit Spielbeginn) im `TimeSystem`.
   Keine Echtzeit-Simulation, keine zweite Uhr, kein Zeitfortschritt im Hintergrund.
2. **Geld:** jede Geldänderung ist eine Buchung im `LedgerSystem` (ID, Zeit, Betrag, Kategorie,
   Beschreibung, Quelle). UI und andere Systeme ändern den Kontostand nie direkt. Keine Doppelbuchungen.
3. **Daten statt Sonderfälle:** Orte, Aktivitäten, Standorte, Ereignisse als Daten mit stabilen IDs.
4. **Ereignisse:** zentral im `EventSystem`, eindeutige IDs, deterministisch (Seed), nie doppelt
   verarbeitet – auch nicht nach dem Laden.

UI zeigt Zustand an und ruft Systeme auf; sie berechnet keine Spielregeln.
Autoloads nur für wirklich globale Dienste. Save-Datei versioniert, lokal, atomar geschrieben.

## Fehlerbericht (vom Nutzer)
Was getan · was erwartet · was passiert · exakte Fehlermeldung · Editor oder nur iPhone · letzter guter Commit.
Dann: Ursache analysieren, minimalen Fix + Regressionstest vorschlagen, nicht neu schreiben.

## Docs aktuell halten
`README.md` (Stand, Versionen), `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `CHANGELOG.md`.
`docs/VISION.md` (Text des Game Directors) und `docs/LEITFADEN.md` (Textfassung des PDF) nicht umschreiben.
