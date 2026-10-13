extends PanelContainer

## Rahmen eines Fensters über der Karte (G2): Titel, Schließen-Button, eigener Scrollbereich.
## Der Inhalt ist ein beliebiges Control mit refresh(). Merkt sich den Scrollstand beim
## Antippen eines Buttons, damit Wischen im Fenster nicht als Tippen zählt.

signal close_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const RoundButtonScript := preload("res://scripts/ui/round_button.gd")

## Hat sich die Liste zwischen Antippen und Loslassen weiter bewegt, war es Scrollen.
const TAP_SCROLL_TOLERANCE := 12

var content: Control
var _title: Label
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
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(extra)
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


func is_closable() -> bool:
	return _close_button.visible


func set_title(text: String) -> void:
	_title.text = text


func remember_scroll() -> void:
	_scroll_at_press = _scroll.scroll_vertical


func was_scroll() -> bool:
	return absi(_scroll.scroll_vertical - _scroll_at_press) > TAP_SCROLL_TOLERANCE


func refresh() -> void:
	if content.has_method("refresh"):
		content.call("refresh")
