extends VBoxContainer

## Fensterinhalt eines Orts (G2): Details, „Hinfahren“ und alles, was man dort tun kann –
## Content, Aktivitäten, Ausrüstung, Gründung, Filiale. Ist man woanders, bleiben die Aktionen
## sichtbar, aber gesperrt mit dem Grund aus den Systemen („Nur vor Ort möglich“).
## Zeigt nur an; Aktionen laufen über die Handler des GameScreens.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

var location_id := ""

var _screen
var _game
var _location_name: Label
var _location_description: Label
var _location_hours: Label
var _location_distance: Label
var _travel_button: Button
## activity_id -> {"button", "reason"}
var _cards := {}
## format_id -> {"button", "reason", "summary", "quality"}
var _content_cards := {}
## equipment_id -> {"button", "reason", "title", "next"}
var _equipment_cards := {}
## company_type_id -> {"button", "reason", "info"}
var _company_cards := {}
var _branch_cards := {}


## screen = GameScreen (Handler und Buttons), game = GameState.
func setup(screen, game, p_location_id: String) -> void:
	_screen = screen
	_game = game
	location_id = p_location_id


func _ready() -> void:
	name = "LocationWindowContent"
	add_theme_constant_override("separation", 16)
	add_child(_build_details())

	var format_ids: PackedStringArray = _game.content.get_catalog().get_ids_at(location_id)
	var ids: PackedStringArray = _game.activities.get_catalog().get_ids_at(location_id)
	var equipment_ids: PackedStringArray = _game.equipment.get_catalog().get_ids_at(location_id)
	var company_ids: PackedStringArray = _game.company.get_catalog().get_ids_at(location_id)
	var branch_ids: PackedStringArray = _game.company.get_catalog().get_ids_with_branch_at(location_id)
	if ids.is_empty() and format_ids.is_empty() and equipment_ids.is_empty() and company_ids.is_empty() \
			and branch_ids.is_empty():
		add_child(UiStyle.label("Hier gibt es nichts zu tun.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	if not format_ids.is_empty() or not ids.is_empty():
		add_child(UiStyle.section_label("Aktivitäten"))
	for id in format_ids:
		add_child(_build_content_card(id))
	for id in ids:
		add_child(_build_activity_card(id))
	if not equipment_ids.is_empty():
		add_child(UiStyle.section_label("Ausrüstung"))
	for id in equipment_ids:
		add_child(_build_equipment_card(id))
	if not company_ids.is_empty() or not branch_ids.is_empty():
		add_child(UiStyle.section_label("Unternehmen"))
	for id in company_ids:
		add_child(_build_company_card(id))
	for id in branch_ids:
		add_child(_build_branch_card(id))
	refresh()


func get_title() -> String:
	return _game.locations.get_catalog().get_definition(location_id).display_name


func refresh() -> void:
	_refresh_details()
	for activity_id in _cards:
		_set_reason(_cards[activity_id], _game.activities.check(activity_id))
	for format_id in _content_cards:
		var format = _game.content.get_catalog().get_definition(format_id)
		var card: Dictionary = _content_cards[format_id]
		card["summary"].text = ActivityText.content_summary(format.duration_minutes, _game.content.preview(format_id))
		card["quality"].text = _game.content.quality_text(format_id)
		_set_reason(card, _game.content.check(format_id))
	for equipment_id in _equipment_cards:
		_refresh_equipment_card(equipment_id)
	for type_id in _company_cards:
		_refresh_company_card(type_id)
	for type_id in _branch_cards:
		_refresh_branch_card(type_id)


static func _set_reason(card: Dictionary, reason: String) -> void:
	card["button"].disabled = not reason.is_empty()
	card["reason"].text = reason
	card["reason"].visible = not reason.is_empty()


func _card_box() -> Array:
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	return [card, box]


func _reason_label() -> Label:
	var reason := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	reason.visible = false
	return reason


# --- Details und Fahrt -------------------------------------------------------------

func _build_details() -> Control:
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
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
	_travel_button = _screen.scroll_button("Hinfahren", "TravelButton")
	_travel_button.pressed.connect(func() -> void: _screen.on_travel_pressed(location_id))
	box.add_child(_travel_button)
	return parts[0]


func _refresh_details() -> void:
	var definition = _game.locations.get_catalog().get_definition(location_id)
	_location_name.text = definition.display_name
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


# --- Karten ------------------------------------------------------------------------

func _build_activity_card(activity_id: String) -> Control:
	var definition = _game.activities.get_catalog().get_definition(activity_id)
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
	box.add_child(UiStyle.label(definition.display_name))
	if not definition.description.is_empty():
		box.add_child(UiStyle.wrapping_label(definition.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	box.add_child(UiStyle.wrapping_label(ActivityText.summary(definition), UiStyle.SMALL_FONT_SIZE))
	var reason := _reason_label()
	box.add_child(reason)
	var button: Button = _screen.scroll_button("Starten", "StartButton_%s" % activity_id)
	button.pressed.connect(func() -> void: _screen.on_activity_pressed(activity_id))
	box.add_child(button)
	_cards[activity_id] = {"button": button, "reason": reason}
	return parts[0]


func _build_content_card(format_id: String) -> Control:
	var format = _game.content.get_catalog().get_definition(format_id)
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
	box.add_child(UiStyle.label("%s · Content" % format.display_name))
	if not format.description.is_empty():
		box.add_child(UiStyle.wrapping_label(format.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var summary := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	summary.name = "ContentSummary_%s" % format_id
	box.add_child(summary)
	var quality := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	box.add_child(quality)
	var reason := _reason_label()
	box.add_child(reason)
	var button: Button = _screen.scroll_button("Produzieren", "ContentButton_%s" % format_id)
	button.pressed.connect(func() -> void: _screen.on_content_pressed(format_id))
	box.add_child(button)
	_content_cards[format_id] = {"button": button, "reason": reason, "summary": summary, "quality": quality}
	return parts[0]


func _build_equipment_card(equipment_id: String) -> Control:
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
	var title := UiStyle.label("")
	title.name = "EquipmentTitle_%s" % equipment_id
	box.add_child(title)
	var next := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	box.add_child(next)
	var reason := _reason_label()
	box.add_child(reason)
	var button: Button = _screen.scroll_button("Kaufen", "EquipmentButton_%s" % equipment_id)
	button.pressed.connect(func() -> void: _screen.on_equipment_pressed(equipment_id))
	box.add_child(button)
	_equipment_cards[equipment_id] = {"button": button, "reason": reason, "title": title, "next": next}
	return parts[0]


func _refresh_equipment_card(equipment_id: String) -> void:
	var definition = _game.equipment.get_catalog().get_definition(equipment_id)
	var card: Dictionary = _equipment_cards[equipment_id]
	var level: int = _game.equipment.get_level(equipment_id)
	var current_name: String = definition.get_level(level)["name"] if level > 0 else "nichts"
	card["title"].text = "%s · Stufe %d/%d (%s)" % [definition.display_name, level, definition.max_level(), current_name]
	var next: Dictionary = _game.equipment.get_next_level(equipment_id)
	var format_names := PackedStringArray()
	for format_id in definition.formats:
		var format = _game.content.get_catalog().get_definition(format_id)
		format_names.append(format.display_name if format != null else format_id)
	if next.is_empty():
		card["next"].text = "Höchste Stufe: +%d %% Qualität für %s." % [definition.get_level(level)["quality_percent"],
				", ".join(format_names)]
	else:
		card["next"].text = "Nächste Stufe: %s · Qualität +%d %% für %s · %s" % [next["name"], next["quality_percent"],
				", ".join(format_names), LedgerSystemScript.format_cents(next["price_cents"])]
	_set_reason(card, _game.equipment.check_buy(equipment_id))
	card["button"].visible = not next.is_empty()
	card["reason"].visible = card["reason"].visible and not next.is_empty()


func _build_company_card(type_id: String) -> Control:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
	box.add_child(UiStyle.label("%s · Unternehmen" % definition.display_name))
	if not definition.description.is_empty():
		box.add_child(UiStyle.wrapping_label(definition.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var info := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	info.name = "CompanyInfo_%s" % type_id
	box.add_child(info)
	var reason := _reason_label()
	box.add_child(reason)
	var button: Button = _screen.scroll_button("Gründen", "CompanyFoundButton_%s" % type_id)
	button.pressed.connect(func() -> void: _screen.on_company_found_pressed(type_id))
	box.add_child(button)
	_company_cards[type_id] = {"button": button, "reason": reason, "info": info}
	return parts[0]


func _refresh_company_card(type_id: String) -> void:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var card: Dictionary = _company_cards[type_id]
	var founded: bool = _game.company.is_founded()
	if founded and _game.company.get_type_id() == type_id:
		card["info"].text = "Gegründet · Firmenkonto %s · Auslastung %d · Ruf %d" % [
				LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.COMPANY)),
				_game.company.utilization, _game.company.reputation]
	else:
		card["info"].text = "%s · Gebühr %s · Einlage %s aufs Firmenkonto" % [
				TimeSystemScript.format_duration(definition.founding_minutes),
				LedgerSystemScript.format_cents(definition.founding_fee_cents),
				LedgerSystemScript.format_cents(definition.min_deposit_cents)]
	_set_reason(card, _game.company.check_found(type_id))
	card["button"].visible = not founded
	card["reason"].visible = card["reason"].visible and not founded


func _build_branch_card(type_id: String) -> Control:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var parts := _card_box()
	var box: VBoxContainer = parts[1]
	box.add_child(UiStyle.label("%s · Filiale" % definition.branch_display_name))
	var info := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	info.name = "BranchInfo_%s" % type_id
	box.add_child(info)
	var reason := _reason_label()
	box.add_child(reason)
	var button: Button = _screen.scroll_button("Filiale eröffnen", "BranchOpenButton_%s" % type_id)
	button.pressed.connect(func() -> void: _screen.on_branch_open_pressed(type_id))
	box.add_child(button)
	_branch_cards[type_id] = {"button": button, "reason": reason, "info": info}
	return parts[0]


func _refresh_branch_card(type_id: String) -> void:
	var definition = _game.company.get_catalog().get_definition(type_id)
	var card: Dictionary = _branch_cards[type_id]
	var ours: bool = _game.company.is_founded() and _game.company.get_type_id() == type_id
	var is_open: bool = ours and _game.company.is_branch_open()
	if is_open:
		card["info"].text = "Geöffnet · +%s Grundumsatz und %s Fixkosten pro Tag" % [
				LedgerSystemScript.format_cents(definition.branch_base_revenue_per_day_cents),
				LedgerSystemScript.format_cents(definition.branch_fixed_costs_per_day_cents)]
	else:
		card["info"].text = "%s · %s vom Firmenkonto · danach +%s Grundumsatz, %s Fixkosten pro Tag" % [
				TimeSystemScript.format_duration(definition.branch_opening_minutes),
				LedgerSystemScript.format_cents(definition.branch_opening_fee_cents),
				LedgerSystemScript.format_cents(definition.branch_base_revenue_per_day_cents),
				LedgerSystemScript.format_cents(definition.branch_fixed_costs_per_day_cents)]
	_set_reason(card, _game.company.check_open_branch())
	card["button"].visible = not is_open
	card["reason"].visible = card["reason"].visible and not is_open
