extends VBoxContainer

## Fenster „Kontakte“ (U.23): je bekanntem Kontakt Rolle, Vertrauen, Wissen, Beschreibung und seine Aktion (Dauer,
## Kosten, gesperrt mit Grund). Werte und Regeln aus dem RelationshipSystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "ContactsContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Kontakte"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(UiStyle.wrapping_label("Vertrauen sinkt, wenn du dich nicht meldest. Wissen bleibt – wer zu viel weiß und zu wenig vertraut, wird zum Risiko.",
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	for contact in _game.relationships.get_known():
		add_child(_card(contact))


func _card(contact) -> Control:
	var relationships = _game.relationships
	var card := UiStyle.card()
	card.name = "Contact_%s" % contact.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UiStyle.label("%s · %s" % [contact.display_name, contact.role], UiStyle.FONT_SIZE, UiStyle.TEXT))
	var values := UiStyle.label("Vertrauen %d · Wissen %d" % [relationships.get_trust(contact.id),
			relationships.get_knowledge(contact.id)], UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	values.name = "ContactValues_%s" % contact.id
	left.add_child(values)
	left.add_child(UiStyle.wrapping_label(contact.description, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	var action: Dictionary = contact.action
	var parts := PackedStringArray([TimeSystemScript.format_duration(action["minutes"])])
	if int(action["cost_cents"]) > 0:
		parts.append(LedgerSystemScript.format_cents(action["cost_cents"]))
	var reason: String = relationships.check_action(contact.id)
	var button: Button = _screen.scroll_button("%s · %s" % [action["label"], " · ".join(parts)] if reason.is_empty()
			else reason, "ContactAction_%s" % contact.id)
	button.disabled = not reason.is_empty()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(340, UiStyle.TOUCH_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", UiStyle.MIN_READ_FONT_SIZE)
	button.pressed.connect(_screen.on_contact_action.bind(contact.id))
	row.add_child(button)
	_game.tutorials.report("first_contacts_open")
	return card
