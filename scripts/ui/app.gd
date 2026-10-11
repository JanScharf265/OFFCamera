extends Control

## Wurzel der App: Theme, Safe Area und Wechsel zwischen den Bildschirmen.
## Hält die aktuelle Spielsitzung (GameState) – dafür ist kein Autoload nötig.

const GameStateScript := preload("res://scripts/core/game_state.gd")
const ActivityCatalogScript := preload("res://scripts/systems/activity_catalog.gd")
const EventCatalogScript := preload("res://scripts/systems/event_catalog.gd")
const MainMenuScript := preload("res://scripts/ui/main_menu.gd")
const GameScreenScript := preload("res://scripts/ui/game_screen.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

## Laufende Sitzung oder null, solange kein Spiel gestartet wurde.
var game: GameStateScript

var _catalog: ActivityCatalogScript
var _event_catalog: EventCatalogScript
var _safe_area: MarginContainer
var _screen: Control


func _ready() -> void:
	theme = UiStyle.create_theme()

	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_safe_area = MarginContainer.new()
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_area)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

	_catalog = ActivityCatalogScript.new()
	_event_catalog = EventCatalogScript.new()
	var errors := PackedStringArray()
	if not _catalog.load_file():
		errors.append_array(_catalog.errors)
	if not _event_catalog.load_file():
		errors.append_array(_event_catalog.errors)
	if not errors.is_empty():
		_show_error("Die Spieldaten konnten nicht geladen werden:\n\n" + "\n".join(errors))
		return
	show_main_menu()


func show_main_menu() -> void:
	var menu := MainMenuScript.new()
	menu.continue_available = game != null
	menu.new_game_pressed.connect(start_new_game)
	menu.continue_pressed.connect(show_game)
	_set_screen(menu)


func start_new_game() -> void:
	game = GameStateScript.new(_catalog, _event_catalog)
	show_game()


func show_game() -> void:
	var screen := GameScreenScript.new()
	screen.setup(game)
	screen.menu_pressed.connect(show_main_menu)
	_set_screen(screen)


func _set_screen(screen: Control) -> void:
	if _screen != null:
		# Sofort aus dem Baum nehmen, erst später löschen – der alte Bildschirm
		# kann gerade noch das Signal senden, das diesen Wechsel ausgelöst hat.
		_safe_area.remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	_safe_area.add_child(screen)


func _show_error(message: String) -> void:
	var text := UiStyle.wrapping_label(message, UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	text.name = "ErrorLabel"
	_set_screen(text)


## Ränder = Grundabstand + Safe Area (Notch, Dynamic Island, Home-Indikator).
## Die Safe Area kommt in Bildschirmpixeln und wird in Viewport-Koordinaten umgerechnet.
func _update_safe_area() -> void:
	var left := float(UiStyle.PADDING)
	var top := float(UiStyle.PADDING)
	var right := float(UiStyle.PADDING)
	var bottom := float(UiStyle.PADDING)

	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0 and window_size.y > 0:
			var to_viewport := get_viewport_rect().size / window_size
			left += maxf(safe.position.x, 0.0) * to_viewport.x
			top += maxf(safe.position.y, 0.0) * to_viewport.y
			right += maxf(window_size.x - safe.end.x, 0.0) * to_viewport.x
			bottom += maxf(window_size.y - safe.end.y, 0.0) * to_viewport.y

	_safe_area.add_theme_constant_override("margin_left", roundi(left))
	_safe_area.add_theme_constant_override("margin_top", roundi(top))
	_safe_area.add_theme_constant_override("margin_right", roundi(right))
	_safe_area.add_theme_constant_override("margin_bottom", roundi(bottom))
