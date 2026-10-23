extends PanelContainer

## Kachel im Ortsfenster (G4.5): Name, Zeile für Zeit („2 h · Ende 10:20“), Wirkungen als Symbol + Zahl
## (grün = gut, rot = Kosten, grau = neutral), eine fest reservierte Hinweiszeile (z. B. Terminkonflikt) und
## unten der Button. Ist die Aktion gesperrt, steht der Grund im Button. Käufe (sofort, ohne Spielzeit) haben
## einen eigenen Button-Stil (UiStyle.style_tile_button). Zeigt nur an.
## G4.5b: Der Button ist sichtbar 56 px hoch, seine Tippfläche 84 px – sie reicht unsichtbar nach oben über die
## Hinweiszeile (beide liegen im „ActionArea“). Gesperrt füllt der Button die volle Höhe (Platz für den Grund),
## die Hinweiszeile tritt dann zurück.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const CAR_ICON := "res://assets/icons/car.svg"

## Wirkung für set_effects(): {"text": "+25,00 €", "tone": 1 (gut) / -1 (Kosten) / 0 (neutral), "icon": Pfad oder ""}.
const TONE_GOOD := 1
const TONE_COST := -1
const TONE_NEUTRAL := 0

var button: Button
var _title: Label
var _time: Label
## G5.7: Auto vor der Zeitzeile und im Button bei „Hinfahren und starten“
var _trip_icon: TextureRect
var _trip := false
var _effects: HFlowContainer
var _info: Label
var _hint: Label
var _action_text := ""
## Text des freien Buttons: Aktionstext oder (G5.7) „Hinfahren und starten“
var _shown_action_text := ""


