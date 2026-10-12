extends VBoxContainer

## Fensterinhalt „Fristen“ (Phase 5): offene Fristen mit offenem Betrag (inkl. Mahngebühr) und
## „Bezahlen“, die nächsten Fälligkeiten und zuletzt erledigte Fristen. Fiktive Spielwerte.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")

const DONE_COUNT := 6

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "ObligationsWindowContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Fristen"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var obligations = _game.obligations

	add_child(UiStyle.section_label("Offen"))
	var open: Array = obligations.get_open()
	if open.is_empty():
		add_child(UiStyle.label("Keine offenen Fristen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for instance in open:
		add_child(_open_card(instance))

	add_child(UiStyle.section_label("Nächste Fälligkeiten"))
	var next_monday := _next_due_day()
	for id in obligations.get_catalog().get_ids():
		var definition = obligations.get_catalog().get_definition(id)
		if definition.requires == "company" and not _game.company.is_founded():
			continue
		var day: int = maxi(next_monday, definition.first_day)
		var amount_text: String = LedgerSystemScript.format_cents(definition.fixed_cents) if not definition.uses_profit() \
				else "%d %% vom Gewinn der Vorwoche" % definition.profit_percent
		add_child(UiStyle.wrapping_label("%s · %s · %s · %s" % [definition.display_name,
				TimeSystemScript.format_stamp(TimeSystemScript.at(day, 0)), amount_text,
				LedgerSystemScript.ACCOUNT_LABELS[definition.account]], UiStyle.SMALL_FONT_SIZE))

	add_child(UiStyle.section_label("Zuletzt erledigt"))
	var done := []
	for instance in obligations.get_instances():
		if instance["status"] != "open":
			done.append(instance)
	if done.is_empty():
		add_child(UiStyle.label("Noch nichts erledigt.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for i in range(done.size() - 1, maxi(done.size() - DONE_COUNT, 0) - 1, -1):
		var instance: Dictionary = done[i]
		var amount := int(instance["amount_cents"]) + int(instance["fee_cents"])
		var status: String = "entfallen (kein Gewinn)" if instance["status"] == "waived" \
				else "bezahlt %s" % LedgerSystemScript.format_cents(-amount)
		add_child(UiStyle.wrapping_label("%s · %s" % [obligations.get_label(instance["id"]), status],
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))


## Nächster Montag nach heute (Fälligkeiten liegen montags 00:00).
func _next_due_day() -> int:
	var day: int = TimeSystemScript.day_of(_game.time.get_minutes()) + 1
	while (day - 1) % TimeSystemScript.DAYS_PER_WEEK != 0:
		day += 1
	return day


func _open_card(instance: Dictionary) -> Control:
	var obligations = _game.obligations
	var definition = obligations.get_catalog().get_definition(instance["obligation"])
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(UiStyle.wrapping_label(obligations.get_label(instance["id"])))
	var details := "Fällig seit %s · %s" % [TimeSystemScript.format_stamp(instance["due_minutes"]),
			LedgerSystemScript.ACCOUNT_LABELS[definition.account] if definition != null else ""]
	box.add_child(UiStyle.wrapping_label(details, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var amount := UiStyle.wrapping_label("Offen: %s" % LedgerSystemScript.format_cents(
			obligations.open_amount(instance["id"])), UiStyle.SMALL_FONT_SIZE)
	amount.name = "ObligationAmount_%s" % node_suffix(instance["id"])
	box.add_child(amount)
	if instance["fee_cents"] > 0:
		box.add_child(UiStyle.wrapping_label("davon Mahngebühr %s (wird erst beim Bezahlen gebucht)" %
				LedgerSystemScript.format_cents(instance["fee_cents"]), UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE))
	elif definition != null:
		var reminder_day: int = TimeSystemScript.day_of(instance["due_minutes"]) + definition.grace_days + 1
		box.add_child(UiStyle.wrapping_label("Ohne Zahlung Mahnung ab %s (+%s, %s)" % [
				TimeSystemScript.format_stamp(TimeSystemScript.at(reminder_day, 0)),
				LedgerSystemScript.format_cents(definition.reminder_fee_cents), _consequence(definition)],
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var reason: String = obligations.check_pay(instance["id"])
	var reason_label := UiStyle.wrapping_label(reason, UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	reason_label.visible = not reason.is_empty()
	box.add_child(reason_label)
	var button: Button = _screen.scroll_button("Bezahlen", "ObligationPayButton_%s" % node_suffix(instance["id"]))
	button.disabled = not reason.is_empty()
	var instance_id: String = instance["id"]
	button.pressed.connect(func() -> void: _screen.on_obligation_pay_pressed(instance_id))
	box.add_child(button)
	return card


## Godot erlaubt kein „@“ in Knotennamen: "rent_home@8" -> "rent_home_8".
static func node_suffix(instance_id: String) -> String:
	return instance_id.replace("@", "_")


static func _consequence(definition) -> String:
	var parts := ActivityText.effect_parts(definition.overdue_effects, 0)
	parts.append_array(ActivityText.company_parts(definition.overdue_company_effects))
	return ", ".join(parts) if not parts.is_empty() else "keine weiteren Folgen"
