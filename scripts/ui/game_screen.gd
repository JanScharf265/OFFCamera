extends Control

## Spielansicht im Querformat (G2): die isometrische Stadtkarte im Vollbild, darüber
## die HUD-Leiste oben (G4.3, scripts/ui/hud_bar.gd: Tag/Uhrzeit/Ort, Energie, Stimmung, Konten),
## runde Buttons (G4.4, round_button.gd): rechts zwei Spalten „Leben“ (Kalender, Fristen, Kanal) und
## „Geschäft“ (Firma nach der Gründung, Buchungen; ab Paket U Organisation und Aufträge), das Menü als
## Zahnrad an der HUD-Leiste, links unten nur „Hier“,
## eine Hinweis-Leiste unten und höchstens ein Fenster (scripts/ui/windows/).
## Gebäude antippen öffnet das Fenster des Orts. Ein offenes Ereignis erscheint als
## Fenster, das zuerst entschieden werden muss.
## Zeigt nur an und ruft Systeme auf – Regeln stehen in den Systemen.
##
## Aktualisiert wird nach jeder Aktion explizit über _refresh(), nicht über die
## System-Signale (die feuern teils mitten im Ablauf einer Aktion).
## Würde eine Aktion einen Termin verpassen lassen, fragt zuerst ein Popup nach (G5.4, conflict_popup.gd).

signal menu_pressed
## Nach jeder erfolgreichen Aktion – die App speichert dann.
signal state_changed

