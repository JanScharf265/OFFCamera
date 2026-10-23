# Changelog

## Unveröffentlicht – Neue Ausrichtung (13.10.2026)
- Erster Lieferant „El Rubio“: nach „Treffen am Hafen“ über „Organisation“ anrufen, Ware (Gras, Haschisch, Pillen, Koks) auf Vorkasse bestellen – bezahlt aus Schwarzgeld, wenn genug da ist, sonst vom Privatkonto –, Lieferung am nächsten Morgen, die auch platzen kann (dann ist das Geld weg); Bestand und Lieferungen unterwegs im Fenster „Organisation“; neuer Auftrag „Die erste Ware“; Erklärungen „Die Ware“ und „Vorkasse“. Außerdem: Die Rückmeldung nach einer Aktion ist jetzt auch über offenen Fenstern sichtbar. Spielstand Version 20 (Ticket U.6)
- „Treffen am Hafen“ zählt nur noch, wenn das Café offen ist; nachts gibt es einen Hinweis, wer bis zur Öffnung bleibt, erfüllt den Auftrag dann (Nachtrag U.4)
- Produkte der Unterwelt als Daten (Gras, Haschisch, Pillen, Koks – Preise, Qualität und Hitze je Einheit, reine Spielwerte); im Spiel noch nicht sichtbar, sie kommen mit dem Lieferanten (U.6) (Ticket U.5)
- Story-Aufträge: Nach der Gründung gibt El Capitán den ersten Auftrag („Erster Deal: Treffen am Hafen“ – ab ins Café am Hafen, Respekt +5). Neuer Button „Aufträge“ mit rotem Punkt für Neues und Erledigtes, Fenster mit Auftragstext, Ziel und Belohnung, Hinweise bei neuem und erledigtem Auftrag; Erklärung „Aufträge“; Spielstand Version 19 (Ticket U.4)
- Einstieg in die Unterwelt: Ab Tag 2 meldet sich „El Capitán“ am Hafen von Puerto Banús („Liegeplatz 14“). „Zuhören“ → du gibst deiner Organisation einen Namen; „Nicht heute“ → er meldet sich zwei Tage später wieder. Danach: Fenster „Organisation“ (Respekt, Hitze, Stabilität) mit eigenem Button, Erklärung „Deine Organisation“. Auch alte Spielstände bekommen den Einstieg beim nächsten Tageswechsel; Spielstand Version 18 (Ticket U.3)
- Grundlage der Organisation: Name, Respekt, Hitze und Stabilität; die Hitze steht als Flamme mit Zahl in der HUD-Leiste (ab 30 gelb, ab 60 rot) und kühlt an ruhigen Tagen langsam ab; noch unsichtbar, bis die Organisation mit dem Einstieg in die Unterwelt (U.3) entsteht; Erklärung „Hitze“; Spielstand Version 17 (Ticket U.2)
- Schwarzgeld als drittes Konto: eigene Zeile „Schwarz“ in der HUD-Leiste, Stand, Filter und Wochenübersicht im Buchungen-Fenster – alles erst sichtbar, wenn es Schwarzgeld gibt (verdient wird es ab U.9); lässt sich nicht auf Privat- oder Firmenkonto umbuchen; Erklärung „Schwarzgeld“; Spielstand Version 16 (alte Spielstände laden weiter) (Ticket U.1)
- Paket T abgeschlossen: feste Liste der Spielmechaniken mit Abdeckungstest (jede Mechanik hat ihr Tutorial, jeder Auslöser wird wirklich gemeldet); die Tests können den echten Spielstand und die Einstellungen am Mac nicht mehr verändern (Ticket T.7)
- Tutorial-Texte für Karriere und Firma: Kanal, Content und Qualität, Ausrüstung, die Symbole auf den Kacheln, Firma gründen, Privat und Firma, Ladenlokal, Tagesabschluss, Fristen, Buchungen – nie mehr als drei hintereinander, und eine Erklärung kommt erst, wenn das Erklärte zu sehen ist. Tipp auf den Ortsnamen im Ortsfenster zeigt die Beschreibung des Orts (Tickets T.6, T.6b)
- Tutorial-Texte für die Grundlagen: 13 kurze Erklärungen (Marbella, Karte bewegen, Orte antippen, Kacheln, Hinfahren, Hinfahren und starten, Energie und Stimmung, Kalender, Erinnerung, Konflikt, Warten, Ereignisse, Speichern) – zum Start nur zwei, der Rest beim ersten Benutzen; Tutorials liegen jetzt auch über dem Fenster, das sie erklären (z. B. Kalender). Lexikon mit festem Schließen-Button und in Spielreihenfolge; in den Einstellungen ist „Spielstand löschen“ nur rot umrandet, „Zurück“ grau (Ticket T.5)
- Einstellungen: Schalter „Tutorials anzeigen“ und „Tutorials zurücksetzen“ (mit Rückfrage); neuer Bildschirm „Hilfe / Lexikon“ mit allen schon gesehenen Erklärungen (Antippen zeigt den Text). Die Einstellungsseite ist kompakter (Buttons paarweise nebeneinander), damit sie ohne Scrollen passt (Ticket T.4)
- Tutorials werden angezeigt: Der Bildschirm wird abgedunkelt, das erklärte Element hervorgehoben (Rahmen, Pfeil), daneben eine Sprechblase mit „Verstanden“; danach kommt das nächste. Zuerst kommen Ereignis, Kalender und Erinnerung, nie zwei Fenster übereinander. Der feste Hinweis „Tippe auf ein Gebäude …“ beim Start entfällt (Ticket T.3)
- Tutorials: Das Spiel merkt sich jetzt, wann eine Erklärung fällig ist und welche schon bestätigt wurden – jede genau einmal, auch über Speichern/Laden; angezeigt wird noch nichts (kommt mit T.3); Spielstand Version 15 – alte Spielstände laden weiter und bekommen keine Spielstart-Erklärungen (Ticket T.2)
- Tutorials vorbereitet: Datenformat `data/tutorials/tutorials.json` mit Prüfung (Felder, Auslöser, Voraussetzungen ohne Zyklen) und drei Platzhaltern – noch nicht im Spiel sichtbar (Ticket T.1)
- Kurze Vibration bei Warnungen (Termin verpassen?, Erinnerung, Termin verpasst, neue Frist oder Mahnung, Ereignis) und bei Geldänderungen ab 100 € – höchstens einmal je Aktion, nicht beim Laden, abschaltbar in den Einstellungen; spürbar nur auf dem iPhone (Ticket G5.9). Paket G5 abgeschlossen
- Rote Zählerpunkte mit Zahl am Kalender (Termine heute, die noch kommen) und an den Fristen (offene Fristen), ab 10 „9+“; der Punkt sitzt neben dem Symbol. Energie- und Stimmungsbalken werden unter 40 gelb und unter 20 rot, die Zahl bleibt daneben; Stimmung ist im Normalfall jetzt blau statt gelb (Ticket G5.8)
- „Hinfahren und starten“: Kacheln eines anderen Orts bieten statt „Nur vor Ort möglich“ einen Kombi-Button mit Gesamtzeit (Auto · „20 min + 2 h“, „Ende 12:20“); geprüft wird für die Ankunft (Firma, Geld, Energie, Öffnungszeiten) und für Termine mit der Gesamtzeit; scheitert die Aktion nach der Fahrt, bist du trotzdem angekommen und bekommst eine klare Meldung; Käufe nur vor Ort; „Hinfahren“ mit Auto-Symbol und eigenem Stil (Ticket G5.7)
- Erinnerung vor Terminen: Beginnt ein Termin in höchstens 30 Spielminuten, erscheint genau einmal ein kleines Fenster mit Termin, Uhrzeit, Ort und Fahrzeit – „Du schaffst es noch“ oder „Du kommst zu spät: Fahrt 20 min“ – und „Hinfahren“, „Warten bis 14:00“ oder „Später“; kommt nach Ereignis und Kalender; Spielstand Version 14 (alte Spielstände laden weiter) (Ticket G5.6)
- „Warten bis 14:00“: Ist man vor Ort und der Termin kommt heute noch, springt die Uhr genau auf den Terminbeginn – kostet nichts, Energie und Stimmung bleiben; danach direkt „Wahrnehmen“. Im Kalender bei jedem Termin (sonst gesperrt mit Grund, z. B. „Erst hinfahren: Studio“) und vor Ort in der Titelzeile des Ortsfensters (Ticket G5.5)
- Würde eine Aktion oder Fahrt einen Termin verpassen lassen, fragt jetzt ein Popup nach („Termin verpassen?“ mit Ende der Aktion, allen betroffenen Terminen, Ort und Kosten; „Trotzdem starten“ / „Abbrechen“) – statt „nochmal tippen“ (Ticket G5.4)
- Kalender öffnet sich bei Tagesbeginn von selbst – genau einmal je Tag, auch nach dem Verschlafen mehrerer Tage nur einmal; offene Ereignisse kommen zuerst; abschaltbar in den Einstellungen; Spielstand Version 13 (alte Spielstände laden weiter) (Ticket G5.3)
- „Termine“ wird „Kalender“: Tagesplan als Zeitstrahl für heute – Termine mit Uhrzeit, Ort und Fahrzeit, fällige und überfällige Fristen, Vergangenes grau, der nächste Termin hervorgehoben, die aktuelle Uhrzeit als rote Linie, Hinweis auf den nächsten späteren Termin; „Wahrnehmen“ wie bisher (Ticket G5.2)
- Start ohne schwarze Pause (Ziel): Hauptmenü und Stadtkarte werden schon hinter dem Ladebildschirm aufgebaut und einmal gezeichnet; der Kartenatlas wird nur einmal gepackt; der Ladebildschirm verschwindet so schnell wie möglich (keine Mindestdauer); ausführliche „[Start]“-Zeilen bis zum ersten Kartenbild (Ticket G5.1c)
- Ladebildschirm im Stil eines Kamera-Suchers statt schwarzem Bildschirm beim Start: blinkendes „● REC“, Aufnahmeleiste mit echtem Fortschritt, Statustexte („Licht an …“, „Marbella wird aufgebaut …“), am Ende schließt sich das Objektiv wie eine Blende; bei einem Ladefehler eine verständliche Meldung (Ticket G5.1b)
- Einstellungen fürs Gerät: „Kalender bei Tagesbeginn automatisch öffnen“ und „Vibration“ (beide an, wirken ab G5.3 bzw. G5.9), gespeichert unabhängig vom Spielstand; „Spielstand löschen“ lässt sie stehen; große, gut erkennbare Schalter (Ticket G5.1)
- Alles Tippbare mindestens 84 px (≈ 44 pt): Kartenschilder und Buchungen-Filter mit unsichtbar größerer Tippfläche; Mini-Beschriftungen 19 px statt 15 px (Spalten so breit wie „Buchungen“), „Privat“/„Firma“ neben dem Betrag; HUD-Leiste voll deckend; Ortsfenster über die volle Breite; Öffnungszeiten in Kurzform („07:00–20:00 · offen“) (Ticket G4.7)
- Reiter im Ortsfenster (Alltag · Content · Geschäft · Unterwelt) – nur wenn die Kacheln eines Orts nicht ohne Scrollen passen; neues Pflichtfeld "tab" in den Daten; Hinweis bei Ausrüstung kürzer („→ USB-Mikrofon“) (Ticket G4.6)
- Kacheln besser lesbar: Schrift 21 px statt 16 px, flachere Buttons (56 px sichtbar) mit großer Tippfläche (84 px), Wirkungen als Symbol + Zahl in höchstens 2 Zeilen, kürzere Namen „Community-Q&A“ und „Merch zeigen“, Konflikt-Hinweis „⚠ Verpasst: 14:00“; Öffnungszeiten und Entfernung im Ortsfenster in 21 px (Ticket G4.5b)
- Ortsfenster als Kachel-Raster (3–4 Spalten, ohne Scrollen): Name, Dauer mit „Ende HH:MM“, Wirkungen als Symbol + Zahl (grün/rot), Hinweiszeile für Terminkonflikte, Sperrgrund im Button, Käufe mit Rahmen-Button; Infos und „Hinfahren“ in der Titelzeile; runder Schließen-Button in allen Fenstern (Ticket G4.5)
- Runde Buttons rechts in zwei Gruppen „Leben“ (Kalender, Fristen, Kanal) und „Geschäft“ (Firma, Buchungen): Kreis 64 px, Tippfläche 84 px, Beschriftung, roter Zählerpunkt bei offenen Fristen; Menü als Zahnrad in der HUD-Leiste; links nur „Hier“ (Ticket G4.4)
- Energie im HUD mit Blitz-Symbol; kurze Hinweise unten lassen Tipps auf die Karte durch, z. B. auf das Schild „Ladenlokal“ (Ticket G4.4)
- HUD als schmale Leiste oben statt zwei großer Kästen: Tag, Uhrzeit, Ort links; Energie und Stimmung als Balken mit Zahl (Stimmung mit Smiley), Privat- und Firmenkonto rechts – mehr sichtbare Karte (Ticket G4.3)
- Feste Querformat-Richtung: Dynamic Island links, Bedienung rechts – die App dreht nicht mehr mit (Ticket G4.2)
- Layout-Mockup für das neue HUD, runde Buttons und Kachel-Ortsfenster (Ticket G4.1)
- Schriftzug „OFF CAMERA“ (Bebas Neue, OFL) im Hauptmenü statt Titel + „Prototyp“; gleiches Bild als Startbild (Boot-Splash und iOS-Launch-Screen) auf der UI-Hintergrundfarbe (Ticket G3.3)
- Neues App-Symbol „Halbes Objektiv“ in allen iOS-Größen, für kleine Größen (bis 87 px) vereinfacht; Test prüft Größe und fehlende Transparenz aller Icons im Export-Preset (Ticket G3.2)
- Drei App-Icon-Entwürfe (SVG) mit Vorschau in 1024 px und 60 px auf hellem und dunklem Hintergrund (Ticket G3.1)
- Spielvision des Game Directors als `docs/VISION.md`, Leitfaden als Text `docs/LEITFADEN.md`; Ticketplan G3, G4, G5, T, U in der ROADMAP; Regeln in `CLAUDE.md` (Unterwelt als Hauptspiel, harte Inhaltsgrenze, Tutorial-Regel)

