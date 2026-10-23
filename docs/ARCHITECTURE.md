# Architektur

Stand Phase 6 (robustes Speichern, Konsistenzprüfung, echte Altstände, lange Tests) auf Basis von Phase 5 (Wertstellung, DayCycle, Fristen, Behördenereignisse, Finanz-UI), G2 (Querformat, Karte als Hauptbildschirm) und Phase 4 (Konten, Unternehmen, Tagesabschluss, Filiale, Management), Phase 3 (Kanal, Content, Ausrüstung, Zufallsereignisse) und Phase 2 + G1 (Orte, isometrische Stadtkarte, Reisezeit, Termine). Abnahme: Phase 1, 2 und G1 auf dem iPhone; Phase 3, 4, G2, 5 und 6 per Tests + Mac-Fensterlauf, iPhone-Abnahme gesammelt in Phase 7 (DECISIONS 021).

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
- Wertstellung (Phase 5): `effective_minutes` je Buchung (Standard = Buchungszeit, nie in der Zukunft);
  `summarize(konto, von, bis)` summiert nach Wertstellung: Einnahmen, Ausgaben, Ergebnis ohne Umbuchungen,
  Umbuchungen getrennt.
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

### DayCycle (`scripts/core/day_cycle.gd`, Phase 5)
- Einziger Empfänger von `TimeSystem.day_changed` für Tageslogik. Ruft je neuem Tag in fester Reihenfolge
  `on_day_changed(tag)` auf: Unternehmen (Tagesabschluss) → Fristen → Ereignisse (Zufall). Signal
  `day_processed(tag)` danach. Spielwoche: `TimeSystem.week_of()` / `week_start()` (Mo–So, Tag 1 = Montag).

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
  `max_times`, `conditions` {min_/max_ followers|community|reputation}}}. Beim Tageswechsel (über den DayCycle) wird je Kandidat
  (Priorität, dann ID) geprüft: Tag ≥ from_day, Bedingungen, Abklingzeit, max_times, dann
  `roll(tag, id)` = FNV-1a("seed|tag|id") % 100 < Chance. Höchstens eins pro Tag. Instanz-ID `<id>@<tag>`;
  Ledger-/Kanal-Schutzschlüssel `event:<instanz>`. Seed kommt vom GameState (neues Spiel zufällig, Tests fest).
- Optionen können zusätzlich `channel` {followers, followers_percent, community, reputation} haben →
  `channel.apply()` mit Begründung „<Titel>: <Option>“. `option_channel_deltas()` liefert die Vorschau (nach Bremse).
- Gespeichert zusätzlich: `seed`.
- Phase 5: `set_world(company, obligations)` (vom GameState) liefert für Bedingungen `condition_values()`:
  offene Fristen, `company_founded` (1/0), Vorwochen-Gewinn des Firmenkontos (in Woche 1: 0). Neue Optionsfelder
  `account` (Geld auf Privat-/Firmenkonto), `minutes` (Spielzeit nach dem Schließen), `company` (über
  `CompanySystem.apply()` mit Begründung). Katalog verlangt je Ereignis eine Option ohne Kosten.

### Tutorials (`data/tutorials/tutorials.json`, `TutorialCatalog`; T.1 – noch ohne System und Anzeige)
- Daten je Eintrag (alle Pflicht, andere Felder sind ein Fehler): `id`, `mechanic` (Mechanik-ID für den
  Abdeckungstest T.7), `trigger` (eine ID aus `TutorialCatalog.TRIGGERS`), `title`, `text` (≤ 240 Zeichen),
  `ui_target` (Knotenname des hervorgehobenen Elements, z. B. `TravelButton`; "" = keins), `order` (≥ 0, kleiner
  zuerst), `requires` (Tutorial-IDs, die vorher gesehen sein müssen).
- Prüfung wie bei den anderen Katalogen, alles oder nichts: fehlende/unbekannte Felder, doppelte IDs, unbekannter
  Auslöser, `requires` auf unbekannte oder eigene ID, Zyklus in `requires` (Tiefensuche). `get_all()` sortiert nach
  `order`, dann ID; `get_for_trigger(trigger)`.
- Seit T.2 in `GameData.load_all()` (`data.tutorials`).
- Anzeige (T.3, `scripts/ui/tutorial_overlay.gd`): Control über der ganzen Spielansicht (MOUSE_FILTER_STOP – darunter
  nichts tippbar), zeichnet die Abdunklung in vier Streifen um das Ziel (`find_child(ui_target)`, sichtbar), einen
  pulsierenden Rahmen und einen Pfeil; Sprechblase unter/über/rechts/links vom Ziel – die erste Lage ganz in der
  Safe Area ohne Überlappung. Ziel fehlt → mittig + `push_warning`. Die Lage des Ziels wird jedes Bild geprüft
  (Fenster sortieren ihre Inhalte erst im nächsten Bild); `place()` legt sofort fest (Spielansicht `_layout()`,
  Tests). `GameScreen._open_due_tutorial()` nach `_refresh()`, nach dem Öffnen eines Orts, nach dem Schließen eines
  Fensters und nach „Später“: wartet, solange ein Ereignis offen ist, der Kalender oder die Erinnerung steht oder das
  Konflikt-Popup offen ist; über einem Ortsfenster darf es liegen. „Verstanden“ → `mark_seen`, speichern, nächstes.
- T.5: 13 Tutorials, 13 Auslöser (neu: `first_window_closed`, `first_action`, `first_conflict_popup`,
  `first_wait_offered`, `first_trip_offered`, `first_new_day` – gemeldet von Spielansicht, Ortsfenster, Kalender).
  `ui_target` mit „*“ → `TutorialOverlay.find_target()` nimmt das erste sichtbare passende Control. Steht ein
  vorrangiges Fenster (Ereignis/Kalender/Erinnerung) oder das Konflikt-Popup, zeigt `_open_due_tutorial()` nur ein
  Tutorial, dessen Ziel darin liegt; das Overlay liegt dann darüber (in `_layout()` nach dem Popup einsortiert).
  `close_tutorial()` schließt ohne „gesehen“ (Tests).
- T.6: 23 Tutorials, 22 Auslöser (neu u. a. `first_channel_open`, `first_company_open`, `first_ledger_open` aus der
  Spielansicht; `first_content_quality`, `first_equipment_offered`, `first_effect_symbols`, `first_company_offered`,
  `first_branch_offered` aus dem Ortsfenster; `first_settlement` über `CompanySystem.day_settled`). Wirkungs-Symbole
  heißen `TileChip_<Symbol>` (z. B. `TileChip_singleplayer`). `_open_due_tutorial()` nimmt das erste fällige Tutorial,
  dessen Ziel jetzt sichtbar ist (ohne Ziel: immer, außer über einem vorrangigen Fenster) – sonst wartet es; erneut
  geprüft bei jedem Anlass und beim Reiterwechsel (`check_tutorials()`). Höchstens `TUTORIAL_CHAIN_MAX` (3)
  hintereinander über „Verstanden“. Sprechblase: passt die volle Breite (560 px) nirgends, seitlich schmaler (ab 280 px).
- Schwarzgeld (U.1): drittes Konto `LedgerSystem.BLACK` („Schwarzgeld“) im einen Ledger – gleiche Regeln (nicht ins
  Minus, Schutzschlüssel), aber keine Umbuchung von oder zu ihm (`TRANSFER_ACCOUNTS` = privat, Firma).
  `is_account_used(konto)` steuert die Anzeige: HUD-Block `BlackBlock` („Schwarz“), im Buchungen-Fenster Stand,
  Filter „Schwarz“ und Wochenzeile erst, wenn es Buchungen gibt. `HudBar.fit_to(breite)` (aus `_layout()`): passt die
  Leiste nicht, Stufe 1 ohne Datum, 2 Beträge ab 1.000 € ohne Cent, 3 ohne die kleinen Beschriftungen. Tutorial-Auslöser
  `first_black_money` über `TutorialSystem.on_ledger_entry` (Signal `entry_posted`).
