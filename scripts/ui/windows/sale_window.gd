extends VBoxContainer

## Fenster eines Verkaufsorts (U.9): je Ware im Bestand Menge wählen (−/+) und „Verkaufen“. Einnahme, Hitze und
## Sperrgrund liefert das SaleSystem; hier wird nur angezeigt. Die Menge gilt nur, solange das Fenster offen ist.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

var spot_id := ""

var _screen
var _game
## product_id -> gewählte Einheiten
var _units := {}


func setup(screen, game, p_spot_id: String) -> void:
	_screen = screen
	_game = game
	spot_id = p_spot_id


func _ready() -> void:
	name = "SaleContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Verkaufen · %s" % _spot().display_name


func _spot():
	return _game.sales.get_catalog().get_definition(spot_id)


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var spot = _spot()
	add_child(UiStyle.wrapping_label(spot.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var terms := UiStyle.wrapping_label("Je Verkauf bis %d Einheiten · dauert %s · Einnahme als Schwarzgeld · jede Einheit bringt Hitze" % [
			spot.max_units, TimeSystemScript.format_duration(spot.minutes)], UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	terms.name = "SaleTerms"
	add_child(terms)
	var any := false
	for product in _game.supply.get_products().get_all():
		var stock: int = _game.supply.get_stock(product.id)
		if stock < 1:
			continue
		any = true
		_units[product.id] = clampi(int(_units.get(product.id, 5)), 1, mini(spot.max_units, stock))
		add_child(_card(product, stock))
	if not any:
		var empty := UiStyle.wrapping_label("Du hast keine Ware. Bestell sie bei deinem Lieferanten (unter „Organisation“).",
				UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
		empty.name = "SaleEmpty"
		add_child(empty)


func _card(product, stock: int) -> Control:
	var spot = _spot()
	var card := UiStyle.card()
	card.name = "SaleProduct_%s" % product.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiStyle.label(product.display_name, UiStyle.FONT_SIZE, UiStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var stock_label := UiStyle.label("Bestand %d" % stock, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	stock_label.name = "SaleStock_%s" % product.id
	head.add_child(stock_label)

	var units: int = _units[product.id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var less: Button = _screen.scroll_button("−", "SaleLess_%s" % product.id)
	less.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	less.disabled = units <= 1
	less.pressed.connect(_change.bind(product.id, -1))
	row.add_child(less)
	var count := UiStyle.label("%d" % units, UiStyle.FONT_SIZE, UiStyle.TEXT)
	count.name = "SaleUnits_%s" % product.id
	count.custom_minimum_size.x = 56
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	var more: Button = _screen.scroll_button("+", "SaleMore_%s" % product.id)
	more.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	more.disabled = units >= mini(spot.max_units, stock)
	more.pressed.connect(_change.bind(product.id, 1))
	row.add_child(more)
	var income: int = _game.sales.income_cents(spot_id, product.id, units)
	var sell: Button = _screen.scroll_button("Verkaufen · %s" % ActivityText.signed_money(income),
			"SaleButton_%s" % product.id)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	sell.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	sell.pressed.connect(_sell.bind(product.id))
	row.add_child(sell)
	var reason: String = _game.sales.check_sale(spot_id, product.id, units)
	sell.disabled = not reason.is_empty()
	var note_text := reason
	if reason.is_empty():
		note_text = "Hitze +%d · %s" % [_game.sales.heat_for(spot_id, product.id, units),
				ActivityText.duration_with_end(_game.time.get_minutes(), spot.minutes)]
		_game.tutorials.report("first_sale_offered")
	var note := UiStyle.wrapping_label(note_text, UiStyle.MIN_READ_FONT_SIZE,
			UiStyle.NEGATIVE if not reason.is_empty() else UiStyle.MUTED)
	note.name = "SaleNote_%s" % product.id
	box.add_child(note)
	return card


func _sell(product_id: String) -> void:
	_screen.on_sale(spot_id, product_id, _units[product_id])


func _change(product_id: String, delta: int) -> void:
	_units[product_id] = int(_units[product_id]) + delta
	refresh()
