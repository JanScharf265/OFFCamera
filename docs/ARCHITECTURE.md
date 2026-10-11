# Architektur

Stand Phase 1, Ticket 1: `TimeSystem` vorhanden, noch nicht im Spiel verdrahtet.

## Umgesetzt

### TimeSystem (`scripts/systems/time_system.gd`)
- `RefCounted`, kein Autoload – wird später von der Spielsitzung besessen; dadurch ohne Szene testbar.
- Kanonische Zeit: ganze Minuten seit Spielbeginn. Minute 0 = Tag 1, 00:00, Montag.
- Einziger Weg, Zeit zu ändern: `advance(minutes)`. Dauer ≤ 0 und verschachtelte Aufrufe aus
  Signal-Handlern werden abgelehnt (`false`, keine Änderung).
- Signale: zuerst `day_changed(day)` pro überschrittenem Tag (aufsteigend), danach genau einmal
  `time_advanced(from, to)`. Beim Feuern ist die neue Zeit bereits gesetzt.
  Das EventSystem (Ticket 5) verarbeitet fällige Ereignisse im Intervall `(from, to]`.

## Tests
`tests/run_tests.gd` (eigener Mini-Runner, kein Addon) führt alle `tests/test_*.gd` aus.
Tests sind per `exclude_filter` vom iOS-Export ausgeschlossen.

## Geplante Verantwortlichkeiten (ab Phase 1)

| System | Einzige Autorität für |
| --- | --- |
| `GameState` | aktueller Spielstand, Spielerwerte |
| `TimeSystem` | Spielzeit (Minuten seit Spielbeginn), Tageswechsel |
| `LedgerSystem` | Buchungen und Kontostand |
| `EventSystem` | geplante/ausgelöste Ereignisse, verarbeitete IDs |
| `ActivitySystem` | Prüfen und Ausführen von Aktivitäten |
| `SaveSystem` | versionierter lokaler Spielstand |

UI-Szenen lesen Zustand und rufen Systeme auf; sie ändern Werte nie direkt.
Systeme melden Änderungen über Signale (z. B. `time_advanced`, `day_changed`, `balance_changed`).

## Geplante Ordner

```
scenes/   app/, menus/, hud/, …
scripts/  core/, systems/, models/, ui/
data/     activities/, locations/, events/
tests/
```

Ordner werden erst angelegt, wenn sie gebraucht werden.
