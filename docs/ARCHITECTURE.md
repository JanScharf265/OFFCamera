# Architektur

Stand Phase 1, Ticket 6: alle Kernsysteme von Phase 1 inkl. Speichern/Laden; iPhone-Abnahme ausstehend.

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

### Ereignisse (`data/events/events.json`, `EventCatalog`, `EventSystem`)
- Daten: `id`, `title`, `text`, optional `priority` (Standard 0), `trigger` {`day` ≥ 1, `hour` 0–23,
  optional `minute`}, `options` (≥ 1) mit `id`, `label`, optional `money_cents`/`category`/`effects`
  (gleiche Regeln wie bei Aktivitäten; gemeinsame Prüfung in `scripts/systems/data_reader.gd`).
- `EventSystem` hört auf `time_advanced(from, to)` und löst jedes noch nie ausgelöste Ereignis mit
  Fälligkeit in `(from, to]` genau einmal aus – sortiert nach Zeit, Priorität (höher zuerst), ID.
  Ein Ereignis genau zur Startzeit des Spiels wird daher nie ausgelöst.
- Ausgelöste Ereignisse warten als „offen“, bis `resolve(event_id, option_id)` aufgerufen wird.
  Dann: Geld über das Ledger (`source = "event"`, `idempotency_key = "event:<id>"`), Werte über
  `PlayerStats`. Entscheidungen kosten keine Spielzeit. Unbekannte Option oder zu wenig Geld:
  Ablehnung mit Text, Ereignis bleibt offen.
- Laden eines Spielstands (Ticket 6) löst nichts erneut aus, weil nur `time_advanced` auslöst.

### Speichern/Laden (`scripts/systems/save_system.gd`)
- Datei `user://savegame.json` (JSON, lesbar). Inhalt: `{"version": 1, "game": GameState.to_dict()}`.
  Jedes System hat `to_dict()` und `restore(data) -> String` (prüft erst alles, ändert nur bei Erfolg,
  sendet keine Signale). Der Kontostand wird beim Laden aus Startwert + Buchungen neu berechnet.
- Gespeichert: Spielzeit, Ledger (Startwert, Buchungen, nächste ID, verwendete Schutzschlüssel),
  Spielerwerte, Ereignisse (ausgelöst, offen, entschieden + gewählte Option).
- Schreiben: `.tmp` schreiben → bisherigen Stand nach `.bak` → `.tmp` nach `savegame.json`.
- Laden: Hauptdatei, sonst Backup. Fehlende Datei = kein Spielstand (kein Fehler). Beschädigt,
  ungültig oder neuere Version → verständliche Meldung, nichts wird übernommen.
- Neue Formatversion: `SAVE_VERSION` erhöhen und in `_migrate()` einen Schritt ergänzen.
- Bekannte Grenze: Ein Ereignis, das erst nach dem Speichern zu den Daten hinzukommt und dessen
  Zeitpunkt schon vorbei ist, wird in diesem Spielstand nie ausgelöst.

### UI (`scenes/app/app.tscn`, `scripts/ui/`)
- `app.gd` (Hauptszene): Theme, Safe Area (nur auf Mobilgeräten, in Viewport-Koordinaten umgerechnet),
  hält die laufende `GameState`-Sitzung und wechselt zwischen `main_menu.gd` und `game_screen.gd`.
- UI wird im Code aus Containern gebaut (keine festen Pixelpositionen). Farben/Größen in `ui_style.gd`,
  Texte für Aktivitäten/Beträge in `activity_text.gd`.
- `game_screen.gd` aktiviert/deaktiviert Aktivitäten ausschließlich über `ActivitySystem.check()`
  und aktualisiert nach jeder Aktion explizit (nicht über System-Signale, die mitten im Ablauf feuern).
- Scrollen per Touch: Karten und Buttons in der Liste haben `mouse_filter = PASS`, damit Wischgesten
  die `ScrollContainer` erreichen. Hat sich die Liste zwischen Antippen und Loslassen eines Buttons
  um mehr als 12 px bewegt, gilt das als Scrollen und die Aktivität startet nicht.
- Offenes Ereignis: `EventPanel` ersetzt die Aktivitätsliste, bis eine Option gewählt ist.
- Automatisch gespeichert wird beim Start eines neuen Spiels, nach jeder erfolgreichen Aktion
  (`GameScreen.state_changed`), beim Wechsel ins Menü und bei `NOTIFICATION_APPLICATION_PAUSED`,
  `…_FOCUS_OUT` und `NOTIFICATION_WM_CLOSE_REQUEST`. Speicherfehler erscheinen in der Rückmeldezeile.
- Hauptmenü: „Fortsetzen“ (Sitzung im Speicher oder Spielstand auf dem Gerät), „Neues Spiel“
  (zweiter Tipp nötig, wenn ein Spiel existiert), „Einstellungen“ (`settings_screen.gd`:
  Spielstand löschen mit zweitem Tipp).

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
