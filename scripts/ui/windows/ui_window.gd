extends PanelContainer

## Rahmen eines Fensters über der Karte (G2): Titel, Schließen-Button, eigener Scrollbereich.
## Der Inhalt ist ein beliebiges Control mit refresh(). Merkt sich den Scrollstand beim
## Antippen eines Buttons, damit Wischen im Fenster nicht als Tippen zählt.

signal close_pressed
## T.6b: Tipp auf den Titel (nur wenn der Inhalt get_description() hat, z. B. Ortsfenster)
signal title_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const RoundButtonScript := preload("res://scripts/ui/round_button.gd")

## Hat sich die Liste zwischen Antippen und Loslassen weiter bewegt, war es Scrollen.
const TAP_SCROLL_TOLERANCE := 12

var content: Control
var _title: Label
## T.6b: unsichtbarer Button um den Titel (Tippfläche ≥ 84 px), null ohne Beschreibung
var _title_button: Button
var _close_button: Button
var _scroll: ScrollContainer
var _scroll_at_press := 0


## kind = Fensterart (z. B. "location"), wird als Knotenname "Window_<kind>" verwendet.
func _init(kind: String, title: String, window_content: Control, closable: bool = true) -> void:
	name = "Window_%s" % kind
	content = window_content
	add_theme_stylebox_override("panel", UiStyle.window_box())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var header := HBoxContainer.new()
	header.name = "WindowHeader"
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	_title = UiStyle.label(title, UiStyle.LARGE_FONT_SIZE)
	_title.name = "WindowTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	# Optional: Inhalt liefert Zusatzelemente für die Titelzeile (z. B. Ortsfenster: Infos + „Hinfahren“, G4.5).
	if content.has_method("take_header_extra"):
		var extra: Control = content.call("take_header_extra")
		add_theme_stylebox_override("panel", UiStyle.window_box(UiStyle.COMPACT_WINDOW_PADDING))
		_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_title.clip_text = false
		_title.add_theme_font_size_override("font_size", UiStyle.COMPACT_TITLE_FONT_SIZE)
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(extra)
	if content.has_method("get_description"):
		# T.6b: Der Titel wird antippbar (Info-Blase mit der Beschreibung); Label bleibt „WindowTitle“.
		_title_button = Button.new()
		_title_button.name = "WindowTitleButton"
		_title_button.focus_mode = Control.FOCUS_NONE
		_title_button.mouse_filter = Control.MOUSE_FILTER_PASS
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			_title_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_title_button.size_flags_horizontal = _title.size_flags_horizontal
		_title_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_title_button.tooltip_text = "Mehr über diesen Ort"
		var index := _title.get_index()
		header.remove_child(_title)
		_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_button.add_child(_title)
		header.add_child(_title_button)
		header.move_child(_title_button, index)
		_title_button.pressed.connect(func() -> void: title_pressed.emit())
		_size_title_button()
	# Rund wie die Buttons der Spielansicht (G4.5): Kreis 56 px, Tippfläche 84 px.
	_close_button = RoundButtonScript.new("", "res://assets/kenney/game-icons/cross.png", UiStyle.CLOSE_ROUND_SIZE)
	_close_button.name = "WindowCloseButton"
	_close_button.tooltip_text = "Schließen"
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_button.visible = closable
	_close_button.pressed.connect(func() -> void: close_pressed.emit())
	header.add_child(_close_button)

	_scroll = ScrollContainer.new()
	_scroll.name = "WindowScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)


## Sichtbare Höhe für den Inhalt (Fenster minus Rand, Titelzeile, Abstand) – synchron aus den Mindestgrößen,
## damit der Inhalt vor dem nächsten Bild entscheiden kann, ob er Reiter braucht (G4.6).
func body_height() -> float:
	var box := get_theme_stylebox("panel")
	var header := get_child(0).get_child(0) as Control
	return size.y - box.get_minimum_size().y - header.get_combined_minimum_size().y \
			- float((get_child(0) as VBoxContainer).get_theme_constant("separation"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_size_title_button()  # erst im Baum gilt die Schrift des Themes


func is_closable() -> bool:
	return _close_button.visible


func set_title(text: String) -> void:
	_title.text = text
	_size_title_button()


## Tippfläche des Titels: so breit wie der Text (mind. 84 px), 84 px hoch.
func _size_title_button() -> void:
	if _title_button == null:
		return
	var width := _title.get_theme_font("font").get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_title.get_theme_font_size("font_size")).x
	_title_button.custom_minimum_size = Vector2(maxf(ceilf(width) + 4.0, UiStyle.TOUCH_SIZE), UiStyle.TOUCH_SIZE)


## Rechteck des Titels (für die Info-Blase) in globalen Koordinaten.
func get_title_rect() -> Rect2:
	return (_title_button if _title_button != null else _title).get_global_rect()


func remember_scroll() -> void:
	_scroll_at_press = _scroll.scroll_vertical


func was_scroll() -> bool:
	return absi(_scroll.scroll_vertical - _scroll_at_press) > TAP_SCROLL_TOLERANCE


func refresh() -> void:
	if content.has_method("refresh"):
		content.call("refresh")
