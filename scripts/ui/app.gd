extends Control

## Wurzel der App: Theme, Safe Area, Bildschirmwechsel und Speichern.
##
## Querformat (G2): Bildschirme mit set_safe_margins() (z. B. die Spielansicht mit Vollbild-Karte)
## bekommen die ganze Fläche und die Safe-Area-Abstände geliefert; alle anderen liegen in einem
## Rahmen innerhalb der Safe Area (Notch links oder rechts, Home-Balken unten).
## Hält die aktuelle Spielsitzung (GameState) – dafür ist kein Autoload nötig.
##
## Automatisch gespeichert wird: beim Start eines neuen Spiels, nach jeder
## erfolgreichen Aktion im Spiel, beim Wechsel ins Menü und wenn die App in den
## Hintergrund geht oder geschlossen wird (iOS kann eine App jederzeit beenden).

const GameStateScript := preload("res://scripts/core/game_state.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const SaveSystemScript := preload("res://scripts/systems/save_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const MainMenuScript := preload("res://scripts/ui/main_menu.gd")
const GameScreenScript := preload("res://scripts/ui/game_screen.gd")
const SettingsScreenScript := preload("res://scripts/ui/settings_screen.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

## Speicherort; Tests setzen einen eigenen Pfad vor dem Einfügen in den Baum.
var save_path := SaveSystemScript.DEFAULT_PATH
## Seed für neue Spiele; -1 = zufällig (Tests setzen einen festen Wert).
var new_game_seed := -1
## Laufende Sitzung oder null, solange kein Spiel gestartet/geladen wurde.
var game: GameStateScript

var _data: GameDataScript
var _safe_area: MarginContainer
## Für Bildschirme, die selbst mit der Safe Area umgehen (volle Fläche).
var _full_area: Control
var _screen: Control
## Aktuelle Abstände [links, oben, rechts, unten] in Viewport-Pixeln (inkl. Grundabstand).
var _margins: Array[float] = []


func _ready() -> void:
	theme = UiStyle.create_theme()

	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_full_area = Control.new()
	_full_area.name = "FullArea"
	_full_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_full_area)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_area)
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

	_data = GameDataScript.new()
	if not _data.load_all():
		_show_error("Die Spieldaten konnten nicht geladen werden:\n\n" + "\n".join(_data.errors))
		return
	show_main_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()


func show_main_menu(message: String = "") -> void:
	_save_game()
	var menu := MainMenuScript.new()
	menu.continue_available = game != null or SaveSystemScript.has_save(save_path)
	menu.save_info = save_info_text(SaveSystemScript.read_meta(save_path))
	menu.confirm_new_game = not SaveSystemScript.corrupt_files(save_path).is_empty()
	menu.message = message
	menu.new_game_pressed.connect(start_new_game)
	menu.continue_pressed.connect(continue_game)
	menu.settings_pressed.connect(show_settings)
	_set_screen(menu)


func start_new_game() -> void:
	game = GameStateScript.new(_data, new_game_seed)
	_save_game()
	show_game()


## Setzt die Sitzung im Speicher fort oder lädt den Spielstand.
func continue_game() -> void:
	if game == null:
		var result := SaveSystemScript.load_game(_data, save_path)
		if result["game"] == null:
			var reason: String = result["error"]
			if not result.get("corrupt_kept", []).is_empty():
				reason += "\nDie defekte Datei wurde aufbewahrt. Mit „Neues Spiel“ kannst du neu beginnen."
			show_main_menu(reason if not reason.is_empty() else "Es gibt noch keinen Spielstand.")
			return
		game = result["game"]
		var lines := PackedStringArray()
		if result["from_backup"] or result.get("source", "") == "tmp":
			lines.append("Der letzte Spielstand war beschädigt – das Backup wurde geladen, die defekte Datei aufbewahrt."
					if result["from_backup"] else "Das letzte Speichern war unterbrochen – es wurde abgeschlossen.")
		lines.append_array(result.get("notices", PackedStringArray()))
		show_game("\n".join(lines))
		return
	show_game()


func show_game(message: String = "") -> void:
	var screen := GameScreenScript.new()
	screen.setup(game)
	screen.menu_pressed.connect(show_main_menu)
	screen.state_changed.connect(_save_game)
	_set_screen(screen)
	if not message.is_empty():
		screen.show_message(message)


func show_settings(message: String = "") -> void:
	var settings := SettingsScreenScript.new()
	settings.has_save = game != null or SaveSystemScript.has_save(save_path)
	settings.corrupt_count = SaveSystemScript.corrupt_files(save_path).size()
	settings.message = message
	settings.delete_save_pressed.connect(_delete_save)
	settings.back_pressed.connect(show_main_menu)
	_set_screen(settings)


func _delete_save() -> void:
	SaveSystemScript.delete_save(save_path)
	game = null
	show_settings("Der Spielstand wurde gelöscht.")