- Organisation (U.2, `scripts/systems/organisation_system.gd`, im GameState als `organisation`): `found(name)`
  (Name 2–24 Zeichen, Signal `founded` → Tutorial-Auslöser `first_organisation_founded`), `change({respect, heat,
  stability})` auf 0–100 begrenzt, ohne Gründung wirkungslos. DayCycle: Tagesabschluss → Organisation → Fristen →
  Ereignisse; `on_day_changed(tag)` senkt die Hitze um `heat_decay_per_quiet_day`, wenn am Vortag keine Hitze dazukam
  (jeder Tag einmal über `last_processed_day`). Regeln: `OrganisationRules` aus `data/underworld/organisation.json`
  (in `GameData.organisation`). HUD: `HeatBlock` (Flamme `assets/icons/flame.svg` + Zahl), sichtbar ab Gründung,
  Farbe über `OrganisationSystem.heat_level()` (ab 30 gelb, ab 60 rot – nur Anzeige).
- Einstieg in die Unterwelt (U.3): Ereignisse mit `trigger {"scripted": true}` kommen nur über
  `EventSystem.trigger_scripted(id, tag)` (Instanz "<id>@<tag>"). Das OrganisationSystem (Schritt im DayCycle) löst
  ab `intro.first_day` das Ereignis `underworld_intro` aus (`intro_state` none/declined → offered) und hört auf
  `event_resolved`: Annehmen-Option → „accepted“ (`needs_name()`), sonst „declined“ mit `next_offer_day` = heute +
  `retry_days`. Die Spielansicht öffnet nach dem Ereignis das nicht schließbare Fenster „organisation_name“
  (`organisation_name_window.gd`, LineEdit), gründet über `on_organisation_name_submitted()` → `found()`; Kalender,
  Erinnerung und Tutorial warten (`PRIORITY_WINDOWS`). Fenster „Organisation“ (`organisation_window.gd`: Balken + Zahl +
  Erklärung je Wert), Seitenbutton `OrganisationButton` (Gruppe Geschäft, sichtbar ab Gründung). Ereignis-Optionen
  können `note` haben (Folge ohne Zahl, ersetzt „Keine Folgen“). `GameData.check_references()` prüft das
  Einstiegs-Ereignis.
- Story-Aufträge (U.4, `scripts/systems/mission_system.gd`, im GameState als `missions`): Katalog
  `MissionCatalog` (`data/underworld/missions.json`: Kapitel, Titel, Auftraggeber, Briefing, Ziel, Zieltext,
  Debriefing, Belohnung in Organisationswerten, order, requires). `update_availability()` startet jeden Auftrag, dessen
  `requires` erledigt sind, sobald die Organisation steht – nach der Gründung, nach jedem Abschluss und nach dem Laden
  (so werden Aufträge, die ein Update anhängt, auch in alten Ständen aktiv). Zieltyp `visit_location` über
  `LocationSystem.traveled` (auch bei „Hinfahren und starten“). `count_unseen()` → roter Punkt am `MissionsButton`
  (Gruppe Geschäft, nach „Organisation“), Fenster `missions_window.gd` markiert alles als gesehen; Hinweise
  („Neuer Auftrag …“, „Auftrag erledigt … (Respekt +5)“) über `take_notices()` in `_after_action`. Gespeichert:
  `active`, `completed` (ID → Zeitpunkt), `unseen`.
- Produkte (U.5, `scripts/systems/product_catalog.gd`, Modell `product_definition.gd`, in `GameData.products`):
  `data/underworld/products.json` – id, Name, kurze Beschreibung, `buy_price_cents`, `sell_price_cents` (> Einkauf),
  `quality` 0–100, `heat_per_unit` 1–20, order; alles je abstrakter „Einheit“. Noch von keinem System genutzt
  (Einkauf U.6, Verkauf U.9, Nachfrage je Gebiet U.12).
- Lieferant und Bestand (U.6, `scripts/systems/supply_system.gd`, im GameState als `supply`): Lieferanten aus
  `SupplierCatalog` (`data/underworld/suppliers.json`: Produkte, Mengen, Lieferzeit, Ausfallrisiko, Freischalt-Auftrag).
  `check_order`/`order` (Vorkasse = Buchung, Kategorie `underworld_purchase`, Quelle `supply`, Konto über
  `payment_account()`: Schwarzgeld, wenn es reicht, sonst privat). DayCycle: Tagesabschluss → Organisation →
  Lieferungen → Fristen → Ereignisse; `roll(order_id)` = FNV-1a(Seed:Bestell-ID) % 100 < `failure_percent` → geplatzt
  (Geld weg), sonst Bestand += Einheiten (Signal `stock_changed` → Aufträge mit Ziel `have_stock`). Seed und
  Auftragsstand werden als Callable gelesen (kein Kreisverweis; Seed stimmt nach dem Laden). UI: Abschnitt „Ware“ +
  „Unterwegs“ + „<Lieferant> anrufen“ oben im Fenster „Organisation“, Fenster `supplier_window.gd` (−/+, Bestellen,
  „Bezahlt aus“, Bestand/unterwegs). Die Rückmeldung (Toast) wird in `_layout()` über ein offenes Fenster gelegt.
- Kredit und Schulden (U.7): Lieferanten mit `credit` (after_deliveries, max_units, markup_percent, due_days,
  grace_days, reminder_fee_percent, pressure_event, pressure_every_days). `SupplySystem.order_on_credit()` bucht nichts;
  am `debt_due_day` (Lieferungen-Schritt im DayCycle) → `ObligationSystem.add_one_off("debt_<bestellung>", …,
  Konto black, Fälligkeit = Tag 00:00)`: einmalige Frist (`obligation` = "one_off", eigene `grace_days` und
  `reminder_fee_cents`), automatisch bezahlt, wenn Schwarzgeld – ersatzweise Privatkonto (`_paying_account`) – reicht.
  Geplatzte Kreditlieferung → Schuld entfällt. Überfällig (nach grace_days) → `EventSystem.trigger_scripted(
  pressure_event)` höchstens alle `pressure_every_days`. Ereignis-Optionen können `organisation` {respect, heat,
  stability} haben (über `set_organisation_changer`, Callable). Tutorial-Overlay scrollt ein Ziel in einem
  ScrollContainer ins Bild (Lage relativ zum Inhalt, stabil).
- Justiz (U.21, `scripts/systems/justice_system.gd`, im GameState als `justice`; Regeln aus
  `data/underworld/justice.json` in `GameData.justice`): Zustand free/custody/bail/prison, Beweislage, Akte (von der
  Polizei), Prozess- und Entlassungstag. `PoliceSystem.set_after_raid(justice.after_raid)` (Festnahme nach Seed),
  `LocationSystem.set_travel_block(justice.travel_block)` und `place()` (Versetzen ohne Fahrzeit), Ort `prison` mit
  `only_when_here`. Ereignis-Optionsfeld `justice` → `set_justice_handler`; Platzhalter `{case}`, `{days}`,
  `{evidence}`, `{verdict}`. CrewSystem `sacrifice(loyalty_loss)`. DayCycle: … Polizei → Justiz (Prozess, Entlassung)
  → Fristen. `wait()` stellt die Zeit über das TimeSystem vor. Fenster `JusticeWindow`.