const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const CityMapScript := preload("res://scripts/ui/city_map.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const HudBarScript := preload("res://scripts/ui/hud_bar.gd")
const ConflictPopupScript := preload("res://scripts/ui/conflict_popup.gd")
const TutorialOverlayScript := preload("res://scripts/ui/tutorial_overlay.gd")
const RoundButtonScript := preload("res://scripts/ui/round_button.gd")
const UiWindowScript := preload("res://scripts/ui/windows/ui_window.gd")
const LocationWindowScript := preload("res://scripts/ui/windows/location_window.gd")
const CalendarWindowScript := preload("res://scripts/ui/windows/calendar_window.gd")
const ReminderWindowScript := preload("res://scripts/ui/windows/reminder_window.gd")
const TripSystemScript := preload("res://scripts/systems/trip_system.gd")
const DayPlanScript := preload("res://scripts/core/day_plan.gd")
## Breite des kleinen Erinnerungsfensters (G5.6)
const REMINDER_MAX_WIDTH := 760.0
const ChannelWindowScript := preload("res://scripts/ui/windows/channel_window.gd")
const CompanyWindowScript := preload("res://scripts/ui/windows/company_window.gd")
const LedgerWindowScript := preload("res://scripts/ui/windows/ledger_window.gd")
const EventWindowScript := preload("res://scripts/ui/windows/event_window.gd")
const ObligationsWindowScript := preload("res://scripts/ui/windows/obligations_window.gd")

## Betrag je Tipp auf Einlage/Entnahme.
const TRANSFER_STEP_CENTS := 10000
## Kurze Hinweise verschwinden nach dieser Zeit (Echtzeit, nur Anzeige); lange bleiben bis zum Antippen.
const TOAST_SECONDS := 4.0
const TOAST_STICKY_LENGTH := 90
const GAP := 16.0
## Icons (Kenney „Game Icons“, CC0). Fehlt eine Datei, bleibt der Button ohne Icon.
const ICON_DIR := "res://assets/kenney/game-icons/"
const ICONS := {
	"AppointmentsButton": "res://assets/icons/calendar.svg",
	"ObligationsButton": ICON_DIR + "exclamation.png",
	"ChannelButton": ICON_DIR + "video.png",
	"CompanyButton": ICON_DIR + "cart.png",
	"LedgerButton": ICON_DIR + "menuList.png",
	"MenuButton": ICON_DIR + "gear.png",
	"HereButton": ICON_DIR + "target.png",
}
## Abstand zwischen den beiden Button-Spalten und zwischen den Buttons einer Spalte.
const COLUMN_GAP := 8.0

var _game: GameStateScript
## Geräte-Schalter „Kalender bei Tagesbeginn automatisch öffnen“ (G5.1/G5.3); von der App vor dem Einfügen gesetzt.
var auto_calendar := true
## Safe-Area-Abstände [links, oben, rechts, unten] in Viewport-Pixeln (von der App).
var _margins: Array[float] = [24.0, 24.0, 24.0, 24.0]
var _map: CityMapScript
var _hud: HudBarScript
var _life_group: PanelContainer
var _business_group: PanelContainer
var _menu_button: RoundButtonScript
var _here_button: RoundButtonScript
var _company_button: RoundButtonScript
var _obligations_button: RoundButtonScript
var _calendar_button: RoundButtonScript
## Vibration (G5.9, von der App gesetzt; null = keine) – die Spielansicht meldet nur ihre eigenen Warnungen.
var haptics
var _toast: PanelContainer
var _feedback_label: Label
var _toast_timer: Timer
var _dim: ColorRect
var _window: UiWindowScript
var _window_kind := ""
var _selected_location := ""
## Offenes Konflikt-Popup (G5.4) oder null.
var _popup: ConflictPopupScript
## Tutorial-Anzeige (T.3) über allem; null = keine
var _tutorial: TutorialOverlayScript


## Vor dem Einfügen in den Baum aufrufen.
func setup(game: GameStateScript) -> void:
	_game = game


## Von der App: Abstände für Notch/Home-Balken. Die Karte bleibt Vollbild.
func set_safe_margins(margins: Array[float]) -> void:
	if margins.size() == 4:
		_margins = margins
	if is_node_ready():
		_layout()


func _ready() -> void:
	assert(_game != null, "GameScreen: setup() wurde nicht aufgerufen.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_location = _game.locations.get_current()

	_map = CityMapScript.new()
	_map.name = "CityMap"
	_map.setup(_game.locations.get_catalog())
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.location_pressed.connect(_on_location_pressed)
	add_child(_map)

	_hud = HudBarScript.new()
	add_child(_hud)

	_life_group = _button_group("LifeGroup", "LEBEN")
	_calendar_button = _round_button("Kalender", "AppointmentsButton", _open_appointments)
	_add_to_group(_life_group, _calendar_button)
	_obligations_button = _round_button("Fristen", "ObligationsButton", _open_obligations)
	_add_to_group(_life_group, _obligations_button)
	_add_to_group(_life_group, _round_button("Kanal", "ChannelButton", _open_channel))
	_business_group = _button_group("BusinessGroup", "GESCHÄFT")
	# Ab Paket U kommen hier „Organisation“ und „Aufträge“ dazu (Entscheidung 038).
	_company_button = _round_button("Firma", "CompanyButton", _open_company)
	_add_to_group(_business_group, _company_button)
	_add_to_group(_business_group, _round_button("Buchungen", "LedgerButton", _open_ledger))
	_menu_button = RoundButtonScript.new("", ICONS["MenuButton"], UiStyle.MENU_ROUND_SIZE)
	_menu_button.name = "MenuButton"
	_menu_button.tooltip_text = "Menü"
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(_menu_button)
	_here_button = RoundButtonScript.new("", ICONS["HereButton"])
	_here_button.name = "HereButton"
	_here_button.tooltip_text = "Hier"
	_here_button.pressed.connect(_on_here_pressed)
	add_child(_here_button)

	_toast = UiStyle.hud_panel()
	_toast.name = "Toast"
	_toast.visible = false  # erst mit der ersten Meldung (T.3: kein fester Starthinweis mehr)
	_toast.gui_input.connect(_on_toast_input)
	add_child(_toast)
	_feedback_label = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_feedback_label)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)
	add_child(_toast_timer)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = UiStyle.DIM
	_dim.visible = false
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	resized.connect(_layout)
	# Der frühere feste Hinweis „Tippe auf ein Gebäude …“ entfällt (T.3) – das erklärt jetzt das Tutorial.
	_refresh()


