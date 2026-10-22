extends VBoxContainer

## Fensterinhalt eines Orts (G2, ab G4.5 als Kachel-Raster): oben Öffnungszeiten, Entfernung und
## „Hinfahren“, darunter alles, was man dort tun kann – Content, Aktivitäten, Ausrüstung, Gründung,
## Filiale – als Kacheln (activity_tile.gd) in 3–4 Spalten, ohne Scrollen. Passen die Kacheln nicht in die
## sichtbare Höhe, erscheinen Reiter in der Titelzeile (G4.6, Zuordnung aus dem Datenfeld "tab"). Ist man woanders, bleiben die
## Aktionen sichtbar, aber gesperrt; der Grund aus den Systemen steht im Button („Nur vor Ort möglich“).
## Zeigt nur an; Aktionen laufen über die Handler des GameScreens.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const ActivityTileScript := preload("res://scripts/ui/activity_tile.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LocationTabScript := preload("res://scripts/models/location_tab.gd")

const CONFLICT_PREFIX := "⚠ Verpasst: "

var location_id := ""

var _screen
var _game
var _location_hours: Label
var _location_distance: Label
var _travel_button: Button
## G5.5: „Warten bis HH:MM“ für den nächsten Termin heute an diesem Ort, nach dem Warten „Wahrnehmen“
## (beide unsichtbar, wenn nichts ansteht)
var _wait_button: Button
var _attend_button: Button
var _appointment_id := ""
var _grid: GridContainer
var _details: Control
var _tab_bar: HBoxContainer
## tab_id -> Button (nur Reiter mit Kacheln, in fester Reihenfolge)
var _tab_buttons := {}
## Kachel -> tab_id
var _tile_tabs := {}
var _current_tab := ""
var _tabs_active := false
## id -> Kachel, je Art
var _cards := {}
var _content_cards := {}
var _equipment_cards := {}
var _company_cards := {}
var _branch_cards := {}


## screen = GameScreen (Handler und Buttons), game = GameState.
func setup(screen, game, p_location_id: String) -> void:
	_screen = screen
	_game = game
	location_id = p_location_id
	_details = _build_details()


## Für ui_window.gd: Infos und „Hinfahren“ stehen in der Titelzeile des Fensters (spart eine Zeile, G4.5).
func take_header_extra() -> Control:
	return _details