- Razzia (U.20, im PoliceSystem): Steht die Akte beim Tageswechsel auf 100 %, `_raid`: `SiteSystem.seize` (eigener
  Standort mit höchstem `risk`), `SupplySystem.remove_stock` (raid_stock_percent je Produkt), Buchung
  `underworld_confiscation` (raid_black_percent des Schwarzgelds), Akte 0, Stufe 1, Hitze −raid_heat_drop, dann
  `trigger_scripted("police_raid")` mit `{site}`, `{stock}`, `{money}`, `{case}`. `set_raid_targets(supply, sites)`
  (einseitig). Gespeichert: `raids`, `last_raid`.
- Polizei (U.19, `scripts/systems/police_system.gd`, im GameState als `police`; Regeln aus
  `data/underworld/police.json` in `GameData.police`): Stufe 0–2, Tage in Folge (heiß/ruhig), Akte (Nummer aus dem
  Seed, Fortschritt 0–100), Anwalt (Buchung `underworld_lawyer`, Wartezeit). DayCycle: … Rivalen → Polizei → Fristen
  → Ereignisse (nach allen Hitze-Änderungen des Tages). Stufenwechsel per `trigger_scripted` (`police_observation`,
  `police_investigation` mit `{case}`, `police_calm`). EventSystem: `add_condition_values` (Bedingung
  `min_/max_police_level`), `add_text_context`; CrewSystem: `set_arrest_bonus`.
- Weitere Standorte (U.18): `sites.json` mit `product`, `sale_units_per_day`, `laundering_limit_cents`,
  `supplier_discount_percent`, `max_level`, `upgrade_cost_cents`, `upgrade_percent`. SiteSystem: Stufen (`levels`,
  gespeichert), `effects()` (Werte auf der Stufe), `check_upgrade`/`upgrade`; DayCycle-Schritt der Standorte: erst
  Produktion (`SupplySystem.add_stock`, nur so viel Platz ist) und Verkauf (Buchung `underworld_site_sales`, Hitze),
  dann Mieten (auf der Stufe). Callables: `supply.set_discount(sites.supplier_discount_percent)`,
  `laundering.set_limit_bonus(sites.laundering_bonus)`; `sites.set_underworld(supply, organisation)` (einseitig).
  Neue Orte `club` und `finca` (mit `unlocked_by_mission`). Kachel: `GameScreen.on_site_pressed` (anmieten/ausbauen).
- Schwarzgeld ausgeben (U.17, `scripts/systems/black_spending_system.gd`, im GameState als `black_spending`; Regeln
  aus `data/underworld/black_spending.json` in `GameData.black_spending`): Schalter `enabled` (gespeichert),
  `account_for(cost)` (Schwarzgeld nur bei an, genug Geld und Tageslimit) und `record(cost, label)` (Tagesbetrag,
  Hitze, Hinweis). ActivitySystem und EquipmentSystem bekommen beide als gebundene Methoden
  (`set_black_spending`) und buchen auf das gewählte Konto; alle anderen Ausgaben bleiben unberührt.
- Waschen (U.16, `scripts/systems/laundering_system.gd`, im GameState als `laundering`; Regeln
  `LaunderingSystem.Rules` aus `data/underworld/laundering.json` in `GameData.laundering`): `check`/`launder` –
  Buchung `underworld_laundering` (Schwarzgeld −) und `laundered_revenue` (Firmenkonto + Betrag − Gebühr), Schlüssel
  `launder:<Tag>:<n>|out/in`, dann Hitze; Tageslimit über gespeicherten Tag und Tagesbetrag; keine Spielzeit.
  UI: Abschnitt im `OrganisationWindow` (`LaunderLess/More/Amount/Button`), `GameScreen.on_launder`.
- Crew-Folgen (U.15, im CrewSystem): Regeln `risks` in `crew.json`; nach den Löhnen `_check_risks` (je Mitglied ab
  `min_days`, Chancen aus Hitze, Polizei des Gebiets, Können, Gier − Loyalität, Bande im Revier; Seed, höchstens ein
  Vorfall je Tag) → `trigger_scripted` (`crew_arrest`, `crew_betrayal`, `crew_informant`, `crew_poached`), Kontext
  `_incidents[instance]` (gespeichert). EventSystem: Optionsfeld `crew` → `set_crew_handler`, Ereignistexte mit
  Platzhaltern über `add_text_context`/`get_text` (das Ereignisfenster nutzt `get_text`). `fire` ändert Stabilität,
  bei geringer Loyalität auch Hitze.
- Rivalen (U.14, `scripts/systems/rival_system.gd`, im GameState als `rivals`; Katalog `RivalSystem.Catalog` aus
  `data/underworld/rivals.json` in `GameData.rivals`): Zustand je Bande (Stärke, Beziehung neutral/conflict/truce,
  bis Tag) und Kontext der „Ärger“-Ereignisse (Instanz → Bande, Gebiet). `TerritorySystem.set_pressure_modifier`
  bekommt `rivals.pressure_percent`, `EventSystem.set_rival_handler` bekommt `rivals.apply_event_action` (gebundene
  Methoden, keine Zyklen). Ereignis-Optionen haben das Feld `rival` (fight/negotiate/retreat). DayCycle: … Crew →
  Gebiete → Rivalen (Ablauf, Erholung, Ärger per `trigger_scripted`) → Fristen → Ereignisse. Fenster `RivalsWindow`.
- Gebiete übernehmen (U.13, `scripts/systems/territory_system.gd`, im GameState als `territory`; Regeln
  `TerritorySystem.Rules` aus `data/underworld/territory.json` in `GameData.territory`): Einfluss und eigene Gebiete
  je District-ID. Das CrewSystem bekommt Callables (`add_influence`, `unit_bonus`, `influence_for_skill`,
  Gebietsdefinition) – keine gegenseitige Referenz; Crew-Mitglieder haben `district`. DayCycle: … Standortkosten →
  Crew (Abrechnung bringt Einfluss, eigene Gebiete +Einheiten) → Gebiete (Druck der Rivalen, Verlust) → Fristen …
  `check_claim`/`claim` (Buchung, Respekt, Signal `claimed` → Aufträge mit Ziel `control_district`). UI:
  `DistrictWindow` (Tipp auf `DistrictLabel_*`), `CrewDistrictButton_*` wechselt das Gebiet, Karte
  `set_controlled_districts`.
- Gebiete und Unterwelt-Ansicht (U.12): `scripts/systems/district_catalog.gd` (in `GameData.districts`,
  `data/underworld/districts.json`: Fläche `area` und Schildzelle `label_cell` auf dem Kartenraster, Farbe,
  Nachfrage/Polizei/Rivalen 0–100, keine Überschneidungen). Noch kein Spielzustand (Übernehmen mit U.13).
  `CityMap.set_underworld_view()` färbt beim Zeichnen um (`draw_texture(…, modulate)`, dunkles Meer, Neon-Rand um
  Orte aus `GameState.underworld_location_ids()`, Gebietsflächen auf Boden-Kacheln, Schilder `DistrictLabel_*`);
  Streamer-Schilder halbtransparent, aber antippbar. `GameScreen`: Gruppe „ANSICHT“ unten rechts mit
  `ViewToggleButton`/`ViewToggleButtonDay` (nur nach Gründung der Organisation), Signal `view_changed` → App speichert
  `Settings.UNDERWORLD_VIEW` (Geräte-Einstellung, kein Spielstand: reine Optik).
