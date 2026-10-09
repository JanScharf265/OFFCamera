# Roadmap

Eine Phase gilt erst als abgeschlossen, wenn ihre Abnahmekriterien erfüllt und committet sind.

## Phase 0 – Projektgrundlage und iPhone-Export ← aktuell
- [x] Godot-Projekt, `.gitignore`, README, Roadmap, Architektur-Notizen
- [x] Minimaler Startbildschirm
- [ ] Projekt öffnet in Godot ohne Fehler, Startszene läuft
- [ ] iOS-Exportvorlagen + Export-Preset
- [ ] Export nach Xcode, Build erfolgreich
- [ ] App startet auf dem iPhone
- [ ] Commit markiert funktionierenden Ausgangsstand, Versionen im README eingetragen

## Phase 1 – Spielbares Grundgerüst
Hauptmenü (Neues Spiel / Fortsetzen / Einstellungen), HUD (Tag, Uhrzeit, Geld, Energie, Stimmung),
2–4 Aktivitäten, zentrales TimeSystem, zentrales Ledger, ein Ereignis, Speichern/Laden, Fehler- und Leerzustände.

Abnahme: Aktivität ändert Zeit exakt wie definiert · Einnahme und Ausgabe im Ledger · Ereignis nur einmal ·
Speichern → App schließen → Laden konsistent · auf dem iPhone komplett per Touch bedienbar.

## Spätere Phasen
2. Alltag und Marbella-Karte (Wohnung, Studio, Café, Fitnessstudio, Büro; Reisezeit, Termine)
3. Streamer-/Creator-Karriere
4. Fiktionales Unternehmen und zweiter Standort
5. Finanzen, Fristen, Behördenereignisse
6. Save/Load-Stabilisierung und Migration
7. Mobile Politur und Performance
8. Balancing und mehr Inhalte
