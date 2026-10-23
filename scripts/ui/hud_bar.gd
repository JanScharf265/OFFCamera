extends PanelContainer

## HUD als schmale Leiste oben über die volle Breite der Safe Area (G4.3).
## Links Tag, Uhrzeit, Ort; rechts Energie und Stimmung (Icon, Balken, Zahl), Privatkonto, Firmenkonto
## (erst nach der Gründung). Plätze für Schwarzgeld und Hitze sind vorgesehen (ab Paket U).
## Zeigt nur an: Werte kommen über refresh() aus dem GameState.

const GameStateScript := preload("res://scripts/core/game_state.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const STAT_ICONS := {
	"energy": "res://assets/icons/bolt.svg",
	"mood": "res://assets/icons/smiley.svg",
}
## Normalfarben; G5.8: Stimmung blau statt gelb, weil Gelb jetzt „niedrig“ bedeutet.
const STAT_COLORS := {"energy": Color("#7FD38A"), "mood": Color("#7FB4F2")}
## Balkenfarbe je Warnstufe (PlayerStats.level_of): niedrig gelb, kritisch rot (G5.8).
const LOW_COLOR := UiStyle.WARNING
const CRITICAL_COLOR := UiStyle.BADGE
const LOCATION_ICON := "res://assets/kenney/game-icons/target.png"
const HEAT_ICON := "res://assets/icons/flame.svg"
const OrganisationSystemScript := preload("res://scripts/systems/organisation_system.gd")
const ICON_SIZE := 20
const STAT_BAR_WIDTH := 48
const CONTENT_MARGIN_X := 18
const COMPACT_LEVELS := 3

var _date_label: Label
var _clock_label: Label
var _location_label: Label
var _balance_label: Label
var _company_block: Control
var _company_balance_label: Label
## Schwarzgeld (U.1) – sichtbar, sobald es welches gibt
var _black_block: Control
var _black_balance_label: Label
## Kleine Beschriftungen „Privat“/„Firma“/„Schwarz“ (für fit_to)
var _money_captions: Array[Label] = []
## Hitze (U.2) – sichtbar, sobald es eine Organisation gibt: Flamme + Zahl, Farbe nach Stufe
var _heat_block: Control
var _heat_icon: TextureRect
var _heat_label: Label
## Betrag in Cent je Betrags-Label (für fit_to)
var _amounts := {}
## U.1: Verdichtungsstufe (0 = alles, 1 = ohne Datum, 2 = + Beträge ab 1.000 € ohne Cent, 3 = + ohne Beschriftungen)
var _compact := 0
var _stat_labels := {}
var _stat_bars := {}