## key = Name-Suffix der Knoten (z. B. "livestream"), action_text = Text des Buttons, wenn frei.
func _init(key: String, title: String, action_button: Button, action_text: String, is_purchase: bool) -> void:
	name = "Tile_%s" % key
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := UiStyle.flat_box(UiStyle.SURFACE, UiStyle.TILE_PADDING)
	panel.content_margin_top = UiStyle.TILE_PADDING - 2
	panel.content_margin_bottom = UiStyle.TILE_PADDING - 2
	add_theme_stylebox_override("panel", panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_title = _line(title, UiStyle.TILE_TITLE_FONT_SIZE, UiStyle.TEXT)
	_title.name = "TileTitle_%s" % key
	box.add_child(_title)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(time_row)
	_trip_icon = TextureRect.new()
	_trip_icon.name = "TileTripIcon_%s" % key
	_trip_icon.texture = load(CAR_ICON)
	_trip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trip_icon.custom_minimum_size = Vector2(UiStyle.TILE_ICON_SIZE, UiStyle.TILE_ICON_SIZE)
	_trip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trip_icon.modulate = UiStyle.MUTED
	_trip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trip_icon.visible = false
	time_row.add_child(_trip_icon)
	_time = _line("", UiStyle.TILE_FONT_SIZE, UiStyle.MUTED)
	_time.name = "TileTime_%s" % key
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time)
	_effects = HFlowContainer.new()
	_effects.name = "TileEffects_%s" % key
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.add_theme_constant_override("h_separation", 8)
	_effects.add_theme_constant_override("v_separation", 0)
	box.add_child(_effects)
	_info = UiStyle.wrapping_label("", UiStyle.TILE_FONT_SIZE, UiStyle.MUTED)
	_info.visible = false
	box.add_child(_info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	# Unten: Hinweiszeile (immer reserviert, damit alle Buttons auf einer Höhe liegen) und darüberliegend die
	# 84-px-Tippfläche des Buttons, von der nur die unteren 56 px gezeichnet werden.
	var action_area := Control.new()
	action_area.name = "ActionArea"
	action_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(action_area)
	_hint = _line("", UiStyle.TILE_FONT_SIZE, UiStyle.WARNING)
	_hint.name = "TileHint_%s" % key
	var hint_height := _hint.get_minimum_size().y
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_bottom = hint_height
	action_area.add_child(_hint)
	action_area.custom_minimum_size.y = maxf(UiStyle.TOUCH_SIZE, hint_height + 4.0 + UiStyle.TILE_BUTTON_VISIBLE)

	button = action_button
	_action_text = action_text
	_shown_action_text = action_text
	button.text = action_text
	# Auto bei „Hinfahren und starten“ (G5.7): klein und eng, damit der Text auf dem iPhone SE in eine Zeile passt.
	button.add_theme_constant_override("icon_max_width", UiStyle.TILE_ICON_SIZE - 4)
	button.add_theme_constant_override("h_separation", 4)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", UiStyle.TILE_BUTTON_FONT_SIZE)
	UiStyle.style_tile_button(button, is_purchase)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	button.offset_top = -UiStyle.TOUCH_SIZE
	action_area.add_child(button)


## Name eines Infotexts (z. B. "CompanyInfo_merch_label"), falls Tests/Anzeige ihn brauchen.
func info_label(node_name: String) -> Label:
	_info.name = node_name
	return _info


func set_title(text: String) -> void:
	_title.text = text


func set_time(text: String) -> void:
	_time.text = text
	_time.visible = not text.is_empty()
	_trip_icon.visible = _trip and _time.visible


## G5.7 „Hinfahren und starten“: an = Auto vor der Zeitzeile (Text z. B. „20 min + 2 h · Ende 15:00“ über set_time)
## und im Button, Button-Text `trip_text`; aus = normaler Aktionstext. Danach set_reason() aufrufen.
func set_trip(on: bool, trip_text: String = "") -> void:
	_trip = on
	_trip_icon.visible = on and _time.visible
	if on:
		_shown_action_text = trip_text
	else:
		_shown_action_text = _action_text
	button.icon = load(CAR_ICON) if on else null


## effects: Array von {"text", "tone", "icon"} (siehe oben). Neu aufgebaut bei jedem Aufruf.
func set_effects(effects: Array) -> void:
	for child in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	for effect in effects:
		_effects.add_child(_chip(effect))
	_effects.visible = not effects.is_empty()


## Freier Text statt Wirkungen (z. B. „Gegründet · Firmenkonto …“); "" blendet ihn aus.
func set_info(text: String) -> void:
	_info.text = text
	_info.visible = not text.is_empty()


## Hinweiszeile: Warnung (gelb, z. B. Terminkonflikt) oder Notiz (grau, z. B. Qualität).
func set_hint(text: String, is_warning: bool = true) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", UiStyle.WARNING if is_warning else UiStyle.MUTED)


## U.18: Aktionstext ändern (z. B. „Anmieten“ → „Ausbauen · 250,00 €“). Danach set_reason() aufrufen.
func set_action_text(text: String) -> void:
	_action_text = text
	if not _trip:
		_shown_action_text = text


## "" = frei (Button zeigt seinen Aktionstext), sonst steht der Sperrgrund im Button.
func set_reason(reason: String) -> void:
	button.disabled = not reason.is_empty()
	button.text = _shown_action_text if reason.is_empty() else reason
	if not reason.is_empty():
		button.icon = null
	button.add_theme_font_size_override("font_size",
			UiStyle.MIN_READ_FONT_SIZE if not reason.is_empty() else UiStyle.TILE_BUTTON_FONT_SIZE)
	_hint.visible = reason.is_empty()  # gesperrt: Der Button nutzt die volle Höhe für den Grund


func _line(text: String, font_size: int, color: Color) -> Label:
	var result := UiStyle.label(text, font_size, color)
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result.clip_text = true
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _chip(effect: Dictionary) -> HBoxContainer:
	var tone: int = effect.get("tone", TONE_NEUTRAL)
	var color := UiStyle.POSITIVE if tone == TONE_GOOD else (UiStyle.NEGATIVE if tone == TONE_COST else UiStyle.MUTED)
	var chip := HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_constant_override("separation", 3)
	var icon_path: String = effect.get("icon", "")
	if not icon_path.is_empty():
		# Stabile UI-ID (T.6), z. B. „TileChip_singleplayer“ = Follower – das Symbole-Tutorial zeigt darauf.
		chip.name = "TileChip_%s" % icon_path.get_file().get_basename()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(UiStyle.TILE_ICON_SIZE, UiStyle.TILE_ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = color
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
	var label := UiStyle.label(effect["text"], UiStyle.TILE_FONT_SIZE, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip
