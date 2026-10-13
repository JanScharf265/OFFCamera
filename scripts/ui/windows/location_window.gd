extends VBoxContainer

## Fensterinhalt eines Orts (G2, ab G4.5 als Kachel-Raster): oben Öffnungszeiten, Entfernung und
## „Hinfahren“, darunter alles, was man dort tun kann – Content, Aktivitäten, Ausrüstung, Gründung,
## Filiale – als Kacheln (activity_tile.gd) in 3–4 Spalten, ohne Scrollen. Ist man woanders, bleiben die
## Aktionen sichtbar, aber gesperrt; der Grund aus den Systemen steht im Button („Nur vor Ort möglich“).
## Zeigt nur an; Aktionen laufen über die Handler des GameScreens.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const ActivityTileScript := preload("res://scripts/ui/activity_tile.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const CONFLICT_PREFIX := "⚠ Verpasst: "

var location_id := ""

var _screen
var _game
var _location_description: Label
var _location_hours: Label
var _location_distance: Label
var _travel_button: Button
var _grid: GridContainer
var _details: Control
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
	_grid.add_theme_constant_override("v_separation", UiStyle.TILE_GAP)
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
	refresh()


func get_title() -> String:
	return _game.locations.get_catalog().get_definition(location_id).display_name


## Vom GameScreen: verfügbare Breite des Inhalts → Spaltenzahl (3–4, bei sehr wenig Platz weniger).
func set_available_width(width: float) -> void:
	var columns := int(floor((width + UiStyle.TILE_GAP) / (UiStyle.TILE_MIN_WIDTH + UiStyle.TILE_GAP)))
	_grid.columns = clampi(columns, 1, UiStyle.TILE_MAX_COLUMNS)


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
	var titles := PackedStringArray()
	for definition in _game.appointments.get_conflicts(minutes):
		titles.append("„%s“ %s" % [definition.title, TimeSystemScript.format_stamp(definition.start_minutes).get_slice(" · ", 1)])
	return CONFLICT_PREFIX + ", ".join(titles) if not titles.is_empty() else ""


func _tile(key: String, title: String, button_name: String, action_text: String, is_purchase: bool,
		action: Callable) -> ActivityTileScript:
	var button: Button = _screen.scroll_button(action_text, button_name)
	button.pressed.connect(action)
	return ActivityTileScript.new(key, title, button, action_text, is_purchase)


# --- Details und Fahrt -------------------------------------------------------------

func _build_details() -> Control:
	var row := HBoxContainer.new()
	row.name = "LocationDetails"
	row.add_theme_constant_override("separation", 16)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	_location_hours = _info_line("LocationHours", UiStyle.TEXT)
	info.add_child(_location_hours)
	_location_distance = _info_line("LocationDistance", UiStyle.MUTED)
	info.add_child(_location_distance)
	_location_description = _info_line("LocationDescription", UiStyle.MUTED)
	info.add_child(_location_description)
	_travel_button = _screen.scroll_button("Hinfahren", "TravelButton")
	_travel_button.custom_minimum_size = Vector2(UiStyle.TRAVEL_BUTTON_WIDTH, UiStyle.TILE_BUTTON_HEIGHT)
	_travel_button.add_theme_font_size_override("font_size", UiStyle.TILE_BUTTON_FONT_SIZE)
	_travel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_travel_button.pressed.connect(func() -> void: _screen.on_travel_pressed(location_id))
	row.add_child(_travel_button)
	return row


func _info_line(node_name: String, color: Color) -> Label:
	var line := UiStyle.label("", UiStyle.TILE_FONT_SIZE, color)
	line.name = node_name
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.clip_text = true
	return line


func _refresh_details() -> void:
	var definition = _game.locations.get_catalog().get_definition(location_id)
	_location_description.text = definition.description
	_location_description.visible = not definition.description.is_empty()
	var now_open: bool = _game.locations.is_open_at(location_id, _game.time.get_minutes())
	_location_hours.text = "Geöffnet: %s · jetzt %s" % [LocationSystemScript.format_hours(definition),
			"offen" if now_open else "geschlossen"]
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


# --- Kacheln -----------------------------------------------------------------------

func _build_activity_card(activity_id: String) -> Control:
	var definition = _game.activities.get_catalog().get_definition(activity_id)
	var tile := _tile(activity_id, definition.display_name, "StartButton_%s" % activity_id, "Starten", false,
			func() -> void: _screen.on_activity_pressed(activity_id))
	tile.tooltip_text = definition.description
	_cards[activity_id] = tile
	return tile


func _build_content_card(format_id: String) -> Control:
	var format = _game.content.get_catalog().get_definition(format_id)
	var tile := _tile(format_id, format.display_name, "ContentButton_%s" % format_id, "Produzieren", false,
			func() -> void: _screen.on_content_pressed(format_id))
	tile.tooltip_text = format.description
	_content_cards[format_id] = tile
	return tile


func _build_equipment_card(equipment_id: String) -> Control:
	var definition = _game.equipment.get_catalog().get_definition(equipment_id)
	var tile := _tile(equipment_id, definition.display_name, "EquipmentButton_%s" % equipment_id, "Kaufen", true,
			func() -> void: _screen.on_equipment_pressed(equipment_id))
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
		tile.set_hint("Nächste: %s" % next["name"], false)
	tile.set_reason(_game.equipment.check_buy(equipment_id))
	tile.button.visible = not next.is_empty()


func _build_company_card(type_id: String) -> Control:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var tile := _tile(type_id, "%s gründen" % definition.display_name, "CompanyFoundButton_%s" % type_id, "Gründen",
			false, func() -> void: _screen.on_company_found_pressed(type_id))
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
			"Eröffnen", false, func() -> void: _screen.on_branch_open_pressed(type_id))
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
