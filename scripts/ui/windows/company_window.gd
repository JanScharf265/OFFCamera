extends VBoxContainer

## Fensterinhalt „Unternehmen“ (G2): Firmenkonto, Auslastung, Ruf, Tagesprognose, Filiale,
## Einlage/Entnahme, Tagesabschlüsse und Unternehmens-Verlauf. Ohne Unternehmen ein Hinweis.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const CompanySystemScript := preload("res://scripts/systems/company_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const LIST_COUNT := 6

var _screen
var _game
var _built_for_founded := false
var _overview: VBoxContainer
var _settlements: VBoxContainer
var _history: VBoxContainer


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "CompanyWindowContent"
	add_theme_constant_override("separation", 12)
	_overview = VBoxContainer.new()
	_overview.name = "CompanyPanel"
	add_child(_overview)
	add_child(UiStyle.section_label("Tagesabschlüsse"))
	_settlements = VBoxContainer.new()
	_settlements.name = "CompanySettlements"
	_settlements.add_theme_constant_override("separation", 8)
	add_child(_settlements)
	add_child(UiStyle.section_label("Unternehmens-Verlauf"))
	_history = VBoxContainer.new()
	_history.name = "CompanyHistory"
	_history.add_theme_constant_override("separation", 8)
	add_child(_history)
	_build_overview()
	refresh()


func get_title() -> String:
	var definition = _game.company.get_type()
	return definition.display_name if definition != null else "Unternehmen"


func refresh() -> void:
	if _built_for_founded != _game.company.is_founded():
		_build_overview()
	if _game.company.is_founded():
		_update_overview()
	_refresh_lists()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_overview() -> void:
	_clear(_overview)
	var company = _game.company
	_built_for_founded = company.is_founded()
	if not company.is_founded():
		var names := PackedStringArray()
		for type_id in company.get_catalog().get_ids():
			var definition = company.get_catalog().get_definition(type_id)
			var location = _game.locations.get_catalog().get_definition(definition.found_location)
			names.append("%s (%s)" % [definition.display_name, location.display_name if location != null else "?"])
		var hint := UiStyle.wrapping_label("Noch kein Unternehmen. Gründen möglich: %s." % ", ".join(names),
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		hint.name = "CompanyHint"
		_overview.add_child(hint)
		return
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.name = "CompanyOverview"
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	_overview.add_child(card)
	for label_name in ["CompanyName", "CompanyAccount"]:
		var label := UiStyle.label("", UiStyle.LARGE_FONT_SIZE if label_name == "CompanyName" else UiStyle.FONT_SIZE)
		label.name = label_name
		box.add_child(label)
	for key in ["utilization", "reputation"]:
		var label := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		label.name = "CompanyValue_%s" % key
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.name = "CompanyBar_%s" % key
		bar.max_value = CompanySystemScript.MAX_SCORE
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		box.add_child(bar)
	for label_name in ["CompanyForecast", "CompanyBranch"]:
		var label := UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE)
		label.name = label_name
		box.add_child(label)
	# Untereinander: nebeneinander wären die Texte breiter als das Fenster.
	var step: String = LedgerSystemScript.format_cents(_screen.TRANSFER_STEP_CENTS)
	var deposit: Button = _screen.scroll_button("%s einlegen (privat → Firma)" % step, "CompanyDepositButton")
	deposit.pressed.connect(func() -> void: _screen.on_company_transfer_pressed(true))
	box.add_child(deposit)
	var withdraw: Button = _screen.scroll_button("%s entnehmen (Firma → privat)" % step, "CompanyWithdrawButton")
	withdraw.pressed.connect(func() -> void: _screen.on_company_transfer_pressed(false))
	box.add_child(withdraw)


func _update_overview() -> void:
	var company = _game.company
	var definition = company.get_type()
	var box := _overview.find_child("CompanyOverview", true, false) as Control
	if definition == null:  # Art in den Daten entfernt (Phase 6): nur Konto und Werte zeigen
		(box.find_child("CompanyName", false, false) as Label).text = "Unternehmen (%s)" % company.get_type_id()
		(box.find_child("CompanyForecast", false, false) as Label).text = \
				"Diese Unternehmensart gibt es nicht mehr – keine Tagesabschlüsse."
		(box.find_child("CompanyBranch", false, false) as Label).visible = false
		(box.find_child("CompanyAccount", false, false) as Label).text = "Firmenkonto: %s" % \
				LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.COMPANY))
		return
	(box.find_child("CompanyName", false, false) as Label).text = definition.display_name
	(box.find_child("CompanyAccount", false, false) as Label).text = "Firmenkonto: %s" % \
			LedgerSystemScript.format_cents(_game.ledger.get_balance(LedgerSystemScript.COMPANY))
	for key in ["utilization", "reputation"]:
		var value: int = company.get_value(key)
		(box.find_child("CompanyValue_%s" % key, false, false) as Label).text = "%s %d/%d" % [
				CompanySystemScript.LABELS[key], value, CompanySystemScript.MAX_SCORE]
		(box.find_child("CompanyBar_%s" % key, false, false) as ProgressBar).value = value
	var outcome: Dictionary = company.preview_day()
	(box.find_child("CompanyForecast", false, false) as Label).text = \
			"Heute erwartet: Umsatz %s · Fixkosten %s · Ergebnis %s (abgerechnet beim Tageswechsel; Auslastung -%d ohne Pflege)" % [
			ActivityText.signed_money(outcome["revenue_cents"]), ActivityText.signed_money(-outcome["costs_cents"]),
			ActivityText.signed_money(outcome["revenue_cents"] - outcome["costs_cents"]), definition.utilization_decay_per_day]
	var branch_label := box.find_child("CompanyBranch", false, false) as Label
	branch_label.visible = definition.has_branch
	if definition.has_branch:
		var location = _game.locations.get_catalog().get_definition(definition.branch_location)
		var place: String = location.display_name if location != null else definition.branch_location
		branch_label.text = ("Filiale %s: geöffnet (%s)" if company.is_branch_open() else "Filiale %s: noch nicht eröffnet (im %s)") \
				% [definition.branch_display_name, place]
	(box.find_child("CompanyDepositButton", true, false) as Button).disabled = \
			not company.check_deposit(_screen.TRANSFER_STEP_CENTS).is_empty()
	(box.find_child("CompanyWithdrawButton", true, false) as Button).disabled = \
			not company.check_withdraw(_screen.TRANSFER_STEP_CENTS).is_empty()


func _refresh_lists() -> void:
	var company = _game.company
	_clear(_settlements)
	var settlements: Array = company.get_settlements()
	if settlements.is_empty():
		_settlements.add_child(UiStyle.label("Noch keine Tagesabschlüsse.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for i in range(settlements.size() - 1, maxi(settlements.size() - LIST_COUNT, 0) - 1, -1):
		var settlement: Dictionary = settlements[i]
		var color := UiStyle.TEXT if settlement["paid"] else UiStyle.NEGATIVE
		_settlements.add_child(UiStyle.wrapping_label(settlement["text"], UiStyle.SMALL_FONT_SIZE, color))

	_clear(_history)
	var history: Array = company.get_history()
	if history.is_empty():
		_history.add_child(UiStyle.label("Noch keine Änderungen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for i in range(history.size() - 1, maxi(history.size() - LIST_COUNT, 0) - 1, -1):
		var lines := ActivityText.company_change_text(history[i])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(UiStyle.wrapping_label(lines[0], UiStyle.SMALL_FONT_SIZE))
		if not lines[1].is_empty():
			row.add_child(UiStyle.wrapping_label(lines[1], UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		_history.add_child(row)