func _ready() -> void:
	name = "LocationWindowContent"
	add_theme_constant_override("separation", 12)

	_grid = GridContainer.new()
	_grid.name = "TileGrid"
	_grid.columns = UiStyle.TILE_MAX_COLUMNS
	_grid.add_theme_constant_override("h_separation", UiStyle.TILE_GAP)
	_grid.add_theme_constant_override("v_separation", UiStyle.TILE_ROW_GAP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_grid)

	var catalog = _game.company.get_catalog()
	for id in _game.content.get_catalog().get_ids_at(location_id):
		_grid.add_child(_build_content_card(id))
	for id in _game.activities.get_catalog().get_ids_at(location_id):
		_grid.add_child(_build_activity_card(id))
	for id in _game.equipment.get_catalog().get_ids_at(location_id):
		_grid.add_child(_build_equipment_card(id))
	for id in catalog.get_ids_at(location_id):
		_grid.add_child(_build_company_card(id))
	for id in catalog.get_ids_with_branch_at(location_id):
		_grid.add_child(_build_branch_card(id))
	if _grid.get_child_count() == 0:
		add_child(UiStyle.label("Hier gibt es nichts zu tun.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	_build_tabs()
	refresh()


func get_title() -> String:
	return _game.locations.get_catalog().get_definition(location_id).display_name


## Vom GameScreen: verfügbare Breite und Höhe des Inhalts → Spaltenzahl (3–4, bei sehr wenig Platz weniger)
## und ob Reiter nötig sind: nur wenn alle Kacheln zusammen nicht ohne Scrollen passen (G4.6).
func set_available_size(width: float, height: float) -> void:
	var columns := int(floor((width + UiStyle.TILE_GAP) / (UiStyle.TILE_MIN_WIDTH + UiStyle.TILE_GAP)))
	_grid.columns = clampi(columns, 1, UiStyle.TILE_MAX_COLUMNS)
	_set_tabs_active(false)
	if _tab_buttons.size() > 1 and _measure_height(width) > height + 0.5:
		_set_tabs_active(true)



func has_tabs() -> bool:
	return _tabs_active


func get_current_tab() -> String:
	return _current_tab


## Reiter wechseln (Tipp auf einen Reiter). Kostet keine Spielzeit, wird nicht gespeichert.
func select_tab(tab_id: String) -> void:
	if not _tab_buttons.has(tab_id):
		return
	_current_tab = tab_id
	_apply_tab_filter()


func _build_tabs() -> void:
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "LocationTabs"
	_tab_bar.add_theme_constant_override("separation", 8)
	_tab_bar.visible = false
	_details.add_child(_tab_bar)
	_details.move_child(_tab_bar, 1)  # zwischen Infos und „Hinfahren“
	for tab_id in LocationTabScript.IDS:
		if tab_id not in _tile_tabs.values():
			continue  # leere Reiter werden nicht gezeigt
		var button: Button = _screen.scroll_button(LocationTabScript.LABELS[tab_id], "LocationTab_%s" % tab_id)
		button.pressed.connect(func() -> void: select_tab(tab_id))
		_tab_bar.add_child(button)
		_tab_buttons[tab_id] = button
		if _current_tab.is_empty():
			_current_tab = tab_id  # Das Fenster öffnet immer auf dem ersten Reiter.
	_apply_tab_filter()


func _set_tabs_active(active: bool) -> void:
	_tabs_active = active
	_tab_bar.visible = active
	_apply_tab_filter()


func _apply_tab_filter() -> void:
	for tile in _tile_tabs:
		tile.visible = not _tabs_active or _tile_tabs[tile] == _current_tab
	for tab_id in _tab_buttons:
		UiStyle.style_tab_button(_tab_buttons[tab_id], tab_id == _current_tab)


## Höhe, die alle sichtbaren Kacheln bei dieser Breite brauchen – synchron gemessen (Container sortieren,
## umbrechende Labels auf ihre Breite setzen), weil die Entscheidung vor dem nächsten Bild fallen muss.
func _measure_height(width: float) -> float:
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


func get_columns() -> int:
	return _grid.columns


func refresh() -> void:
	_refresh_details()
	var now: int = _game.time.get_minutes()
	for activity_id in _cards:
		var definition = _game.activities.get_catalog().get_definition(activity_id)
		var tile: ActivityTileScript = _cards[activity_id]
		tile.set_time(ActivityText.duration_with_end(now, definition.duration_minutes))
		tile.set_effects(ActivityText.effect_chips(definition.effects, definition.money_cents, {},
				definition.company_effects))
		tile.set_hint(_conflict_hint(definition.duration_minutes))
		tile.set_reason(_game.activities.check(activity_id))
	for format_id in _content_cards:
		var format = _game.content.get_catalog().get_definition(format_id)
		var tile: ActivityTileScript = _content_cards[format_id]
		var outcome: Dictionary = _game.content.preview(format_id)
		tile.set_time(ActivityText.duration_with_end(now, format.duration_minutes))
		tile.set_effects(ActivityText.effect_chips(outcome["effects"], outcome["income_cents"],
				{"followers": outcome["followers"], "community": outcome["community"], "reputation": outcome["reputation"]}))
		var conflict := _conflict_hint(format.duration_minutes)
		if conflict.is_empty():
			tile.set_hint("Qualität %d %%" % outcome["quality_percent"], false)
		else:
			tile.set_hint(conflict)
		tile.set_reason(_game.content.check(format_id))
	for equipment_id in _equipment_cards:
		_refresh_equipment_card(equipment_id)
	for type_id in _company_cards:
		_refresh_company_card(type_id, now)
	for type_id in _branch_cards:
		_refresh_branch_card(type_id, now)


## Hinweis, wenn die Aktion einen Termin verpassen ließe (Termine aus dem AppointmentSystem).
func _conflict_hint(minutes: int) -> String:
	# Kurz (G4.5b): nur die Uhrzeit, z. B. „⚠ Verpasst: 14:00“ – „Termin“ passt in 21 px nicht in die Kachel.
	# Den vollen Namen nennt die Warnung beim Start.
	var times := PackedStringArray()
	for definition in _game.appointments.get_conflicts(minutes):
		times.append(TimeSystemScript.format_stamp(definition.start_minutes).get_slice(" · ", 1))
	if times.is_empty():
		return ""
	return CONFLICT_PREFIX + ", ".join(times)


func _tile(key: String, title: String, button_name: String, action_text: String, is_purchase: bool,
		action: Callable, tab: String) -> ActivityTileScript:
	var button: Button = _screen.scroll_button(action_text, button_name)
	button.pressed.connect(action)
	var tile := ActivityTileScript.new(key, title, button, action_text, is_purchase)
	_tile_tabs[tile] = tab
	return tile


# --- Details und Fahrt -------------------------------------------------------------

func _build_details() -> Control:
	var row := HBoxContainer.new()
	row.name = "LocationDetails"
	row.add_theme_constant_override("separation", 16)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	# Zwei Zeilen (G4.5b, spart Höhe für die Kacheln): Öffnungszeiten, Entfernung. Die Beschreibung des Orts steht
	# nur noch im Tooltip des Fensterinhalts (später im Lexikon, Paket T).
	_location_hours = _info_line("LocationHours", UiStyle.TEXT)
	info.add_child(_location_hours)
	_location_distance = _info_line("LocationDistance", UiStyle.MUTED)
	info.add_child(_location_distance)
	_travel_button = _screen.scroll_button("Hinfahren", "TravelButton")
	_travel_button.add_theme_font_size_override("font_size", UiStyle.TILE_BUTTON_FONT_SIZE)
	# Sichtbar mittig wie die Reiter (G4.7), Tippfläche 84 px.
	UiStyle.style_accent_touch_button(_travel_button, UiStyle.TAB_VISIBLE)
	_travel_button.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE * 2.0, UiStyle.TOUCH_SIZE)
	_travel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_travel_button.pressed.connect(func() -> void: _screen.on_travel_pressed(location_id))
	_wait_button = _screen.scroll_button("", "WaitButton")
	_wait_button.add_theme_font_size_override("font_size", UiStyle.TILE_BUTTON_FONT_SIZE)
	UiStyle.style_accent_touch_button(_wait_button, UiStyle.TAB_VISIBLE)
	_wait_button.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE * 2.0, UiStyle.TOUCH_SIZE)
	_wait_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wait_button.pressed.connect(func() -> void: _screen.on_wait_pressed(_appointment_id))
	row.add_child(_wait_button)
	_attend_button = _screen.scroll_button("Wahrnehmen", "LocationAttendButton")
	_attend_button.add_theme_font_size_override("font_size", UiStyle.TILE_BUTTON_FONT_SIZE)
	UiStyle.style_accent_touch_button(_attend_button, UiStyle.TAB_VISIBLE)
	_attend_button.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE * 2.0, UiStyle.TOUCH_SIZE)
	_attend_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_attend_button.pressed.connect(func() -> void: _screen.on_attend_pressed(_appointment_id))
	row.add_child(_attend_button)
	row.add_child(_travel_button)
	return row


