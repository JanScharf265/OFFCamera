extends VBoxContainer

## Fensterinhalt „Buchungen“ (G2): Kontostände und die letzten Buchungen, filterbar nach
## alle / Privatkonto / Firmenkonto.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const SHOWN_COUNT := 20
## Filter-ID -> Beschriftung ("" = alle Konten)
const FILTERS := {"": "Alle", "private": "Privat", "company": "Firma"}

var _screen
var _game
var _filter := ""
var _balances: Label
var _list: VBoxContainer
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for filter_id in FILTERS:
		var button := UiStyle.side_button(FILTERS[filter_id])
		button.name = "LedgerFilter_%s" % (filter_id if not filter_id.is_empty() else "all")
		button.custom_minimum_size = Vector2(160, 64)
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
	_balances.text = text
	for filter_id in _filter_buttons:
		_filter_buttons[filter_id].set_pressed_no_signal(filter_id == _filter)

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
		var account_mark := " (Firma)" if entry.account == LedgerSystemScript.COMPANY else ""
		var label := UiStyle.wrapping_label("%s  %s%s" % [TimeSystemScript.format_stamp(entry.time_minutes),
				entry.description, account_mark], UiStyle.SMALL_FONT_SIZE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var amount_color := UiStyle.POSITIVE if entry.is_income() else UiStyle.NEGATIVE
		row.add_child(UiStyle.label(ActivityText.signed_money(entry.amount_cents), UiStyle.SMALL_FONT_SIZE, amount_color))
		_list.add_child(row)
