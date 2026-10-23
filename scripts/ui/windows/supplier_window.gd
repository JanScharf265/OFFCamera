extends VBoxContainer

## Fenster eines Lieferanten (U.6): Angebot je Produkt mit Werten (Einkauf, Verkauf, Qualität, Hitze je Einheit),
## Menge wählen (−/+), „Bestellen“ auf Vorkasse. Ob und von welchem Konto bezahlt wird, sagt das SupplySystem; hier
## wird nur angezeigt. Die Menge je Produkt gilt nur, solange das Fenster offen ist.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

var supplier_id := ""

var _screen
var _game
## product_id -> gewählte Einheiten
var _units := {}


func setup(screen, game, p_supplier_id: String) -> void:
	_screen = screen
	_game = game
	supplier_id = p_supplier_id


func _ready() -> void:
	name = "SupplierContent"
	add_theme_constant_override("separation", 12)
	var supplier = _supplier()
	for product_id in supplier.products:
		_units[product_id] = clampi(5, supplier.min_units, supplier.max_units)
	refresh()


func get_title() -> String:
	return "Lieferant · %s" % _supplier().name


func _supplier():
	return _game.supply.get_suppliers().get_definition(supplier_id)


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var supplier = _supplier()
	add_child(UiStyle.wrapping_label(supplier.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var terms := UiStyle.wrapping_label("Vorkasse · Lieferung nach %d Tag%s am Morgen · Risiko, dass sie platzt: %d %%" % [
			supplier.delivery_days, "" if supplier.delivery_days == 1 else "en", supplier.failure_percent],
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	terms.name = "SupplierTerms"
	add_child(terms)
	var credit: Dictionary = _game.supply.credit_terms(supplier_id)
	if not credit.is_empty():
		var credit_line := UiStyle.wrapping_label("Auf Kredit: ab der %d. angekommenen Lieferung · bis %d Einheiten · +%d %% · fällig nach %d Tagen" % [
				int(credit["after_deliveries"]), int(credit["max_units"]), int(credit["markup_percent"]),
				int(credit["due_days"])], UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
		credit_line.name = "SupplierCreditTerms"
		add_child(credit_line)
		for debt in _game.supply.get_debts(supplier_id):
			var debt_line := UiStyle.wrapping_label("Schulden: %s · %s" % [LedgerSystemScript.format_cents(debt["amount_cents"]),
					"überfällig – unter „Fristen“ bezahlen" if debt["overdue"] else "fällig Tag %d" % debt["due_day"]],
					UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE if debt["overdue"] else UiStyle.WARNING)
			debt_line.name = "SupplierDebt_%s" % debt["order_id"]
			add_child(debt_line)
	for product in _game.supply.get_products().get_all():
		if product.id in supplier.products:
			add_child(_card(product))


func _card(product) -> Control:
	var card := UiStyle.card()
	card.name = "SupplierProduct_%s" % product.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiStyle.label(product.display_name, UiStyle.FONT_SIZE, UiStyle.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var on_the_way := 0
	for order in _game.supply.get_pending_orders():
		if order["product"] == product.id:
			on_the_way += int(order["units"])
	var stock_text := "Bestand %d" % _game.supply.get_stock(product.id)
	if on_the_way > 0:
		stock_text += " · unterwegs %d" % on_the_way
	var stock := UiStyle.label(stock_text, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED if on_the_way == 0 else UiStyle.ACCENT)
	stock.name = "SupplierStock_%s" % product.id
	head.add_child(stock)
	box.add_child(UiStyle.wrapping_label(product.description, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	var values := UiStyle.wrapping_label("Einkauf %s · Verkauf ca. %s · Qualität %d · Hitze %d je Einheit" % [
			LedgerSystemScript.format_cents(product.buy_price_cents),
			LedgerSystemScript.format_cents(product.sell_price_cents), product.quality, product.heat_per_unit],
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	values.name = "SupplierValues_%s" % product.id
	box.add_child(values)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var units: int = _units[product.id]
	var supplier = _supplier()
	var less: Button = _screen.scroll_button("−", "SupplierLess_%s" % product.id)
	less.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	less.disabled = units <= supplier.min_units
	less.pressed.connect(func() -> void: _change(product.id, -1))
	row.add_child(less)
	var count := UiStyle.label("%d" % units, UiStyle.FONT_SIZE, UiStyle.TEXT)
	count.name = "SupplierUnits_%s" % product.id
	count.custom_minimum_size.x = 56
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	var more: Button = _screen.scroll_button("+", "SupplierMore_%s" % product.id)
	more.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	more.disabled = units >= supplier.max_units
	more.pressed.connect(func() -> void: _change(product.id, 1))
	row.add_child(more)
	var cost: int = _game.supply.order_cost(product.id, units)
	var order: Button = _screen.scroll_button("Bestellen · %s" % LedgerSystemScript.format_cents(cost),
			"SupplierOrderButton_%s" % product.id)
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	order.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	order.pressed.connect(func() -> void: _screen.on_supply_order(supplier_id, product.id, _units[product.id]))
	row.add_child(order)
	var reason: String = _game.supply.check_order(supplier_id, product.id, units)
	order.disabled = not reason.is_empty()
	var note_text: String = reason if not reason.is_empty() else "Bezahlt aus: %s" % \
			LedgerSystemScript.ACCOUNT_LABELS[_game.supply.payment_account(cost)]
	var note := UiStyle.wrapping_label(note_text, UiStyle.MIN_READ_FONT_SIZE,
			UiStyle.NEGATIVE if not reason.is_empty() else UiStyle.MUTED)
	note.name = "SupplierNote_%s" % product.id
	box.add_child(note)
	if not _game.supply.credit_terms(supplier_id).is_empty():
		_add_credit(box, product.id, units)
	return card


## U.7: „Auf Kredit“ – gesperrt mit Grund (z. B. „Kredit erst nach der ersten Lieferung.“).
func _add_credit(box: VBoxContainer, product_id: String, units: int) -> void:
	var debt: int = _game.supply.credit_cost(supplier_id, product_id, units)
	var credit: Button = _screen.scroll_button("Auf Kredit · %s später" % LedgerSystemScript.format_cents(debt),
			"SupplierCreditButton_%s" % product_id)
	credit.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	credit.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	UiStyle.style_neutral_button(credit)
	credit.pressed.connect(func() -> void: _screen.on_supply_credit_order(supplier_id, product_id, _units[product_id]))
	box.add_child(credit)
	var reason: String = _game.supply.check_credit_order(supplier_id, product_id, units)
	credit.disabled = not reason.is_empty()
	if reason.is_empty():
		_game.tutorials.report("first_credit_offered")
	else:
		var why := UiStyle.wrapping_label(reason, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
		why.name = "SupplierCreditNote_%s" % product_id
		box.add_child(why)


func _change(product_id: String, delta: int) -> void:
	var supplier = _supplier()
	_units[product_id] = clampi(_units[product_id] + delta, supplier.min_units, supplier.max_units)
	refresh()