## Volle Breite der Info-Spalte; „…“ nur als Notfall, damit die Titelzeile das Fenster nie verbreitert
## (der Layout-Test prüft, dass auf echten Geräten nichts abgeschnitten wird).
func _info_line(node_name: String, color: Color) -> Label:
	var line := UiStyle.label("", UiStyle.TILE_FONT_SIZE, color)
	line.name = node_name
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _refresh_details() -> void:
	var definition = _game.locations.get_catalog().get_definition(location_id)
	tooltip_text = definition.description
	var now_open: bool = _game.locations.is_open_at(location_id, _game.time.get_minutes())
	# Kurzform (G4.7), damit die Titelzeile auch mit Reitern und „Hinfahren“ nichts abschneidet.
	if definition.has_hours:
		_location_hours.text = "%s · %s" % [LocationSystemScript.format_hours(definition),
				"offen" if now_open else "geschlossen"]
	else:
		_location_hours.text = "immer geöffnet"
	var here: bool = location_id == _game.locations.get_current()
	if here:
		_location_distance.text = "Du bist hier."
	else:
		var tenths: int = _game.locations.distance_tenths(_game.locations.get_current(), location_id)
		var minutes: int = _game.locations.travel_minutes_to(location_id)
		_location_distance.text = "%s · %s Fahrt" % [ActivityText.km(tenths), TimeSystemScript.format_duration(minutes)]
		_travel_button.text = "Hinfahren (%s)" % TimeSystemScript.format_duration(minutes)
	_travel_button.visible = not here
	_travel_button.disabled = not _game.locations.check_travel(location_id).is_empty()
	_refresh_wait()


