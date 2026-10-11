# Changelog

## Unveröffentlicht – Phase 4
- LedgerSystem mit Konten „privat“ und „Firma“: Kontostand und Überziehungsschutz je Konto; Umbuchungen (Einlage/Entnahme) als zwei verknüpfte Buchungen, nie halb (Ticket 4.1)
- Spielstand Version 6 mit Migration: alte Buchungen gehören zum Privatkonto (Ticket 4.1)
- Unternehmensart „Merch-Label“ als Daten; Gründung im Büro (1 h, 150 € Gebühr, 200 € Einlage aufs Firmenkonto); Auslastung und Ruf des Unternehmens mit Protokoll; Einlage/Entnahme als Umbuchungen (Ticket 4.2)
- Spielstand Version 7 (Unternehmen) mit Migration von Version 6 (Ticket 4.2)
- Tagesabschluss bei jedem Tageswechsel: Umsatz (Grundumsatz + Reichweite, × Auslastung, × Ruf) und Fixkosten auf dem Firmenkonto, Auslastung sinkt ohne Pflege; Firmenkonto nie negativ, unbezahlte Fixkosten kosten Ruf; jeder Abschluss mit Erklärung in der Rückmeldung (Ticket 4.3)
- Spielstand Version 8 (Tagesabschluss) mit Migration von Version 7 (Ticket 4.3)
- Neuer Ort „Ladenlokal“ an der Promenade (eigenes Gebäude auf der Karte); dort Filiale „Merch-Laden“ eröffnen (300 € vom Firmenkonto, 2 h), danach eigener Grundumsatz und eigene Fixkosten im Tagesabschluss (Ticket 4.4)
- Management-Aktivitäten als Daten: Ware nachbestellen, Kampagne planen (Büro), Merch im Stream zeigen (Studio), Laden führen (Ladenlokal) – mit Voraussetzung und Wirkung aufs Unternehmen (Ticket 4.4)
- Spielstand Version 9 (Filiale) mit Migration von Version 8 (Ticket 4.4)
- Spielansicht: Firmenkonto im HUD, Abschnitt „Unternehmen“ (Auslastung, Ruf, erwartetes Tagesergebnis, Filiale, Einlage/Entnahme 100 €), „Tagesabschlüsse“ und „Unternehmens-Verlauf“ mit Begründungen; Firmenbuchungen in den letzten Buchungen markiert (Ticket 4.5)

## Unveröffentlicht – Phase 3 (iPhone-Abnahme ok, 11.10.2026)
- ChannelSystem: Kanalprofil mit Followern (0–1.000.000, Wachstumsbremse), Community-Stimmung und Ruf (0–100); jede Änderung mit Begründung im Kanal-Protokoll (Ticket 3.1)
- Spielstand Version 3 (Kanal) mit Migration von Version 2 (Ticket 3.1)
- Content-Formate als Daten: Kurzvideo (Wohnung), Livestream, Langes Video, Q&A mit der Community (Studio); exakt berechnete Wirkung mit Vorschau auf der Karte (Ticket 3.2)
- Aktivität „Kurzer Stream“ entfällt, ersetzt durch das Format „Livestream“ (Ticket 3.2)
- Ausrüstung als Daten: Kamera, Mikrofon, Licht mit je 3 Stufen, Kauf im Studio über das Ledger, Qualitätsbonus für passende Formate (Ticket 3.3)
- Spielstand Version 4 (Ausrüstung) mit Migration von Version 3 (Ticket 3.3)
- Zufällige, regelbasierte Karriere-Ereignisse mit festem Seed: Kooperationsanfrage, Shitstorm, Raid, Technikpanne, virales Kurzvideo; Bedingungen an den Kanal, Abklingzeit, höchstens eins pro Tag (Ticket 3.4)
- Ereignis-Optionen können Follower (absolut/prozentual), Community-Stimmung und Ruf ändern – mit Begründung im Kanal-Protokoll (Ticket 3.4)
- Spielstand Version 5 (Seed) mit Migration von Version 4 (Ticket 3.4)
- Spielansicht: Kanal im HUD, Kanal-Karte (Follower, Wachstumsbremse, Community-Stimmung, Ruf) und Kanal-Verlauf mit Begründung jeder Änderung, inklusive Hinweis, wenn Bremse oder Grenze gekürzt haben (Ticket 3.5)

## Unveröffentlicht – Grafik-Ticket G1 (iPhone-Abnahme ok, 11.10.2026)
- Isometrische Stadtkarte im Stil eines Städtebauspiels: Straßen, Promenade, Strand, Meer, Bäume, Füllbebauung
- Eigene Gebäude für Wohnung, Studio, Café am Hafen, Fitnessstudio und Büro, mit antippbaren Namensschildern
- Wippende Standortmarkierung, Route zum ausgewählten Ort, Taxi fährt beim Reisen zum Ziel
- Karte per Wischgeste verschiebbar (520 px hoch)
- Grafiken: Kenney „Isometric Tiles“ City, Buildings, Vehicles (CC0) unter `assets/kenney/`

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
