# Architektur

Stand Phase 4 (Tickets 4.1–4.5 umgesetzt, Abnahme ausstehend: Konten, Unternehmen, Tagesabschluss, Filiale, Management, Unternehmens-UI) auf Basis von Phase 3 (abgeschlossen, auf dem iPhone abgenommen) auf Basis von Phase 2 + Grafik-Ticket G1: Kanalprofil, Content-Formate, Ausrüstung, Zufallsereignisse, Karriere-UI; Orte, isometrische Stadtkarte, Reisezeit, ortsgebundene Aktivitäten, Termine, Spielstand v2. Phase 1 und 2 auf dem iPhone abgenommen.

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
- Konten (Phase 4): `private` und `company` im selben Ledger; jede Buchung hat `account`. `post(…, account)`,
  `get_balance(account)`, `can_afford(betrag, account)`, `recalculate_balance(account)`,
  `get_entries_for_account(account)` – ohne Angabe jeweils das Privatkonto.
- `transfer(betrag, von, nach, beschreibung, quelle, schlüssel)`: zwei Buchungen (Kategorie `transfer`,
  Referenz = Schlüssel, Schutzschlüssel `<schlüssel>|out`/`|in`); erst alles prüfen, dann beide buchen.
  Beim Laden wird eine halbe Umbuchung abgelehnt. `balance_changed(betrag, konto)`.
- Einzige Autorität für Geld. Beträge in **ganzen Cent** (`int`), Einnahme > 0, Ausgabe < 0.
- Kontostand = Startwert + Summe aller Buchungen; `recalculate_balance()` prüft das.
- Jede Buchung: ID `tx_000001…`, Spielzeit vom TimeSystem, Betrag, Kategorie, Beschreibung, Quelle,
  optionale Referenz.
- `post()` lehnt ab (gibt `null`, setzt `last_rejection`, keine Signale):
  ungültig (`INVALID`), nicht genug Geld (`INSUFFICIENT_FUNDS`, außer `allow_negative`),
  bereits verwendeter `idempotency_key` (`DUPLICATE`).
- Signale: `entry_posted(entry)`, danach `balance_changed(balance_cents)`.

### GameData (`scripts/core/game_data.gd`)
- Hält alle Datenkataloge (Aktivitäten, Ereignisse, Orte, Termine). `load_all()` lädt alle Dateien und
  prüft Verweise (Aktivität/Termin → Ort, Startort `home`). Einmal beim App-Start geladen, danach nur gelesen.
  Tests überschreiben einzelne Kataloge mit `load_data()`.

### GameState (`scripts/core/game_state.gd`)
- Bündelt die Systeme einer Spielsitzung (kein Autoload). `GameState.new(game_data)` = neues Spiel
  mit Startwerten (Platzhalter: Tag 1 08:00, Wohnung, 500,00 €, Energie 80, Stimmung 60).

### PlayerStats (`scripts/models/player_stats.gd`)
- Abstrakte Werte 0–100 (`energy`, `mood`), nur über `apply(deltas)` änderbar, begrenzt auf 0–100.

### Orte (`data/locations/locations.json`, `LocationCatalog`, `LocationSystem`)
- Daten: `id`, `display_name`, optional `description`, `map_position` [x, y] mit 0–1 (x rechts, y unten),
  optional `opening_hours` {`open`, `close`} in vollen Stunden (0 ≤ open < close ≤ 24; fehlt = immer offen).
- `LocationSystem`: aktueller Ort, `distance_tenths()` (Luftlinie, Karte = 8 × 8 km, auf 100 m gerundet),
  `travel_minutes_for()` = 5 min + 3 min/km, aufgerundet auf 5 min (nur ganze Zahlen).
  `check_travel(id)` / `travel(id)`: Ort setzen → `time.advance(fahrzeit)` → `traveled`.
  `check_open_during(ort, start, dauer)`: Beginn im Öffnungsfenster und Ende bis Ladenschluss.
- Gespeichert: `{"current": id}`; unbekannter Ort beim Laden → Startort.

