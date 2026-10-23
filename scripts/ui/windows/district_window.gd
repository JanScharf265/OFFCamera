extends VBoxContainer

## Fenster eines Gebiets (U.13): Beschreibung, Nachfrage/Polizei/Rivalen, dein Einfluss (mit Änderung je Tag),
## zugeteilte Dealer und „Beanspruchen“. Regeln, Werte und Sperrgründe liefert das TerritorySystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const DistrictCatalogScript := preload("res://scripts/systems/district_catalog.gd")
const RivalSystemScript := preload("res://scripts/systems/rival_system.gd")

var district_id := ""

var _screen
var _game


func setup(screen, game, p_district_id: String) -> void:
	_screen = screen
	_game = game
	district_id = p_district_id


func _ready() -> void:
	name = "DistrictContent"
	add_theme_constant_override("separation", 10)
	refresh()


func get_title() -> String:
	return "Gebiet · %s" % _district().display_name


func _district():
	return _game.territory.get_districts().get_definition(district_id)


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var district = _district()
	var territory = _game.territory
	add_child(UiStyle.wrapping_label(district.description, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var parts := PackedStringArray()
	for key in DistrictCatalogScript.VALUE_KEYS:
		parts.append("%s %d" % [DistrictCatalogScript.VALUE_LABELS[key], district.get(key)])
	var values := UiStyle.label(" · ".join(parts), UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	values.name = "DistrictValues"
	add_child(values)

	var gang = _game.rivals.get_catalog().get_for_district(district_id)
	if gang != null:
		var relation: String = _game.rivals.get_relation(gang.id)
		var rival_line := UiStyle.wrapping_label("Revier von %s · Stärke %d · %s" % [gang.display_name,
				_game.rivals.get_strength(gang.id), RivalSystemScript.RELATION_LABELS[relation]],
				UiStyle.MIN_READ_FONT_SIZE, UiStyle.NEGATIVE if relation == RivalSystemScript.CONFLICT else UiStyle.TEXT)
		rival_line.name = "DistrictRival"
		add_child(rival_line)
	var controlled: bool = territory.is_controlled(district_id)
	var status := UiStyle.wrapping_label("Gehört dir seit Tag %d." % territory.controlled_since(district_id) if controlled
			else "Gehört dir nicht.", UiStyle.FONT_SIZE, UiStyle.ACCENT if controlled else UiStyle.TEXT)
	status.name = "DistrictStatus"
	add_child(status)
	var influence: int = territory.get_influence(district_id)
	var dealers: int = _game.crew.count_in_district(district_id)
	var line := UiStyle.wrapping_label("Dein Einfluss: %d von 100 · Dealer hier: %d · Rivalen drücken −%d am Tag" % [
			influence, dealers, territory.rival_pressure(district_id)], UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
	line.name = "DistrictInfluence"
	add_child(line)
	var rules = territory.get_rules()
	var hint_text := "Fällt der Einfluss unter %d, ist das Gebiet weg. Dealer hier verkaufen %d Einheit mehr am Tag." % [
			rules.get_value("lose_below"), rules.get_value("controlled_unit_bonus")] if controlled \
			else "Dealer, die du unter „Crew“ hierher schickst, bringen jeden Tag Einfluss. Ab %d kannst du das Gebiet beanspruchen." % \
			rules.get_value("claim_min_influence")
	var hint := UiStyle.wrapping_label(hint_text, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	hint.name = "DistrictHint"
	add_child(hint)
	if not controlled:
		var reason: String = territory.check_claim(district_id)
		var claim: Button = _screen.scroll_button("Beanspruchen · %s" % LedgerSystemScript.format_cents(
				rules.get_value("claim_cost_cents")) if reason.is_empty() else reason, "DistrictClaimButton")
		claim.disabled = not reason.is_empty()
		claim.custom_minimum_size = Vector2(420, UiStyle.TOUCH_SIZE)
		claim.size_flags_horizontal = Control.SIZE_SHRINK_END
		claim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		claim.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		claim.pressed.connect(_screen.on_district_claim.bind(district_id))
		add_child(claim)
