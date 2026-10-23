extends Control

## „Hilfe / Lexikon“ (T.4): alle GESEHENEN Tutorials des aktuellen Spielstands (keine Spoiler), in Spielreihenfolge
## (T.5) – Liste aus TutorialSystem.get_seen(). Jeder Eintrag ist ein Button mit dem Titel; Antippen klappt den vollen
## Text auf (umbrechend, nichts abgeschnitten). T.5: eigener Bildschirm über die ganze Safe Area – Titelzeile mit
## immer sichtbarem rundem Schließen-Button oben rechts (wie die Fenster), darunter die scrollende Liste.

signal back_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const RoundButtonScript := preload("res://scripts/ui/round_button.gd")

## Vor dem Einfügen in den Baum setzen: Liste von Tutorial-Definitionen (leer = noch nichts gesehen).
var entries: Array = []

var _margins: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _frame: VBoxContainer


func _ready() -> void:
	name = "LexiconScreen"
	_frame = VBoxContainer.new()
	_frame.name = "LexiconFrame"
	_frame.add_theme_constant_override("separation", 12)
	add_child(_frame)

	var header := HBoxContainer.new()
	header.name = "LexiconHeader"
	header.add_theme_constant_override("separation", 16)
	_frame.add_child(header)
	var title := UiStyle.label("Hilfe / Lexikon", UiStyle.LARGE_FONT_SIZE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := RoundButtonScript.new("", "res://assets/kenney/game-icons/cross.png", UiStyle.CLOSE_ROUND_SIZE)
	close.name = "LexiconCloseButton"
	close.tooltip_text = "Schließen"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.name = "LexiconScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "LexiconList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	if entries.is_empty():
		var empty := UiStyle.wrapping_label("Hier stehen die Erklärungen, die du im Spiel schon gesehen hast.",
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		empty.name = "LexiconEmpty"
		list.add_child(empty)
	for definition in entries:
		list.add_child(_entry(definition))
	var back := UiStyle.button("Zurück")
	back.name = "BackButton"
	UiStyle.style_neutral_button(back)
	back.pressed.connect(func() -> void: back_pressed.emit())
	list.add_child(back)

	resized.connect(_layout)
	_layout()


## Von der App: Abstände [links, oben, rechts, unten] (Safe Area inkl. Grundabstand).
func set_safe_margins(margins: Array[float]) -> void:
	if margins.size() == 4:
		_margins = margins
	if is_node_ready():
		_layout()


func _layout() -> void:
	if _frame == null:
		return
	_frame.position = Vector2(_margins[0], _margins[1])
	_frame.size = Vector2(maxf(size.x - _margins[0] - _margins[2], 0.0), maxf(size.y - _margins[1] - _margins[3], 0.0))


func _entry(definition) -> Control:
	var card := UiStyle.card()
	card.name = "LexiconEntry_%s" % definition.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := Button.new()
	head.name = "LexiconTitle_%s" % definition.id
	head.text = "+  %s" % definition.title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.mouse_filter = Control.MOUSE_FILTER_PASS  # Wischen erreicht die Liste
	head.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	head.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	head.add_theme_color_override("font_color", UiStyle.TEXT)
	box.add_child(head)
	var text := UiStyle.wrapping_label(definition.text, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	text.name = "LexiconText_%s" % definition.id
	text.visible = false
	box.add_child(text)
	head.pressed.connect(func() -> void:
		text.visible = not text.visible
		head.text = ("–  %s" if text.visible else "+  %s") % definition.title)
	return card
