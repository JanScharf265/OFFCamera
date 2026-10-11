extends VBoxContainer

## Spielansicht: HUD (Datum, Uhrzeit, Ort, Konto, Werte), Content-Formate und Aktivitäten am aktuellen
## Ort, nächste Termine, Stadtkarte mit Fahrten, letzte Buchungen.
## Ist ein Ereignis offen, ersetzt es die Liste, bis entschieden ist.
## Zeigt nur an und ruft Systeme auf – Regeln stehen in den Systemen.
##
## Aktualisiert wird nach jeder Aktion explizit über _refresh(), nicht über
## die System-Signale: Die feuern teils mitten im Ablauf einer Aktivität,
## wo check() noch "Zeitfortschritt läuft" melden würde.
##
## Würde eine Aktion einen Termin verpassen lassen, erscheint zuerst eine
## Warnung; erst ein zweiter Tipp auf denselben Button führt sie aus.

signal menu_pressed
## Nach jeder erfolgreichen Aktion (Aktivität, Fahrt, Termin, Ereignis-Entscheidung) – die App speichert dann.
signal state_changed

const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const CityMapScript := preload("res://scripts/ui/city_map.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const RECENT_ENTRY_COUNT := 5
const UPCOMING_APPOINTMENT_COUNT := 2
## Hat sich die Liste zwischen Antippen und Loslassen weiter bewegt,
## war es ein Scrollen, kein Tippen – die Aktion startet dann nicht.
const TAP_SCROLL_TOLERANCE := 12
const CONFIRM_HINT := " Nochmal tippen, um trotzdem fortzufahren."

var _game: GameStateScript
var _date_label: Label
var _clock_label: Label
var _location_label: Label
var _balance_label: Label
var _stat_labels := {}
var _stat_bars := {}
var _feedback_label: Label
## activity_id -> {"button": Button, "reason": Label}
var _cards := {}
## format_id -> {"button": Button, "reason": Label, "summary": Label, "quality": Label}
var _content_cards := {}
var _activity_title: Label
var _activity_list: VBoxContainer
var _activities_location := ""
var _appointment_list: VBoxContainer
var _map: CityMapScript
var _selected_location := ""
var _location_name: Label
var _location_description: Label
var _location_hours: Label
var _location_distance: Label
var _location_activities: Label
var _travel_button: Button
var _ledger_list: VBoxContainer
var _scroll: ScrollContainer
var _event_panel: PanelContainer
var _shown_event_id := ""
var _scroll_at_press := 0
## Schlüssel der Aktion, deren Warnung gerade angezeigt wird (z. B. "travel:gym").
var _confirm_key := ""


## Vor dem Einfügen in den Baum aufrufen.
func setup(game: GameStateScript) -> void:
	_game = game


func _ready() -> void:
	assert(_game != null, "GameScreen: setup() wurde nicht aufgerufen.")
	add_theme_constant_override("separation", 16)
	_selected_location = _game.locations.get_current()

	add_child(_build_hud())

	_feedback_label = UiStyle.wrapping_label("Wähle eine Aktivität oder fahre zu einem anderen Ort.",
			UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	_feedback_label.name = "FeedbackLabel"
	add_child(_feedback_label)

	_event_panel = UiStyle.card()
	_event_panel.name = "EventPanel"
	_event_panel.visible = false
	add_child(_event_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "ActivityScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	_activity_title = UiStyle.section_label("")
	content.add_child(_activity_title)
	_activity_list = _list("ActivityList", 16)
	content.add_child(_activity_list)

	content.add_child(UiStyle.section_label("Termine"))
	_appointment_list = _list("AppointmentList", 16)
	content.add_child(_appointment_list)

	content.add_child(UiStyle.section_label("Stadtkarte · Marbella"))
	_map = CityMapScript.new()
	_map.name = "CityMap"
	_map.setup(_game.locations.get_catalog())
	_map.pin_down.connect(_remember_scroll)
	_map.location_pressed.connect(_on_location_pressed)
	content.add_child(_map)
	content.add_child(_build_location_panel())

	content.add_child(UiStyle.section_label("Letzte Buchungen"))
	_ledger_list = _list("LedgerList", 8)
	content.add_child(_ledger_list)

	var menu_button := UiStyle.button("Menü")
	menu_button.name = "MenuButton"
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(menu_button)

	_refresh()


func _list(node_name: String, separation: int) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.name = node_name
	list.add_theme_constant_override("separation", separation)
	return list


func _build_hud() -> Control:
	var hud := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	hud.add_child(box)

	var top_row := HBoxContainer.new()
	box.add_child(top_row)
	_date_label = UiStyle.label("")
	_date_label.name = "DateLabel"
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_date_label)
	_clock_label = UiStyle.label("", UiStyle.LARGE_FONT_SIZE)
	_clock_label.name = "ClockLabel"
	top_row.add_child(_clock_label)

	_location_label = UiStyle.label("")
	_location_label.name = "LocationLabel"
	box.add_child(_location_label)

	_balance_label = UiStyle.label("")
	_balance_label.name = "BalanceLabel"
	box.add_child(_balance_label)

	for key in PlayerStatsScript.KEYS:
		var stat_label := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		box.add_child(stat_label)
		_stat_labels[key] = stat_label
		var bar := ProgressBar.new()
		bar.min_value = PlayerStatsScript.MIN_VALUE
		bar.max_value = PlayerStatsScript.MAX_VALUE
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		box.add_child(bar)
		_stat_bars[key] = bar
	return hud


func _build_location_panel() -> Control:
	var panel := UiStyle.card()
	panel.name = "LocationPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_location_name = UiStyle.label("")
	_location_name.name = "LocationName"
	box.add_child(_location_name)
	_location_description = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	box.add_child(_location_description)
	_location_hours = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	_location_hours.name = "LocationHours"
	box.add_child(_location_hours)
	_location_distance = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	_location_distance.name = "LocationDistance"
	box.add_child(_location_distance)
	_location_activities = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	box.add_child(_location_activities)
	_travel_button = _scroll_button("Hinfahren", "TravelButton")
	_travel_button.pressed.connect(_on_travel_pressed)
	box.add_child(_travel_button)
	return panel


## Button in der Scroll-Liste: Wischgesten erreichen die ScrollContainer (PASS),
## und der Scrollstand beim Antippen wird gemerkt.
func _scroll_button(text: String, node_name: String) -> Button:
	var button := UiStyle.button(text)
	button.name = node_name
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(_remember_scroll)
	return button


func _remember_scroll() -> void:
	_scroll_at_press = _scroll.scroll_vertical


func _was_scroll() -> bool:
	return absi(_scroll.scroll_vertical - _scroll_at_press) > TAP_SCROLL_TOLERANCE


func _build_activity_card(activity_id: String) -> Control:
	var definition := _game.activities.get_catalog().get_definition(activity_id)
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiStyle.label(definition.display_name))
	if not definition.description.is_empty():
		box.add_child(UiStyle.wrapping_label(definition.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	box.add_child(UiStyle.wrapping_label(ActivityText.summary(definition), UiStyle.SMALL_FONT_SIZE))

	var reason := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	reason.visible = false
	box.add_child(reason)

	var button := _scroll_button("Starten", "StartButton_%s" % activity_id)
	button.pressed.connect(_on_activity_pressed.bind(activity_id))
	box.add_child(button)

	_cards[activity_id] = {"button": button, "reason": reason}
	return card


## Karte für ein Content-Format; Wirkung und Qualität werden in _refresh_activities() aktualisiert.
func _build_content_card(format_id: String) -> Control:
	var format := _game.content.get_catalog().get_definition(format_id)
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiStyle.label("%s · Content" % format.display_name))
	if not format.description.is_empty():
		box.add_child(UiStyle.wrapping_label(format.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var summary := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	summary.name = "ContentSummary_%s" % format_id
	box.add_child(summary)
	var quality := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	box.add_child(quality)

	var reason := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	reason.visible = false
	box.add_child(reason)

	var button := _scroll_button("Produzieren", "ContentButton_%s" % format_id)
	button.pressed.connect(_on_content_pressed.bind(format_id))
	box.add_child(button)

	_content_cards[format_id] = {"button": button, "reason": reason, "summary": summary, "quality": quality}
	return card


## true = ausführen. Bei einer Warnung erst beim zweiten Tipp auf dieselbe Aktion.
func _confirmed(key: String, warning: String) -> bool:
	if warning.is_empty() or _confirm_key == key:
		_confirm_key = ""
		return true
	_confirm_key = key
	_show_feedback(warning + CONFIRM_HINT, UiStyle.NEGATIVE)
	return false


func _on_activity_pressed(activity_id: String) -> void:
	if _was_scroll():
		return
	var definition := _game.activities.get_catalog().get_definition(activity_id)
	if not _confirmed("activity:" + activity_id, _game.appointments.conflict_warning(definition.duration_minutes)):
		return
	var reason := _game.activities.start(activity_id)
	_after_action(reason, "%s erledigt" % definition.display_name)


func _on_content_pressed(format_id: String) -> void:
	if _was_scroll():
		return
	var format := _game.content.get_catalog().get_definition(format_id)
	if not _confirmed("content:" + format_id, _game.appointments.conflict_warning(format.duration_minutes)):
		return
	var outcome := _game.content.preview(format_id)
	var reason := _game.content.produce(format_id)
	var parts := ActivityText.channel_parts({"followers": outcome["followers"], "community": outcome["community"],
			"reputation": outcome["reputation"]})
	if outcome["income_cents"] != 0:
		parts.append(ActivityText.signed_money(outcome["income_cents"]))
	var result := " (%s)" % " · ".join(parts) if not parts.is_empty() else ""
	_after_action(reason, "%s produziert%s" % [format.display_name, result])


func _on_location_pressed(location_id: String) -> void:
	if _was_scroll():
		return
	_selected_location = location_id
	_refresh()


func _on_travel_pressed() -> void:
	if _was_scroll():
		return
	var target := _selected_location
	var warning := _game.appointments.conflict_warning(_game.locations.travel_minutes_to(target))
	if not _confirmed("travel:" + target, warning):
		return
	var origin := _game.locations.get_current()
	var reason := _game.locations.travel(target)
	if reason.is_empty():
		_map.play_travel(origin, target)
	var name_text := _game.locations.get_catalog().get_definition(target).display_name if reason.is_empty() else ""
	_after_action(reason, "Angekommen: %s" % name_text)


func _on_attend_pressed(appointment_id: String) -> void:
	if _was_scroll():
		return
	var warning := _game.appointments.conflict_warning(_game.appointments.minutes_to_attend(appointment_id),
			appointment_id)
	if not _confirmed("attend:" + appointment_id, warning):
		return
	var title := _game.appointments.get_catalog().get_definition(appointment_id).title
	var reason := _game.appointments.attend(appointment_id)
	_after_action(reason, "„%s“ wahrgenommen" % title)


## Rückmeldung nach einer zeitverbrauchenden Aktion, inklusive verpasster Termine.
func _after_action(reason: String, success_text: String) -> void:
	_confirm_key = ""
	if reason.is_empty():
		var text := "%s – jetzt %s." % [success_text, _game.time.format_clock()]
		for id in _game.appointments.take_missed_notices():
			var definition := _game.appointments.get_catalog().get_definition(id)
			text += "\nTermin verpasst: „%s“ (%s)." % [definition.title,
					ActivityText.option_summary(definition.missed_effects, 0)]
		_show_feedback(text, UiStyle.TEXT)
	else:
		_show_feedback(reason, UiStyle.NEGATIVE)
	_refresh()
	if reason.is_empty():
		state_changed.emit()


## Hinweis in der Rückmeldezeile (z. B. nach dem Laden eines Backups).
func show_message(text: String) -> void:
	_show_feedback(text, UiStyle.TEXT)


## Fehler in der Rückmeldezeile (z. B. Speichern fehlgeschlagen).
func show_error(text: String) -> void:
	_show_feedback(text, UiStyle.NEGATIVE)


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	_date_label.text = _game.time.format_date()
	_clock_label.text = _game.time.format_clock()
	_location_label.text = "Ort: %s" % _game.locations.get_current_definition().display_name
	_balance_label.text = "Konto: %s" % LedgerSystemScript.format_cents(_game.ledger.get_balance())

	for key in PlayerStatsScript.KEYS:
		var value := _game.stats.get_value(key)
		_stat_labels[key].text = "%s %d/%d" % [PlayerStatsScript.LABELS[key], value, PlayerStatsScript.MAX_VALUE]
		_stat_bars[key].value = value

	_refresh_activities()
	_refresh_appointments()
	_refresh_location_panel()
	_refresh_ledger_list()
	_refresh_event()


func _refresh_activities() -> void:
	var current := _game.locations.get_current()
	if current != _activities_location:
		_activities_location = current
		_activity_title.text = "Aktivitäten · %s" % _game.locations.get_current_definition().display_name
		_clear(_activity_list)
		_cards.clear()
		_content_cards.clear()
		var format_ids := _game.content.get_catalog().get_ids_at(current)
		var ids := _game.activities.get_catalog().get_ids_at(current)
		if ids.is_empty() and format_ids.is_empty():
			_activity_list.add_child(UiStyle.label("Hier gibt es nichts zu tun.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		for id in format_ids:
			_activity_list.add_child(_build_content_card(id))
		for id in ids:
			_activity_list.add_child(_build_activity_card(id))

	for activity_id in _cards:
		var reason := _game.activities.check(activity_id)
		var card: Dictionary = _cards[activity_id]
		card["button"].disabled = not reason.is_empty()
		card["reason"].text = reason
		card["reason"].visible = not reason.is_empty()

	for format_id in _content_cards:
		var format := _game.content.get_catalog().get_definition(format_id)
		var card: Dictionary = _content_cards[format_id]
		card["summary"].text = ActivityText.content_summary(format.duration_minutes, _game.content.preview(format_id))
		card["quality"].text = _game.content.quality_text(format_id)
		var reason := _game.content.check(format_id)
		card["button"].disabled = not reason.is_empty()
		card["reason"].text = reason
		card["reason"].visible = not reason.is_empty()


func _refresh_appointments() -> void:
	_clear(_appointment_list)
	var upcoming := _game.appointments.get_upcoming()
	if upcoming.is_empty():
		_appointment_list.add_child(UiStyle.label("Keine anstehenden Termine.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		return
	for i in mini(upcoming.size(), UPCOMING_APPOINTMENT_COUNT):
		var definition := upcoming[i]
		var location := _game.locations.get_catalog().get_definition(definition.location)
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
		# Button nur, wenn der Termin jetzt wahrgenommen werden kann – sonst nur der Grund.
		var reason := _game.appointments.check(definition.id)
		if not reason.is_empty():
			box.add_child(UiStyle.wrapping_label(reason, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		else:
			var button := _scroll_button("Wahrnehmen", "AttendButton_%s" % definition.id)
			button.pressed.connect(_on_attend_pressed.bind(definition.id))
			box.add_child(button)
		_appointment_list.add_child(card)


func _refresh_location_panel() -> void:
	var catalog := _game.locations.get_catalog()
	if not catalog.has(_selected_location):
		_selected_location = _game.locations.get_current()
	var definition := catalog.get_definition(_selected_location)
	_map.set_state(_game.locations.get_current(), _selected_location)

	_location_name.text = definition.display_name
	_location_description.text = definition.description
	_location_description.visible = not definition.description.is_empty()
	var now_open := _game.locations.is_open_at(_selected_location, _game.time.get_minutes())
	_location_hours.text = "Geöffnet: %s · jetzt %s" % [LocationSystemScript.format_hours(definition),
			"offen" if now_open else "geschlossen"]

	var names := PackedStringArray()
	for id in _game.activities.get_catalog().get_ids_at(_selected_location):
		names.append(_game.activities.get_catalog().get_definition(id).display_name)
	_location_activities.text = "Hier: %s" % (", ".join(names) if not names.is_empty() else "nichts")

	var reason := _game.locations.check_travel(_selected_location)
	if _selected_location == _game.locations.get_current():
		_location_distance.text = "Du bist hier."
		_travel_button.text = "Hinfahren"
	else:
		var tenths := _game.locations.distance_tenths(_game.locations.get_current(), _selected_location)
		var minutes := _game.locations.travel_minutes_to(_selected_location)
		_location_distance.text = "%s · %s Fahrt" % [ActivityText.km(tenths), TimeSystemScript.format_duration(minutes)]
		_travel_button.text = "Hinfahren (%s)" % TimeSystemScript.format_duration(minutes)
	_travel_button.disabled = not reason.is_empty()


func _refresh_event() -> void:
	var pending := _game.events.get_next_pending()
	_scroll.visible = pending == null
	_event_panel.visible = pending != null
	if pending == null:
		_shown_event_id = ""
		return
	if pending.id == _shown_event_id:
		return
	_shown_event_id = pending.id

	_clear(_event_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_event_panel.add_child(box)
	box.add_child(UiStyle.section_label("Ereignis"))
	box.add_child(UiStyle.wrapping_label(pending.title))
	box.add_child(UiStyle.wrapping_label(pending.text, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for option in pending.options:
		box.add_child(UiStyle.wrapping_label(ActivityText.option_summary(option.effects, option.money_cents),
				UiStyle.SMALL_FONT_SIZE))
		var button := UiStyle.button(option.label)
		button.name = "EventOption_%s" % option.id
		button.pressed.connect(_on_event_option_pressed.bind(pending.id, option.id, option.label))
		box.add_child(button)


func _on_event_option_pressed(event_id: String, option_id: String, option_label: String) -> void:
	var reason := _game.events.resolve(event_id, option_id)
	if reason.is_empty():
		_show_feedback("„%s“ gewählt." % option_label, UiStyle.TEXT)
	else:
		_show_feedback(reason, UiStyle.NEGATIVE)
	_refresh()
	if reason.is_empty():
		state_changed.emit()


func _refresh_ledger_list() -> void:
	_clear(_ledger_list)
	var entries := _game.ledger.get_entries()
	if entries.is_empty():
		_ledger_list.add_child(UiStyle.label("Noch keine Buchungen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		return

	var oldest_shown := maxi(entries.size() - RECENT_ENTRY_COUNT, 0)
	for i in range(entries.size() - 1, oldest_shown - 1, -1):
		var entry := entries[i]
		var row := HBoxContainer.new()
		var text := UiStyle.wrapping_label("%s  %s" % [TimeSystemScript.format_stamp(entry.time_minutes), entry.description],
				UiStyle.SMALL_FONT_SIZE)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var amount_color := UiStyle.POSITIVE if entry.is_income() else UiStyle.NEGATIVE
		row.add_child(UiStyle.label(ActivityText.signed_money(entry.amount_cents), UiStyle.SMALL_FONT_SIZE, amount_color))
		_ledger_list.add_child(row)


## Entfernt alle Kinder sofort aus dem Baum und löscht sie später.
func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
