extends VBoxContainer

## Fensterinhalt „Termine“ (G2): anstehende Termine mit „Wahrnehmen“ (nur wenn möglich, sonst der Grund).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SHOWN_COUNT := 6

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "AppointmentList"
	add_theme_constant_override("separation", 16)
	refresh()


func get_title() -> String:
	return "Termine"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var upcoming: Array = _game.appointments.get_upcoming()
	if upcoming.is_empty():
		add_child(UiStyle.label("Keine anstehenden Termine.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		return
	for i in mini(upcoming.size(), SHOWN_COUNT):
		var definition = upcoming[i]
		var location = _game.locations.get_catalog().get_definition(definition.location)
		var card := UiStyle.card()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)
		box.add_child(UiStyle.wrapping_label(definition.title))
		box.add_child(UiStyle.wrapping_label("%s · %s · %s" % [TimeSystemScript.format_stamp(definition.start_minutes),
				location.display_name, TimeSystemScript.format_duration(definition.duration_minutes)],
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		box.add_child(UiStyle.wrapping_label("Wahrnehmen: %s · Verpasst: %s" % [
				ActivityText.option_summary(definition.effects, definition.money_cents),
				ActivityText.option_summary(definition.missed_effects, 0)], UiStyle.SMALL_FONT_SIZE))
		var reason: String = _game.appointments.check(definition.id)
		if not reason.is_empty():
			box.add_child(UiStyle.wrapping_label(reason, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		else:
			var button: Button = _screen.scroll_button("Wahrnehmen", "AttendButton_%s" % definition.id)
			var id: String = definition.id
			button.pressed.connect(func() -> void: _screen.on_attend_pressed(id))
			box.add_child(button)
		add_child(card)