# --- Aufbau -----------------------------------------------------------------------

## Gruppe runder Buttons auf dezentem Hintergrund mit kleiner Überschrift (z. B. „LEBEN“).
func _button_group(node_name: String, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.flat_box(UiStyle.HUD_SURFACE, 0)
	box.content_margin_top = 6
	box.content_margin_bottom = 8
	box.content_margin_left = 6
	box.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(COLUMN_GAP))
	panel.add_child(column)
	var header := UiStyle.mini_label(title, UiStyle.MUTED)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(header)
	add_child(panel)
	return panel


func _add_to_group(group: PanelContainer, button: RoundButtonScript) -> void:
	group.get_node("Buttons").add_child(button)


func _round_button(caption: String, node_name: String, action: Callable) -> RoundButtonScript:
	var button := RoundButtonScript.new(caption, ICONS.get(node_name, ""))
	button.name = node_name
	button.pressed.connect(action)
	return button


## Ordnet alles innerhalb der Safe Area an; die Karte füllt den ganzen Bildschirm.
func _layout() -> void:
	if not is_node_ready():
		return
	var left := _margins[0]
	var top := _margins[1]
	var right := size.x - _margins[2]
	var bottom := size.y - _margins[3]

	_hud.reset_size()
	_hud.position = Vector2(left, top)
	_hud.size = Vector2(right - left, _hud.size.y)
	# Zahnrad: Kreis mittig in der Leiste, die Tippfläche (84 px) reicht unsichtbar darunter.
	_menu_button.position = Vector2(right - UiStyle.TOUCH_SIZE, top)
	_menu_button.set_circle_top((_hud.size.y - UiStyle.MENU_ROUND_SIZE) / 2.0)
	# Rechts zwei Spalten unter der Tippfläche des Zahnrads: „Geschäft“ außen, „Leben“ daneben.
	var columns_top := top + UiStyle.TOUCH_SIZE + COLUMN_GAP
	_business_group.reset_size()
	_business_group.position = Vector2(right - _business_group.size.x, columns_top)
	_life_group.reset_size()
	_life_group.position = Vector2(_business_group.position.x - COLUMN_GAP - _life_group.size.x, columns_top)
	# Links (Seite der Dynamic Island) nur „Hier“ unten.
	_here_button.position = Vector2(left, bottom - UiStyle.TOUCH_SIZE)

	# Der Hinweis liegt zwischen „Hier“ und den Button-Spalten.
	var toast_left := left + UiStyle.TOUCH_SIZE + GAP
	var toast_right := _life_group.position.x - GAP
	var toast_width := maxf(minf(900.0, toast_right - toast_left), 200.0)
	# Umbrechende Labels berechnen ihre Mindesthöhe für die Breite, die sie gerade haben (anfangs ~1 px →
	# riesig). Breite setzen, Umbruch erzwingen (get_line_count) und Mindestgröße neu berechnen lassen –
	# dann stimmt die Höhe sofort, nicht erst ein Bild später (gemessen in Phase 7).
	_feedback_label.custom_minimum_size.x = toast_width - 28.0
	_feedback_label.size = Vector2(toast_width - 28.0, 0.0)
	_feedback_label.get_line_count()
	_feedback_label.update_minimum_size()
	_toast.reset_size()
	_toast.position = Vector2((toast_left + toast_right - _toast.size.x) / 2.0, bottom - _toast.size.y)

	_dim.position = Vector2.ZERO
	_dim.size = size
	if _window != null and _window_kind == "location":
		# Ortsfenster (G4.5, seit G4.7 volle Breite – Entscheidung 049): unter der HUD-Leiste über die ganze Breite
		# der Safe Area; die Button-Spalten liegen darunter (abgedunkelt, wie bei allen Fenstern). Unten nutzt es
		# den Grundabstand mit (nicht den Bereich des Home-Balkens), damit zwei Kachel-Reihen passen.
		var window_top := top + _hud.size.y + COLUMN_GAP / 2.0
		var window_bottom := size.y - maxf(_margins[3] - UiStyle.PADDING, 0.0) - COLUMN_GAP
		_window.custom_minimum_size = Vector2(right - left, window_bottom - window_top)
		_window.size = _window.custom_minimum_size
		_window.position = Vector2(left, window_top)
		_window.content.call("set_available_size", _window.size.x - 2.0 * UiStyle.COMPACT_WINDOW_PADDING,
				_window.body_height())
	elif _window != null and _window_kind == "reminder":
		# Kleines Fenster mittig (G5.6), so hoch wie nötig (höchstens die Safe Area).
		var small_width := minf(REMINDER_MAX_WIDTH, right - left - 2.0 * GAP)
		_window.custom_minimum_size = Vector2.ZERO
		_window.size = Vector2(small_width, bottom - top)
		var frame := _window.size.y - _window.body_height()
		var inner := small_width - _window.get_theme_stylebox("panel").get_minimum_size().x
		var height := minf(frame + _window.content.call("needed_height", inner), bottom - top)
		_window.custom_minimum_size = Vector2(small_width, height)
		_window.size = _window.custom_minimum_size
		_window.position = Vector2((left + right - small_width) / 2.0, (top + bottom - height) / 2.0)
	elif _window != null:
		var width := minf(UiStyle.WINDOW_MAX_WIDTH, right - left - 2.0 * GAP)
		_window.custom_minimum_size = Vector2(width, bottom - top)
		_window.size = _window.custom_minimum_size
		_window.position = Vector2((left + right - width) / 2.0, top)
	if _tutorial != null:
		# Tutorial ganz oben (T.3): Aussparung und Sprechblase in der Safe Area.
		move_child(_tutorial, get_child_count() - 1)
		_tutorial.place(size, Rect2(left, top, right - left, bottom - top))
	if _popup != null:
		# Konflikt-Popup immer ganz oben, Panel mittig in der Safe Area (G5.4).
		move_child(_popup, get_child_count() - 1)
		_popup.place(size, Rect2(left, top, right - left, bottom - top))


