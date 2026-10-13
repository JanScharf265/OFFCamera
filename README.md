# OFF CAMERA

Singleplayer-Lebens- und Managementsimulation für das eigene iPhone (Godot 4 + GDScript).
Kein App Store, kein Android, offline spielbar.

## Stand

**Phase 0–7 sowie G1 und G2 abgeschlossen; der gebündelte iPhone-Test von Build 0.7.0 ist bestanden (13.10.2026, 338/338 Tests + 3/3 lange Tests grün). Neue Ausrichtung: Die Unterwelt wird das Hauptspiel (`docs/VISION.md`). Als Nächstes: Pakete G3 (Icon/Logo) → G4 (UI-Layout) → G5 (Komfort) → T (Tutorials) → U (Unterwelt), dann Phase 8.** Siehe [`docs/ROADMAP.md`](docs/ROADMAP.md).

| Was | Status |
| --- | --- |
| Godot-Projekt + Startbildschirm | läuft im Godot-Editor (Mac) |
| iOS-Export nach Xcode | funktioniert |
| Start auf dem iPhone | funktioniert (11.10.2026) |

## Versionen

| Tool | Version |
| --- | --- |
| Godot | 4.7.2.stable |
| Xcode | 27.0 (27A266a) |
| macOS | 27.0.1 |
| Test-iPhone | iPhone19,2 (Modell-ID), iOS 27.0 (24A437) |

Godot nicht mitten in einer Phase aktualisieren.

## Projekt öffnen (Mac)

```sh
git clone https://github.com/JanScharf265/OFFCamera.git
cd OFFCamera
```

1. Godot öffnen → **Importieren** → `project.godot` in diesem Ordner wählen.
2. Ist die Godot-Version neuer als im Projekt hinterlegt, fragt Godot evtl. nach einem Upgrade → bestätigen.
3. **F5** (bzw. ▶) startet den Startbildschirm. Erwartet: dunkler Hintergrund, „OFF CAMERA“, darunter App- und Godot-Version.

## iOS-Export (Phase 0)

Voraussetzungen: Xcode installiert und einmal gestartet, Apple-ID in Xcode angemeldet
(Xcode → Settings → Accounts), iPhone per Kabel verbunden und entsperrt.

1. **Exportvorlagen:** Godot → Editor → Exportvorlagen verwalten → *Herunterladen und installieren*
   (müssen exakt zur Godot-Version passen).
2. **Preset:** Projekt → Exportieren → Hinzufügen → **iOS**.
   - `App Store Team ID`: deine 10-stellige Team-ID. Bei kostenlosem Konto („Personal Team“):
     Schlüsselbundverwaltung → Zertifikat „Apple Development: …“ → Feld *Organisationseinheit*.
     (Das Zertifikat entsteht, sobald Xcode einmal mit deinem Konto signiert hat.)
   - `Bundle Identifier`: z. B. `com.<deinname>.offcamera` (muss eindeutig sein).
   - Falls vorhanden: **Export Project Only** aktivieren – Godot erzeugt dann nur das Xcode-Projekt,
     gebaut und signiert wird in Xcode.
3. **Projekt exportieren** → Ziel z. B. `exports/ios/OFFCamera.ipa`
   (der Ordner `exports/` ist in `.gitignore`). Godot erzeugt dort ein Xcode-Projekt.
4. Das erzeugte `OFFCamera.ipa.xcodeproj` in Xcode öffnen.
5. Target → *Signing & Capabilities* → Team wählen, „Automatically manage signing“ an.
6. Oben dein iPhone als Ziel wählen → **Run** (▶).
7. Auf dem iPhone ggf. *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* aktivieren
   und unter *Allgemein → VPN & Geräteverwaltung* dem Entwicklerzertifikat vertrauen.

Kostenloses Apple-Konto: App läuft nach einigen Tagen ab und muss dann neu installiert werden.

### Bekannte Stolpersteine (beim ersten Export erlebt)

| Meldung | Lösung |
| --- | --- |
| Godot: „ETC2/ASTC-Texturkompression benötigt“ | Projekteinstellung „ETC2 ASTC importieren“ aktivieren |
| Godot: „App-Store-Team-ID nicht angegeben“ | Team-ID = `OU=` aus `security find-certificate -c "Apple Development" -p \| openssl x509 -noout -subject` |
| Xcode: Release-Signing-Konflikt „Apple Distribution“ | Im Godot-Preset Exportmethode Release = Development, Codesignierungsidentität Release = `Apple Development` |
| Xcode: `Undefined symbol: _main` + „Ignoring file …“ | Als Ziel das echte iPhone wählen (nicht Simulator), dann Product → Clean Build Folder |
| Xcode: CoreDeviceError 4016 | iPhone entsperren, Entwicklermodus an, Verbindung unter Window → Devices and Simulators prüfen |
| Xcode hängt bei „Extracting OS library symbols“ | Nur beim ersten Mal pro iOS-Version, einige Minuten warten |
| „Developer App Certificate is not trusted“ | iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung → Zertifikat vertrauen |

Export ohne Editor (Phase 7, im Projektordner; erzeugt nur das Xcode-Projekt, signiert nichts):

