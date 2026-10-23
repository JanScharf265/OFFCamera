extends VBoxContainer

## Fenster „Crew“ (U.10): eigene Leute (Rolle, Können, Loyalität, Gier, Lohn, „Feuern“) und die Bewerber des Tages
## („Einstellen“). U.11: Dealer zeigen, was sie am Tag verkaufen, abzweigen und an Hitze bringen; Mitglieder mit Rang
## und „Befördern“. Regeln, Werte und Sperrgründe liefert das CrewSystem; hier wird nur angezeigt.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CrewSystemScript := preload("res://scripts/systems/crew_system.gd")

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "CrewContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Crew"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var crew = _game.crew
	var members: Array = crew.get_members()
	var summary := UiStyle.wrapping_label("%d von %d Leuten · Löhne %s am Tag (beim Tageswechsel, aus Schwarzgeld oder vom Privatkonto)" % [
			members.size(), crew.get_catalog().max_members, LedgerSystemScript.format_cents(crew.wages_per_day())],
			UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	summary.name = "CrewSummary"
	add_child(summary)
	add_child(UiStyle.section_label("Deine Leute"))
	if members.is_empty():
		var empty := UiStyle.label("Noch niemand.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		empty.name = "CrewEmpty"
		add_child(empty)
	for member in members:
		add_child(_card(member, true))
	add_child(UiStyle.section_label("Bewerber heute"))
	var applicants: Array = crew.get_applicants()
	if applicants.is_empty():
		var none := UiStyle.label("Heute meldet sich niemand mehr.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		none.name = "ApplicantsEmpty"
		add_child(none)
	for applicant in applicants:
		add_child(_card(applicant, false))


## Kompakt (zwei bis drei Bewerber ohne Scrollen): links Name, Werte, Rolle; rechts Lohn und Button.
func _card(person: Dictionary, is_member: bool) -> Control:
	var role = _game.crew.get_catalog().get_role(person["role"])
	var card := UiStyle.card()
	card.name = ("CrewMember_%s" if is_member else "Applicant_%s") % person["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var title_text := "%s · %s" % [person["name"], role.display_name if role != null else person["role"]]
	if is_member:
		title_text += " · Rang %d" % int(person.get("rank", 1))
	left.add_child(UiStyle.label(title_text, UiStyle.FONT_SIZE, UiStyle.TEXT))
	var parts := PackedStringArray()
	for key in CrewSystemScript.VALUE_KEYS:
		parts.append("%s %d" % [CrewSystemScript.VALUE_LABELS[key], person[key]])
	var values := UiStyle.label(" · ".join(parts), UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	values.name = "CrewValues_%s" % person["id"]
	left.add_child(values)
	if _game.crew.is_dealer(person):
		var units: int = _game.crew.dealer_units(person)
		var info := UiStyle.wrapping_label("Verkauft %d–%d Einheiten am Tag · zweigt %d %% ab · Hitze %d %%" % [units,
				units + 1, _game.crew.skim_percent(person), _game.crew.heat_percent(person)], UiStyle.MIN_READ_FONT_SIZE,
				UiStyle.ACCENT)
		info.name = "CrewDealerInfo_%s" % person["id"]
		left.add_child(info)
		if is_member:
			_game.tutorials.report("first_dealer_in_crew")
	if role != null and not is_member:
		left.add_child(UiStyle.wrapping_label(role.description, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 260
	row.add_child(right)
	var wage := UiStyle.label("%s/Tag" % LedgerSystemScript.format_cents(person["wage_cents"]), UiStyle.MIN_READ_FONT_SIZE,
			UiStyle.TEXT)
	wage.name = "CrewWage_%s" % person["id"]
	wage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(wage)
	var button: Button
	if is_member:
		button = _screen.scroll_button("Feuern", "CrewFireButton_%s" % person["id"])
		UiStyle.style_neutral_button(button)
		button.pressed.connect(_screen.on_crew_fire.bind(person["id"]))
	else:
		button = _screen.scroll_button("Einstellen", "CrewHireButton_%s" % person["id"])
		button.pressed.connect(_screen.on_crew_hire.bind(person["id"]))
		var reason: String = _game.crew.check_hire(person["id"])
		button.disabled = not reason.is_empty()
		if not reason.is_empty():
			button.text = reason
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			_game.tutorials.report("first_crew_open")
	button.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	button.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	right.add_child(button)
	if is_member:
		right.add_child(_promote_button(person))
		if _game.crew.is_dealer(person):
			right.add_child(_district_button(person))
	return card


## U.13: Gebiet des Dealers – Tipp wechselt zum nächsten Gebiet (danach „keins“).
func _district_button(member: Dictionary) -> Button:
	var district = _game.data.districts.get_definition(member.get("district", ""))
	var button: Button = _screen.scroll_button("Gebiet: %s" % (district.display_name if district != null else "keins"),
			"CrewDistrictButton_%s" % member["id"])
	UiStyle.style_neutral_button(button)
	button.pressed.connect(_screen.on_crew_assign_next.bind(member["id"]))
	button.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	button.add_theme_font_size_override("font_size", UiStyle.MIN_READ_FONT_SIZE)
	return button


## U.11: „Befördern · 195,00 €“ – gesperrt mit Grund (z. B. „Erst nach 3 Tagen (noch 2).“).
func _promote_button(member: Dictionary) -> Button:
	var reason: String = _game.crew.check_promote(member["id"])
	var button: Button = _screen.scroll_button("Befördern · %s" % LedgerSystemScript.format_cents(
			_game.crew.promotion_cost(member)) if reason.is_empty() else reason, "CrewPromoteButton_%s" % member["id"])
	button.pressed.connect(_screen.on_crew_promote.bind(member["id"]))
	button.disabled = not reason.is_empty()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	button.add_theme_font_size_override("font_size", UiStyle.MIN_READ_FONT_SIZE)
	if reason.is_empty():
		_game.tutorials.report("first_promotion_possible")
	return button
