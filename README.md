# OFF CAMERA

Singleplayer-Lebens- und Managementsimulation für das eigene iPhone (Godot 4 + GDScript).
Kein App Store, kein Android, offline spielbar.

## Stand

**Phase 0 – Projektgrundlage und iPhone-Export** (siehe [`docs/ROADMAP.md`](docs/ROADMAP.md))

| Was | Status |
| --- | --- |
| Godot-Projekt + Startbildschirm | angelegt, im Editor noch ungetestet |
| iOS-Export nach Xcode | offen |
| Start auf dem iPhone | offen |

## Versionen

| Tool | Version |
| --- | --- |
| Godot | _bitte eintragen, z. B. 4.5.1.stable_ |
| Xcode | _bitte eintragen (`xcodebuild -version`)_ |
| macOS | _bitte eintragen_ |
| Test-iPhone | _Modell + iOS-Version eintragen_ |

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
4. Das erzeugte `.xcodeproj` in Xcode öffnen.
5. Target → *Signing & Capabilities* → Team wählen, „Automatically manage signing“ an.
6. Oben dein iPhone als Ziel wählen → **Run** (▶).
7. Auf dem iPhone ggf. *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* aktivieren
   und unter *Allgemein → VPN & Geräteverwaltung* dem Entwicklerzertifikat vertrauen.

Kostenloses Apple-Konto: App läuft nach einigen Tagen ab und muss dann neu installiert werden.

Fehler? Exakte Meldung aus Godot bzw. Xcode kopieren (siehe „Fehlerbericht“ in [`CLAUDE.md`](CLAUDE.md)).

## Projektstruktur

```
project.godot        Projektkonfiguration (Hochformat, GL-Compatibility-Renderer)
scenes/app/          App-Szenen (aktuell: Startbildschirm)
scripts/ui/          UI-Skripte (zeigen nur an, keine Spielregeln)
docs/                Roadmap, Architektur, Entscheidungen
```

Weitere Ordner (`scripts/systems/`, `data/`, `tests/` …) entstehen erst, wenn sie gebraucht werden.
