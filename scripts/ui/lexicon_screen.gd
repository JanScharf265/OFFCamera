extends VBoxContainer

## „Hilfe / Lexikon“ (T.4): alle GESEHENEN Tutorials des aktuellen Spielstands (keine Spoiler), sortiert nach Bereich
## und Reihenfolge – Liste aus TutorialSystem.get_seen(). Jeder Eintrag ist ein Button mit dem Titel; Antippen klappt
## den vollen Text auf (umbrechend, nichts abgeschnitten). Die Liste scrollt im Menü-Scrollbereich der App.

signal back_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

## Vor dem Einfügen in den Baum setzen: Liste von Tutorial-Definitionen (leer = noch nichts gesehen).
var entries: Array = []


func _ready() -> void:
	name = "LexiconScreen"
	add_theme_constant_override("separation", 12)
	var title := UiStyle.label("Hilfe / Lexikon", UiStyle.LARGE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	if entries.is_empty():
		var empty := UiStyle.wrapping_label("Hier stehen die Erklärungen, die du im Spiel schon gesehen hast.",
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		empty.name = "LexiconEmpty"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(empty)
	for definition in entries:
		add_child(_entry(definition))
	var back := UiStyle.button("Zurück")
	back.name = "BackButton"
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func _entry(definition) -> Control:
	var card := UiStyle.card()
	card.name = "LexiconEntry_%s" % definition.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := Button.new()
	head.name = "LexiconTitle_%s" % definition.id
	head.text = "+  %s" % definition.title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
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