# --- Fenster ----------------------------------------------------------------------

func _open_window(kind: String, content: Control, closable: bool = true) -> void:
	_close_window()
	_window_kind = kind
	_window = UiWindowScript.new(kind, content.call("get_title"), content, closable)
	_window.close_pressed.connect(_on_window_closed)
	_dim.visible = true
	add_child(_window)
	_layout()


func _close_window() -> void:
	if _window != null:
		remove_child(_window)
		_window.queue_free()
	_window = null
	_window_kind = ""
	_dim.visible = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and _window != null and _window.is_closable():
		_on_window_closed()


## Vom Spieler geschlossen: Eine Erinnerung, die auf Ereignis oder Kalender gewartet hat, kommt jetzt (G5.6),
## danach ein wartendes Tutorial (T.3).
func _on_window_closed() -> void:
	_close_window()
	_open_due_reminder()
	_open_due_tutorial()


## Reihenfolge Ereignis → Kalender → Erinnerung → Tutorial (T.3): Das Tutorial wartet, solange eines dieser Fenster
## oder das Konflikt-Popup offen ist; über einem Ortsfenster darf es liegen (dort zeigt es z. B. auf „Hinfahren“).
## Welches fällig ist, entscheidet das TutorialSystem; „Verstanden“ markiert es als gesehen, dann kommt das nächste.
func _open_due_tutorial() -> void:
	if _tutorial != null or _popup != null or _game.events.has_pending() \
			or _window_kind in ["event", "calendar", "reminder"]:
		return
	var tutorial_id := _game.tutorials.get_next_due()
	if tutorial_id.is_empty():
		return
	_tutorial = TutorialOverlayScript.new(_game.tutorials.get_catalog().get_definition(tutorial_id), self)
	_tutorial.confirmed.connect(_on_tutorial_confirmed)
	add_child(_tutorial)
	_layout()