func _init() -> void:
	name = "HudBar"
	add_theme_stylebox_override("panel", UiStyle.flat_box(UiStyle.HUD_BAR_SURFACE, 0))
	var box := get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_left = CONTENT_MARGIN_X
	box.content_margin_right = CONTENT_MARGIN_X
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.HUD_GAP)
	add_child(row)

	_date_label = _label("DateLabel", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	row.add_child(_date_label)
	_clock_label = _label("ClockLabel", UiStyle.FONT_SIZE, UiStyle.TEXT)
	row.add_child(_clock_label)
	var location := HBoxContainer.new()
	location.add_theme_constant_override("separation", 6)
	location.add_child(_icon(LOCATION_ICON, UiStyle.TEXT))
	_location_label = _label("LocationLabel", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	location.add_child(_location_label)
	row.add_child(location)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	for key in PlayerStatsScript.KEYS:
		row.add_child(_stat(key))
	var private_block := _money("Privat", "BalanceLabel")
	_balance_label = private_block.get_child(1)
	row.add_child(private_block)
	_company_block = _money("Firma", "CompanyBalanceLabel")
	_company_block.name = "CompanyBlock"
	_company_balance_label = _company_block.get_child(1)
	row.add_child(_company_block)
	# Paket U: Schwarzgeld (U.1), Hitze folgt (Plätze nach Entscheidung 042).
	_black_block = _money("Schwarz", "BlackBalanceLabel")
	_black_block.name = "BlackBlock"
	_black_balance_label = _black_block.get_child(1)
	_black_block.visible = false
	row.add_child(_black_block)
	_heat_block = HBoxContainer.new()
	_heat_block.name = "HeatBlock"
	_heat_block.tooltip_text = "Hitze"
	_heat_block.add_theme_constant_override("separation", 6)
	_heat_icon = _icon(HEAT_ICON, UiStyle.TEXT)
	_heat_block.add_child(_heat_icon)
	_heat_label = _label("HeatValue", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	_heat_block.add_child(_heat_label)
	_heat_block.visible = false
	row.add_child(_heat_block)
	# Platz für das Zahnrad (Menü): Es liegt als eigener Button mit großer Tippfläche über der Leiste (G4.4).
	var menu_space := Control.new()
	menu_space.name = "MenuSpace"
	# Der Kreis sitzt mittig in einer 84-px-Tippfläche am rechten Rand: Platz = halbe Tippfläche + halber Kreis
	# minus Innenabstand der Leiste.
	menu_space.custom_minimum_size.x = UiStyle.TOUCH_SIZE / 2.0 + UiStyle.MENU_ROUND_SIZE / 2.0 - CONTENT_MARGIN_X
	row.add_child(menu_space)


func refresh(game: GameStateScript) -> void:
	_date_label.text = game.time.format_date()
	_clock_label.text = game.time.format_clock()
	_location_label.text = game.locations.get_current_definition().display_name
	_amounts[_balance_label] = game.ledger.get_balance()
	var founded := game.company.is_founded()
	_company_block.visible = founded
	_company_balance_label.visible = founded
	_amounts[_company_balance_label] = game.ledger.get_balance(LedgerSystemScript.COMPANY)
	_black_block.visible = game.ledger.is_account_used(LedgerSystemScript.BLACK)
	_amounts[_black_balance_label] = game.ledger.get_balance(LedgerSystemScript.BLACK)
	_heat_block.visible = game.organisation.is_founded()
	var heat: int = game.organisation.get_value("heat")
	_heat_label.text = str(heat)
	_heat_icon.modulate = heat_color(heat)
	_apply_compact()
	for key in PlayerStatsScript.KEYS:
		var value := game.stats.get_value(key)
		_stat_labels[key].text = str(value)
		_stat_bars[key].value = value
		var fill := (_stat_bars[key] as ProgressBar).get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = bar_color(key, value)


## U.1: Passt die Leiste nicht in `width` (schmale Geräte, alle Konten sichtbar), wird sie stufenweise schmaler:
## erst ohne Datum (steht auch im Kalender), dann Beträge ab 1.000 € ohne Cent, zuletzt ohne die kleinen
## Beschriftungen. Auf breiten Geräten bleibt alles.
func fit_to(width: float) -> void:
	for level in range(0, COMPACT_LEVELS + 1):
		_compact = level
		_apply_compact()
		if get_combined_minimum_size().x <= width + 0.5:
			return


func get_compact_level() -> int:
	return _compact


func _apply_compact() -> void:
	_date_label.visible = _compact < 1
	for label in _amounts:
		var cents: int = _amounts[label]
		(label as Label).text = LedgerSystemScript.format_cents(cents) if _compact < 2 or absi(cents) < 100000 \
				else LedgerSystemScript.format_cents(cents).replace(",%02d €" % (absi(cents) % 100), " €")
	for caption in _money_captions:
		caption.visible = _compact < 3


## Farbe der Hitze (U.2): ruhig hell, ab 30 gelb, ab 60 rot (Grenzen im OrganisationSystem, nur Anzeige).
static func heat_color(value: int) -> Color:
	match OrganisationSystemScript.heat_level(value):
		2:
			return CRITICAL_COLOR
		1:
			return LOW_COLOR
	return UiStyle.TEXT


## Farbe des Balkens: normal, unter 40 gelb, unter 20 rot (Grenzen in PlayerStats).
static func bar_color(key: String, value: int) -> Color:
	match PlayerStatsScript.level_of(value):
		PlayerStatsScript.LEVEL_CRITICAL:
			return CRITICAL_COLOR
		PlayerStatsScript.LEVEL_LOW:
			return LOW_COLOR
	return STAT_COLORS[key]


func _label(node_name: String, font_size: int, color: Color) -> Label:
	var result := UiStyle.label("", font_size, color)
	result.name = node_name
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return result


func _icon(path: String, color: Color) -> TextureRect:
	var result := TextureRect.new()
	result.texture = load(path) if ResourceLoader.exists(path) else null
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.modulate = color
	return result


## Icon, Balken und Zahl, z. B. ⚡ ▬▬▬ 80. Name des Blocks: Stat_<key>, der Zahl: StatValue_<key>.
func _stat(key: String) -> HBoxContainer:
	var block := HBoxContainer.new()
	block.name = "Stat_%s" % key
	block.tooltip_text = PlayerStatsScript.LABELS[key]
	block.add_theme_constant_override("separation", 6)
	var color: Color = STAT_COLORS[key]
	block.add_child(_icon(STAT_ICONS[key], color))
	var bar := ProgressBar.new()
	bar.name = "StatBar_%s" % key
	bar.min_value = PlayerStatsScript.MIN_VALUE
	bar.max_value = PlayerStatsScript.MAX_VALUE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(STAT_BAR_WIDTH, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _bar_box(UiStyle.SURFACE_PRESSED))
	bar.add_theme_stylebox_override("fill", _bar_box(color))
	block.add_child(bar)
	_stat_bars[key] = bar
	var value := _label("StatValue_%s" % key, UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	value.custom_minimum_size.x = 36  # bis „100“, damit die Leiste nicht springt
	block.add_child(value)
	_stat_labels[key] = value
	return block


func _bar_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	return box


## Kleine Beschriftung neben dem Betrag, z. B. „Privat 500,00 €“ (G4.7: nebeneinander, damit die Leiste mit
## 19-px-Beschriftung nicht höher wird).
func _money(caption: String, value_name: String) -> HBoxContainer:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	var caption_label := UiStyle.mini_label(caption, UiStyle.MUTED)
	_money_captions.append(caption_label)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	block.add_child(caption_label)
	var value := _label(value_name, UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	block.add_child(value)
	return block
