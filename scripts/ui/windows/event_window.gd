extends VBoxContainer

## Fensterinhalt eines offenen Ereignisses (G2): Text, Optionen mit allen Folgen.
## Das Fenster lässt sich nicht schließen – erst entscheiden, dann weiterspielen.

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
	add_child(UiStyle.wrapping_label(definition.text, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for option in definition.options:
		var channel: Dictionary = _game.events.option_channel_deltas(instance_id, option.id)
		add_child(UiStyle.wrapping_label(ActivityText.option_summary(option.effects, option.money_cents, channel),
				UiStyle.SMALL_FONT_SIZE))
		var button := UiStyle.button(option.label)
		button.name = "EventOption_%s" % option.id
		var option_id: String = option.id
		var label: String = option.label
		button.pressed.connect(func() -> void: _screen.on_event_option_pressed(instance_id, option_id, label))
		add_child(button)


func get_title() -> String:
	return "Ereignis: %s" % _game.events.get_definition_for(instance_id).title
