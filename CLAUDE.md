# OFF CAMERA – Regeln für Claude Code

Godot 4 + GDScript, Ziel nur iOS/iPhone (Querformat, Touch, offline; Stadtkarte als Hauptbildschirm, Safe Area beachten). Der Nutzer ist Game Director
und entscheidet über Umfang und Prioritäten. Spiel ist fiktional; illegale Aktivitäten bleiben
abstrakte Spielwerte – keine realen Anleitungen (Geldwäsche, Steuerhinterziehung, Ermittlungsumgehung).

## Arbeitsweise
- Nur die aktuelle Phase aus `docs/ROADMAP.md` bearbeiten, keine späteren Phasen vorziehen.
- Pro Auftrag ein kleines Arbeitspaket: Ist-Zustand prüfen → kurzer Plan mit Dateien → umsetzen → Tests → Doku.
- Bei großen/riskanten Änderungen vorher Freigabe einholen.
- Keine Godot-APIs erfinden. Unsicherheit benennen und einen konkreten Test vorschlagen.
- Ehrlich unterscheiden: automatischer Test / Editor-Test / echter iPhone-Test. Nie einen Build oder Test
  als gelaufen melden, der nicht gelaufen ist. (In der Cloud-Umgebung gibt es kein Godot und kein Xcode.)
- Diffs statt ganzer Dateien, kurze Zusammenfassungen (Budget: max. 100 $ KI-Nutzung).
- Niemals Geheimnisse, Zertifikate oder Provisioning-Profile committen.

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
