extends PanelContainer

## Kachel im Ortsfenster (G4.5): Name, Zeile für Zeit („2 h · Ende 10:20“), Wirkungen als Symbol + Zahl
## (grün = gut, rot = Kosten, grau = neutral), eine fest reservierte Hinweiszeile (z. B. Terminkonflikt) und
## unten der Button. Ist die Aktion gesperrt, steht der Grund im Button. Käufe (sofort, ohne Spielzeit) haben
## einen eigenen Button-Stil (UiStyle.style_purchase_button). Zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

## Wirkung für set_effects(): {"text": "+25,00 €", "tone": 1 (gut) / -1 (Kosten) / 0 (neutral), "icon": Pfad oder ""}.
const TONE_GOOD := 1
const TONE_COST := -1
const TONE_NEUTRAL := 0

var button: Button
var _title: Label
var _time: Label
var _effects: HFlowContainer
var _info: Label
var _hint: Label
var _action_text := ""


## key = Name-Suffix der Knoten (z. B. "livestream"), action_text = Text des Buttons, wenn frei.
func _init(key: String, title: String, action_button: Button, action_text: String, is_purchase: bool) -> void:
	name = "Tile_%s" % key
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", UiStyle.flat_box(UiStyle.SURFACE, UiStyle.TILE_PADDING))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_title = _line(title, UiStyle.TILE_TITLE_FONT_SIZE, UiStyle.TEXT)
	_title.name = "TileTitle_%s" % key
	box.add_child(_title)
	_time = _line("", UiStyle.TILE_FONT_SIZE, UiStyle.MUTED)
	_time.name = "TileTime_%s" % key
	box.add_child(_time)
	_effects = HFlowContainer.new()
	_effects.name = "TileEffects_%s" % key
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.add_theme_constant_override("h_separation", 12)
	_effects.add_theme_constant_override("v_separation", 0)
	box.add_child(_effects)
	_info = UiStyle.wrapping_label("", UiStyle.TILE_FONT_SIZE, UiStyle.MUTED)
	_info.visible = false
	box.add_child(_info)
	# Hinweiszeile ist immer da (auch leer), damit alle Buttons auf einer Höhe liegen.
	_hint = _line("", UiStyle.TILE_FONT_SIZE, UiStyle.WARNING)
	_hint.name = "TileHint_%s" % key
	_hint.custom_minimum_size.y = UiStyle.TILE_HINT_HEIGHT
	box.add_child(_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	button = action_button
	_action_text = action_text
	button.text = action_text
	button.custom_minimum_size.y = UiStyle.TILE_BUTTON_HEIGHT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_purchase:
		UiStyle.style_purchase_button(button)
	box.add_child(button)


## Name eines Infotexts (z. B. "CompanyInfo_merch_label"), falls Tests/Anzeige ihn brauchen.
func info_label(node_name: String) -> Label:
	_info.name = node_name
	return _info


func set_title(text: String) -> void:
	_title.text = text


func set_time(text: String) -> void:
	_time.text = text
	_time.visible = not text.is_empty()


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


## "" = frei (Button zeigt seinen Aktionstext), sonst steht der Sperrgrund im Button.
func set_reason(reason: String) -> void:
	button.disabled = not reason.is_empty()
	button.text = _action_text if reason.is_empty() else reason
	button.add_theme_font_size_override("font_size",
			UiStyle.TILE_REASON_FONT_SIZE if not reason.is_empty() else UiStyle.TILE_BUTTON_FONT_SIZE)


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
	chip.add_theme_constant_override("separation", 4)
	var icon_path: String = effect.get("icon", "")
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
