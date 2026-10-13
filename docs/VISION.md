NEUE AUSRICHTUNG VOM GAME DIRECTOR – bitte zuerst nur planen, noch nichts coden.

Hintergrund: Laut Leitfaden (Abschnitt 1.1, 1.3 C, 9.3 und ursprüngliche Phase 4) ist OFF CAMERA ein Spiel über eine Person in Marbella, die öffentlich Streamer ist und parallel eine fiktionale, kriminell geprägte Organisation führt. Das ist bei Phase 4 verloren gegangen (nur Merch-Label). Ab jetzt gilt:
- Die UNTERWELT ist das Hauptspiel. Der Großteil von Geld, Entscheidungen und Spannung kommt von dort.
- Die STREAMER-Karriere ist das Nebenspiel: legales Einkommen, Tarnung, öffentliches Image – und das Risiko, dass alles auffliegt.
- Merch-Label bleibt als legale Firma und wird zur Tarnfirma.
Bitte CLAUDE.md, ROADMAP und DECISIONS entsprechend anpassen (Spielvision, neue Phasen), sobald ich den Plan freigebe.

Arbeitspakete und Reihenfolge (mein Vorschlag, bestätige oder begründe anders):
G3 Icon/Logo → G4 UI-Layout → G5 Hinweise & Komfort → T Tutorial-System → U Unterwelt (jedes U-Ticket mit eigenem Tutorial) → danach Phase 8 Balancing.

====================================================
PAKET G3 – NEUES APP-ICON UND LOGO
====================================================
Das aktuelle Icon gefällt mir nicht. Ich will etwas deutlich Schöneres und Modernes:
- Stil: modern, flach/minimal, kräftig, hochwertig – wirkt wie eine echte App im App Store. Dunkler Grund mit Verlauf, ein starker Akzent (z. B. Neon-Rot/Magenta), klare Form, auch in klein (40 px) gut erkennbar. Kein Text im Icon oder höchstens „OC“.
- Idee: das Doppelleben zeigen – z. B. Kamera-Objektiv bzw. „REC“-Punkt, der ausgeschaltet/halb im Schatten ist, oder Kamera halb hell/halb dunkel.
- Bitte 3 unterschiedliche Entwürfe als PNG-Vorschau (1024 px und 60 px nebeneinander, auf hellem und dunklem Homescreen-Hintergrund) erzeugen und mir die Pfade nennen. Ich wähle dann aus.
- Quelle als SVG im Repo, alle iOS-Größen daraus erzeugen, im Export-Preset eintragen.
- Passend dazu: Schriftzug/Logo „OFF CAMERA“ fürs Hauptmenü und den Startbildschirm (Splash), gleiche Farbwelt. Nur frei nutzbare Schriften (OFL/CC0) mit Lizenz im Repo.
- Keine fremden Marken/Logos.

====================================================
PAKET G4 – UI-LAYOUT ÜBERARBEITEN (Bildschirmfläche besser nutzen)
====================================================
Feedback vom iPhone (Screenshot liegt mir vor):
- Ortsfenster: Aktivitäten sollen ohne Scrollen sichtbar sein. Statt Liste ein Raster aus Kacheln (3–4 Spalten im Querformat), Fenster ca. 85 % der Bildschirmbreite. Jede Kachel: Name, Dauer, Energie-/Geld-Wirkung als kleine Icons + Zahl, Start-Button, Sperrgrund kurz. Wenn ein Ort mehr Aktivitäten hat als in ein Raster passen: Reiter (z. B. Alltag / Content / Geschäft / Unterwelt) statt Scrollen.
- HUD: statt zwei großer Kästen eine schmale Leiste oben über die volle Breite (links Tag/Uhrzeit/Ort, rechts Konto, Firmenkonto, Schwarzgeld, Hitze; Energie/Stimmung als kleine Balken mit Icon).
- Seitenbuttons: kleiner und kompakter (runde Icon-Buttons ca. 56–64 px mit Mini-Beschriftung), sinnvoll gruppiert (z. B. Leben: Kalender, Fristen, Kanal; Geschäft: Organisation/Unterwelt, Firma, Buchungen; Menü klein in eine Ecke). Roter Zähler-Punkt bei offenen Dingen. Muss Platz für die neuen Unterwelt-Buttons haben.
- Ziel: deutlich mehr sichtbare Karte. Alles in der Safe Area, Touch-Ziele mindestens 44 pt, Layout-Tests für die echten Bildschirmgrößen aus 7.2 anpassen.
- Bitte vorher ein Layout-Mockup (Screenshot aus dem Fensterlauf oder Skizze) zeigen, bevor umgebaut wird.

