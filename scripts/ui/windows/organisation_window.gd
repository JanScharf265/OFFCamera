extends VBoxContainer

## Fenster „Organisation“ (U.3): Name, Respekt in der Szene, Hitze und Stabilität – je als Balken mit Zahl und einem
## Satz, was der Wert bedeutet. Seit U.6 darunter: Ware im Bestand, Lieferungen unterwegs und die erreichbaren
## Lieferanten („El Rubio anrufen“). Werte aus OrganisationSystem und SupplySystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const OrganisationSystemScript := preload("res://scripts/systems/organisation_system.gd")
const HudBarScript := preload("res://scripts/ui/hud_bar.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

const EXPLANATIONS := {
	"respect": "Wie ernst dich die Szene nimmt. Wer Respekt hat, bekommt bessere Deals.",
	"heat": "Wie genau die Polizei hinschaut. Jeder Tag kühlt ein wenig ab.",
	"stability": "Wie fest deine Leute zusammenhalten. Wackelt sie, wird es teuer.",
}

var _game
var _screen
var _rows := {}
## U.16: gewählter Betrag zum Waschen (Cent), nur solange das Fenster offen ist
var _launder_cents := 0
## U.6: Ware, Lieferungen, Lieferanten – wird bei jedem refresh() neu aufgebaut
var _supply_box: VBoxContainer


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "OrganisationContent"
	add_theme_constant_override("separation", 12)
	# Ware und Lieferant zuerst – das ist, was man hier tut; die Werte darunter (U.6).
	_supply_box = VBoxContainer.new()
	_supply_box.name = "OrganisationSupply"
	_supply_box.add_theme_constant_override("separation", 8)
	add_child(_supply_box)
	add_child(UiStyle.section_label("Werte"))
	for key in OrganisationSystemScript.KEYS:
		add_child(_row(key))
	refresh()


func get_title() -> String:
	return "Organisation · %s" % _game.organisation.get_name()


func refresh() -> void:
	for key in _rows:
		var value: int = _game.organisation.get_value(key)
		var bar := _rows[key]["bar"] as ProgressBar
		bar.value = value
		(_rows[key]["value"] as Label).text = str(value)
		if key == "heat":
			(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = HudBarScript.heat_color(value)
	_refresh_supply()


func _refresh_supply() -> void:
	for child in _supply_box.get_children():
		_supply_box.remove_child(child)
		child.queue_free()
	var supply = _game.supply
	_supply_box.add_child(UiStyle.section_label("Ware"))
	var any := false
	for product in supply.get_products().get_all():
		var units: int = supply.get_stock(product.id)
		if units > 0:
			any = true
			var line := UiStyle.label("%s: %d Einheit%s" % [product.display_name, units, "" if units == 1 else "en"],
					UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
			line.name = "StockLine_%s" % product.id
			_supply_box.add_child(line)
	if not any:
		var empty := UiStyle.label("Noch keine Ware.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		empty.name = "StockEmpty"
		_supply_box.add_child(empty)
	for order in supply.get_pending_orders():
		var product = supply.get_products().get_definition(order["product"])
		var supplier = supply.get_suppliers().get_definition(order["supplier"])
		var line := UiStyle.wrapping_label("Unterwegs: %d × %s von %s – kommt Tag %d" % [order["units"],
				product.display_name if product != null else order["product"],
				supplier.name if supplier != null else order["supplier"], order["due_day"]],
				UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
		line.name = "PendingOrder_%s" % order["id"]
		_supply_box.add_child(line)
	var incoming: int = supply.incoming_units()
	var capacity_text := "Platz für Ware: %d von %d belegt" % [supply.total_stock() + incoming, _game.sites.capacity()]
	if incoming > 0:
		capacity_text += " (davon unterwegs %d)" % incoming
	var capacity_line := UiStyle.label(capacity_text, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	capacity_line.name = "StockCapacity"
	_supply_box.add_child(capacity_line)
	for site in _game.sites.get_owned():
		var site_line := UiStyle.wrapping_label("%s · %s/Tag" % [site.display_name,
				LedgerSystemScript.format_cents(site.running_cost_per_day_cents)], UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
		site_line.name = "OwnedSite_%s" % site.id
		_supply_box.add_child(site_line)
	for debt in supply.get_debts():
		var supplier_def = supply.get_suppliers().get_definition(debt["supplier"])
		var line := UiStyle.wrapping_label("Schulden bei %s: %s · %s" % [
				supplier_def.name if supplier_def != null else debt["supplier"],
				LedgerSystemScript.format_cents(debt["amount_cents"]),
				"überfällig – unter „Fristen“ bezahlen" if debt["overdue"] else "fällig Tag %d" % debt["due_day"]],
				UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE if debt["overdue"] else UiStyle.WARNING)
		line.name = "Debt_%s" % debt["order_id"]
		_supply_box.add_child(line)
	if _game.crew.is_available():
		var crew_button: Button = _screen.scroll_button("Crew (%d)" % _game.crew.get_members().size(), "CrewButton")
		crew_button.pressed.connect(_screen.open_crew)
		_supply_box.add_child(crew_button)
	if _game.black_spending.is_available():
		_add_black_spending()
	if _game.laundering.is_available():
		_add_laundering()
	if _game.rivals.is_available():
		var rivals_button: Button = _screen.scroll_button("Rivalen", "RivalsButton")
		rivals_button.pressed.connect(_screen.open_rivals)
		_supply_box.add_child(rivals_button)
	for supplier in supply.get_unlocked():
		var button: Button = _screen.scroll_button("%s anrufen" % supplier.name, "SupplierButton_%s" % supplier.id)
		button.pressed.connect(func() -> void: _screen.open_supplier(supplier.id))
		_supply_box.add_child(button)


func _row(key: String) -> Control:
	var card := UiStyle.card()
	card.name = "OrganisationRow_%s" % key
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var title := UiStyle.label(OrganisationSystemScript.LABELS[key], UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	title.custom_minimum_size.x = 160
	head.add_child(title)
	var bar := ProgressBar.new()
	bar.name = "OrganisationBar_%s" % key
	bar.min_value = OrganisationSystemScript.MIN_VALUE
	bar.max_value = OrganisationSystemScript.MAX_VALUE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var background := StyleBoxFlat.new()
	background.bg_color = UiStyle.SURFACE_PRESSED
	background.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.ACCENT if key != "heat" else UiStyle.TEXT
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	head.add_child(bar)
	var value := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	value.name = "OrganisationValue_%s" % key
	value.custom_minimum_size.x = 48
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(value)
	box.add_child(UiStyle.wrapping_label(EXPLANATIONS[key], UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	_rows[key] = {"bar": bar, "value": value}
	return card


## U.16: Waschen über die Tarnfirma – Betrag (−/+ in Schritten), ein Button, Zahlen aus dem LaunderingSystem.
func _add_laundering() -> void:
	var laundering = _game.laundering
	var rules = laundering.get_rules()
	var step: int = rules.get_value("step_cents")
	var remaining: int = laundering.remaining_today()
	var black: int = _game.ledger.get_balance(LedgerSystemScript.BLACK)
	var most := maxi(step, mini(remaining, black) / step * step)
	_launder_cents = clampi(_launder_cents if _launder_cents > 0 else step * 5, step, most)
	_supply_box.add_child(UiStyle.section_label("Waschen über die Firma"))
	var terms := UiStyle.wrapping_label("Gebühr %d %% · heute noch %s möglich · Hitze +%d je 1.000 €" % [
			rules.get_value("fee_percent"), LedgerSystemScript.format_cents(remaining), rules.get_value("heat_per_1000_euro")],
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	terms.name = "LaunderTerms"
	_supply_box.add_child(terms)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_supply_box.add_child(row)
	var less: Button = _screen.scroll_button("−", "LaunderLess")
	less.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	less.disabled = _launder_cents <= step
	less.pressed.connect(_change_launder.bind(-step))
	row.add_child(less)
	var amount := UiStyle.label(LedgerSystemScript.format_cents(_launder_cents), UiStyle.FONT_SIZE, UiStyle.TEXT)
	amount.name = "LaunderAmount"
	amount.custom_minimum_size.x = 150
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(amount)
	var more: Button = _screen.scroll_button("+", "LaunderMore")
	more.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE, UiStyle.TOUCH_SIZE)
	more.disabled = _launder_cents >= most
	more.pressed.connect(_change_launder.bind(step))
	row.add_child(more)
	var reason: String = laundering.check(_launder_cents)
	var net: int = _launder_cents - laundering.fee_for(_launder_cents)
	var button: Button = _screen.scroll_button("Waschen · %s aufs Firmenkonto" % LedgerSystemScript.format_cents(net)
			if reason.is_empty() else reason, "LaunderButton")
	button.disabled = not reason.is_empty()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	button.pressed.connect(_launder)
	row.add_child(button)
	_game.tutorials.report("first_laundering_offered")


func _change_launder(delta: int) -> void:
	_launder_cents += delta
	refresh()


func _launder() -> void:
	_screen.on_launder(_launder_cents)


## U.17: Schalter „Alltag mit Schwarzgeld bezahlen“ – Regeln und Zustand aus dem BlackSpendingSystem.
func _add_black_spending() -> void:
	var spending = _game.black_spending
	var rules = spending.get_rules()
	_supply_box.add_child(UiStyle.section_label("Schwarzgeld im Alltag"))
	var terms := UiStyle.wrapping_label("Aktivitäten und Ausrüstung · heute noch %s · Hitze +%d je 100 €, mindestens +%d je Zahlung · Miete, Fristen und Firma nie" % [
			LedgerSystemScript.format_cents(spending.remaining_today()), rules.get_value("heat_per_100_euro"),
			rules.get_value("min_heat")], UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	terms.name = "BlackSpendingTerms"
	_supply_box.add_child(terms)
	var on: bool = spending.is_enabled()
	var toggle: Button = _screen.scroll_button("Mit Schwarzgeld bezahlen: An" if on else "Mit Schwarzgeld bezahlen: Aus",
			"BlackSpendingToggle")
	if not on:
		UiStyle.style_neutral_button(toggle)
	toggle.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	toggle.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	toggle.pressed.connect(_screen.on_black_spending_toggle.bind(not on))
	_supply_box.add_child(toggle)
	_game.tutorials.report("first_black_spending_offered")
