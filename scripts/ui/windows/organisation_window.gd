extends VBoxContainer

## Fenster „Organisation“ (U.3): Name, Respekt in der Szene, Hitze und Stabilität – je als Balken mit Zahl und einem
## Satz, was der Wert bedeutet. Werte aus dem OrganisationSystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const OrganisationSystemScript := preload("res://scripts/systems/organisation_system.gd")
const HudBarScript := preload("res://scripts/ui/hud_bar.gd")

const EXPLANATIONS := {
	"respect": "Wie ernst dich die Szene nimmt. Wer Respekt hat, bekommt bessere Deals.",
	"heat": "Wie genau die Polizei hinschaut. Ruhige Tage kühlen ab.",
	"stability": "Wie fest deine Leute zusammenhalten. Wackelt sie, wird es teuer.",
}

var _game
var _rows := {}


func setup(_screen, game) -> void:
	_game = game


func _ready() -> void:
	name = "OrganisationContent"
	add_theme_constant_override("separation", 12)
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
