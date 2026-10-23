extends VBoxContainer

## Fensterinhalt „Buchungen“ (G2): Kontostände und die letzten Buchungen, filterbar nach
## alle / Privatkonto / Firmenkonto / Schwarzgeld (U.1 – Filter, Stand und Wochenübersicht erst, wenn es welches gibt).

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SHOWN_COUNT := 20
## Filter-ID -> Beschriftung ("" = alle Konten)
const FILTERS := {"": "Alle", "private": "Privat", "company": "Firma", "black": "Schwarz"}

var _screen
var _game
var _filter := ""
var _balances: Label
var _list: VBoxContainer
var _weeks: VBoxContainer
var _filter_buttons := {}


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "LedgerWindowContent"
	add_theme_constant_override("separation", 12)
	_balances = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
	_balances.name = "LedgerBalances"
	add_child(_balances)
	add_child(UiStyle.section_label("Wochenübersicht (nach Wertstellung, ohne Umbuchungen)"))
	_weeks = VBoxContainer.new()
	_weeks.name = "LedgerWeeks"
	_weeks.add_theme_constant_override("separation", 4)
	add_child(_weeks)
	add_child(UiStyle.section_label("Buchungen"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for filter_id in FILTERS:
		var button := UiStyle.side_button(FILTERS[filter_id])
		button.name = "LedgerFilter_%s" % (filter_id if not filter_id.is_empty() else "all")
		button.custom_minimum_size = Vector2(160, 64)
		UiStyle.grow_touch_area(button, 64.0)  # sichtbar 64 px, Tippfläche 84 px (G4.7)
		button.toggle_mode = true
		button.pressed.connect(func() -> void:
			_filter = filter_id
			refresh())
		row.add_child(button)
		_filter_buttons[filter_id] = button
	_list = VBoxContainer.new()
	_list.name = "LedgerList"
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)
	refresh()


func get_title() -> String:
	return "Buchungen"


func refresh() -> void:
	var text := "Privatkonto: %s" % LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.PRIVATE))
	if _game.company.is_founded():
		text += " · Firmenkonto: %s" % LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.COMPANY))
	var black_used: bool = _game.ledger.is_account_used(LedgerSystemScript.BLACK)
	if black_used:
		text += " · Schwarzgeld: %s" % LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.BLACK))
	_balances.text = text
	_filter_buttons[LedgerSystemScript.BLACK].visible = black_used
	for filter_id in _filter_buttons:
		_filter_buttons[filter_id].set_pressed_no_signal(filter_id == _filter)
	_refresh_weeks()

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries: Array = _game.ledger.get_entries() if _filter.is_empty() \
			else _game.ledger.get_entries_for_account(_filter)
	if entries.is_empty():
		_list.add_child(UiStyle.label("Noch keine Buchungen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		return
	for i in range(entries.size() - 1, maxi(entries.size() - SHOWN_COUNT, 0) - 1, -1):
		var entry = entries[i]
		var row := HBoxContainer.new()
		var account_mark: String = {LedgerSystemScript.COMPANY: " (Firma)", LedgerSystemScript.BLACK: " (Schwarz)"}.get(
				entry.account, "")
		var label := UiStyle.wrapping_label("%s  %s%s" % [TimeSystemScript.format_stamp(entry.time_minutes),
				entry.description, account_mark], UiStyle.SMALL_FONT_SIZE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var amount_color := UiStyle.POSITIVE if entry.is_income() else UiStyle.NEGATIVE
		row.add_child(UiStyle.label(ActivityText.signed_money(entry.amount_cents), UiStyle.SMALL_FONT_SIZE, amount_color))
		_list.add_child(row)


## Diese und letzte Woche je Konto: Einnahmen, Ausgaben, Ergebnis (Umbuchungen getrennt).
func _refresh_weeks() -> void:
	for child in _weeks.get_children():
		_weeks.remove_child(child)
		child.queue_free()
	var week := TimeSystemScript.week_of(_game.time.get_minutes())
	var accounts := [LedgerSystemScript.PRIVATE]
	if _game.company.is_founded():
		accounts.append(LedgerSystemScript.COMPANY)
	if _game.ledger.is_account_used(LedgerSystemScript.BLACK):
		accounts.append(LedgerSystemScript.BLACK)
	for shown_week in [week, week - 1]:
		if shown_week < 1:
			continue
		for account in accounts:
			var summary: Dictionary = _game.ledger.summarize(account, TimeSystemScript.week_start(shown_week),
					TimeSystemScript.week_start(shown_week + 1))
			var label := UiStyle.wrapping_label("Woche %d%s · %s: Einnahmen %s · Ausgaben %s · Ergebnis %s" % [
					shown_week, " (läuft)" if shown_week == week else "", LedgerSystemScript.ACCOUNT_LABELS[account],
					ActivityText.signed_money(summary["income_cents"]), ActivityText.signed_money(summary["expense_cents"]),
					ActivityText.signed_money(summary["net_cents"])], UiStyle.SMALL_FONT_SIZE,
					UiStyle.TEXT if shown_week == week else UiStyle.MUTED)
			label.name = "LedgerWeek_%d_%s" % [shown_week, account]
			_weeks.add_child(label)

