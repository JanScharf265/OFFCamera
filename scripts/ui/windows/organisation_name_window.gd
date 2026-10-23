extends VBoxContainer

## Namenseingabe nach „Zuhören“ am Hafen (U.3): Das Fenster lässt sich nicht schließen – erst einen Namen geben.
## Gegründet wird über die Spielansicht (OrganisationSystem.found); die Prüfung des Namens macht das System.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

var _screen
var _game
var _input: LineEdit
var _reason: Label


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "OrganisationNameContent"
	add_theme_constant_override("separation", 14)
	add_child(UiStyle.wrapping_label("El Capitán nickt. „Dann brauchst du einen Namen. Einen, den man sich merkt – "
			+ "und den keiner mit deinem Kanal verbindet.“", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	add_child(UiStyle.label("Wie soll deine Organisation heißen?", UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT))
	_input = LineEdit.new()
	_input.name = "OrganisationNameInput"
	_input.placeholder_text = "z. B. Los Lobos"
	_input.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	_input.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	_input.max_length = 40
	_input.text_submitted.connect(func(_text: String) -> void: _submit())
	add_child(_input)
	_reason = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	_reason.name = "OrganisationNameReason"
	_reason.visible = false
	add_child(_reason)
	var found := UiStyle.button("Gründen")
	found.name = "OrganisationFoundButton"
	found.pressed.connect(_submit)
	add_child(found)


func get_title() -> String:
	return "Deine Organisation"


## Für Tests und die Spielansicht: Text im Eingabefeld setzen.
func set_name_text(text: String) -> void:
	_input.text = text


func _submit() -> void:
	var reason: String = _screen.on_organisation_name_submitted(_input.text)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