## Unveröffentlicht – Phase 7
- Gebündelter iPhone-Test (Build 0.7.0) bestanden – Phase 7 abgeschlossen (Ticket 7.5)
- Export packt keine Dateien aus `exports/` mehr ins Paket (`.gdignore` in `exports/` und `tools/`, Ausschlussfilter); Code-Signatur „Apple Development“ im Export-Preset
- Warnung „ObjectDB instances leaked at exit“ untersucht: im Spiel kein Leck (0 Objekte pro neuem Spiel, Laden, App-Durchgang), Ursache sind Kreisverweise in Tests; Wächter-Tests `test_memory.gd` (Ticket 7.1)
- Aufgeräumt: ungenutztes Kartensignal `pin_down` und ungenutzter Getter entfernt (Ticket 7.1)
- Layout-Tests für typische iPhones im Querformat (16:9 ohne Notch, Notch, Dynamic Island, Grenzfall): HUD, Seitenleisten, Hinweis und alle Fenster in der Safe Area und ohne Überlappung; Menüs passen in die Höhe (Ticket 7.2)
- Hauptmenü und Einstellungen kompakter (Titel 56 px, Buttons 84 px ≈ 46 pt, Spielstand-Info einzeilig) und in einem Scrollbereich als Sicherheitsnetz – vorher wären auf Notch-iPhones unten Buttons abgeschnitten worden (Ticket 7.2)
- Version 0.7.0 (Build 7), eigenes Platzhalter-App-Symbol, Werkzeuge vom Export ausgeschlossen; iOS-Export nach Xcode ohne Editor geprüft (Querformat links/rechts, Daten und Grafiken im Paket, Tests nicht) (Ticket 7.4)
- Akku: Stromsparmodus (Godot zeichnet nur bei Änderungen) und 60 FPS; die Standortmarkierung wippt nur 3 s nach Ankunft/Auswahl – Ruhezustand von 120 auf 0 gezeichnete Bilder pro Sekunde (Mac) (Ticket 7.3)
- Kartengrafiken beim Start zu einem Texturatlas gepackt: Zeichenaufrufe je Bild von 963 auf 206, Wischen von 133–169 auf 179–206 FPS möglich (Mac) (Ticket 7.3)
- Hinweis-Leiste hat sofort die richtige Höhe (Umbruch wird erzwungen statt ein Bild später korrigiert) (Ticket 7.2)