### Aktivitäten (`data/activities/activities.json`, `ActivityCatalog`, `ActivitySystem`)
- Daten: `id` (a–z, 0–9, _), `display_name`, `description`, `location` (Orts-ID), `duration_minutes` (> 0),
  optional `money_cents` (+ Einnahme / − Ausgabe, dann `category` Pflicht), optional `effects`
  (nur Schlüssel aus `PlayerStats.KEYS`, ganze Zahlen).
- `ActivityCatalog` prüft alles beim Laden, sammelt verständliche Fehler und übernimmt bei
  einem Fehler gar nichts.
- Optional (Phase 4): `requires` (`company`/`branch`) und `company` {utilization, reputation} – Effekte aufs
  Unternehmen werden nach den Spielerwerten mit Begründung (Name der Aktivität) angewendet.
- `ActivitySystem.check(id)` / `start(id)` geben `""` (ok) oder einen Anzeigetext zurück.
  `start` prüft erst alles (kein laufender Zeitfortschritt, Spieler ist am Ort, Ort für die ganze Dauer
  geöffnet, Energie reicht, Geld reicht) und führt
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
- Laden eines Spielstands (Ticket 6) löst nichts erneut aus, weil nur `time_advanced`/`day_changed` auslösen.
- Zufallsereignisse (Phase 3): `trigger` {`random`: {`chance_percent` 1–100, `from_day` ≥ 2, `cooldown_days`,
  `max_times`, `conditions` {min_/max_ followers|community|reputation}}}. Bei `day_changed(tag)` wird je Kandidat
  (Priorität, dann ID) geprüft: Tag ≥ from_day, Bedingungen, Abklingzeit, max_times, dann
  `roll(tag, id)` = FNV-1a("seed|tag|id") % 100 < Chance. Höchstens eins pro Tag. Instanz-ID `<id>@<tag>`;
  Ledger-/Kanal-Schutzschlüssel `event:<instanz>`. Seed kommt vom GameState (neues Spiel zufällig, Tests fest).
- Optionen können zusätzlich `channel` {followers, followers_percent, community, reputation} haben →
  `channel.apply()` mit Begründung „<Titel>: <Option>“. `option_channel_deltas()` liefert die Vorschau (nach Bremse).
- Gespeichert zusätzlich: `seed`.

### Termine (`data/appointments/appointments.json`, `AppointmentCatalog`, `AppointmentSystem`)
- Daten: `id`, `title`, optional `description`, `location`, `start` {`day`, `hour`, optional `minute`},
  `duration_minutes` (> 0), optional `money_cents`/`category`/`effects` (beim Wahrnehmen),
  `missed_effects` (Pflicht, `mood` < 0).
- `check(id)` / `attend(id)`: nur vor Ort, ab 1 h vor Beginn bis Beginn. Ausführung: Status setzen →
  Buchung (`source = "appointment"`, `idempotency_key = "appointment:<id>"`) → Effekte →
  `time.advance(warten bis Beginn + Dauer)`.
- Verpassen: auf `time_advanced(from, to)` wird jeder offene Termin mit Beginn < `to` verpasst,
  `missed_effects` genau einmal angewendet; `take_missed_notices()` liefert sie einmal für die Anzeige.
- `conflict_warning(minuten)`: Text, wenn eine Aktion über den Beginn eines offenen Termins hinausliefe.
  Die UI verlangt dann einen zweiten Tipp.
- Termine mit Beginn vor `since_minutes` (Spielbeginn bzw. Migration) entfallen ohne Strafe.
- Gespeichert: `since_minutes`, `attended`, `missed` (sortierte ID-Listen).

### Kanal (`scripts/systems/channel_system.gd`, Modell `scripts/models/channel_change.gd`)
- Einzige Autorität für das Kanalprofil: `followers` (0–1.000.000), `community` und `reputation` (0–100).
- Einziger Weg zu ändern: `apply(deltas, quelle, begründung, referenz, idempotency_key)`. Ablehnung (`null`, keine
  Änderung): unbekannter Schlüssel, keine ganze Zahl, leere Quelle/Begründung, alles 0, Schlüssel schon verwendet.