- Crew (U.10, `scripts/systems/crew_system.gd`, im GameState als `crew`): Katalog `CrewSystem.Catalog`
  (`data/underworld/crew.json`: Freischalt-Auftrag, `max_members`, `applicants_per_day`, Namenslisten, Rollen mit
  Lohnspanne). Bewerber werden nicht gespeichert, sondern aus `fnv1a(Seed:crew:Tag:Platz)` berechnet (gleich nach dem
  Laden); gespeichert sind nur Mitglieder, heute gefeuerte Bewerber (`gone_today`) und der verarbeitete Tag.
  `hire`/`fire` sofort (keine Spielzeit); Signal `hired` → Aufträge mit Ziel `crew_role`. DayCycle: … Standortkosten →
  Löhne → Fristen …: eine Buchung `underworld_wages` für alle (Schwarzgeld, sonst privat), sonst `add_one_off`.
  Fenster `CrewWindow` (Button „Crew (N)“ im Organisations-Fenster).
  U.11: Rollen haben `offered` (nur angebotene kommen als Bewerber); Regeln `dealing` und `promotion` in `crew.json`.
  `on_day_changed`: erst `_settle_dealers` (Dealer, vor dem Tag eingestellt, verkaufen `dealer_units` aus dem Bestand,
  Produkte in Katalogreihenfolge → eine Buchung `underworld_street_sales` aufs Schwarzgeld, Gier zweigt
  `skim_percent` ab, Hitze × `heat_percent` → `organisation.change`), dann Löhne, dann Loyalität (+/−).
  `check_promote`/`promote`: Buchung, dann Rang/Können/Loyalität/Lohn.
- Verkaufen (U.9, `scripts/systems/sale_system.gd`, im GameState als `sales`): Katalog `SaleSystem.Catalog`
  (`data/underworld/sale_spots.json`: Ort, Freischalt-Auftrag, Minuten, höchstens Einheiten je Verkauf, Preis- und
  Hitze-Prozent). `check_open` (Kachel), `check_sale`/`sell`: vor Ort, Organisation gegründet, Auftrag erledigt,
  Bestand reicht → `SupplySystem.remove_stock` → Buchung `underworld_sale` aufs Schwarzgeld → `organisation.change`
  (Hitze = Einheiten × `heat_per_unit` × Prozent) → `time.advance`. Signal `sold` → Aufträge mit Ziel `sold_units`
  (Gesamtzahl verkaufter Einheiten, gespeichert als `sales.sold_units`). Ortsfenster: Kachel nur, wenn verfügbar;
  `SaleWindow` (Ware, Menge, „Verkaufen“) ruft `GameScreen.on_sale` (mit Konflikt-Popup).
- Standorte (U.8, `scripts/systems/site_system.gd`, im GameState als `sites`): Katalog `SiteCatalog`
  (`data/underworld/sites.json`, Felder nach Leitfaden 9.3: Typ, Ort, Freischalt-Auftrag, Start- und laufende Kosten,
  Aufbauzeit, Kapazität, Personalplätze, Produktivität, Risiko, Aktivitäten, Voraussetzungen). `check_acquire`/`acquire`
  (vor Ort, Buchung, dann `setup_minutes` Spielzeit; Signal `site_acquired` → Aufträge mit Ziel `own_site`). DayCycle:
  … Lieferungen → Standortkosten → Fristen …: je eigenem Standort eine Buchung (Schwarzgeld, sonst privat), sonst
  `add_one_off` (Frist). `capacity()` = 20 + Kapazitäten → `SupplySystem.check_space()` (Bestand + unterwegs).
  Orte mit `unlocked_by_mission` (Ortsdaten) sind bis dahin unbekannt: `LocationSystem.is_known()` (Callable auf
  MissionSystem), `check_travel` sperrt, `CityMap.set_hidden_locations()` blendet Schild und Gebäude aus (Haus statt
  Gebäude). Ortsfenster: Standort-Kachel (Reiter „Unterwelt“) mit „Anmieten“; Fenster „Organisation“: Platz und eigene
  Standorte.
- Ortsbeschreibung (T.6b): `ui_window.gd` macht den Titel antippbar, wenn der Inhalt `get_description()` hat
  (`WindowTitleButton`, ≥ 84 × 84 px, Signal `title_pressed`); die Spielansicht zeigt `LocationInfo` (fängt jeden Tipp
  und schließt) mit `LocationInfoBubble` unter dem Titel, in die Safe Area geschoben. Kein Tooltip mehr.
- Abdeckung (T.7): `scripts/models/mechanics.gd` (`NAMES`: Mechanik-ID → Name) ist die feste Liste;
  `tests/test_tutorial_coverage.gd` prüft Mechanik ↔ Tutorial in beide Richtungen und dass jeder Auslöser im Spielcode
  gemeldet (`report("…")` / `report.bind("…")`) und von einem Tutorial genutzt wird.
- Einstellungen und Lexikon (T.4): Geräte-Schalter `tutorials` (settings.cfg, Standard an) → `GameScreen.show_tutorials`;
  aus = `_open_due_tutorial()` zeigt nichts, das TutorialSystem merkt weiter. „Tutorials zurücksetzen“ →
  `App._reset_tutorials()` → `TutorialSystem.reset_seen()` (gesehen und `seen_triggers` leer, `first_game_start` gilt als
  gemeldet) im Spiel im Speicher oder im geladenen Spielstand, dann speichern. „Hilfe / Lexikon“
  (`scripts/ui/lexicon_screen.gd`, seit T.5 eigener Bildschirm über die Safe Area: Titelzeile mit rundem
  Schließen-Button, darunter `LexiconScroll`): `TutorialSystem.get_seen()` in Spielreihenfolge (order, ID), Titel als
  Button, Antippen klappt den Text auf. Button-Stile: `UiStyle.style_neutral_button`, `style_danger_button`.
- TutorialSystem (T.2, `scripts/systems/tutorial_system.gd`, im GameState als `tutorials`): `report(trigger)` merkt
  einen Auslöser (unbekannte → Fehler, nichts passiert; mehrfach schadet nicht; Signal `tutorial_due` beim ersten
  Mal). Fällig (`get_due()`, nach `order`): Auslöser gemeldet, nicht gesehen, alle `requires` gesehen.
  `mark_seen(id)` bestätigt – erst dann kommt es nicht wieder. Melder: App (`first_game_start` bei „Neues Spiel“),
  Spielansicht (`first_location_open`, `first_location_elsewhere`, `first_calendar_open`,
  `first_appointment_reminder`), Systeme über Signale (`event_triggered` → `first_event`, `obligation_due` →
  `first_obligation_due`; als gebundene Methode, nicht als Lambda – sonst Kreisverweis). Kostet keine Zeit, kein Geld.
  Gespeichert (Version 15): `tutorials` = {`fired`, `seen`, `seen_triggers`} – Tutorials mit einem Auslöser aus
  `seen_triggers` gelten als gesehen.

### Termine (`data/appointments/appointments.json`, `AppointmentCatalog`, `AppointmentSystem`)
- Daten: `id`, `title`, optional `description`, `location`, `start` {`day`, `hour`, optional `minute`},
  `duration_minutes` (> 0), optional `money_cents`/`category`/`effects` (beim Wahrnehmen),
  `missed_effects` (Pflicht, `mood` < 0).
- `check(id)` / `attend(id)`: nur vor Ort, ab 1 h vor Beginn bis Beginn. Ausführung: Status setzen →
  Buchung (`source = "appointment"`, `idempotency_key = "appointment:<id>"`) → Effekte →
  `time.advance(warten bis Beginn + Dauer)`.
- Verpassen: auf `time_advanced(from, to)` wird jeder offene Termin mit Beginn < `to` verpasst,
  `missed_effects` genau einmal angewendet; `take_missed_notices()` liefert sie einmal für die Anzeige.