## Unveröffentlicht – Phase 6
- Echte Testspielstände v1–v11, erzeugt mit dem Code der jeweiligen Commits; jeder lädt bis zur aktuellen Version, behält Zeit, Konten, Ort, Kanal, Ausrüstung, Unternehmen und ist weiterspielbar (Ticket 6.1)
- Migrationen als Einzelschritte n → n + 1; ein Test verlangt eine Testdatei je Version (Ticket 6.1)
- Konsistenzprüfung nach dem Laden über System-Grenzen (Zeitstempel, Buchungsnummern, Schutzschlüssel, Zähler für Einlagen/Entnahmen, gebuchte Fristen, Tagesabschlüsse); unstimmige Stände werden wie defekte behandelt und das Backup geladen (Ticket 6.3)
- Entfernte Daten: Laden mit Hinweis statt Ablehnung – Ort → Startort, Ausrüstung entfernt, Unternehmen ohne Art bleibt (ohne Abschlüsse), offene Frist ohne Definition bleibt bezahlbar, offenes Ereignis ohne Daten entfällt; Hinweise erscheinen nach dem Laden (Ticket 6.3)
- Spielstand Version 12 mit Migration und echter Testdatei: Frist-Instanzen speichern Konto, Kategorie und Bezeichnung (Ticket 6.3)
- Hauptmenü zeigt unter „Fortsetzen“ Spieltag, Uhrzeit, Konto und Speicherzeit (aus dem Spielstand-Kopf); Hinweise sagen, dass defekte Dateien aufbewahrt werden; „Neues Spiel“ braucht auch bei aufbewahrten defekten Ständen einen zweiten Tipp; Einstellungen zeigen ihre Anzahl (Ticket 6.5)
- Lange Tests als eigener Lauf (`run_tests.gd -- --long`): Rundlauf mit Spiel-Bot (30 Seeds × 30 Tage, Speichern/Laden ergibt denselben Stand, Konsistenz jeden Tag), Störungstest mit beschädigten Spielständen aller Versionen, Messung von Größe und Zeit (Ticket 6.4)
- Migrationen gegen falsche Typen in beschädigten Dateien gehärtet (vorher Skriptfehler statt Ablehnung), mit Regressionstests (Ticket 6.4)
- Robustes Speichern: Kopf mit App-Version, Speicherzeit, Spieltag, Kontostand und Datenkennung; 3 rotierende Backups; .tmp wird nach dem Schreiben geprüft; eine liegengebliebene .tmp wird nur übernommen, wenn sie vollständig lesbar ist und alle Prüfungen besteht, sonst als defekter Stand aufbewahrt (Regressionstest); defekte Stände werden nie überschrieben (höchstens 3 Kopien); kein Speichern während eines Zeitfortschritts (Ticket 6.2)

