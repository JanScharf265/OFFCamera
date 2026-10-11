# Changelog

## Unveröffentlicht – Phase 2
- Orte als Daten mit Kartenposition und Öffnungszeiten; Verweise zwischen Datenkatalogen werden beim Start geprüft (`GameData`)
- LocationSystem: aktueller Ort, Reisezeit (5 min + 3 min/km, aufgerundet auf 5 min), Fahrten über das TimeSystem
- Aktivitäten an Orte gebunden, Öffnungszeiten geprüft; neue Aktivitäten Schlafen, Kaffee, Training, Woche planen
- AppointmentSystem: feste Termine aus Daten, wahrnehmen vor Ort ab 1 h vorher, verpasst kostet Stimmung (genau einmal), Kollisionswarnung
- Spielansicht: Ort im HUD, Aktivitäten am aktuellen Ort, Terminliste, Stadtkarte mit Ortsdetails und „Hinfahren“; Warnung vor Terminkollision mit zweitem Tipp
- Spielstand Version 2 (Ort, Termine) mit Migration von Version 1

## Unveröffentlicht – Phase 1
- TimeSystem: kanonische Spielzeit in Minuten, Tageswechsel, Wochentage (Ticket 1)
- Eigener Test-Runner, Tests vom iOS-Export ausgeschlossen
- LedgerSystem: Buchungen in Cent, Kontostand nur über Buchungen, Schutz vor Doppelbuchung und Überziehung (Ticket 2)
- GameState, PlayerStats, Aktivitäten als JSON-Daten mit Prüfung, ActivitySystem (Ticket 3)
- Hauptmenü (Neues Spiel, Fortsetzen im Speicher), Spielansicht mit HUD, Aktivitäten-Karten und letzten Buchungen; Safe Area (Ticket 4)
- Alter Phase-0-Startbildschirm entfernt
- Scrollen per Touch auf dem iPhone, Schutz vor Fehlstart beim Scrollen
- EventSystem mit Ereignissen als JSON-Daten; erstes Ereignis „Anfrage einer kleinen Marke“ (Tag 1, 20:00) (Ticket 5)
- Speichern/Laden mit Versionsnummer, Backup und Prüfung; automatisches Speichern; Fortsetzen nach Neustart (Ticket 6)
- Einstellungen mit „Spielstand löschen“; Rückfrage vor „Neues Spiel“ (Ticket 6)

## 0.0.1 – Phase 0
- Godot-4-Grundprojekt (Hochformat, GL Compatibility, 720×1280)
- Startbildschirm mit App- und Engine-Version
- README mit Mac-/iOS-Exportanleitung, CLAUDE.md, Roadmap, Architektur, Entscheidungen
- Erster erfolgreicher Start auf dem iPhone (Godot 4.7.2, Xcode 27.0, iOS 27.0)
