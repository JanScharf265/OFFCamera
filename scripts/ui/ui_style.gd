extends RefCounted

## Gemeinsame Farben, Größen und Bausteine für die UI.
## Größen beziehen sich auf die 720 px hohe Basisauflösung im Querformat (1280 × 720)
## (ca. 1,8 Bildpunkte pro iOS-Punkt – 96 px ≈ 53 pt Touch-Höhe).

const BACKGROUND := Color(0.07, 0.07, 0.09)
const SURFACE := Color(0.13, 0.13, 0.16)
const SURFACE_PRESSED := Color(0.2, 0.2, 0.25)
const TEXT := Color(0.92, 0.92, 0.95)
const MUTED := Color(0.62, 0.62, 0.68)
const ACCENT := Color(0.84, 0.27, 0.35)
const ACCENT_PRESSED := Color(0.66, 0.2, 0.27)
const DISABLED := Color(0.25, 0.25, 0.28)
const POSITIVE := Color(0.45, 0.8, 0.5)
const NEGATIVE := Color(0.95, 0.5, 0.45)

const PADDING := 24
const FONT_SIZE := 30
const SMALL_FONT_SIZE := 24
const LARGE_FONT_SIZE := 44
const TITLE_FONT_SIZE := 72
const BUTTON_HEIGHT := 96
const CORNER_RADIUS := 16
## Breite der zentrierten Spalte für Menüs (Querformat).
const COLUMN_WIDTH := 640
## Querformat-Menüs (Phase 7): kompakter Titel und Buttons (84 px ≈ 46 pt, über Apples 44 pt).
const MENU_TITLE_FONT_SIZE := 56
const MENU_BUTTON_HEIGHT := 84
## Querformat-Spielansicht (G2): Seitenbuttons, Fenster, Hinweise.
## 4 Buttons je Seite müssen unter das HUD passen (720 px hoch, Safe Area). Gemessen (Godot 4.7):
## Mindesthöhe eines Seitenbuttons = Icon-Größe (icon_max_width) + 84 px für Text und Rand –
## mit 28 px also 112 px; 4 × 112 + 3 × 8 = 472 px (Test test_side_bars_fit_on_screen_with_company).
const SIDE_BUTTON_SIZE := Vector2(140, 84)
const SIDE_ICON_SIZE := 28
const WINDOW_MAX_WIDTH := 980
const HUD_SURFACE := Color(0.07, 0.07, 0.09, 0.86)
const DIM := Color(0, 0, 0, 0.55)


static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", TEXT)

	theme.set_stylebox("normal", "Button", _box(ACCENT))
	theme.set_stylebox("hover", "Button", _box(ACCENT))  # Touch: kein Hover-Effekt
	theme.set_stylebox("pressed", "Button", _box(ACCENT_PRESSED))
	theme.set_stylebox("hover_pressed", "Button", _box(ACCENT_PRESSED))
	theme.set_stylebox("disabled", "Button", _box(DISABLED))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED)
	return theme


static func label(text: String, font_size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func wrapping_label(text: String, font_size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var result := label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func section_label(text: String) -> Label:
	return label(text, SMALL_FONT_SIZE, MUTED)


static func button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = BUTTON_HEIGHT
	return result


## Karten leiten Berührungen weiter (PASS), damit eine umgebende
## ScrollContainer auch dann scrollt, wenn die Geste auf der Karte beginnt.
static func card() -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", _box(SURFACE, PADDING))
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	return result


## Abgerundeter Hintergrund in einer Farbe (z. B. für Karten-Pins).
static func flat_box(color: Color, padding: int = 12) -> StyleBoxFlat:
	return _box(color, padding)


static func _box(color: Color, padding: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_content_margin_all(padding)
	return box


## Halbtransparente Fläche für HUD-Ecken und Hinweise über der Karte.
static func hud_panel() -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", _box(HUD_SURFACE, 14))
	return result


## Kleiner Button am Bildschirmrand (Seitenleiste), optional mit Icon über dem Text.
static func side_button(text: String, icon_path: String = "") -> Button:
	var result := Button.new()
	result.text = text
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		result.icon = load(icon_path) as Texture2D
		result.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		result.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.add_theme_constant_override("icon_max_width", SIDE_ICON_SIZE)
	result.custom_minimum_size = SIDE_BUTTON_SIZE
	result.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	for state in ["normal", "hover", "disabled"]:
		result.add_theme_stylebox_override(state, _box(HUD_SURFACE, 8))
	for state in ["pressed", "hover_pressed"]:
		result.add_theme_stylebox_override(state, _box(SURFACE_PRESSED, 8))
	return result


## Hintergrund eines Fensters.
static func window_box() -> StyleBoxFlat:
	var box := _box(BACKGROUND, PADDING)
	box.border_color = SURFACE_PRESSED
	box.set_border_width_all(2)
	return box