## Nächster offener Termin heute an diesem Ort, nur vor Ort (G5.5): vor Beginn „Warten bis 14:00“ an der Stelle von
## „Hinfahren“, ab Beginn „Wahrnehmen“, sobald das AppointmentSystem es erlaubt. Aus der Ferne steht hier „Hinfahren“ –
## ein zweiter, gesperrter Button passt im „Grenzfall“ nicht in die Titelzeile; den Grund nennt der Kalender.
func _refresh_wait() -> void:
	_appointment_id = ""
	var now: int = _game.time.get_minutes()
	if location_id == _game.locations.get_current():
		for definition in _game.appointments.get_upcoming():
			if definition.location == location_id \
					and TimeSystemScript.day_of(definition.start_minutes) == TimeSystemScript.day_of(now):
				_appointment_id = definition.id
				break
	var waits: bool = not _appointment_id.is_empty() and _game.appointments.offers_wait(_appointment_id)
	_wait_button.visible = waits
	_attend_button.visible = not waits and not _appointment_id.is_empty() \
			and _game.appointments.check(_appointment_id).is_empty()
	if not waits:
		return
	var start: int = _game.appointments.get_catalog().get_definition(_appointment_id).start_minutes
	_wait_button.text = "Warten bis %s" % TimeSystemScript.format_stamp(start).get_slice(" · ", 1)
	_wait_button.disabled = not _game.appointments.check_wait(_appointment_id).is_empty()


# --- Kacheln -----------------------------------------------------------------------

func _build_activity_card(activity_id: String) -> Control:
	var definition = _game.activities.get_catalog().get_definition(activity_id)
	var tile := _tile(activity_id, definition.display_name, "StartButton_%s" % activity_id, "Starten", false,
			func() -> void: _screen.on_activity_pressed(activity_id), definition.tab)
	tile.tooltip_text = definition.description
	_cards[activity_id] = tile
	return tile


func _build_content_card(format_id: String) -> Control:
	var format = _game.content.get_catalog().get_definition(format_id)
	var tile := _tile(format_id, format.display_name, "ContentButton_%s" % format_id, "Produzieren", false,
			func() -> void: _screen.on_content_pressed(format_id), format.tab)
	tile.tooltip_text = format.description
	_content_cards[format_id] = tile
	return tile


func _build_equipment_card(equipment_id: String) -> Control:
	var definition = _game.equipment.get_catalog().get_definition(equipment_id)
	var tile := _tile(equipment_id, definition.display_name, "EquipmentButton_%s" % equipment_id, "Kaufen", true,
			func() -> void: _screen.on_equipment_pressed(equipment_id), definition.tab)
	_equipment_cards[equipment_id] = tile
	return tile


