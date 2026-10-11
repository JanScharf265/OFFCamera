# Architektur

Stand Phase 1, Ticket 3: Zeit, Ledger, Spielerwerte und Aktivitäten vorhanden; noch keine Spiel-UI.

## Umgesetzt

### TimeSystem (`scripts/systems/time_system.gd`)
- `RefCounted`, kein Autoload – wird später von der Spielsitzung besessen; dadurch ohne Szene testbar.
- Kanonische Zeit: ganze Minuten seit Spielbeginn. Minute 0 = Tag 1, 00:00, Montag.
- Einziger Weg, Zeit zu ändern: `advance(minutes)`. Dauer ≤ 0 und verschachtelte Aufrufe aus
  Signal-Handlern werden abgelehnt (`false`, keine Änderung).
- Signale: zuerst `day_changed(day)` pro überschrittenem Tag (aufsteigend), danach genau einmal
  `time_advanced(from, to)`. Beim Feuern ist die neue Zeit bereits gesetzt.
  Das EventSystem (Ticket 5) verarbeitet fällige Ereignisse im Intervall `(from, to]`.

### LedgerSystem (`scripts/systems/ledger_system.gd`, Modell `scripts/models/ledger_entry.gd`)
- Einzige Autorität für Geld. Beträge in **ganzen Cent** (`int`), Einnahme > 0, Ausgabe < 0.
- Kontostand = Startwert + Summe aller Buchungen; `recalculate_balance()` prüft das.
- Jede Buchung: ID `tx_000001…`, Spielzeit vom TimeSystem, Betrag, Kategorie, Beschreibung, Quelle,
  optionale Referenz.
- `post()` lehnt ab (gibt `null`, setzt `last_rejection`, keine Signale):
  ungültig (`INVALID`), nicht genug Geld (`INSUFFICIENT_FUNDS`, außer `allow_negative`),
  bereits verwendeter `idempotency_key` (`DUPLICATE`).
- Signale: `entry_posted(entry)`, danach `balance_changed(balance_cents)`.

### GameState (`scripts/core/game_state.gd`)
- Bündelt die Systeme einer Spielsitzung (kein Autoload). `GameState.new(catalog)` = neues Spiel
  mit Startwerten (Platzhalter: Tag 1 08:00, 500,00 €, Energie 80, Stimmung 60).

### PlayerStats (`scripts/models/player_stats.gd`)
- Abstrakte Werte 0–100 (`energy`, `mood`), nur über `apply(deltas)` änderbar, begrenzt auf 0–100.

### Aktivitäten (`data/activities/activities.json`, `ActivityCatalog`, `ActivitySystem`)
- Daten: `id` (a–z, 0–9, _), `display_name`, `description`, `duration_minutes` (> 0),
  optional `money_cents` (+ Einnahme / − Ausgabe, dann `category` Pflicht), optional `effects`
  (nur Schlüssel aus `PlayerStats.KEYS`, ganze Zahlen).
- `ActivityCatalog` prüft alles beim Laden, sammelt verständliche Fehler und übernimmt bei
  einem Fehler gar nichts.
- `ActivitySystem.check(id)` / `start(id)` geben `""` (ok) oder einen Anzeigetext zurück.
  `start` prüft erst alles (Energie reicht, Geld reicht, kein laufender Zeitfortschritt) und führt
  dann aus: Buchung (Zeitstempel = Beginn) → Effekte → `time.advance(dauer)` → `activity_completed`.
- Datendateien werden per `include_filter="data/*"` in den iOS-Export aufgenommen.

### Konvention: Verweise zwischen Skripten
Skripte referenzieren einander über `const X := preload("res://…")` statt über `class_name`.
So funktionieren sie auch im Headless-Testlauf direkt nach `git pull`, bevor der Editor den
Klassen-Cache aktualisiert hat.

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