- `get_conflicts(minuten)`: offene Termine, deren Beginn eine Aktion überspringen würde. Die UI fragt dann per
  Konflikt-Popup nach (G5.4). `conflict_warning(minuten)` liefert denselben Befund als Text (nur noch in Tests genutzt).
- Warten bis Terminbeginn (G5.5): `offers_wait(id)` (offen, heute, noch nicht begonnen → die UI zeigt den Button),
  `check_wait(id)` (Grund oder "", z. B. „Erst hinfahren: Studio“), `wait_until_start(id)` = nur
  `time.advance(bis Beginn)` – kein Geld, keine Werte; Ereignisse, Fristen und Tagesabschlüsse in der Wartezeit laufen
  normal. Bei Ankunft genau zum Beginn gilt der Termin nicht als verpasst (verpasst nur bei Beginn < `to`).
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

### Fristen (`data/obligations/obligations.json`, `ObligationCatalog`, `ObligationSystem`, Phase 5)
- Daten: `id`, `display_name`, `description`, `account`, `category`, `requires` („company“), `schedule` {`weekday`,
  `first_day` ≥ 2}, `amount` {`fixed_cents`} oder {`profit_percent`}, `grace_days`, `reminder_fee_cents`,
  `overdue_effects`, `overdue_company_effects`.
- `on_day_changed(tag)` (vom DayCycle, nach dem Tagesabschluss): für jede Frist mit passendem Wochentag ab
  `first_day` genau eine Instanz `<frist>@<tag>` (fällig Tag 00:00). Betrag fest oder Prozent vom positiven
  Vorwochen-Ergebnis (`LedgerSystem.summarize`); 0 € → Status `waived`. Gedeckt → sofort gebucht (Quelle
  `obligation`, Schutzschlüssel `obligation:<instanz>`, Wertstellung = Fälligkeit, Status `paid`), sonst `open`.
- Überfällig (5.3): offen länger als `grace_days` nach dem Fälligkeitstag → einmal gemahnt (`reminded`):
  `fee_cents` += Mahngebühr (nicht gebucht!), `overdue_effects` auf PlayerStats bzw. `overdue_company_effects`
  über `CompanySystem.apply()` mit Begründung „Mahnung: …“. `check_pay()` / `pay()`: nur mit vollem offenem
  Betrag; bucht Grundbetrag (Wertstellung = Fälligkeit) und Mahngebühr (Kategorie `reminder_fee`, `…:fee`).
- `get_instances()`, `get_open()`, `count_open()`, `open_amount()`, `take_notices()` (Hinweise je einmal).
- Gespeichert: `last_processed_day`, `instances` (offene immer, erledigte bis 100).

### Speichern/Laden (`scripts/systems/save_system.gd`)
- Datei `user://savegame.json` (JSON, lesbar). Inhalt: `{"version": 22, "meta": {…}, "game": GameState.to_dict()}`.
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
- Migration 11 → 12: Frist-Instanzen bekommen leere `account`/`category`/`label`; `ObligationSystem.restore()`
  ergänzt sie aus den Daten oder setzt Ersatzwerte (privat, „obligation“, ID).
- Migration 10 → 11: Fristen leer, `last_processed_day` = gespeicherter Tag.
- Migration 12 → 13 (G5.3): `day_start` = {`calendar_shown_day`: gespeicherter Tag} – der Kalender für den Tag des
  alten Stands gilt als gezeigt, ab dem nächsten Tageswechsel öffnet er sich wie gewohnt.
- Migration 33 → 34 (U.21): `justice` = frei, Tag verarbeitet.
- Migration 32 → 33 (U.20): `police.raids` = 0, `police.last_raid` = {}.
- Migration 31 → 32 (U.19): `police` = Stufe 0, Tag verarbeitet.
- Migration 30 → 31 (U.18): `sites.levels` = {} (eigene Standorte auf Stufe 1).
- Migration 29 → 30 (U.17): `black_spending` = Schalter aus.
- Migration 28 → 29 (U.16): `laundering` = nichts gewaschen.
- Migration 27 → 28 (U.15): `crew.incidents` = {}.
- Migration 26 → 27 (U.14): `rivals` = alle neutral in Ausgangsstärke, Tag verarbeitet.
- Migration 25 → 26 (U.13): `territory` leer (Tag verarbeitet), Crew-Mitglieder `district` = "".
- Migration 24 → 25 (U.11): Crew-Mitglieder bekommen `rank` = 1.
- Migration 23 → 24 (U.10): `crew` = keine Mitglieder, gespeicherter Tag gilt als verarbeitet.
- Migration 22 → 23 (U.9): `sales` = {`sold_units`: 0}.
- Migration 21 → 22 (U.8): `sites` = keiner angemietet, gespeicherter Tag gilt als verarbeitet.
- Migration 20 → 21 (U.7): Bestellungen bekommen `credit` = false und leere Schuldfelder; `last_pressure_day` = 0,
  `delivered_before_trim` = {}.
- Migration 19 → 20 (U.6): `supply` = kein Bestand, keine Bestellungen, gespeicherter Tag gilt als verarbeitet.
- Migration 18 → 19 (U.4): `missions` = leer; ist die Organisation gegründet, startet die Kette beim Laden.
- Migration 17 → 18 (U.3): `organisation.intro_state` = „none“ (bzw. „done“, falls gegründet), `next_offer_day` = 2 –
  der Einstieg kommt beim nächsten Tageswechsel.
- Migration 16 → 17 (U.2): `organisation` = nicht gegründet, Startwerte der Standardregeln, gespeicherter Tag gilt
  als verarbeitet.
- Migration 15 → 16 (U.1): `ledger.opening_balances.black` = 0 (Schwarzgeld-Konto ohne Buchungen).
- Migration 14 → 15 (T.2): `tutorials` = {`fired`: [], `seen`: [], `seen_triggers`: [„first_game_start“]} – wer
  schon spielt, bekommt keine Spielstart-Erklärungen; alle anderen Tutorials kommen normal.
- Migration 13 → 14 (G5.6): `reminders` = {`reminded`: [], `reminded_until_minutes`: gespeicherte Zeit + 30} – Termine,
  deren Beginn schon höchstens 30 Spielminuten entfernt ist, gelten als erinnert (keine nachträgliche Erinnerung).
- Migration 9 → 10: Wertstellung = Buchungszeit; Tagesabschlüsse (`company`, `day:<t>`) auf Tag t, 23:59.
- Schreiben (Phase 6): `.tmp` schreiben und wieder einlesen → wenn eine Hauptdatei existiert, Backups rotieren
  (`.bak2` → `.bak3`, `.bak` → `.bak2`, Hauptdatei → `.bak`) → `.tmp` nach `savegame.json`. Nie während eines
  Zeitfortschritts. Kopf `meta` (optional): App-Version, Speicherzeit, Spieltag, Uhrzeit, Privatkonto, `data_id`
  (`GameData.fingerprint`); `read_meta()` liest ihn ohne zu laden.
- Nach `GameState.restore()` prüft `scripts/core/consistency_check.gd` Regeln über System-Grenzen; Verletzung =
  wie defekt (aufbewahren, nächstes Backup). Entfernte Daten regeln die Systeme tolerant und melden es über
  `restore_notices`; `GameState.load_notices()` sammelt sie, das Ladeergebnis enthält `notices`, die App zeigt sie.
