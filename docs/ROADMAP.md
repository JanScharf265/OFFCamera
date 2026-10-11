# Roadmap

Eine Phase gilt erst als abgeschlossen, wenn ihre Abnahmekriterien erfüllt und committet sind.

## Phase 0 – Projektgrundlage und iPhone-Export ✅ (11.10.2026)
- [x] Godot-Projekt, `.gitignore`, README, Roadmap, Architektur-Notizen
- [x] Minimaler Startbildschirm
- [x] Projekt öffnet in Godot ohne Fehler, Startszene läuft (Godot 4.7.2, Mac)
- [x] iOS-Exportvorlagen (4.7.2)
- [x] iOS-Export-Preset
- [x] Export nach Xcode, Build erfolgreich
- [x] App startet auf dem iPhone (iOS 27.0)
- [x] Commit markiert funktionierenden Ausgangsstand (`bac525c`), Versionen im README eingetragen
- [x] App startet auch ohne Xcode vom Homescreen

## Phase 1 – Spielbares Grundgerüst ← aktuell
Hauptmenü (Neues Spiel / Fortsetzen / Einstellungen), HUD (Tag, Uhrzeit, Geld, Energie, Stimmung),
2–4 Aktivitäten, zentrales TimeSystem, zentrales Ledger, ein Ereignis, Speichern/Laden, Fehler- und Leerzustände.

- [x] Ticket 1: TimeSystem + Test-Runner (12/12 Tests grün auf dem Mac)
- [x] Ticket 2: LedgerSystem (27/27 Tests grün auf dem Mac)
- [x] Ticket 3: GameState + ActivitySystem (Aktivitäten als Daten) (48/48 Tests grün)
- [x] Ticket 4: Hauptmenü + HUD (53/53 Tests grün, auf dem iPhone bedienbar inkl. Scrollen)
- [x] Ticket 5: EventSystem (ein Ereignis, genau einmal) (Tests grün, im Editor geprüft)
- [ ] Ticket 6: SaveSystem, „Fortsetzen“, Einstellungen (Code fertig; Testlauf + iPhone-Abnahme ausstehend)

Abnahme auf dem iPhone (alle Punkte abhaken, dann ist Phase 1 fertig):
- [ ] Neues Spiel startet: Tag 1 · Mo, 08:00, 500,00 €, Energie 80, Stimmung 60
- [ ] Aktivität ändert Zeit exakt wie auf der Karte angegeben
- [ ] Eine Ausgabe (Essen gehen) und eine Einnahme (Kurzer Stream) stehen in den letzten Buchungen
- [ ] Gesperrte Aktivität zeigt den Grund (z. B. zu wenig Energie)
- [ ] Ereignis um 20:00 erscheint genau einmal; nach „Zusagen“ +30,00 € in den Buchungen
- [ ] App komplett beenden (wegwischen), neu öffnen, „Fortsetzen“: gleiche Zeit, gleiches Geld, gleiche Buchungen
- [ ] Ereignis kommt nach dem Laden nicht erneut
- [ ] „Neues Spiel“ fragt nach, bevor es den Spielstand überschreibt
- [ ] Einstellungen → Spielstand löschen (mit Rückfrage) → „Fortsetzen“ ist weg
- [ ] Alles per Touch bedienbar, nichts von Notch/Home-Balken verdeckt, Liste scrollbar
- [ ] Flugmodus an: App funktioniert unverändert

## Spätere Phasen
2. Alltag und Marbella-Karte (Wohnung, Studio, Café, Fitnessstudio, Büro; Reisezeit, Termine)
3. Streamer-/Creator-Karriere
4. Fiktionales Unternehmen und zweiter Standort
5. Finanzen, Fristen, Behördenereignisse
6. Save/Load-Stabilisierung und Migration
7. Mobile Politur und Performance
8. Balancing und mehr Inhalte
