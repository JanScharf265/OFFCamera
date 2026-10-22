extends Control

## Konflikt-Popup (G5.4): ersetzt das frühere „nochmal tippen“. Würde eine Aktion (Aktivität, Content, Fahrt,
## Gründung, Filiale, Termin) einen Termin verpassen lassen, fragt es nach – mit der Aktion und ihrem Ende, allen
## betroffenen Terminen (Name, Uhrzeit, Ort) und was das Verpassen kostet. „Trotzdem starten“ führt die Aktion genau
## einmal aus, „Abbrechen“ ändert nichts. Deckt alles darunter ab (auch Fenster). Zeigt nur an; die Konflikte
## kommen aus AppointmentSystem.get_conflicts().

signal closed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const MAX_WIDTH := 760.0

var _panel: PanelContainer
var _on_confirm: Callable
var _used := false


## title, action_line (z. B. „Livestream · 2 h · Ende 14:40“), conflicts: Array von [Kopfzeile, Kosten].
func _init(title: String, action_line: String, conflicts: Array, on_confirm: Callable) -> void:
	name = "ConflictPopup"
	_on_confirm = on_confirm
	mouse_filter = Control.MOUSE_FILTER_STOP  # nichts darunter ist tippbar, solange das Popup offen ist
	var dim := ColorRect.new()
	dim.name = "PopupDim"
	dim.color = UiStyle.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "PopupPanel"
	_panel.add_theme_stylebox_override("panel", UiStyle.window_box())
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var heading := UiStyle.wrapping_label(title, UiStyle.LARGE_FONT_SIZE)
	heading.name = "ConflictTitle"
	box.add_child(heading)
	var action := UiStyle.wrapping_label(action_line, UiStyle.FONT_SIZE)
	action.name = "ConflictAction"
	box.add_child(action)
	box.add_child(UiStyle.label("Damit verpasst du:", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	for i in conflicts.size():
		var card := UiStyle.card()
		card.name = "ConflictEntry_%d" % i
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 4)
		card.add_child(lines)
		lines.add_child(UiStyle.wrapping_label(conflicts[i][0], UiStyle.SMALL_FONT_SIZE))
		lines.add_child(UiStyle.wrapping_label(conflicts[i][1], UiStyle.MIN_READ_FONT_SIZE, UiStyle.NEGATIVE))
		box.add_child(card)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var cancel := UiStyle.button("Abbrechen")
	cancel.name = "ConflictCancelButton"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover"]:
		cancel.add_theme_stylebox_override(state, UiStyle.flat_box(UiStyle.SURFACE, 16))
	cancel.pressed.connect(_close)
	buttons.add_child(cancel)
	var confirm := UiStyle.button("Trotzdem starten")
	confirm.name = "ConflictConfirmButton"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm)
	buttons.add_child(confirm)


## Von der Spielansicht: Fläche (ganzer Bildschirm) und Safe-Area-Rechteck für das Panel.
func place(full_size: Vector2, safe: Rect2) -> void:
	position = Vector2.ZERO
	size = full_size
	var width := minf(MAX_WIDTH, safe.size.x)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.size = Vector2(width, 0)
	# Umbrechende Labels kennen ihre Höhe erst bei bekannter Breite – sofort ordnen und umbrechen lassen
	# (wie die Layout-Tests und der Ladebildschirm), sonst ist das Panel anfangs tausende Pixel hoch.
	for i in 2:
		_sort(_panel)
		for node in _panel.find_children("*", "Label", true, false):
			var label := node as Label
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				label.get_line_count()
				label.update_minimum_size()
	_panel.reset_size()
	_panel.size.x = width
	_panel.position = Vector2(safe.position.x + (safe.size.x - width) / 2.0,
			maxf(safe.position.y, safe.position.y + (safe.size.y - _panel.size.y) / 2.0))


func _confirm() -> void:
	if _used:
		return
	_used = true
	var action := _on_confirm
	_close()
	action.call()


func _close() -> void:
	_used = true
	closed.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


static func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort(child)