- Laden (Phase 6): gültige liegengebliebene `.tmp` (dann Speichern zu Ende führen), sonst Hauptdatei, `.bak`, `.bak2`,
  `.bak3`. Defekte Dateien → `<name>.corrupt-<zeit>.json` (höchstens 3, `corrupt_files()`), neuere Versionen bleiben
  unberührt. Ergebnis zusätzlich `source` und `corrupt_kept`. Früher: Hauptdatei, sonst Backup. Fehlende Datei = kein Spielstand (kein Fehler). Beschädigt,
  ungültig oder neuere Version → verständliche Meldung, nichts wird übernommen.
- Neue Formatversion: `SAVE_VERSION` erhöhen, in `_run_migration()` einen Schritt n → n + 1 ergänzen und eine
  echte Testdatei `tests/fixtures/saves/v<neu>.json` anlegen (Erzeuger `tests/fixtures/make_save.gd`, README).
  `tests/test_save_fixtures.gd` lädt alle Versionen, prüft Kernwerte und spielt eine Woche weiter.
- Bekannte Grenze: Ein Ereignis, das erst nach dem Speichern zu den Daten hinzukommt und dessen
  Zeitpunkt schon vorbei ist, wird in diesem Spielstand nie ausgelöst.

### UI (`scenes/app/app.tscn`, `scripts/ui/`)
- `app.gd` (Hauptszene): Theme, Safe Area (nur auf Mobilgeräten, in Viewport-Koordinaten umgerechnet;
  `safe_margins()` statisch und getestet; übernimmt die Safe Area je Seite so, wie iOS sie meldet – seit G4.2
  läuft das Spiel nur in EINER Querformat-Richtung, Dynamic Island links). Querformat (G2): Bildschirme mit `set_safe_margins(abstände)`
  bekommen die volle Fläche (z. B. Vollbild-Karte), alle anderen liegen als zentrierte Spalte
  (`UiStyle.COLUMN_WIDTH`) in einem Scrollbereich (`MenuScroll`) innerhalb der Safe Area,
  hält die laufende `GameState`-Sitzung und wechselt zwischen `main_menu.gd` und `game_screen.gd`.
- UI wird im Code aus Containern gebaut (keine festen Pixelpositionen). Farben/Größen in `ui_style.gd`,
  Texte für Aktivitäten/Beträge in `activity_text.gd`.
- Schriftzug „OFF CAMERA“ (G3.3): Baustein `logo.gd` (Bebas Neue, OFL) im Hauptmenü; dasselbe Bild als Startbild
  (`assets/splash/splash.png`, erzeugt von `tools/splash/make_splash.gd`).
- Spielansicht im Querformat (G2, `game_screen.gd`): Stadtkarte im Vollbild (auch unter Notch/Home-Balken),
  darüber innerhalb der Safe Area: `HudBar` (G4.3, `hud_bar.gd`: schmale Leiste über die volle Breite – links Tag,
  Uhrzeit, Ort; rechts Energie und Stimmung als Icon + Balken + Zahl, Privat- und Firmenkonto), runde Buttons
  (G4.4, `round_button.gd`: Kreis 64 px, Tippfläche 84 px, Beschriftung, roter Zählerpunkt) rechts in zwei Gruppen
  `LifeGroup` (Kalender, Fristen, Kanal) und `BusinessGroup` (Firma nach der Gründung, Buchungen; ab U Organisation,
  Aufträge), `MenuButton` als Zahnrad in der Leiste, links unten nur `HereButton`,
  unten zwischen „Hier“ und den Spalten der Hinweis `Toast` (`FeedbackLabel`; kurze Texte ca. 4 s und lassen Tipps auf die
  Karte durch, lange/mehrzeilige bleiben bis zum Antippen).
- Ortsfenster (G4.5, `windows/location_window.gd` + `activity_tile.gd`): unter der HUD-Leiste über die volle Breite der
  Safe Area (seit G4.7; die Button-Spalten liegen abgedunkelt darunter); Infos und „Hinfahren“ in der Titelzeile
  (`take_header_extra()`, von `ui_window.gd` eingebaut), darunter ein `GridContainer` mit 3–4 Spalten
  (`set_available_size()` vom GameScreen, Kacheln mind. `UiStyle.TILE_MIN_WIDTH` breit). Jede Kachel: Name,
  „Dauer · Ende HH:MM“ (`ActivityText.duration_with_end`), Wirkungs-Chips (`ActivityText.effect_chips`), feste
  Hinweiszeile, Button mit Sperrgrund; Käufe mit Rahmen-Button. G4.5b: Kachel-Buttons (`UiStyle.style_tile_button`)
  sind 84 px hoch (Tippfläche), gezeichnet werden nur die unteren 56 px (negative `expand_margin_top`); Hinweiszeile
  und Button liegen übereinander im `ActionArea`. Lesetext ≥ `UiStyle.MIN_READ_FONT_SIZE` (21 px).
  G4.6 Reiter: Jede Aktion an einem Ort hat in den Daten das Pflichtfeld `tab` (IDs in `models/location_tab.gd`,
  geprüft von `DataReader.tab_field`). `set_available_size()` misst synchron (Container sortieren, Umbrüche setzen),
  ob alle Kacheln in die sichtbare Höhe (`UiWindow.body_height()`) passen; sonst erscheinen Reiter in der Titelzeile
  (`LocationTabs`, nur nicht leere, feste Reihenfolge) und das Raster zeigt nur die Kacheln des gewählten Reiters.
  Die Wahl ist reine Anzeige (nicht im Spielstand), das Fenster öffnet immer auf dem ersten Reiter.
- Tippflächen und Schrift (G4.7): Alles Tippbare ist mindestens `UiStyle.TOUCH_SIZE` (84 px ≈ 44 pt) groß. Wo ein
  Button sichtbar kleiner bleiben soll (Kartenschilder, Buchungen-Filter, Kachel-Buttons, Reiter, „Hinfahren“),
  zeichnen die Styleboxen mit negativer `expand_margin` nur einen Teil (`UiStyle.grow_touch_area`,
  `style_tile_button`, `style_tab_button`, `style_accent_touch_button`). Lesetext ≥ `MIN_READ_FONT_SIZE` (21 px),
  Mini-Beschriftungen (`UiStyle.mini_label`, Meta `mini_caption`) ≥ `MINI_FONT_SIZE` (19 px). Runde Buttons mit
  Beschriftung sind mindestens so breit wie diese. Die HUD-Leiste ist voll deckend (`HUD_BAR_SURFACE`).
  `tests/test_touch_and_fonts.gd` prüft das für Spielansicht und jedes Fenster auf allen 4 Geräteklassen.
- Geräte-Einstellungen (G5.1, `scripts/core/settings.gd`): eigene Datei `user://settings.cfg` (ConfigFile, Abschnitt
  `device`), getrennt vom Spielstand und ohne Version. Die App lädt sie beim Start (`App.settings`, Pfad
  `App.settings_path` für Tests) und reicht sie an die Einstellungsseite. Schalter: `calendar_auto_open` (ab G5.3),
  `vibration` (ab G5.9), Standard jeweils an. Laden ist fehlertolerant (fehlend/kaputt → Standardwerte, kaputte Datei
  bleibt liegen, unbekannte Schlüssel und falsche Typen werden ignoriert); Speichern atomar (.tmp → umbenennen).