func _save_game() -> void:
	if game == null:
		return
	var error := SaveSystemScript.save(game, save_path)
	if error.is_empty():
		return
	push_error("App: %s" % error)
	if _screen != null and _screen.has_method("show_error"):
		_screen.call("show_error", error)


func _set_screen(screen: Control) -> void:
	if _screen != null:
		# Sofort aus dem Baum nehmen, erst später löschen – der alte Bildschirm
		# kann gerade noch das Signal senden, das diesen Wechsel ausgelöst hat.
		var holder := _screen.get_parent()
		# Menüs hängen in Scrollbereich + Zentrierung – den ganzen Rahmen entfernen.
		var outer: Node = holder.get_parent() if holder is CenterContainer else _screen
		outer.get_parent().remove_child(outer)
		outer.queue_free()
	_screen = screen
	if screen.has_method("set_safe_margins"):
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_full_area.add_child(screen)
		screen.call("set_safe_margins", _margins)
	else:
		# Menüs: zentrierte Spalte mit begrenzter Breite – in einem Scrollbereich als Sicherheitsnetz,
		# falls sie auf einem Gerät einmal nicht in die Höhe passen (Phase 7).
		screen.custom_minimum_size.x = maxf(screen.custom_minimum_size.x, UiStyle.COLUMN_WIDTH)
		var scroll := ScrollContainer.new()
		scroll.name = "MenuScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(center)
		center.add_child(screen)
		_safe_area.add_child(scroll)


func _show_error(message: String) -> void:
	var text := UiStyle.wrapping_label(message, UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
	text.name = "ErrorLabel"
	_set_screen(text)


## Ränder = Grundabstand + Safe Area (Notch, Dynamic Island, Home-Indikator).
func _update_safe_area() -> void:
	var window_size := Vector2.ZERO
	var safe := Rect2()
	if OS.has_feature("mobile"):
		window_size = Vector2(DisplayServer.window_get_size())
		safe = Rect2(DisplayServer.get_display_safe_area())
	apply_margins(safe_margins(window_size, safe, get_viewport_rect().size, UiStyle.PADDING))


## Wendet Abstände [links, oben, rechts, unten] an: Rahmen der Menüs und Spielansicht.
## (Auch von den Layout-Tests aufgerufen, um Geräte mit Notch nachzustellen.)
func apply_margins(margins: Array[float]) -> void:
	_margins = margins
	_safe_area.add_theme_constant_override("margin_left", roundi(_margins[0]))
	_safe_area.add_theme_constant_override("margin_top", roundi(_margins[1]))
	_safe_area.add_theme_constant_override("margin_right", roundi(_margins[2]))
	_safe_area.add_theme_constant_override("margin_bottom", roundi(_margins[3]))
	if _screen != null and _screen.has_method("set_safe_margins"):
		_screen.call("set_safe_margins", _margins)


## Abstände [links, oben, rechts, unten] in Viewport-Pixeln: Grundabstand + Bereich außerhalb der
## Safe Area. Die Safe Area kommt in Bildschirmpixeln und wird in Viewport-Koordinaten umgerechnet.
## Ohne gültige Fenstergröße (Desktop, Tests) nur der Grundabstand.
static func safe_margins(window_size: Vector2, safe: Rect2, viewport_size: Vector2, padding: float) -> Array[float]:
	var margins: Array[float] = [padding, padding, padding, padding]
	if window_size.x <= 0 or window_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return margins
	var to_viewport := viewport_size / window_size
	margins[0] += maxf(safe.position.x, 0.0) * to_viewport.x
	margins[1] += maxf(safe.position.y, 0.0) * to_viewport.y
	margins[2] += maxf(window_size.x - safe.end.x, 0.0) * to_viewport.x
	margins[3] += maxf(window_size.y - safe.end.y, 0.0) * to_viewport.y
	return margins


## Kurzinfo aus dem Spielstand-Kopf, z. B. "Tag 9 · Di, 08:00 · 400,00 € · gespeichert 12.10., 14:03".
## "" ohne Kopf (ältere Spielstände) – dann zeigt das Menü nur „Fortsetzen“.
static func save_info_text(meta: Dictionary) -> String:
	if meta.is_empty() or not meta.has("day_label"):
		return ""
	var text := "%s, %s" % [meta.get("day_label", ""), meta.get("clock", "")]
	if meta.has("private_balance_cents"):
		text += " · %s" % LedgerSystemScript.format_cents(int(meta["private_balance_cents"]))
	if int(meta.get("saved_at_unix", 0)) > 0:
		# Gerätezeit nur für die Anzeige – mit der Spielzeit hat sie nichts zu tun.
		var local := int(meta["saved_at_unix"]) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var date := Time.get_datetime_dict_from_unix_time(local)
		text += " · gespeichert %02d.%02d., %02d:%02d" % [date["day"], date["month"], date["hour"], date["minute"]]
	return text

