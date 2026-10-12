# Changelog

## Unveröffentlicht – Phase 5
- Wertstellung je Buchung: Tagesabschlüsse gehören zum abgerechneten Tag (23:59), nicht zum Zeitpunkt der Abrechnung; Wochenauswertung je Konto ohne Umbuchungen (Ticket 5.1)
- Fester Ablauf am Tageswechsel (DayCycle): erst Tagesabschluss, dann Fristen, dann Ereignisse (Ticket 5.1)
- Spielstand Version 10 mit Migration: Wertstellung nachgetragen, alte Tagesabschlüsse auf ihren Tag korrigiert (Ticket 5.1)
- Fristen als Daten (ObligationSystem): Miete Wohnung 80 €/Woche und Miete Studio 40 €/Woche vom Privatkonto, fiktive Stadtabgabe 15 % vom positiven Wochengewinn vom Firmenkonto; fällig montags ab Tag 8, automatisch bezahlt wenn gedeckt, sonst offen; Hinweise in der Rückmeldung (Ticket 5.2)
- Spielstand Version 11 (Fristen) mit Migration von Version 10 (Ticket 5.2)
- Überfällige Fristen: nach 2 Tagen Kulanz einmal gemahnt – Mahngebühr erhöht den offenen Betrag (gebucht erst beim Bezahlen, kein Konto wird negativ), Stimmung −5 bzw. Ruf des Unternehmens −5; Bezahlen von Hand nur mit vollem offenen Betrag (Ticket 5.3)

## Unveröffentlicht – Grafik-Ticket G2 (Querformat)
- Querformat in beide Richtungen, Basisauflösung 1280×720 (G2.1)
- Stadtkarte als Vollbild-Hauptbildschirm; HUD in den oberen Ecken (Zeit/Tag/Ort, Konten, Energie, Stimmung); Seitenbuttons Termine, Kanal, Firma, Buchungen, Menü, Hier; Hinweise unten (G2.2)
- Fenster statt langer Liste: Gebäude antippen öffnet den Ort (Aktionen an fremden Orten gesperrt mit Grund), Fenster für Termine, Kanal, Unternehmen, Buchungen (Filter privat/Firma); Ereignisse als Fenster, das zuerst entschieden werden muss (G2.3)
- Zoom 0,5–1,0 per Zwei-Finger-Geste, Trackpad oder Mausrad (G2.2)
- Icons für die Seitenbuttons und „Schließen“: Kenney „Game Icons“ und „Game Icons Expansion“ (CC0) unter `assets/kenney/` (G2.4)
- Safe Area als eigene, getestete Berechnung; Bildschirme können die volle Fläche nutzen und bekommen die Abstände (Notch seitlich, Home-Balken) geliefert; Menüs als zentrierte Spalte (G2.1)

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

## Unveröffentlicht – Phase 3 (abgenommen per Tests + Mac-Fensterlauf; iPhone-Abnahme offen, Phase 7)
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