func _on_tutorial_confirmed(tutorial_id: String) -> void:
	_game.tutorials.mark_seen(tutorial_id)
	if _tutorial != null:
		remove_child(_tutorial)
		_tutorial.queue_free()
		_tutorial = null
	state_changed.emit()  # gesehen speichern
	_open_due_tutorial()


## Reihenfolge Ereignis → Kalender → Erinnerung (G5.6), nie zwei Fenster übereinander: Die Erinnerung wartet, solange
## ein Ereignis offen ist oder der Kalender steht; sonst ersetzt sie ein offenes Fenster. Fällig sagt das
## ReminderSystem (genau einmal je Termin).
func _open_due_reminder() -> void:
	if _game.events.has_pending() or _window_kind in ["event", "calendar", "reminder"]:
		return
	var appointment_id := _game.reminders.take_due()
	if appointment_id.is_empty():
		return
	if haptics != null:
		haptics.warn("reminder")
	_game.tutorials.report("first_appointment_reminder")
	var content := ReminderWindowScript.new()
	content.setup(self, _game, appointment_id)
	_open_window("reminder", content)


## „Später“: nur schließen – die Erinnerung kommt für diesen Termin nicht wieder.
func close_reminder() -> void:
	if _window_kind == "reminder":
		_close_window()


## „Später“ (G5.6): schließen; ein wartendes Tutorial kommt danach (T.3).
func on_reminder_later_pressed() -> void:
	close_reminder()
	_open_due_tutorial()


func on_reminder_travel_pressed(location_id: String) -> void:
	close_reminder()
	on_travel_pressed(location_id)


func on_reminder_wait_pressed(appointment_id: String) -> void:
	close_reminder()
	on_wait_pressed(appointment_id)


func _open_location(location_id: String) -> void:
	_selected_location = location_id
	# Tutorial-Auslöser (T.2); ein fälliges Tutorial zeigt sich über dem Fenster (T.3).
	_game.tutorials.report("first_location_open")
	if location_id != _game.locations.get_current():
		_game.tutorials.report("first_location_elsewhere")
	var content := LocationWindowScript.new()
	content.setup(self, _game, location_id)
	_open_window("location", content)
	_map.set_state(_game.locations.get_current(), _selected_location)
	_open_due_tutorial()


## Kalender (G5.2, ersetzt „Termine“): Tagesplan als Zeitstrahl.
func _open_appointments() -> void:
	_game.tutorials.report("first_calendar_open")
	var content := CalendarWindowScript.new()
	content.setup(self, _game)
	_open_window("calendar", content)


func _open_obligations() -> void:
	var content := ObligationsWindowScript.new()
	content.setup(self, _game)
	_open_window("obligations", content)


func _open_channel() -> void:
	var content := ChannelWindowScript.new()
	content.setup(self, _game)
	_open_window("channel", content)


func _open_company() -> void:
	var content := CompanyWindowScript.new()
	content.setup(self, _game)
	_open_window("company", content)


func _open_ledger() -> void:
	var content := LedgerWindowScript.new()
	content.setup(self, _game)
	_open_window("ledger", content)


func _on_location_pressed(location_id: String) -> void:
	if _window != null and not _window.is_closable():
		return  # Ereignis muss zuerst entschieden werden
	_open_location(location_id)


func _on_here_pressed() -> void:
	var current := _game.locations.get_current()
	_map.center_on(current)
	_open_location(current)


# --- Buttons in Fenstern ----------------------------------------------------------

## Button in einem Fensterinhalt: Wischgesten erreichen den Scrollbereich (PASS),
## und der Scrollstand beim Antippen wird gemerkt (Tippen vs. Scrollen).
func scroll_button(text: String, node_name: String) -> Button:
	var button := UiStyle.button(text)
	button.name = node_name
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(func() -> void:
		if _window != null:
			_window.remember_scroll())
	return button


