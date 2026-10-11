# Entscheidungen

## 001 – Renderer: GL Compatibility
Für eine 2D-Management-UI auf dem iPhone ist der Compatibility-Renderer die einfachste und robusteste Wahl.
Keine aufwendigen Effekte nötig. Kann später geändert werden, falls es einen konkreten Grund gibt.

## 002 – Hochformat, 720×1280 Basisauflösung
`display/window/handheld/orientation = portrait`, Stretch-Modus `canvas_items` mit Aspect `expand`,
damit sich die UI an verschiedene iPhone-Seitenverhältnisse anpasst. Die Editor-Fenstergröße ist auf
405×720 verkleinert, damit das Testfenster auf den Mac-Bildschirm passt.

## 003 – Godot-Version
Festgelegt auf **Godot 4.7.2.stable** (Standard-Version, nicht .NET), bestätigt über „Über Godot“ und installierte iOS-Exportvorlagen.
Xcode 27.0. Nicht mitten in einer Phase aktualisieren.
