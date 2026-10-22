extends VBoxContainer

## Fensterinhalt „Kalender“ (G5.2, ersetzt „Termine“): Tagesplan als Zeitstrahl für heute – Termine und Fristen
## mit Uhrzeit, Ort und Fahrzeit; Vergangenes grau, der nächste Termin hervorgehoben, die aktuelle Uhrzeit als Linie.
## Termine, die man jetzt wahrnehmen kann, haben „Wahrnehmen“, sonst steht der Grund da. Kommt ein Termin heute noch,
## gibt es „Warten bis HH:MM“ (G5.5) – gesperrt mit Grund, z. B. „Erst hinfahren: Studio“.
## Die Daten kommen aus DayPlan (scripts/core/day_plan.gd); hier wird nur angezeigt.

const DayPlanScript := preload("res://scripts/core/day_plan.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const TIME_COLUMN := 96.0
const MARKER_COLUMN := 28.0
const STATE_TEXTS := {
	DayPlanScript.STATE_ATTENDED: "erledigt",
	DayPlanScript.STATE_MISSED: "verpasst",
	DayPlanScript.STATE_PAST: "vorbei",
	DayPlanScript.STATE_NEXT: "als Nächstes",
	DayPlanScript.STATE_UPCOMING: "",
	DayPlanScript.STATE_PAID: "bezahlt",
	DayPlanScript.STATE_WAIVED: "erlassen",
	DayPlanScript.STATE_OPEN: "offen",
}

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "CalendarContent"
	add_theme_constant_override("separation", 10)
	refresh()


func get_title() -> String:
	return "Kalender · %s" % _game.time.format_date()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var plan: Dictionary = DayPlanScript.for_day(_game)
	var entries: Array = plan["entries"]
	if entries.is_empty():
		var empty := UiStyle.wrapping_label("Heute keine Termine und Fristen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		empty.name = "CalendarEmpty"
		add_child(empty)
	for i in entries.size():
		if i == plan["now_index"]:
			add_child(_now_line(plan["now_minutes"]))
		add_child(_entry_row(entries[i]))
	if not entries.is_empty() and plan["now_index"] >= entries.size():
		add_child(_now_line(plan["now_minutes"]))
	var later: Dictionary = plan["next_later"]
	if not later.is_empty():
		var location = _game.locations.get_catalog().get_definition(later["location_id"])
		var hint := UiStyle.wrapping_label("Nächster Termin: %s · %s (%s)" % [
				TimeSystemScript.format_stamp(later["start_minutes"]), later["title"],
				location.display_name if location != null else later["location_id"]], UiStyle.MIN_READ_FONT_SIZE,
				UiStyle.MUTED)
		hint.name = "CalendarNextLater"
		add_child(hint)


## Linie für die aktuelle Uhrzeit.
func _now_line(now: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "CalendarNowLine"
	row.add_theme_constant_override("separation", 8)
	var time := UiStyle.label(_clock(now), UiStyle.SMALL_FONT_SIZE, UiStyle.BADGE)
	time.custom_minimum_size.x = TIME_COLUMN
	row.add_child(time)
	var line := ColorRect.new()
	line.color = UiStyle.BADGE
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	var label := UiStyle.label("Jetzt", UiStyle.MIN_READ_FONT_SIZE, UiStyle.BADGE)
	row.add_child(label)
	return row


func _entry_row(entry: Dictionary) -> Control:
	var past := DayPlanScript.is_past(entry)
	var row := HBoxContainer.new()
	row.name = "CalendarEntry_%s" % String(entry["id"]).replace("@", "_")
	row.add_theme_constant_override("separation", 8)
	var time := UiStyle.label(_clock(entry["start_minutes"]), UiStyle.SMALL_FONT_SIZE,
			UiStyle.MUTED if past else UiStyle.TEXT)
	time.custom_minimum_size.x = TIME_COLUMN
	time.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(time)
	row.add_child(_marker(entry, past))

	var card := UiStyle.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if entry["state"] == DayPlanScript.STATE_NEXT:
		var frame := (card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		frame.border_color = UiStyle.ACCENT
		frame.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", frame)
	if past:
		card.modulate = Color(1, 1, 1, 0.55)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := UiStyle.wrapping_label(entry["title"], UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED if past else UiStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var state_text: String = STATE_TEXTS.get(entry["state"], "")
	if entry["overdue"]:
		state_text = "überfällig"
	if not state_text.is_empty():
		var state := UiStyle.label(state_text, UiStyle.MIN_READ_FONT_SIZE, _state_color(entry))
		state.name = "CalendarState_%s" % String(entry["id"]).replace("@", "_")
		head.add_child(state)
	box.add_child(head)
	box.add_child(UiStyle.wrapping_label(_detail(entry), UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	if entry["kind"] == DayPlanScript.KIND_APPOINTMENT and not past:
		_add_attend(box, entry["id"])
	row.add_child(card)
	return row


## Punkt auf dem Zeitstrahl mit Linie nach unten.
func _marker(entry: Dictionary, past: bool) -> Control:
	var marker := Control.new()
	marker.custom_minimum_size = Vector2(MARKER_COLUMN, 0)
	marker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var color := UiStyle.ACCENT if entry["state"] == DayPlanScript.STATE_NEXT \
			else (UiStyle.DISABLED if past else UiStyle.MUTED)
	marker.draw.connect(func() -> void:
		var x := marker.size.x / 2.0
		marker.draw_line(Vector2(x, 0), Vector2(x, marker.size.y), UiStyle.SURFACE_PRESSED, 3.0)
		marker.draw_circle(Vector2(x, 20.0), 9.0, color))
	return marker


func _detail(entry: Dictionary) -> String:
	if entry["kind"] == DayPlanScript.KIND_OBLIGATION:
		var amount := LedgerSystemScript.format_cents(entry["amount_cents"])
		if entry["overdue"]:
			return "Fällig seit %s · offen %s" % [TimeSystemScript.format_stamp(entry["start_minutes"]), amount]
		if entry["state"] == DayPlanScript.STATE_OPEN:
			return "Fällig heute · offen %s" % amount
		return "Frist · %s" % amount
	var location = _game.locations.get_catalog().get_definition(entry["location_id"])
	var where: String = location.display_name if location != null else entry["location_id"]
	var span := "%s–%s" % [_clock(entry["start_minutes"]), _clock(entry["end_minutes"])]
	var travel: int = entry["travel_minutes"]
	var trip := "du bist dort" if travel == 0 else "%s Fahrt" % TimeSystemScript.format_duration(travel)
	return "%s · %s · %s" % [where, span, trip]


func _add_attend(box: VBoxContainer, appointment_id: String) -> void:
	if _game.appointments.offers_wait(appointment_id):
		_add_wait(box, appointment_id)
	var reason: String = _game.appointments.check(appointment_id)
	if not reason.is_empty():
		box.add_child(UiStyle.wrapping_label(reason, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
		return
	var button: Button = _screen.scroll_button("Wahrnehmen", "AttendButton_%s" % appointment_id)
	button.pressed.connect(func() -> void: _screen.on_attend_pressed(appointment_id))
	box.add_child(button)


## G5.5: „Warten bis 14:00“ – gesperrt mit Grund darunter (z. B. „Erst hinfahren: Studio“).
func _add_wait(box: VBoxContainer, appointment_id: String) -> void:
	var start: int = _game.appointments.get_catalog().get_definition(appointment_id).start_minutes
	var button: Button = _screen.scroll_button("Warten bis %s" % _clock(start), "WaitButton_%s" % appointment_id)
	button.pressed.connect(func() -> void: _screen.on_wait_pressed(appointment_id))
	box.add_child(button)
	var reason: String = _game.appointments.check_wait(appointment_id)
	button.disabled = not reason.is_empty()
	if not reason.is_empty():
		var label := UiStyle.wrapping_label(reason, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
		label.name = "WaitReason_%s" % appointment_id
		box.add_child(label)


func _state_color(entry: Dictionary) -> Color:
	match entry["state"]:
		DayPlanScript.STATE_NEXT:
			return UiStyle.ACCENT
		DayPlanScript.STATE_OPEN:
			return UiStyle.NEGATIVE
		DayPlanScript.STATE_MISSED:
			return UiStyle.NEGATIVE
	return UiStyle.MUTED


## Uhrzeit im Tag, z. B. "14:00" (format_stamp liefert "Tag 1 · 14:00").
static func _clock(minutes: int) -> String:
	return TimeSystemScript.format_stamp(minutes).get_slice(" · ", 1)