func _was_scroll() -> bool:
	return _window != null and _window.was_scroll()


## Führt `run` aus – oder fragt erst per Popup, wenn die Aktion (Dauer `minutes`) einen Termin verpassen ließe.
## Die Konflikte kommen aus dem AppointmentSystem; hier wird nur angezeigt.
func _guard(minutes: int, action_name: String, run: Callable, except_id: String = "") -> void:
	var conflicts := _game.appointments.get_conflicts(minutes, except_id)
	if conflicts.is_empty():
		run.call()
		return
	var lines := []
	for definition in conflicts:
		var location := _game.locations.get_catalog().get_definition(definition.location)
		lines.append(["„%s“ · %s · %s" % [definition.title, TimeSystemScript.format_stamp(definition.start_minutes),
				location.display_name if location != null else definition.location],
				"Verpasst: %s" % ActivityText.option_summary(definition.missed_effects, 0)])
	var action_line := "%s · %s" % [action_name, ActivityText.duration_with_end(_game.time.get_minutes(), minutes)]
	_close_popup()
	_popup = ConflictPopupScript.new("Termin verpassen?", action_line, lines, run)
	if haptics != null:
		haptics.warn("conflict")
	_popup.closed.connect(func() -> void: _popup = null)
	add_child(_popup)
	_layout()


func _close_popup() -> void:
	if _popup != null:
		remove_child(_popup)
		_popup.queue_free()
		_popup = null