====================================================
PAKET G5 – HINWEISE UND KOMFORT
====================================================
- Dynamic Island / Notch (Test-iPhone hat Dynamic Island): Layout soll sich an die Safe Area anpassen und die Button-Leisten automatisch auf die Seite OHNE Insel legen (beide Querformat-Richtungen). Test mit Safe Area links und rechts.
- KALENDER statt „Termine“: Der Button „Termine“ wird zu „Kalender“. Beim Tagesbeginn (erste Aktion nach dem Aufwachen bzw. nach dem Tageswechsel) öffnet sich der Kalender automatisch mit dem Tagesplan als Zeitstrahl: Termine, Fristen, später Unterwelt-Lieferungen/Deals. Abschaltbar in den Einstellungen. Wahrnehmen von Terminen wie bisher.
- Erinnerungen im Spiel (keine echten iOS-Mitteilungen, da die Spielzeit nur durch Aktionen läuft): Endet eine Aktion innerhalb von 30 Spielminuten vor einem Termin oder liegt der Termin danach in ≤ 30 min, erscheint oben ein Hinweis mit Termin, Ort und Fahrzeit. Genau einmal pro Termin.
- Konflikt-Warnung als richtiges Popup statt „zweimal tippen“: zeigt Ende der Aktion, betroffenen Termin, Buttons „Trotzdem starten“ / „Abbrechen“. Gilt für Aktivitäten, Fahrten und später Unterwelt-Aktionen.
- Rote Punkte mit Zahl an den Seitenbuttons: Termine heute, fällige Fristen, offene Ereignisse/Aufträge.
- Vorschau auf jeder Aktivitäts-Kachel: „Ende HH:MM“ plus Wirkungen.
- „Warten bis Terminbeginn“ als Aktion, wenn man vor Ort zu früh ist (Zeit über das TimeSystem).
- „Hinfahren und starten“ als Kombi-Button bei Kacheln anderer Orte (inkl. Konflikt-Prüfung für die Gesamtzeit).
- Vibration (Input.vibrate_handheld) bei Warnungen, Razzien, großen Geldänderungen – mit Schalter in den Einstellungen. Falls die API auf iOS anders heißt oder nicht geht: benennen, nicht erfinden.

====================================================
PAKET T – TUTORIAL-SYSTEM (während des Spielens)
====================================================
Ziel: Für jeden neuen Schritt im Spiel ein kurzes Tutorial, sodass man ALLES versteht, ohne nachzufragen.
- Datengetrieben (z. B. data/tutorials/tutorials.json): ID, Auslöser (erstes Mal X passiert/sichtbar), Text, hervorgehobenes UI-Element, Reihenfolge, Voraussetzungen.
- Anzeige: Element wird hervorgehoben (abdunkeln + Rahmen/Pfeil), kurzer Text (max. 2–3 Sätze, einfache Worte), Button „Verstanden“. Kostet keine Spielzeit, kollidiert nicht mit Ereignis-Fenstern oder dem Kalender (Reihenfolge festlegen).
- Abdecken: ALLES Bestehende (Karte, Wischen/Zoomen, Gebäude antippen, Hinfahren, Aktivitäten, Energie/Stimmung, Kalender/Termine, Erinnerungen, Ereignisse, Kanal/Content/Ausrüstung, Firma gründen/Einlage/Entnahme, Tagesabschluss, Fristen/Mahnung, Buchungen/Wochenübersicht, Speichern/Fortsetzen) UND jede neue Unterwelt-Mechanik (Schwarzgeld, Hitze, Crew, Gebiete, Waschen, Lieferant/Schulden, Razzia, Festnahme, Doppelleben, Aufträge).
- Jedes Tutorial erscheint genau einmal. Gesehene IDs im Spielstand (neue Version + Migration).
- Einstellungen: Tutorials an/aus und „Tutorials zurücksetzen“.
- Fenster „Hilfe/Lexikon“: alle bisher gesehenen Erklärungen zum Nachlesen.
- Tests: jedes Tutorial genau einmal, bleibt nach Laden gesehen, Abdeckungstest (jede Mechanik-ID hat ein Tutorial), Texte passen ins Layout (echte Bildschirmgrößen aus 7.2).
- Regel für die Zukunft (in CLAUDE.md): Jede neue Mechanik bekommt im selben Ticket ihr Tutorial.