```sh
timeout 600 ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "iOS" exports/ios/OFFCamera.ipa
```

Das Ergebnis heißt `exports/ios/OFFCamera.xcodeproj` (frühere Exporte hießen `OFFCamera.ipa.xcodeproj` – den alten
Satz vom 11.10. habe ich nach `exports/ios/_alt_2026-10-11/` verschoben, damit er nicht versehentlich geöffnet wird).
App-Symbol: Quellen `assets/icon/app_icon.svg` (ab 114 px) und `assets/icon/app_icon_small.svg` (bis 87 px); alle iOS-Größen
`assets/icon/app_icon_<px>.png` erzeugt `tools/icon/make_icon.gd` (Befehl in der Datei), danach `--import`.
Warnungen zu Kamera-/Mikrofon-/Foto-Usage-Descriptions sind harmlos (die App fragt diese Rechte nicht an).

Fehler? Exakte Meldung aus Godot bzw. Xcode kopieren (siehe „Fehlerbericht“ in [`CLAUDE.md`](CLAUDE.md)).

## Tests ausführen (Mac)

```sh
cd ~/Developer/OFFCamera
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
```

Nach dem Hinzufügen neuer Grafiken einmal importieren (sonst fehlen sie im Headless-Lauf):
`… --headless --path . --import`

Am Ende steht `N bestanden, M fehlgeschlagen`.

### Lange Tests (Phase 6)

Rundlauf (30 zufällige Spielverläufe à 30 Tage, Speichern/Laden zwischendurch), Störungstest (beschädigte
Spielstände aller Versionen) und Messung (Größe, Lade-/Speicherzeit nach 60 und 180 Spieltagen):

```sh
timeout 900 ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd -- --long
```

Läuft getrennt von der normalen Suite (die soll unter einer Minute bleiben) – am Ende jedes Tickets, das das
Speichern betrifft, und am Ende einer Phase.

### Testspielstände alter Versionen (Phase 6)

`tests/fixtures/saves/v<N>.json` sind echte Spielstände, erzeugt mit dem Code des Commits, in dem Version N aktuell
war; `v<N>.expect.json` hält die Kernwerte. Neu erzeugen (z. B. nach einer neuen Formatversion, im Projektordner):

```sh
OUT=/tmp/offcamera-saves; mkdir -p "$OUT/hist" "$OUT/v11"
git archive <commit> | tar -x -C "$OUT/hist"            # alter Stand, kein Worktree nötig
timeout 120 ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "$OUT/hist" \
  -s "$PWD/tests/fixtures/make_save.gd" -- "$OUT/v11"
cp "$OUT/v11/save.json" tests/fixtures/saves/v11.json; cp "$OUT/v11/expect.json" tests/fixtures/saves/v11.expect.json
```

Für die aktuelle Version statt `--path "$OUT/hist"` einfach `--path .`. Ein Test verlangt eine Datei je Version. ERROR-Zeilen direkt nach
„(die folgende ERROR-Meldung ist erwartet)“ sind beabsichtigt.

## Spielstand

Liegt lokal auf dem Gerät (`user://savegame.json`, daneben die Backups `savegame.json.bak`, `.bak2`, `.bak3`;
defekte Stände werden als `savegame.corrupt-<zeit>.json` aufbewahrt, höchstens 3). Auf dem Mac:
`~/Library/Application Support/Godot/app_userdata/OFF CAMERA/`. Zurücksetzen im Spiel über
Einstellungen → Spielstand löschen.

## Projektstruktur

```
project.godot        Projektkonfiguration (Querformat, GL-Compatibility-Renderer)
scenes/app/          Hauptszene app.tscn
scripts/core/        GameState (eine Spielsitzung), GameData (alle Datenkataloge)
scripts/systems/     Spielsysteme (Zeit, Ledger, Orte, Aktivitäten, Ereignisse, Termine, Kanal, Content, Ausrüstung, Unternehmen, Speichern, Datenprüfung)
scripts/models/      Datenmodelle (Buchung, Spielerwerte, Ort, Aktivität, Ereignis, Termin, Kanal-Änderung, Content-Format, Ausrüstung, Unternehmensart)
data/locations/      Orte als JSON (Kartenposition, Öffnungszeiten)
data/activities/     Aktivitäten als JSON (je an einen Ort gebunden)
data/events/         Ereignisse als JSON
data/appointments/   Feste Termine als JSON
data/content/        Content-Formate als JSON (Phase 3)
data/equipment/      Ausrüstung mit Stufen als JSON (Phase 3)
data/company/        Unternehmensarten als JSON (Phase 4)
data/obligations/    Fristen (Mieten, fiktive Stadtabgabe) als JSON (Phase 5)
scripts/ui/          UI: App-Wurzel, Hauptmenü, Spielansicht, Stadtkarte, windows/ (Fenster) – zeigen nur an, keine Spielregeln
assets/kenney/       Grafiken aus Kenney-CC0-Paketen (nur benutzte Dateien, je mit License.txt)
tests/               Tests + Runner (nicht im iOS-Export)
docs/                Roadmap, Architektur, Entscheidungen
```

Weitere Ordner entstehen erst, wenn sie gebraucht werden.
