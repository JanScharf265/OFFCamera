extends VBoxContainer

## Fenster „Rivalen“ (U.14): je Bande Stärke, Aggression, Revier, Beziehung (neutral / Konflikt / Waffenstillstand
## bis Tag X) und „Waffenstillstand anbieten“. Werte, Kosten und Sperrgründe liefert das RivalSystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const RivalSystemScript := preload("res://scripts/systems/rival_system.gd")

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "RivalsContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Rivalen"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(UiStyle.wrapping_label("Wer im Revier einer Bande Einfluss sammelt, bekommt Ärger. Ein Waffenstillstand kostet Geld und hält eine Woche – solange drücken sie nicht auf deinen Einfluss.",
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	for gang in _game.rivals.get_catalog().get_all():
		add_child(_card(gang))


func _card(gang) -> Control:
	var rivals = _game.rivals
	var card := UiStyle.card()
	card.name = "Rival_%s" % gang.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UiStyle.label(gang.display_name, UiStyle.FONT_SIZE, UiStyle.TEXT))
	var names := PackedStringArray()
	for district_id in gang.districts:
		var district = _game.data.districts.get_definition(district_id)
		names.append(district.display_name if district != null else district_id)
	var values := UiStyle.wrapping_label("Stärke %d · Aggression %d · Revier: %s" % [rivals.get_strength(gang.id),
			gang.aggression, ", ".join(names)], UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	values.name = "RivalValues_%s" % gang.id
	left.add_child(values)
	left.add_child(UiStyle.wrapping_label(gang.description, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	var relation: String = rivals.get_relation(gang.id)
	var status_text: String = RivalSystemScript.RELATION_LABELS[relation]
	if relation != RivalSystemScript.NEUTRAL:
		status_text += " bis Tag %d" % rivals.get_until_day(gang.id)
	var status := UiStyle.label(status_text, UiStyle.MIN_READ_FONT_SIZE,
			UiStyle.NEGATIVE if relation == RivalSystemScript.CONFLICT else UiStyle.ACCENT if relation == RivalSystemScript.TRUCE
			else UiStyle.MUTED)
	status.name = "RivalStatus_%s" % gang.id
	left.add_child(status)
	var reason: String = rivals.check_truce(gang.id)
	var button: Button = _screen.scroll_button("Waffenstillstand · %s" % LedgerSystemScript.format_cents(
			rivals.truce_cost(gang.id)) if reason.is_empty() else reason, "RivalTruceButton_%s" % gang.id)
	button.disabled = not reason.is_empty()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(300, UiStyle.TOUCH_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", UiStyle.MIN_READ_FONT_SIZE)
	button.pressed.connect(_screen.on_rival_truce.bind(gang.id))
	row.add_child(button)
	return card