====================================================
PAKET U – UNTERWELT (Hauptspiel)
====================================================
Ton: so realistisch wie möglich in Thema und Atmosphäre, Stil Narcos/Gomorrha, Schauplatz Marbella, Puerto Banús, San Pedro, Nueva Andalucía, Hafen, Costa del Sol. Düstere, glaubwürdige Texte.

Bausteine (bitte jeweils als Daten mit stabilen IDs, auf den bestehenden Systemen aufbauen):

1. Organisation
   - Spieler gibt ihr einen Namen. Werte: Respekt in der Szene, Hitze (Polizei-Aufmerksamkeit 0–100, sinkt langsam bei Ruhe), Stabilität.
   - Übersicht/Dashboard als eigenes Fenster und Seitenbutton „Organisation“.

2. Produkte
   - Echte Namen: Gras, Haschisch, Koks, Pillen. Werte pro Produkt: Einkaufspreis, Verkaufspreis, Qualität, Nachfrage je Gebiet, Hitze pro verkaufter Menge.
   - Nur Zahlen und Entscheidungen. Keine Herstellungs-, Streck- oder Mengenangaben aus der echten Welt.

3. Standorte (Leitfaden 9.3: ID, Typ, Freischaltung, Startkosten, laufende Kosten, Kapazität, Personal, Produktivität, Risiko, Aktivitäten, Voraussetzungen)
   - Typen z. B.: Versteck/Bunker, Lager, Plantage/Labor (nur „Produktion: X Einheiten/Tag“), Verkaufspunkt, Club (auch Tarnfirma), Liegeplatz am Hafen (Import).
   - Als Gebäude auf der Karte, freischaltbar, ausbaubar. Gebäude mit erkennbarer Optik (Kenney CC0).

4. Crew / Personal
   - Rollen: Dealer, Läufer, Fahrer, Schutz, Produktion, Buchhalter, Anwalt.
   - Werte: Lohn, Können, Loyalität, Gier/Risiko. Einstellen, befördern, feuern.
   - Folgen: Verhaftung, Verrat, Spitzel, Abwerbung durch Rivalen.

5. Gebiete
   - Marbella in Viertel aufteilen, jedes mit Nachfrage, Polizeipräsenz, Einfluss der Rivalen.
   - Gebiete übernehmen, halten, verlieren. Auf der Karte sichtbar (Farbe/Overlay).

6. Rivalen und Lieferanten
   - 2–3 ERFUNDENE Gangs mit Stärke, Aggression, Gebieten. Konflikte, Verhandlungen, Waffenstillstand, Übernahmen. Gewalt nur als Text und Folgen (Crew verletzt/weg, Standort verloren).
   - Ein erfundener Lieferant/Kartell: Deals auf Vorkasse oder auf Kredit, Schulden mit Fristen (bestehendes Fristen-System nutzen), Lieferung kann platzen, Druck bei Schulden.

7. Geld
   - Schwarzgeld als drittes Konto im EINEN Ledger (wie privat/Firma).
   - Schwarzgeld ausgeben ist eingeschränkt bzw. erhöht Hitze.
   - „Waschen“ über Tarnfirmen (Merch-Label, Club, später Immobilien) als reiner Spielmechanismus: Gebühr in %, Tageslimit je Tarnfirma, Risiko. Kein echtes Vorgehen beschreiben.

8. Polizei und Justiz (Gegenspieler: Guardia Civil / Policía Nacional als Institutionen, Beamte und Fälle erfunden)
   - Eskalationsstufen nach Hitze: Beobachtung → Ermittlung → Razzia → Festnahme.
   - Optionen als Entscheidungen: Anwalt, Bestechung (teuer, riskant), Füße stillhalten, Crew-Mitglied opfern, kooperieren.
   - Kaution, Prozess, Gefängnis als Spieltage mit Einschränkungen. Game Over ja/nein = offene Frage an mich.
   - Mit den Behördenereignissen aus Phase 5 verbinden.

