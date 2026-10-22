extends VBoxContainer

## Fensterinhalt „Erinnerung“ (G5.6): Termin in höchstens 30 Spielminuten – Name, Uhrzeit, Ort, Fahrzeit vom aktuellen
## Ort und eine klare Aussage („Du schaffst es noch“ / „Du kommst zu spät: Fahrt 20 min“). Buttons „Hinfahren“ (wenn
## nicht dort), „Warten bis HH:MM“ (wenn dort, G5.5) und „Später“. Die Werte kommen aus ReminderSystem.describe();
## hier wird nur angezeigt. Kleines Fenster, mittig (Größe aus needed_height()).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var appointment_id := ""

var _screen
var _game
## Werte beim Öffnen – die Erinnerung zeigt den Moment, in dem sie kam (jede Aktion schließt sie).
var _info := {}


func setup(screen, game, p_appointment_id: String) -> void:
	_screen = screen
	_game = game
	appointment_id = p_appointment_id
	_info = game.reminders.describe(appointment_id)


func _ready() -> void:
	name = "ReminderContent"
	add_theme_constant_override("separation", 10)
	_build()


func get_title() -> String:
	return "Termin in %s" % TimeSystemScript.format_duration(_info["minutes_left"])


func _build() -> void:
	var location = _game.locations.get_catalog().get_definition(_info["location_id"])
	var where: String = location.display_name if location != null else _info["location_id"]
	var title := UiStyle.wrapping_label(_info["title"], UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	title.name = "ReminderAppointment"
	add_child(title)
	var when := UiStyle.wrapping_label("%s · %s" % [_clock(_info["start_minutes"]), where], UiStyle.MIN_READ_FONT_SIZE,
			UiStyle.MUTED)
	when.name = "ReminderWhen"
	add_child(when)
	var trip_text := "Du bist dort." if _info["here"] \
			else "Fahrt von hier: %s" % TimeSystemScript.format_duration(_info["travel_minutes"])
	var trip := UiStyle.wrapping_label(trip_text, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	trip.name = "ReminderTravel"
	add_child(trip)
	var verdict_text := "Du schaffst es noch" if _info["on_time"] \
			else "Du kommst zu spät: Fahrt %s" % TimeSystemScript.format_duration(_info["travel_minutes"])
	var verdict := UiStyle.wrapping_label(verdict_text, UiStyle.SMALL_FONT_SIZE,
			UiStyle.POSITIVE if _info["on_time"] else UiStyle.NEGATIVE)
	verdict.name = "ReminderVerdict"
	add_child(verdict)

	var buttons := HBoxContainer.new()
	buttons.name = "ReminderButtons"
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	if _info["here"]:
		var wait: Button = _screen.scroll_button("Warten bis %s" % _clock(_info["start_minutes"]), "ReminderWaitButton")
		wait.disabled = not _game.appointments.check_wait(appointment_id).is_empty()
		wait.pressed.connect(func() -> void: _screen.on_reminder_wait_pressed(appointment_id))
		_grow(wait)
		buttons.add_child(wait)
	else:
		var travel: Button = _screen.scroll_button("Hinfahren", "ReminderTravelButton")
		travel.disabled = not _game.locations.check_travel(_info["location_id"]).is_empty()
		travel.pressed.connect(func() -> void: _screen.on_reminder_travel_pressed(_info["location_id"]))
		_grow(travel)
		buttons.add_child(travel)
	var later: Button = _screen.scroll_button("Später", "ReminderLaterButton")
	for state in ["normal", "hover"]:
		later.add_theme_stylebox_override(state, UiStyle.flat_box(UiStyle.SURFACE_PRESSED, 16))
	later.pressed.connect(func() -> void: _screen.on_reminder_later_pressed())
	_grow(later)
	buttons.add_child(later)


## Höhe, die der Inhalt bei `width` braucht (umbrechende Labels erst mit ihrer Breite messen).
func needed_height(width: float) -> float:
	size = Vector2(width, size.y)
	for i in 2:
		_sort(self)
		for node in find_children("*", "Label", true, false):
			var label := node as Label
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				label.get_line_count()
				label.update_minimum_size()
	return get_combined_minimum_size().y


static func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort(child)


static func _grow(button: Button) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = UiStyle.TOUCH_SIZE


static func _clock(minutes: int) -> String:
	return TimeSystemScript.format_stamp(minutes).get_slice(" · ", 1)
