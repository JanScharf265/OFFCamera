extends Control

## Tutorial-Anzeige (T.3): dunkelt den Bildschirm ab, spart das Ziel-Element (ui_target, ein Knotenname unter der
## Spielansicht) aus und hebt es mit pulsierendem Rahmen hervor; ein Pfeil zeigt von der Sprechblase darauf. Die
## Sprechblase (Titel, Text, „Verstanden“) liegt in der Safe Area und verdeckt das Ziel nicht. Ohne ui_target – oder
## wenn das Ziel nicht (sichtbar) da ist – steht sie mittig ohne Pfeil; ein fehlendes Ziel kommt als Warnung ins Log.
## Darunter ist nichts tippbar. Zeigt nur an: „Verstanden“ meldet `confirmed`, die Spielansicht ruft mark_seen().

signal confirmed(tutorial_id: String)

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const BUBBLE_MAX_WIDTH := 560.0
## Abstand zwischen Ziel und Sprechblase (Platz für den Pfeil)
const GAP := 56.0
## Luft um das ausgesparte Ziel
const HOLE_PADDING := 8.0
const FRAME_WIDTH := 4.0
const PULSE_SPEED := 4.0

var tutorial_id := ""
var target_name := ""

var _search_root: Node
var _target: Control
var _bubble: PanelContainer
var _text: Label
var _title: Label
var _hole := Rect2()
var _has_hole := false
var _safe := Rect2()
var _time := 0.0
var _used := false
var _warned := false


## search_root = Spielansicht (dort wird ui_target gesucht).
func _init(definition, search_root: Node) -> void:
	name = "TutorialOverlay"
	tutorial_id = definition.id
	target_name = definition.ui_target
	_search_root = search_root
	mouse_filter = Control.MOUSE_FILTER_STOP  # nichts darunter tippbar

	_bubble = PanelContainer.new()
	_bubble.name = "TutorialBubble"
	var box := UiStyle.window_box()
	box.border_color = UiStyle.ACCENT
	box.set_border_width_all(3)
	_bubble.add_theme_stylebox_override("panel", box)
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_bubble.add_child(column)
	_title = UiStyle.wrapping_label(definition.title, UiStyle.FONT_SIZE, UiStyle.TEXT)
	_title.name = "TutorialTitle"
	column.add_child(_title)
	_text = UiStyle.wrapping_label(definition.text, UiStyle.SMALL_FONT_SIZE, UiStyle.TEXT)
	_text.name = "TutorialText"
	column.add_child(_text)
	var ok := UiStyle.button("Verstanden")
	ok.name = "TutorialConfirmButton"
	ok.custom_minimum_size = Vector2(UiStyle.TOUCH_SIZE * 2.5, UiStyle.TOUCH_SIZE)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_confirm)
	column.add_child(ok)


## true, wenn das Ziel gefunden und sichtbar ist (sonst steht die Sprechblase mittig).
func has_target() -> bool:
	return _has_hole


## Rechteck des hervorgehobenen Ziels (mit Luft) in Overlay-Koordinaten; leer ohne Ziel.
func get_hole() -> Rect2:
	return _hole if _has_hole else Rect2()


## Legt Overlay, Aussparung, Sprechblase und Pfeil neu fest. full_size = Größe der Spielansicht, safe = Safe Area.
func place(full_size: Vector2, safe: Rect2) -> void:
	position = Vector2.ZERO
	size = full_size
	_safe = safe
	_find_target()
	var width := minf(BUBBLE_MAX_WIDTH, safe.size.x)
	_bubble.custom_minimum_size = Vector2(width, 0)
	_bubble.size = Vector2(width, 0)
	_settle(_bubble, width)
	var bubble_size := Vector2(width, _bubble.get_combined_minimum_size().y)
	_bubble.size = bubble_size
	_bubble.position = _bubble_position(bubble_size)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _search_root != null and is_inside_tree():
		var before := _hole
		_find_target()
		if before != _hole:
			place(size, _safe)
	queue_redraw()


func _find_target() -> void:
	_has_hole = false
	_target = null
	if target_name.is_empty():
		return
	var node := find_target(_search_root, target_name)
	if node == null:
		if not _warned:
			_warned = true
			push_warning("Tutorial '%s': Ziel '%s' nicht gefunden – Sprechblase mittig." % [tutorial_id, target_name])
		return
	_target = node
	var rect := node.get_global_rect()
	rect.position -= get_global_rect().position
	_hole = rect.grow(HOLE_PADDING).intersection(Rect2(Vector2.ZERO, size))
	_has_hole = _hole.has_area()


