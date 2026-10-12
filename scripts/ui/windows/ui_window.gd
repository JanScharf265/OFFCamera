extends PanelContainer

## Rahmen eines Fensters über der Karte (G2): Titel, Schließen-Button, eigener Scrollbereich.
## Der Inhalt ist ein beliebiges Control mit refresh(). Merkt sich den Scrollstand beim
## Antippen eines Buttons, damit Wischen im Fenster nicht als Tippen zählt.

signal close_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

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
	box.add_child(header)
	_title = UiStyle.label(title, UiStyle.LARGE_FONT_SIZE)
	_title.name = "WindowTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	_close_button = UiStyle.side_button("Schließen", "res://assets/kenney/game-icons/cross.png")
	_close_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_close_button.name = "WindowCloseButton"
	_close_button.custom_minimum_size = Vector2(200, 72)
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