- Start (G5.1b): Hauptszene ist der leichte Ladebildschirm `scenes/boot/loading.tscn` (`scripts/ui/loading_screen.gd`,
  hängt nur an UiStyle und `safe_area.gd`). Er lädt je Bild einen Schritt: App-Szene per
  `ResourceLoader.load_threaded_request`/`load_threaded_get_status`, Spieldaten (`GameData.load_all`), Kartengrafiken
  (`CityMap.texture_paths()`, ebenfalls im Hintergrund), Spielstand-Kopf. Fortschritt = Gewicht der fertigen Schritte +
  Anteil im laufenden Schritt, nie rückwärts. Danach instanziiert er die App, übergibt `preloaded_data` und
  `preloaded_resources` (hält die Grafiken im Cache) und wird freigegeben. Fehler → Meldung im Ladebildschirm.
  Zeitstempel als „[Start] … ms“ im Log. Safe-Area-Rechnung liegt in `scripts/ui/safe_area.gd` (App nutzt sie mit).
  G5.1c: Die Schritte „app“ und „warmup“ bauen die App (Hauptmenü) bzw. einen Probe-Spielbildschirm (neues Spiel nur im
  Speicher) unter dem Ladebildschirm auf (gleicher Eltern-Knoten, davor in der Reihenfolge = darunter gezeichnet) und
  lassen sie je `WARM_FRAMES` Bilder zeichnen; der Probe-Bildschirm wird danach freigegeben. Am Ende entfernt sich der
  Ladebildschirm nur noch (ohne Mindestdauer, so schnell wie möglich). Die Karte teilt ihre gepackten Grafiken
  (`CityMap._shared_textures`). `scripts/ui/start_log.gd` schreibt die „[Start]“-Zeilen (Hauptmenü, Tipp, Spielstand
  geladen, Spielbildschirm) und die Bildzeiten danach, bis ein Bild < 50 ms dauert.
- Kalender bei Tagesbeginn (G5.3, `scripts/systems/day_start_system.gd`, im GameState als `day_start`, im Spielstand
  seit Version 13): merkt den zuletzt „gezeigten“ Tag. `take_calendar_due(auto_open)` ist genau einmal je Tag wahr
  (über übersprungene Tage einmal für den aktuellen) und merkt den Tag auch bei ausgeschaltetem Geräte-Schalter. Die
  Spielansicht fragt es in `_refresh()` erst, wenn kein Ereignis offen ist, und öffnet dann den Kalender (ersetzt ein
  offenes Fenster). Neues Spiel: Tag 1 gilt als gezeigt. Kostet keine Spielzeit.
- Vibration (G5.9, `scripts/core/haptics.gd`, gehört der App als `haptics`): `attach(game)` hört auf
  `LedgerSystem.entry_posted` (Betrag ≥ ±100 €, Umbuchungen ausgenommen), `appointment_missed`, `obligation_due`,
  `obligation_reminded`, `event_triggered`; die Spielansicht meldet Konflikt-Popup und Erinnerung über `warn()`.
  Vibriert (`Input.vibrate_handheld(60)`) nur bei Schalter „Vibration“ an, höchstens einmal je 1,5 s
  (`LOCK_MSEC`, echte Zeit), nicht solange `quiet` (Aufbau der Spielansicht nach Laden/Neues Spiel). `count`/`history`
  zählen für Tests; Uhr und Ausgabe sind austauschbar. Kein Spielstand.
- Zählerpunkte und Balkenfarben (G5.8): `RoundButton.set_badge(n)` – roter Punkt mit Zahl in Mini-Schrift (19 px),
  ab 10 „9+“ (breitere Pille), oben rechts außerhalb des Symbols. Die Spielansicht setzt in `_refresh()` (nach jeder
  Aktion, Fahrt, Warten und beim Laden) Kalender = `DayPlan.count_upcoming_today()` (Termine heute im Zustand
  „als Nächstes“/„anstehend“) und Fristen = `ObligationSystem.count_open()` (Instanzen entstehen erst bei
  Fälligkeit, offen = fällig oder überfällig). HUD-Balken: `PlayerStats.level_of(wert)` (LOW_BELOW 40,
  CRITICAL_BELOW 20) → `HudBar.bar_color()` normal / `UiStyle.WARNING` / `UiStyle.BADGE`; die Zahl bleibt daneben.
- „Hinfahren und starten“ (G5.7, `scripts/systems/trip_system.gd`, im GameState als `trips`, ohne Zustand): für
  Aktivitäten, Content, Gründung und Filiale an einem anderen Ort (`offers`). `check(kind, id)` prüft die Aktion so,
  als wäre man angekommen – die Systeme haben dafür `check_on_arrival(id, start)` bzw.
  `check_found_on_arrival`/`check_open_branch_on_arrival` (gleiche Regeln wie `check()`, nur ohne „Nur vor Ort“ und
  mit den Öffnungszeiten ab der Ankunft). `run()` = `locations.travel()` + normale Aktion; Rückgabe
  {`arrived`, `reason`} – scheitert die Aktion nach der Fahrt, ist man trotzdem dort. Die Spielansicht fragt vorher
  das Konflikt-Popup mit der Gesamtzeit (`total_minutes`) und speichert auch bei „angekommen, aber gescheitert“.
  Kachel: Auto + „20 min + 2 h“, Hinweiszeile „Ende 15:00“ (oder der Konflikt), Button „Hinfahren und starten“ mit
  Auto; sonst der Grund im Button. Käufe haben keine Kombi. „Hinfahren“ in der Titelzeile: `UiStyle.style_travel_button`.
- Erinnerung vor Terminen (G5.6, `scripts/systems/reminder_system.gd`, im GameState als `reminders`, im Spielstand seit
  Version 14 mit `reminded` und `reminded_until_minutes`): `take_due()` liefert einen offenen Termin, der in 1–30
  Spielminuten beginnt, genau einmal je Termin; `describe(id)` liefert Name, Beginn, Ort, Fahrzeit vom aktuellen Ort,
  „dort“ und `on_time` (jetzt + Fahrzeit ≤ Beginn). Springt eine Aktion über das Fenster, ist der Termin verpasst –
  keine Erinnerung. Die Spielansicht fragt nach Ereignis und Kalender (`_open_due_reminder()`, auch nach dem Schließen
  eines Fensters) und zeigt `reminder_window.gd` als kleines Fenster mittig: „Du schaffst es noch“ / „Du kommst zu
  spät: Fahrt 20 min“, „Hinfahren“ oder „Warten bis HH:MM“, „Später“. Kostet keine Spielzeit.
  Gebäude/Schild antippen öffnet das Fenster des Orts; „Hier“ zentriert die Karte auf den aktuellen Ort und öffnet ihn.
  Icons der Seitenbuttons als Tabelle `ICONS` (Kenney „Game Icons“, CC0); fehlt eine Datei, bleibt nur der Text.
- Fenster (`scripts/ui/windows/`): `ui_window.gd` ist der Rahmen (Titel, „Schließen“, eigener Scrollbereich,
  Tippen vs. Scrollen: > 12 px Bewegung zwischen Antippen und Loslassen = Scrollen). Inhalte mit `setup()`,
  `get_title()`, `refresh()`: `location_window.gd` (Details, „Hinfahren“, Content, Aktivitäten, Ausrüstung,
  Gründung, Filiale – an fremden Orten sichtbar, aber gesperrt mit dem Grund aus `check()`; G5.5: vor Ort steht beim
  nächsten Termin heute „Warten bis HH:MM“ bzw. danach „Wahrnehmen“ in der Titelzeile),
  `calendar_window.gd` (G5.2: Tagesplan als Zeitstrahl aus `scripts/core/day_plan.gd` – Termine und Fristen des Tages,
  sortiert, mit Zustand, Fahrzeit und Platz der Jetzt-Linie; „Wahrnehmen“; G5.5: „Warten bis HH:MM“, gesperrt mit Grund), `obligations_window.gd` (Fristen: offen/Mahngebühr/Bezahlen, nächste Fälligkeiten),
  `channel_window.gd` (Kanal + Verlauf), `company_window.gd` (Unternehmen,
  Tagesabschlüsse, Verlauf, Einlage/Entnahme), `ledger_window.gd` (Wochenübersicht je Konto nach Wertstellung, Buchungen, Filter alle/privat/Firma),
  `event_window.gd` (offenes Ereignis, nicht schließbar). Immer nur ein Fenster, Karte dahinter abgedunkelt
  (`Dim`, Tippen schließt). Aktionen laufen über öffentliche Handler des GameScreens (`on_activity_pressed()` …),
  der nach jeder Aktion `_refresh()` aufruft (HUD, Karte, offenes Fenster, Ereignis) – nicht über System-Signale.
