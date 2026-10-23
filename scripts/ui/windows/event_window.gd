extends VBoxContainer

## Fensterinhalt eines offenen Ereignisses (G2): Text, Optionen mit allen Folgen.
## Das Fenster lässt sich nicht schließen – erst entscheiden, dann weiterspielen.
## GD 086: Jede Antwort ist eine Zeile – Folgen links (umbrechend), Button rechts auf der Bedienseite (84 px hoch,
## feste Breite) –, damit auch drei Antworten ohne Scrollen sichtbar sind (Layout-Test für alle Ereignisse).

## Breite der Antwort-Buttons (längste Beschriftung „Einspruch einlegen (1 h 30 min)“ passt in 24 px)
const OPTION_BUTTON_WIDTH := 430.0

const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var instance_id := ""

var _screen
var _game


func setup(screen, game, p_instance_id: String) -> void:
	_screen = screen
	_game = game
	instance_id = p_instance_id


func _ready() -> void:
	name = "EventPanel"
	add_theme_constant_override("separation", 12)
	var definition = _game.events.get_definition_for(instance_id)
	add_child(UiStyle.wrapping_label(_game.events.get_text(instance_id), UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for option in definition.options:
		var channel: Dictionary = _game.events.option_channel_deltas(instance_id, option.id)
		var row := HBoxContainer.new()
		row.name = "EventOptionRow_%s" % option.id
		row.add_theme_constant_override("separation", 16)
		add_child(row)
		var summary := UiStyle.wrapping_label(ActivityText.event_option_summary(option, channel), UiStyle.MIN_READ_FONT_SIZE)
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(summary)
		var button := UiStyle.button(option.label)
		button.name = "EventOption_%s" % option.id
		button.custom_minimum_size = Vector2(OPTION_BUTTON_WIDTH, UiStyle.TOUCH_SIZE)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var blocked: String = _game.events.check_option(instance_id, option.id)
		if not blocked.is_empty():
			button.disabled = true
			summary.text = blocked
			summary.add_theme_color_override("font_color", UiStyle.MUTED)
		var option_id: String = option.id
		var label: String = option.label
		button.pressed.connect(func() -> void: _screen.on_event_option_pressed(instance_id, option_id, label))
		row.add_child(button)


func get_title() -> String:
	return "Ereignis: %s" % _game.events.get_definition_for(instance_id).title
