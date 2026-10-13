extends RefCounted

## Testhilfe (Phase 7): typische iPhones im Querformat nachstellen. Headless ist das Fenster nur
## 64 × 64 – die Tests setzen Größe und Safe Area deshalb selbst.
## Viewport: Höhe immer 720 (Stretch „expand“), Breite = 720 × Seitenverhältnis.
## Safe Area: Apple-Punktmaße (quer: seitlich Notch/Dynamic Island, unten Home-Balken),
## umgerechnet mit 720 / Bildschirmhöhe in Punkten, plus 24 px Grundabstand (UiStyle.PADDING).

const PADDING := 24.0

## Name -> {size: Vector2, margins: [links, oben, rechts, unten]}
const DEVICES := {
	"iPhone SE (16:9, ohne Notch)": {"size": Vector2(1280, 720), "margins": [24.0, 24.0, 24.0, 24.0]},
	# 2532 × 1170 px = 844 × 390 pt; quer: 47 pt seitlich, 21 pt unten
	"iPhone 13/14 (Notch)": {"size": Vector2(1558, 720), "margins": [110.8, 24.0, 110.8, 62.8]},
	# 2796 × 1290 px = 932 × 430 pt; quer: 59 pt seitlich, 21 pt unten
	"iPhone 15/16 Pro Max (Dynamic Island)": {"size": Vector2(1560, 720), "margins": [122.8, 24.0, 122.8, 59.2]},
	# Härtefall: schmal UND große Ränder (rechnerischer Grenzfall, kein echtes Gerät)
	"Grenzfall schmal + Notch": {"size": Vector2(1280, 720), "margins": [134.0, 24.0, 134.0, 64.0]},
}


## Stellt ein Gerät für die laufende App nach (App-Größe und Safe Area).
static func apply(app: Control, device: String) -> void:
	var spec: Dictionary = DEVICES[device]
	app.size = spec["size"]
	var margins: Array[float] = []
	for value in spec["margins"]:
		margins.append(float(value))
	app.call("apply_margins", margins)
	var screen := app.find_child("CityMap", true, false)
	if screen != null:
		var game_screen := screen.get_parent() as Control
		game_screen.size = spec["size"]
		game_screen.call("set_safe_margins", margins)


## Sicherer Bereich (Rechteck innerhalb der Ränder) für ein Gerät.
static func safe_rect(device: String) -> Rect2:
	var spec: Dictionary = DEVICES[device]
	var m: Array = spec["margins"]
	var size: Vector2 = spec["size"]
	return Rect2(m[0], m[1], size.x - m[0] - m[2], size.y - m[1] - m[3])


## Rechteck eines Controls in Koordinaten der Spielansicht.
static func rect_of(control: Control) -> Rect2:
	return Rect2(control.position, control.size)


## Headless gibt es kein „nächstes Bild“, in dem Container umbrechende Labels auf ihre Breite setzen.
## Für Messungen: jedem umbrechenden Label unterhalb von `root` die Breite `width` geben und den
## Umbruch erzwingen – danach liefert get_combined_minimum_size() die echte Höhe.
static func settle_labels(root: Control, width: float) -> void:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			label.size = Vector2(width, 0.0)
			label.get_line_count()
			label.update_minimum_size()


## Headless sortieren Container ihre Kinder erst im nächsten Bild. Für Messungen verschachtelter Controls:
## alle Container unterhalb von `root` (von oben nach unten) sofort sortieren lassen.
static func sort_containers(root: Node) -> void:
	if root is Container:
		root.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in root.get_children():
		sort_containers(child)


## Rechteck eines (auch verschachtelten) Controls in Koordinaten von `screen`.
static func screen_rect(control: Control, screen: Control) -> Rect2:
	return Rect2(control.global_position - screen.global_position, control.size)