- Wachstumsbremse: positive Follower-Änderungen × (MAX − aktuell) / MAX, gerundet (`damped_follower_gain()`
  auch als Vorschau). Danach Begrenzung auf die Grenzen.
- Kanal-Protokoll: Eintrag `ch_000001…` mit Spielzeit, Quelle, Begründung, Referenz, `requested` und `applied`
  (`was_limited()` = Bremse/Grenze hat gekürzt). Signal `channel_changed(change)`. Letzte 200 Einträge bleiben.
- Gespeichert: Werte, `next_number`, `history`, `used_keys`.

### Content (`data/content/formats.json`, `ContentFormatCatalog`, `ContentSystem`)
- Daten: `id`, `display_name`, optional `description`, `location`, `duration_minutes` (> 0), optional `effects`
  (PlayerStats), `channel` {`followers_base` ≥ 0, `followers_per_mille` ≥ 0, `community`, `reputation`},
  `income` {`base_cents` ≥ 0, `per_1000_followers_cents` ≥ 0}. `GameData` prüft den Ort.
- Qualität = 100 % + Boni aus dem EquipmentSystem + Community-Bonus.
- `preview(id)`: exakte Wirkung beim aktuellen Stand (Qualität mit Anteilen, Follower roh/gebremst, Community,
  Ruf, Einnahme, Effekte); `quality_text()`/`explain()` für Anzeige und Kanal-Protokoll.
- `check(id)` / `produce(id)` wie beim ActivitySystem (Ort, Öffnungszeit, Energie). Ausführung: Einnahme ins Ledger
  (`source = "content"`, Kategorie `creator`, Zeitstempel = Beginn) → Effekte → `channel.apply()` mit Begründung →
  `time.advance(dauer)` → `content_produced`. Kein eigener Spielstand (Schutzschlüssel aus Format + Startminute).
- UI: Content-Karten stehen im Abschnitt „Aktivitäten“ vor den Aktivitäten des Orts (Button `ContentButton_<id>`).

### Ausrüstung (`data/equipment/equipment.json`, `EquipmentCatalog`, `EquipmentSystem`)
- Daten: `id`, `display_name`, `location` (Kaufort), `formats` (verbesserte Formate), `levels` (≥ 1) mit `name`,
  `price_cents` > 0, `quality_percent` > 0 und steigend. `GameData` prüft Ort und Formate.
- `check_buy(id)` / `buy(id)`: nächste Stufe, nur am Kaufort, nur mit genug Geld. Ausgabe im Ledger
  (Kategorie/Quelle `equipment`, Schutzschlüssel `equipment:<id>:<stufe>`), dann Stufe erhöhen. Keine Spielzeit.
- `quality_parts(format)` liefert die Boni für das ContentSystem.
- Gespeichert: `{"levels": {id: stufe}}`; unbekannte Teile werden beim Laden ignoriert, zu hohe Stufen begrenzt.
- UI: Abschnitt „Ausrüstung“ am Kaufort (Button `EquipmentButton_<id>`, verschwindet auf höchster Stufe).

### Unternehmen (`data/company/company_types.json`, `CompanyTypeCatalog`, `CompanySystem`)
- Daten je Art: `id`, `display_name`, `description`, `found_location`, `founding_minutes`, `founding_fee_cents`,
  `min_deposit_cents`, `start_utilization`, `start_reputation`, `fixed_costs_per_day_cents`,
  `base_revenue_per_day_cents`, `revenue_per_1000_followers_cents`, `utilization_decay_per_day`. `GameData` prüft den Ort.
- `check_found(art)` / `found(art)`: am Gründungsort, geöffnet für die Dauer, Gebühr + Einlage auf dem Privatkonto.
  Ablauf: Gebühr (`company:found:fee`) → Umbuchung privat → Firma (`company:deposit:1`) → Werte setzen, Protokoll
  → `time.advance(dauer)` → `company_founded`.
