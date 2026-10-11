# OFF CAMERA

Singleplayer-Lebens- und Managementsimulation für das eigene iPhone (Godot 4 + GDScript).
Kein App Store, kein Android, offline spielbar.

## Stand

**Phase 0 abgeschlossen ✅ – als Nächstes Phase 1: Spielbares Grundgerüst** (siehe [`docs/ROADMAP.md`](docs/ROADMAP.md))

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

Godot 4.7 benennt die exportierten Dateien `OFFCamera.ipa.xcodeproj`, `OFFCamera.ipa.xcframework` usw. – das ist normal.
Warnungen zu Kamera-/Mikrofon-/Foto-Usage-Descriptions sind harmlos (die App fragt diese Rechte nicht an).

Fehler? Exakte Meldung aus Godot bzw. Xcode kopieren (siehe „Fehlerbericht“ in [`CLAUDE.md`](CLAUDE.md)).

## Tests ausführen (Mac)

```sh
cd ~/Developer/OFFCamera
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
```

Am Ende steht `N bestanden, M fehlgeschlagen`. ERROR-Zeilen direkt nach
„(die folgende ERROR-Meldung ist erwartet)“ sind beabsichtigt.

## Projektstruktur

```
project.godot        Projektkonfiguration (Hochformat, GL-Compatibility-Renderer)
scenes/app/          App-Szenen (aktuell: Startbildschirm)
scripts/systems/     Spielsysteme (Zeit, später Ledger, Events, …)
scripts/ui/          UI-Skripte (zeigen nur an, keine Spielregeln)
tests/               Tests + Runner (nicht im iOS-Export)
docs/                Roadmap, Architektur, Entscheidungen
```

Weitere Ordner (`data/` …) entstehen erst, wenn sie gebraucht werden.