## Erstes sichtbares Control unter `root`, dessen Name zu `pattern` passt („*“ als Platzhalter, T.5); null = keins.
static func find_target(root: Node, pattern: String) -> Control:
	if pattern.is_empty() or root == null:
		return null
	if not "*" in pattern:
		var exact := root.find_child(pattern, true, false) as Control
		return exact if exact != null and exact.is_visible_in_tree() else null
	for node in root.find_children(pattern, "Control", true, false):
		if (node as Control).is_visible_in_tree():
			return node
	return null


## Unter, über, rechts oder links vom Ziel – die erste Lage, die ganz in die Safe Area passt; sonst die mit dem
## meisten Platz (in die Safe Area geschoben). Ohne Ziel mittig.
func _bubble_position(bubble_size: Vector2) -> Vector2:
	if not _has_hole:
		return _safe.get_center() - bubble_size / 2.0
	var center := _hole.get_center()
	var candidates := [
		Vector2(center.x - bubble_size.x / 2.0, _hole.end.y + GAP),
		Vector2(center.x - bubble_size.x / 2.0, _hole.position.y - GAP - bubble_size.y),
		Vector2(_hole.end.x + GAP, center.y - bubble_size.y / 2.0),
		Vector2(_hole.position.x - GAP - bubble_size.x, center.y - bubble_size.y / 2.0),
	]
	var best := Vector2.ZERO
	var best_overlap := INF
	for i in candidates.size():
		var candidate: Vector2 = candidates[i]
		# Entlang der Seite in die Safe Area schieben (nur quer zur Richtung, damit der Abstand zum Ziel bleibt).
		if i < 2:
			candidate.x = clampf(candidate.x, _safe.position.x, _safe.end.x - bubble_size.x)
		else:
			candidate.y = clampf(candidate.y, _safe.position.y, _safe.end.y - bubble_size.y)
		var rect := Rect2(candidate, bubble_size)
		if _safe.encloses(rect) and not rect.intersects(_hole):
			return candidate
		var clamped := Vector2(clampf(candidate.x, _safe.position.x, _safe.end.x - bubble_size.x),
				clampf(candidate.y, _safe.position.y, _safe.end.y - bubble_size.y))
		var overlap := Rect2(clamped, bubble_size).intersection(_hole).get_area()
		if overlap < best_overlap:
			best_overlap = overlap
			best = clamped
	return best


func _draw() -> void:
	var dim := UiStyle.DIM
	var full := Rect2(Vector2.ZERO, size)
	if not _has_hole:
		draw_rect(full, dim)
		return
	# Abdunkeln um die Aussparung herum (vier Streifen).
	draw_rect(Rect2(0, 0, size.x, _hole.position.y), dim)
	draw_rect(Rect2(0, _hole.end.y, size.x, size.y - _hole.end.y), dim)
	draw_rect(Rect2(0, _hole.position.y, _hole.position.x, _hole.size.y), dim)
	draw_rect(Rect2(_hole.end.x, _hole.position.y, size.x - _hole.end.x, _hole.size.y), dim)
	# Pulsierender Rahmen.
	var pulse := 0.6 + 0.4 * sin(_time * PULSE_SPEED)
	var frame_color := Color(UiStyle.ACCENT, pulse)
	draw_rect(_hole, frame_color, false, FRAME_WIDTH)
	# Pfeil von der Sprechblase zum Ziel.
	var bubble := Rect2(_bubble.position, _bubble.size)
	var from := _closest_point(bubble, _hole.get_center())
	var to := _closest_point(_hole, from)
	if from.distance_to(to) > 8.0:
		var direction := (to - from).normalized()
		var tip := to - direction * 4.0
		draw_line(from, tip - direction * 12.0, UiStyle.ACCENT, 5.0, true)
		var side := Vector2(-direction.y, direction.x) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 22.0 + side, tip - direction * 22.0 - side]),
				UiStyle.ACCENT)


static func _closest_point(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))


func _confirm() -> void:
	if _used:
		return
	_used = true
	confirmed.emit(tutorial_id)


## Container sofort sortieren und umbrechende Labels auf ihre Breite setzen (sonst riesige Mindesthöhen).
static func _settle(root: Control, width: float) -> void:
	root.size = Vector2(width, root.size.y)
	for i in 2:
		_sort(root)
		for node in root.find_children("*", "Label", true, false):
			var label := node as Label
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				label.get_line_count()
				label.update_minimum_size()


static func _sort(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_sort(child)
