extends VBoxContainer

## Spielansicht: HUD (Datum, Uhrzeit, Konto, Werte), Aktivitäten, letzte Buchungen.
## Zeigt nur an und ruft Systeme auf – Regeln stehen in den Systemen.
##
## Aktualisiert wird nach jeder Aktion explizit über _refresh(), nicht über
## die System-Signale: Die feuern teils mitten im Ablauf einer Aktivität,
## wo check() noch "Zeitfortschritt läuft" melden würde.

signal menu_pressed

const GameStateScript := preload("res://scripts/core/game_state.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const RECENT_ENTRY_COUNT := 5
## Hat sich die Liste zwischen Antippen und Loslassen weiter bewegt,
## war es ein Scrollen, kein Tippen – die Aktivität startet dann nicht.
const TAP_SCROLL_TOLERANCE := 12

var _game: GameStateScript
var _date_label: Label
var _clock_label: Label
var _balance_label: Label
var _stat_labels := {}
var _stat_bars := {}
var _feedback_label: Label
## activity_id -> {"button": Button, "reason": Label}
var _cards := {}
var _ledger_list: VBoxContainer
var _scroll: ScrollContainer
var _scroll_at_press := 0


## Vor dem Einfügen in den Baum aufrufen.
func setup(game: GameStateScript) -> void:
	_game = game


func _ready() -> void:
	assert(_game != null, "GameScreen: setup() wurde nicht aufgerufen.")
	add_theme_constant_override("separation", 16)

	add_child(_build_hud())

	_feedback_label = UiStyle.wrapping_label("Wähle eine Aktivität.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	_feedback_label.name = "FeedbackLabel"
	add_child(_feedback_label)

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

	content.add_child(UiStyle.section_label("Aktivitäten"))
	for id in _game.activities.get_catalog().get_ids():
		content.add_child(_build_activity_card(id))

	content.add_child(UiStyle.section_label("Letzte Buchungen"))
	_ledger_list = VBoxContainer.new()
	_ledger_list.name = "LedgerList"
	_ledger_list.add_theme_constant_override("separation", 8)
	content.add_child(_ledger_list)

	var menu_button := UiStyle.button("Menü")
	menu_button.name = "MenuButton"
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(menu_button)

	_refresh()


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

	var button := UiStyle.button("Starten")
	button.name = "StartButton_%s" % activity_id
	# PASS: Wischgesten auf dem Button erreichen die ScrollContainer.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(func() -> void: _scroll_at_press = _scroll.scroll_vertical)
	button.pressed.connect(_on_activity_pressed.bind(activity_id))
	box.add_child(button)

	_cards[activity_id] = {"button": button, "reason": reason}
	return card


func _on_activity_pressed(activity_id: String) -> void:
	if absi(_scroll.scroll_vertical - _scroll_at_press) > TAP_SCROLL_TOLERANCE:
		return
	var definition := _game.activities.get_catalog().get_definition(activity_id)
	var reason := _game.activities.start(activity_id)
	if reason.is_empty():
		_show_feedback("%s erledigt – jetzt %s." % [definition.display_name, _game.time.format_clock()], UiStyle.TEXT)
	else:
		_show_feedback(reason, UiStyle.NEGATIVE)
	_refresh()


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	_date_label.text = _game.time.format_date()
	_clock_label.text = _game.time.format_clock()
	_balance_label.text = "Konto: %s" % LedgerSystemScript.format_cents(_game.ledger.get_balance())

	for key in PlayerStatsScript.KEYS:
		var value := _game.stats.get_value(key)
		_stat_labels[key].text = "%s %d/%d" % [PlayerStatsScript.LABELS[key], value, PlayerStatsScript.MAX_VALUE]
		_stat_bars[key].value = value

	for activity_id in _cards:
		var reason := _game.activities.check(activity_id)
		var card: Dictionary = _cards[activity_id]
		card["button"].disabled = not reason.is_empty()
		card["reason"].text = reason
		card["reason"].visible = not reason.is_empty()

	_refresh_ledger_list()


func _refresh_ledger_list() -> void:
	for child in _ledger_list.get_children():
		_ledger_list.remove_child(child)
		child.queue_free()

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