- Buttons aktivieren/deaktivieren sich ausschließlich über die `check()`-Funktionen der Systeme.
- Stadtkarte (Grafik-Ticket G1), nur Darstellung:
  - `city_layout.gd` (RefCounted, ohne Szene testbar): festes isometrisches Raster 15 × 15 plus Umland;
    Straßen auf den Zeilen/Spalten 1, 5, 9, 13 (13 = Strandpromenade), darunter Strand und Meer.
    Jeder Ort kommt auf das nächste freie Grundstück an einer Straße (aus `map_position`, deterministisch).
    `travel_path()` = Breitensuche über Straßen; Projektion `cell_to_world()` (Kachel 132 × 66).
  - `city_map.gd`: zeichnet in `_draw()` nach dem Maleralgorithmus (nur sichtbare Zellen). Zoom 0,5–1,0
    (Start 0,75) per Zwei-Finger-Geste (`InputEventScreenTouch/Drag`), Trackpad (`InputEventMagnifyGesture`)
    oder Mausrad; der Punkt unter den Fingern bleibt stehen. `center_on(ort)` für „Hier“.
    Namensschilder sind Buttons `MapPin_<id>`; Tippen aufs Gebäude wählt ebenfalls aus.
    `mouse_filter = STOP`: Wischen verschiebt nur die Karte (ab 12 px kein Tipp mehr), Grenzen = Stadt inkl. Strand.
    `play_travel(von, nach)` animiert ein Taxi entlang der Straßen (Tween, 0,8–2,5 s) und schwenkt die Kamera mit;
    aufgerufen vom GameScreen erst nach erfolgreichem `LocationSystem.travel()`. `LocationMarker` wippt über dem aktuellen Ort.
  - Beim Start werden alle Kartengrafiken in einen Texturatlas gepackt (`_pack_atlas()`, `AtlasTexture`), damit Godot
    Zeichenaufrufe bündelt. Die Standortmarkierung wippt nur 3 s nach `restart()` (Stromsparmodus).
  - Gebäudeaussehen je Orts-ID als Tabelle `BUILDINGS`; Grafiken unter `assets/kenney/` (CC0, je mit `License.txt`).
    Fehlt eine Grafik, wird das Teil ausgelassen statt abzustürzen.
- Kollision mit Termin (G5.4, `conflict_popup.gd`): `GameScreen._guard()` fragt `get_conflicts()` und zeigt bei
  Treffern ein Popup über allem – Aktion mit Dauer und Ende, alle betroffenen Termine (Name, Uhrzeit, Ort) und die
  Kosten des Verpassens aus den Daten; „Abbrechen“ ändert nichts, „Trotzdem starten“ führt die Aktion genau einmal
  aus. Gilt für Aktivitäten, Content, Fahrten, Gründung, Filiale und Termine.
- Offenes Ereignis: Fenster `Window_event` (Inhalt `EventPanel`) ersetzt jedes andere Fenster und sperrt die
  Karte, bis eine Option gewählt ist.
- Automatisch gespeichert wird beim Start eines neuen Spiels, nach jeder erfolgreichen Aktion
  (`GameScreen.state_changed`), beim Wechsel ins Menü und bei `NOTIFICATION_APPLICATION_PAUSED`,
  `…_FOCUS_OUT` und `NOTIFICATION_WM_CLOSE_REQUEST`. Speicherfehler erscheinen als Hinweis.
- Hauptmenü: „Fortsetzen“ mit Kurzinfo aus dem Spielstand-Kopf (`SaveInfoLabel`, `App.save_info_text()`),
  „Neues Spiel“
  (zweiter Tipp nötig, wenn ein Spiel existiert), „Einstellungen“ (`settings_screen.gd`:
  Spielstand löschen mit zweitem Tipp; Anzahl aufbewahrter defekter Stände). Nach dem Laden zeigt die Spielansicht
  Hinweise (Backup geladen, Speichern abgeschlossen, entfernte Daten).

### Konvention: Verweise zwischen Skripten
Skripte referenzieren einander über `const X := preload("res://…")` statt über `class_name`.
So funktionieren sie auch im Headless-Testlauf direkt nach `git pull`, bevor der Editor den
Klassen-Cache aktualisiert hat.

## Tests
`tests/run_tests.gd` (eigener Mini-Runner, kein Addon) führt alle `tests/test_*.gd` aus.
Tests sind per `exclude_filter` vom iOS-Export ausgeschlossen.
Skriptfehler während eines Tests (eigener Logger über `OS.add_logger`) lassen den Test fehlschlagen.
Lange Tests (Phase 6) liegen in `tests/long/` (Spiel-Bot `bot.gd`, Rundlauf, Störungen, Messung) und laufen nur mit
`run_tests.gd -- --long`. Echte Testspielstände aller Versionen: `tests/fixtures/saves/`.
Headless ist das Fenster nur 64 × 64 – Layout-Tests stellen Geräte nach (`tests/layout_helper.gd`, `test_layout.gd`). Godot-Läufe immer mit Zeitlimit
(`timeout`, bei Fensterläufen zusätzlich `--quit-after`).

## Geplante Verantwortlichkeiten (ab Phase 1)

| System | Einzige Autorität für |
| --- | --- |
| `GameState` | aktueller Spielstand, Spielerwerte |
| `TimeSystem` | Spielzeit (Minuten seit Spielbeginn), Tageswechsel |
| `LedgerSystem` | Buchungen und Kontostand |
| `EventSystem` | geplante/ausgelöste Ereignisse, verarbeitete IDs |
| `ActivitySystem` | Prüfen und Ausführen von Aktivitäten |
| `LocationSystem` | aktueller Ort, Reisezeit, Öffnungszeiten, Fahrten |
| `TripSystem` | „Hinfahren und starten“: Prüfung bei Ankunft, Fahrt + Aktion (ohne Zustand, G5.7) |
| `AppointmentSystem` | Termine: wahrnehmen, warten bis Beginn, verpasst, Kollisionen |
| `ChannelSystem` | Follower, Community-Stimmung, Ruf, Kanal-Protokoll |
| `ContentSystem` | Prüfen, Berechnen und Produzieren von Content |
| `EquipmentSystem` | Ausrüstungsstufen, Kauf, Qualitätsbonus |
| `CompanySystem` | Unternehmen: Gründung, Auslastung, Ruf, Einlage/Entnahme |
| `ObligationSystem` | Fristen: Fälligkeit, Betrag, Zahlung, offen/überfällig |
| `SaveSystem` | versionierter lokaler Spielstand |

UI-Szenen lesen Zustand und rufen Systeme auf; sie ändern Werte nie direkt.
Systeme melden Änderungen über Signale (z. B. `time_advanced`, `day_changed`, `balance_changed`).

## Geplante Ordner

```
assets/   kenney/ (CC0-Grafiken)
scenes/   app/, menus/, hud/, …
scripts/  core/, systems/, models/, ui/
data/     activities/, locations/, events/, appointments/, content/, equipment/, company/, obligations/
tests/
```

Ordner werden erst angelegt, wenn sie gebraucht werden.