9. Doppelleben (Verbindung zum Streamer-Teil)
   - Unterwelt-Aktionen kosten Spielzeit und kollidieren mit Streams/Terminen.
   - Kanal bringt legales Einkommen und senkt Hitze-Anstieg leicht (Tarnung).
   - Ereignisse: Paparazzi, Leak, Gerüchte im Chat, Skandal → Follower/Ruf brechen ein. Hohe Bekanntheit = mehr Aufmerksamkeit.

10. Beziehungen (Leitfaden 1.3 A, 6.6, als einfache Fortschrittswerte)
   - Wenige Figuren: z. B. Partner/in, bester Freund, Manager, Kontakt am Hafen, bestechlicher Beamter, Rivalenboss.
   - Werte Vertrauen/Wissen („weiß von der Unterwelt“), Ereignisse mit Entscheidungen.

11. Story-Aufträge
   - Aufträge/Missionen als Daten (Kette z. B. „Erster Deal → eigenes Versteck → erster Dealer → erstes Gebiet …“) als roter Faden durchs Spiel, mit Belohnungen, verknüpft mit den Tutorials. Offene Aufträge mit rotem Punkt.

12. Ablauf am Tageswechsel
   - Fester Ablauf erweitern: Unterwelt-Abrechnung (Verkäufe, Löhne, Produktion), Hitze-Änderung, Fristen, Ereignisse, dann Kalender öffnen – alles genau einmal, auch nach dem Laden.

13. HUD/UI
   - Schwarzgeld und Hitze sichtbar im HUD (Layout aus G4).
   - Seitenbuttons: Organisation, Crew, Gebiete, Aufträge (oder zusammengefasst – Vorschlag machen).

Harte Grenze (CLAUDE.md + Leitfaden 6.5): Alles sind Spielmechaniken mit Zahlen und Entscheidungen. KEINE realen Herstellungs- oder Streckschritte, Chemikalien, Mengen, Schmuggelrouten oder -methoden, Verstecktechniken, Geldwäsche-Konstruktionen oder Tricks gegen Ermittlungen. KEINE echten kriminellen Organisationen oder realen Personen.

Architektur (die vier Regeln bleiben):
- eine Spielzeit,
- ein Ledger (jetzt drei Konten),
- alles als Daten mit Prüfung,
- Ereignisse zentral, deterministisch, genau einmal.
Neue Spielstand-Version mit Migration und Testdatei (Regel aus Phase 6). Bestehende Spielstände laden weiter, die Unterwelt startet dort über ein Einstiegs-Ereignis.

====================================================
WAS ICH JETZT VON DIR WILL
====================================================
1. Kurz prüfen, was es schon gibt und wiederverwendet wird (Unternehmen, Konten, Fristen, Termine, Ereignisse, Karte, Layout).
2. Plan als Ticketliste je Paket (G3, G4, G5, T, U), mit betroffenen Dateien, in sinnvollen kleinen Tickets.
3. Offene Entscheidungsfragen mit deiner Empfehlung, mindestens:
   - Game Over bei Festnahme oder Gefängnis-Phase mit Weiterspielen?
   - Startet ein neues Spiel schon mit kleiner Unterwelt oder kommt sie per Einstiegs-Ereignis an Tag 1–2?
   - Wie stark wird der Streamer-Teil zurückgestuft (Einnahmen, Gewicht)?
   - Gewalt nur als Text und Folgen – ok?
   - Seitenbuttons: wie viele, welche zusammenfassen?
   - Welche Beziehungsfiguren in U, welche erst in Phase 8?
4. Falls noch nicht erledigt: export_presets.cfg (Code-Sign „Apple Development“) committen und .gdignore in exports/ und tools/.
Nach jedem Ticket wie immer: Tests grün, Mac-Fensterlauf mit Screenshots, Doku, Commit. Godot nur mit Zeitlimit.

ZUSATZ:
- Speichere diesen kompletten Text zuerst unverändert als docs/VISION.md und committe ihn. Alle späteren Schritte beziehen sich darauf.
- Teile den Plan in kleine Tickets auf, die jeweils in eine Sitzung passen (lieber zu klein als zu groß). Trag sie als nummerierte Checkliste in die ROADMAP ein.
- In diesem Schritt NUR planen. Nach dem Plan STOPP und auf meine Entscheidungen warten.