- Filiale (optional je Art: `branch` {location, display_name, opening_minutes, opening_fee_cents,
  base_revenue_per_day_cents, fixed_costs_per_day_cents}): `check_open_branch()` / `open_branch()` am Filial-Ort,
  Kosten vom Firmenkonto (`company:branch:open`), Spielzeit. Danach Filial-Umsatz/-Kosten im Tagesabschluss.
- `deposit()` / `withdraw()`: Umbuchungen `company:deposit:<n>` / `company:withdraw:<n>`, keine Spielzeit.
- `apply(deltas, quelle, begründung, referenz, schlüssel)` für `utilization`/`reputation` (0–100), Protokoll `co_000001…`.
- Tagesabschluss: `day_changed(tag)` rechnet Tag − 1 ab (wenn gegründet und noch nicht abgerechnet).
  `preview_day()` = Grundlage, Reichweite, Auslastung, Ruf-Anteil, Umsatz, Fixkosten. Buchungen aufs Firmenkonto:
  Umsatz (`sales`, `company:day:<t>:revenue`), Fixkosten (`fixed_costs`, `:costs`) nur wenn gedeckt, sonst Ruf −
  (`:unpaid`); danach Auslastung − Verfall (`:decay`). Eintrag in `get_settlements()` (letzte 60) mit Erklärtext;
  `take_settlement_notices()` liefert neue Abschlüsse einmal für die Rückmeldung (wie verpasste Termine).
- Gespeichert: `{"founded": false}` oder Art, Gründungszeit, Werte, Zähler, Protokoll, `used_keys`,
  `last_settled_day`, `settlements`, `branch_open`.
- UI (vorläufig): Karte „Merch-Label · Unternehmen“ im Büro mit „Gründen“ bzw. Kurzstatus.

### Speichern/Laden (`scripts/systems/save_system.gd`)
- Datei `user://savegame.json` (JSON, lesbar). Inhalt: `{"version": 9, "game": GameState.to_dict()}`.
  Jedes System hat `to_dict()` und `restore(data) -> String` (prüft erst alles, ändert nur bei Erfolg,
  sendet keine Signale). Der Kontostand wird beim Laden aus Startwert + Buchungen neu berechnet.
- Gespeichert: Spielzeit, Ledger (Startwert, Buchungen, nächste ID, verwendete Schutzschlüssel),
  Spielerwerte, Ort, Ereignisse (ausgelöst, offen, entschieden + gewählte Option), Termine, Kanal, Ausrüstung.
- Migration 1 → 2: Ort = Wohnung, Termine `since_minutes` = gespeicherte Spielzeit.
- Migration 2 → 3: Kanal mit Startwerten und leerem Protokoll.
- Migration 3 → 4: Ausrüstung leer (nichts gekauft).
- Migration 4 → 5: Ereignis-Seed = `MIGRATED_SEED` (1).
- Migration 5 → 6: `opening_balance_cents` → `opening_balances` {private, company: 0}, alle Buchungen `account = private`.
- Migration 6 → 7: Unternehmen `{"founded": false}`.
- Migration 7 → 8: gegründetes Unternehmen: `last_settled_day` = gespeicherter Tag − 1, `settlements` leer.
- Migration 8 → 9: gegründetes Unternehmen: `branch_open = false`.
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
- Spielansicht (von oben): HUD mit Ort, Aktivitäten am aktuellen Ort (Liste wird bei Ortswechsel neu
  gebaut), nächste 2 Termine („Wahrnehmen“ nur wenn möglich, sonst der Grund), Stadtkarte
  (siehe unten), Ortsdetails mit „Hinfahren“, letzte Buchungen.
