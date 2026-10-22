extends Button

## Runder Button der Spielansicht (G4.4): sichtbarer Kreis mit Symbol, optional eine kleine Beschriftung
## darunter und ein roter Zählerpunkt. Die Tippfläche ist der ganze Button (UiStyle.TOUCH_SIZE, ≥ 84 px ≈ 44 pt),
## auch dort, wo nichts gezeichnet ist. Gezeichnet wird nur über die Kinder; der Button selbst ist unsichtbar.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

## G5.8: Zahl in Mini-Schrift (19 px) – Punkt so hoch, dass sie hineinpasst; bei „9+“ breiter (Pille).
const BADGE_SIZE := 26.0
const BADGE_WIDE := 36.0
## ab dieser Zahl „9+“
const BADGE_MAX := 9

var _circle: Panel
var _circle_box: StyleBoxFlat
var _badge: Panel
var _badge_label: Label
var _badge_count := 0
var _caption_label: Label
var _circle_size: float
var _circle_top := 0.0


## caption leer = ohne Beschriftung. circle_size: sichtbarer Durchmesser.
func _init(caption: String, icon_path: String, circle_size: float = UiStyle.ROUND_BUTTON_SIZE) -> void:
	_circle_size = circle_size
	custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = caption
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	_circle = Panel.new()
	_circle.name = "Circle"
	_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle_box = UiStyle.flat_box(UiStyle.HUD_SURFACE, 0)
	_circle_box.set_corner_radius_all(int(circle_size / 2.0))
	_circle_box.border_color = UiStyle.ROUND_BUTTON_BORDER
	_circle_box.set_border_width_all(2)
	_circle_box.anti_aliasing = true
	_circle.add_theme_stylebox_override("panel", _circle_box)
	add_child(_circle)
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_size := roundf(circle_size * 0.46)
	icon_rect.size = Vector2(icon_size, icon_size)
	icon_rect.position = Vector2(circle_size - icon_size, circle_size - icon_size) / 2.0
	_circle.add_child(icon_rect)

	if not caption.is_empty():
		_caption_label = UiStyle.mini_label(caption)
		_caption_label.name = "Caption"
		_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_caption_label)

	_badge = Panel.new()
	_badge.name = "Badge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_box := UiStyle.flat_box(UiStyle.BADGE, 0)
	badge_box.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	badge_box.anti_aliasing = true
	_badge.add_theme_stylebox_override("panel", badge_box)
	_badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.visible = false
	add_child(_badge)
	_badge_label = UiStyle.mini_label("")
	_badge_label.name = "BadgeLabel"
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.size = _badge.size
	_badge.add_child(_badge_label)

	button_down.connect(func() -> void: _circle_box.bg_color = UiStyle.SURFACE_PRESSED)
	button_up.connect(func() -> void: _circle_box.bg_color = UiStyle.HUD_SURFACE)
	resized.connect(_arrange)
	_arrange()


## Mit Beschriftung ist der Button mindestens so breit wie sie (G4.7: 19-px-Schrift, nichts abgeschnitten) –
## die Spalten werden dadurch etwas breiter.
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _caption_label != null:
		var text_width := _caption_label.get_theme_font("font").get_string_size(_caption_label.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.MINI_FONT_SIZE).x
		custom_minimum_size.x = maxf(UiStyle.TOUCH_SIZE, ceilf(text_width) + 8.0)
		_arrange()


## Abstand des Kreises von der Oberkante der Tippfläche (z. B. Zahnrad mittig in der HUD-Leiste).
func set_circle_top(top: float) -> void:
	_circle_top = top
	_arrange()


## Roter Zählerpunkt mit Zahl; 0 = unsichtbar, ab 10 „9+“.
func set_badge(count: int) -> void:
	_badge_count = maxi(count, 0)
	_badge.visible = _badge_count > 0
	_badge_label.text = str(_badge_count) if _badge_count <= BADGE_MAX else "%d+" % BADGE_MAX
	_badge.size = Vector2(BADGE_SIZE if _badge_count <= BADGE_MAX else BADGE_WIDE, BADGE_SIZE)
	_badge_label.size = _badge.size
	_arrange()


func get_badge() -> int:
	return _badge_count if _badge.visible else 0


func _arrange() -> void:
	var width := maxf(size.x, custom_minimum_size.x)
	var top := _circle_top
	if _caption_label == null and is_zero_approx(_circle_top):
		top = (maxf(size.y, custom_minimum_size.y) - _circle_size) / 2.0
	_circle.size = Vector2(_circle_size, _circle_size)
	_circle.position = Vector2((width - _circle_size) / 2.0, top)
	if _caption_label != null:
		_caption_label.size = Vector2(width, 0.0)
		_caption_label.position = Vector2(0.0, top + _circle_size)
	# Oben rechts am Kreis, rechts über den Kreis hinaus, damit das Symbol frei bleibt (G5.8).
	_badge.position = Vector2((width + _circle_size) / 2.0 - _badge.size.x + 12.0, top - 10.0)