func _refresh_equipment_card(equipment_id: String) -> void:
	var definition = _game.equipment.get_catalog().get_definition(equipment_id)
	var tile: ActivityTileScript = _equipment_cards[equipment_id]
	var level: int = _game.equipment.get_level(equipment_id)
	var current_name: String = definition.get_level(level)["name"] if level > 0 else "nichts"
	tile.set_time("Stufe %d/%d · %s" % [level, definition.max_level(), current_name])
	var next: Dictionary = _game.equipment.get_next_level(equipment_id)
	if next.is_empty():
		tile.set_effects([ActivityText.chip("+%d %% Qualität" % definition.get_level(level)["quality_percent"], 1)])
		tile.set_hint("Höchste Stufe", false)
	else:
		tile.set_effects([ActivityText.chip(ActivityText.signed_money(-next["price_cents"]), -1, ActivityText.MONEY_ICON),
				ActivityText.chip("+%d %% Qualität" % next["quality_percent"], 1)])
		tile.set_hint("→ %s" % next["name"], false)  # nächste Stufe; kurz, damit nichts abgeschnitten wird
	tile.set_reason(_game.equipment.check_buy(equipment_id))
	tile.button.visible = not next.is_empty()


func _build_company_card(type_id: String) -> Control:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var tile := _tile(type_id, definition.display_name, "CompanyFoundButton_%s" % type_id, "Gründen",
			false, func() -> void: _screen.on_company_found_pressed(type_id), definition.tab)
	tile.tooltip_text = definition.description
	tile.info_label("CompanyInfo_%s" % type_id)
	_company_cards[type_id] = tile
	return tile


func _refresh_company_card(type_id: String, now: int) -> void:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var tile: ActivityTileScript = _company_cards[type_id]
	var founded: bool = _game.company.is_founded()
	if founded and _game.company.get_type_id() == type_id:
		tile.set_title(definition.display_name)
		tile.set_time("")
		tile.set_effects([])
		tile.set_info("Gegründet · Firmenkonto %s · Auslastung %d · Ruf %d" % [
				LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.COMPANY)),
				_game.company.utilization, _game.company.reputation])
		tile.set_hint("")
	else:
		tile.set_time(ActivityText.duration_with_end(now, definition.founding_minutes))
		tile.set_effects([])  # Gebühr und Einlage stehen im Infotext
		tile.set_info("%s · Gebühr %s · Einlage %s aufs Firmenkonto" % [
				TimeSystemScript.format_duration(definition.founding_minutes),
				LedgerSystemScript.format_cents(definition.founding_fee_cents),
				LedgerSystemScript.format_cents(definition.min_deposit_cents)])
		tile.set_hint(_conflict_hint(definition.founding_minutes))
	tile.set_reason(_game.company.check_found(type_id))
	tile.button.visible = not founded


func _build_branch_card(type_id: String) -> Control:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var tile := _tile("branch_%s" % type_id, definition.branch_display_name, "BranchOpenButton_%s" % type_id,
			"Eröffnen", false, func() -> void: _screen.on_branch_open_pressed(type_id), definition.tab)
	tile.info_label("BranchInfo_%s" % type_id)
	_branch_cards[type_id] = tile
	return tile


func _refresh_branch_card(type_id: String, now: int) -> void:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var tile: ActivityTileScript = _branch_cards[type_id]
	var ours: bool = _game.company.is_founded() and _game.company.get_type_id() == type_id
	var is_open: bool = ours and _game.company.is_branch_open()
	var per_day := [ActivityText.chip("+%s/Tag" % LedgerSystemScript.format_cents(
			definition.branch_base_revenue_per_day_cents), 1, ActivityText.MONEY_ICON),
			ActivityText.chip("-%s/Tag" % LedgerSystemScript.format_cents(definition.branch_fixed_costs_per_day_cents), -1)]
	if is_open:
		tile.set_time("Geöffnet")
		tile.set_effects(per_day)
		tile.set_hint("")
	else:
		tile.set_time(ActivityText.duration_with_end(now, definition.branch_opening_minutes))
		tile.set_effects([ActivityText.chip(ActivityText.signed_money(-definition.branch_opening_fee_cents), -1,
				ActivityText.MONEY_ICON)] + per_day)
		tile.set_hint(_conflict_hint(definition.branch_opening_minutes))
	tile.set_info("")
	tile.set_reason(_game.company.check_open_branch())
	tile.button.visible = not is_open