func on_activity_pressed(activity_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.activities.get_catalog().get_definition(activity_id)
	_guard(definition.duration_minutes, definition.display_name, func() -> void:
		_after_action(_game.activities.start(activity_id), "%s erledigt" % definition.display_name))


func on_content_pressed(format_id: String) -> void:
	if _was_scroll():
		return
	var format := _game.content.get_catalog().get_definition(format_id)
	_guard(format.duration_minutes, format.display_name, func() -> void:
		var outcome := _game.content.preview(format_id)
		var reason := _game.content.produce(format_id)
		var parts := ActivityText.channel_parts({"followers": outcome["followers"], "community": outcome["community"],
				"reputation": outcome["reputation"]})
		if outcome["income_cents"] != 0:
			parts.append(ActivityText.signed_money(outcome["income_cents"]))
		var result := " (%s)" % " · ".join(parts) if not parts.is_empty() else ""
		_after_action(reason, "%s produziert%s" % [format.display_name, result]))


func on_equipment_pressed(equipment_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.equipment.get_catalog().get_definition(equipment_id)
	var next := _game.equipment.get_next_level(equipment_id)
	var reason := _game.equipment.buy(equipment_id)
	var text := ""
	if reason.is_empty():
		text = "%s gekauft: %s (%s)" % [definition.display_name, next["name"],
				ActivityText.signed_money(-next["price_cents"])]
	_after_action(reason, text)


func on_company_found_pressed(type_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.company.get_catalog().get_definition(type_id)
	_guard(definition.founding_minutes, "%s gründen" % definition.display_name, func() -> void:
		_after_action(_game.company.found(type_id), "%s gegründet" % definition.display_name))


func on_branch_open_pressed(type_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.company.get_catalog().get_definition(type_id)
	_guard(definition.branch_opening_minutes, "%s eröffnen" % definition.branch_display_name, func() -> void:
		_after_action(_game.company.open_branch(), "%s eröffnet" % definition.branch_display_name))


func on_travel_pressed(location_id: String) -> void:
	if _was_scroll():
		return
	var target := _game.locations.get_catalog().get_definition(location_id)
	_guard(_game.locations.travel_minutes_to(location_id), "Fahrt nach %s" % target.display_name, func() -> void:
		var origin := _game.locations.get_current()
		var reason := _game.locations.travel(location_id)
		if reason.is_empty():
			_map.play_travel(origin, location_id)
		_after_action(reason, "Angekommen: %s" % target.display_name if reason.is_empty() else ""))


## G5.7 „Hinfahren und starten“: Konflikt-Popup für die Gesamtzeit (Fahrt + Aktion), dann Fahrt und Aktion über das
## TripSystem. Scheitert die Aktion nach der Fahrt, ist man trotzdem angekommen – mit klarer Meldung.
func on_trip_pressed(kind: String, id: String) -> void:
	if _was_scroll():
		return
	var location_id: String = _game.trips.target_location(kind, id)
	var target := _game.locations.get_catalog().get_definition(location_id)
	var action_name := _trip_action_name(kind, id)
	_guard(_game.trips.total_minutes(kind, id), "Fahrt nach %s + %s" % [target.display_name, action_name],
			func() -> void:
				var origin := _game.locations.get_current()
				var result: Dictionary = _game.trips.run(kind, id)
				if result["arrived"]:
					_map.play_travel(origin, location_id)
				if result["arrived"] and not result["reason"].is_empty():
					_after_action("Angekommen: %s – aber %s: %s" % [target.display_name, action_name, result["reason"]],
							"", true)
				else:
					_after_action(result["reason"], "Angekommen: %s · %s erledigt" % [target.display_name, action_name]))


func _trip_action_name(kind: String, id: String) -> String:
	match kind:
		TripSystemScript.KIND_ACTIVITY:
			return _game.activities.get_catalog().get_definition(id).display_name
		TripSystemScript.KIND_CONTENT:
			return _game.content.get_catalog().get_definition(id).display_name
		TripSystemScript.KIND_FOUND:
			return "%s gründen" % _game.company.get_catalog().get_definition(id).display_name
		TripSystemScript.KIND_BRANCH:
			return "%s eröffnen" % _game.company.get_catalog().get_definition(id).branch_display_name
	return id


func on_attend_pressed(appointment_id: String) -> void:
	if _was_scroll():
		return
	var title := _game.appointments.get_catalog().get_definition(appointment_id).title
	_guard(_game.appointments.minutes_to_attend(appointment_id), "„%s“ wahrnehmen" % title, func() -> void:
		_after_action(_game.appointments.attend(appointment_id), "„%s“ wahrgenommen" % title), appointment_id)


## G5.5: bis zum Terminbeginn warten. Fiele ein anderer Termin in die Wartezeit, fragt das Konflikt-Popup.
func on_wait_pressed(appointment_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.appointments.get_catalog().get_definition(appointment_id)
	var until := TimeSystemScript.format_stamp(definition.start_minutes).get_slice(" · ", 1)
	_guard(_game.appointments.minutes_to_start(appointment_id), "Warten bis %s" % until, func() -> void:
		_after_action(_game.appointments.wait_until_start(appointment_id), "Gewartet bis „%s“" % definition.title),
			appointment_id)


func on_obligation_pay_pressed(instance_id: String) -> void:
	if _was_scroll():
		return
	var reason := _game.obligations.pay(instance_id)
	# Erfolg: Der Hinweis des Systems („… bezahlt: -80,00 €.“) kommt über _after_action dazu.
	_after_action(reason, "Frist bezahlt")


func on_company_transfer_pressed(is_deposit: bool) -> void:
	if _was_scroll():
		return
	var amount := ActivityText.signed_money(TRANSFER_STEP_CENTS)
	if is_deposit:
		_after_action(_game.company.deposit(TRANSFER_STEP_CENTS), "Einlage %s ins Unternehmen" % amount)
	else:
		_after_action(_game.company.withdraw(TRANSFER_STEP_CENTS), "Entnahme %s aus dem Unternehmen" % amount)


func on_event_option_pressed(instance_id: String, option_id: String, option_label: String) -> void:
	# Wie jede Aktion: Optionen mit Spielzeit (Phase 5) können Tagesabschlüsse/Fristen auslösen.
	_after_action(_game.events.resolve(instance_id, option_id), "„%s“ gewählt" % option_label)


## Rückmeldung nach einer Aktion, inklusive verpasster Termine und Tagesabschlüsse.
## changed_anyway (G5.7): gescheitert, aber der Zustand hat sich geändert (angekommen) – trotzdem speichern.
func _after_action(reason: String, success_text: String, changed_anyway: bool = false) -> void:
	if reason.is_empty() or changed_anyway:
		var text := "%s – jetzt %s." % [success_text, _game.time.format_clock()] if reason.is_empty() \
				else "%s – jetzt %s." % [reason.trim_suffix("."), _game.time.format_clock()]
		for id in _game.appointments.take_missed_notices():
			var definition := _game.appointments.get_catalog().get_definition(id)
			text += "\nTermin verpasst: „%s“ (%s)." % [definition.title,
					ActivityText.option_summary(definition.missed_effects, 0)]
		for settlement in _game.company.take_settlement_notices():
			text += "\nTagesabschluss %s" % settlement
		for notice in _game.obligations.take_notices():
			text += "\n%s" % notice
		_show_feedback(text, UiStyle.TEXT if reason.is_empty() else UiStyle.NEGATIVE)
	else:
		_show_feedback(reason, UiStyle.NEGATIVE)
	_refresh()
	if reason.is_empty() or changed_anyway:
		state_changed.emit()


# --- Hinweise ---------------------------------------------------------------------

## Hinweis (z. B. nach dem Laden eines Backups).
func show_message(text: String) -> void:
	_show_feedback(text, UiStyle.TEXT)


## Fehler (z. B. Speichern fehlgeschlagen).
func show_error(text: String) -> void:
	_show_feedback(text, UiStyle.NEGATIVE)


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	var sticky := text.length() > TOAST_STICKY_LENGTH or "\n" in text
	# Kurze Hinweise lassen Tipps auf die Karte durch (G4.4); lange muss man antippen, um sie zu schließen.
	_toast.mouse_filter = Control.MOUSE_FILTER_STOP if sticky else Control.MOUSE_FILTER_IGNORE
	if sticky:
		_toast_timer.stop()  # lange Texte bleiben, bis man sie antippt
	elif is_inside_tree():
		_toast_timer.start(TOAST_SECONDS)
	_layout()


func _on_toast_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_toast.visible = false


# --- Anzeige ----------------------------------------------------------------------

func _refresh() -> void:
	_hud.refresh(_game)
	_company_button.visible = _game.company.is_founded()
	# Zählerpunkte (G5.8): Zählungen aus DayPlan bzw. ObligationSystem. Offene Ereignisse bekommen keinen Punkt –
	# sie öffnen sofort ihr eigenes Fenster, das sich erst nach der Entscheidung schließt.
	_calendar_button.set_badge(DayPlanScript.count_upcoming_today(_game))
	_obligations_button.set_badge(_game.obligations.count_open())

	if not _game.locations.get_catalog().has(_selected_location):
		_selected_location = _game.locations.get_current()
	_map.set_state(_game.locations.get_current(), _selected_location)

	var pending_id := _game.events.get_next_pending_id()
	if not pending_id.is_empty():
		var shown: String = _window.content.get("instance_id") if _window_kind == "event" else ""
		if shown != pending_id:
			var content := EventWindowScript.new()
			content.setup(self, _game, pending_id)
			_open_window("event", content, false)
	elif _window_kind == "event":
		_close_window()
	# G5.3: Erst wenn kein Ereignis offen ist, öffnet sich bei Tagesbeginn genau einmal der Kalender (ersetzt ein
	# offenes Fenster – nie zwei übereinander). Ob er fällig ist, entscheidet das DayStartSystem.
	if pending_id.is_empty() and _game.day_start.take_calendar_due(auto_calendar):
		_open_appointments()
	_open_due_reminder()

	if _window != null:
		_window.refresh()
		_window.set_title(_window.content.call("get_title"))
	_layout()
	_open_due_tutorial()