## Unveröffentlicht – Phase 5
- Wertstellung je Buchung: Tagesabschlüsse gehören zum abgerechneten Tag (23:59), nicht zum Zeitpunkt der Abrechnung; Wochenauswertung je Konto ohne Umbuchungen (Ticket 5.1)
- Fester Ablauf am Tageswechsel (DayCycle): erst Tagesabschluss, dann Fristen, dann Ereignisse (Ticket 5.1)
- Spielstand Version 10 mit Migration: Wertstellung nachgetragen, alte Tagesabschlüsse auf ihren Tag korrigiert (Ticket 5.1)
- Fristen als Daten (ObligationSystem): Miete Wohnung 80 €/Woche und Miete Studio 40 €/Woche vom Privatkonto, fiktive Stadtabgabe 15 % vom positiven Wochengewinn vom Firmenkonto; fällig montags ab Tag 8, automatisch bezahlt wenn gedeckt, sonst offen; Hinweise in der Rückmeldung (Ticket 5.2)
- Spielstand Version 11 (Fristen) mit Migration von Version 10 (Ticket 5.2)
- Fristen-Fenster (offene Fristen mit offenem Betrag, Mahngebühr-Hinweis, Bezahlen, nächste Fälligkeiten, zuletzt erledigt), Seitenbutton „Fristen (n)“ rot bei offenen Fristen, Wochenübersicht je Konto im Buchungen-Fenster (Ticket 5.5)
- Test-Runner: Skriptfehler während eines Tests lassen den Test fehlschlagen (Logger über `OS.add_logger`) (Ticket 5.5)
- Seitenbuttons kleiner (Icons 50-px-Varianten, Icon-Größe 28), damit 4 Buttons je Seite unter das HUD passen (Ticket 5.5)
- Behördenereignisse (fiktiv, abstrakte Folgen): Vollstreckungsankündigung (sicher ab 3 offenen Fristen), Gewerbekontrolle, Nachforderung der Stadtkasse, Prüfungstermin, Lärmbeschwerde am Studio, Förderbescheid; neue Bedingungen (offene Fristen, Unternehmen, Vorwochen-Gewinn) und Optionen mit Konto, Spielzeit und Unternehmenswirkung; jedes Ereignis hat eine kostenlose Option (Ticket 5.4)
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