- Stadtkarte (Grafik-Ticket G1), nur Darstellung:
  - `city_layout.gd` (RefCounted, ohne Szene testbar): festes isometrisches Raster 15 × 15 plus Umland;
    Straßen auf den Zeilen/Spalten 1, 5, 9, 13 (13 = Strandpromenade), darunter Strand und Meer.
    Jeder Ort kommt auf das nächste freie Grundstück an einer Straße (aus `map_position`, deterministisch).
    `travel_path()` = Breitensuche über Straßen; Projektion `cell_to_world()` (Kachel 132 × 66).
  - `city_map.gd`: zeichnet in `_draw()` nach dem Maleralgorithmus (nur sichtbare Zellen), Zoom 0,75.
    Namensschilder sind Buttons `MapPin_<id>`; Tippen aufs Gebäude wählt ebenfalls aus.
    `mouse_filter = STOP`: Wischen verschiebt nur die Karte (ab 12 px kein Tipp mehr), Grenzen = Stadt inkl. Strand.
    `play_travel(von, nach)` animiert ein Taxi entlang der Straßen (Tween, 0,8–2,5 s) und schwenkt die Kamera mit;
    aufgerufen vom GameScreen erst nach erfolgreichem `LocationSystem.travel()`. `LocationMarker` wippt über dem aktuellen Ort.
  - Gebäudeaussehen je Orts-ID als Tabelle `BUILDINGS`; Grafiken unter `assets/kenney/` (CC0, je mit `License.txt`).
    Fehlt eine Grafik, wird das Teil ausgelassen statt abzustürzen.
- Kanal (Phase 3): HUD-Zeile `ChannelLabel`; Abschnitt „Kanal“ (Follower, Anteil laut Wachstumsbremse,
  Balken für Community-Stimmung und Ruf) und „Kanal-Verlauf“ (letzte 5 Protokolleinträge: Zeit, Begründung,
  tatsächliche Änderung; bei Kürzung auch die gewünschte Änderung und die Ursache). Texte in `activity_text.gd`.
- Unternehmen (Phase 4): HUD-Zeile `CompanyBalanceLabel` (nur mit Unternehmen); Abschnitt „Unternehmen“
  (Hinweis zur Gründung bzw. Karte mit Firmenkonto, Auslastung, Ruf, `preview_day()`-Prognose, Filial-Status,
  Einlage/Entnahme in 100-€-Schritten), „Tagesabschlüsse“ (letzte 5, unbezahlte rot) und „Unternehmens-Verlauf“
  (letzte 5 Protokolleinträge). Firmenbuchungen in „Letzte Buchungen“ mit „(Firma)“. Gründungs- und
  Filial-Karten erscheinen am jeweiligen Ort im Abschnitt „Aktivitäten“.
- Kollision mit Termin: erster Tipp zeigt die Warnung, zweiter Tipp auf dieselbe Aktion führt aus.
- Offenes Ereignis: `EventPanel` ersetzt die Liste, bis eine Option gewählt ist.
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
| `LocationSystem` | aktueller Ort, Reisezeit, Öffnungszeiten, Fahrten |
| `AppointmentSystem` | Termine: wahrnehmen, verpasst, Kollisionen |
| `ChannelSystem` | Follower, Community-Stimmung, Ruf, Kanal-Protokoll |
| `ContentSystem` | Prüfen, Berechnen und Produzieren von Content |
| `EquipmentSystem` | Ausrüstungsstufen, Kauf, Qualitätsbonus |
| `CompanySystem` | Unternehmen: Gründung, Auslastung, Ruf, Einlage/Entnahme |
| `SaveSystem` | versionierter lokaler Spielstand |

UI-Szenen lesen Zustand und rufen Systeme auf; sie ändern Werte nie direkt.
Systeme melden Änderungen über Signale (z. B. `time_advanced`, `day_changed`, `balance_changed`).

## Geplante Ordner

```
assets/   kenney/ (CC0-Grafiken)
scenes/   app/, menus/, hud/, …
scripts/  core/, systems/, models/, ui/
data/     activities/, locations/, events/, appointments/, content/, equipment/, company/
tests/
```

Ordner werden erst angelegt, wenn sie gebraucht werden.
