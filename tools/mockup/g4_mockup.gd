extends SceneTree
## Layout-Mockup für Paket G4 (Ticket G4.1) – nur ein Bild, ändert das Spiel nicht.
## Startet das echte Spiel (Karte als Hintergrund), blendet die bisherige Bedienung aus und legt den
## Entwurf darüber: HUD-Leiste oben, runde Buttons rechts (Leben/Geschäft), Ortsfenster mit Kachel-Raster.
## iPhone 15/16 Pro Max quer (1560 × 720 Basis-Pixel), Dynamic Island links.
##   timeout 90 ~/Downloads/Godot.app/Contents/MacOS/Godot --path . --resolution 1560x720 --quit-after 400 \
##     -s tools/mockup/g4_mockup.gd -- "$PWD/tools/mockup" "<Ordner mit Kenney-Icons PNG/White/2x>"
## Alle Werte sind Beispielwerte.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const W := 1560.0
const H := 720.0
const SAFE_L := 123.0   # Seite der Insel (gemessen in 7.2)
const SAFE_R := 48.0    # Seite ohne Insel – nur abgerundete Ecken (Annahme, in G4.2 prüfen)
const SAFE_B := 59.0    # Home-Balken
const BAR_Y := 10.0
const BAR_H := 54.0
const CELL := 84.0      # Tippfläche
const CIRCLE := 64.0    # sichtbarer Kreis
const RED := Color("#FF3B5C")

var _frames := 0
var _app: Node
var _layer: CanvasLayer
var _icons := ""
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_icons = args[1]
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames == 2:
		_app = load("res://scenes/app/app.tscn").instantiate()
		_app.save_path = "user://g4_mockup_save.json"
		root.add_child(_app)
	elif _frames == 6 or _frames == 8:  # zweiter Tipp bestätigt, falls ein Spielstand existiert
		var button := _app.find_child("NewGameButton", true, false)
		if button:
			button.pressed.emit()
	elif _frames == 12:
		for n in ["HudLeft", "HudRight", "LeftBar", "RightBar", "Toast", "FeedbackLabel"]:
			var node := _app.find_child(n, true, false)
			if node:
				node.visible = false
		_build(false)
	elif _frames == 30:
		_save("g4_1_karte.png")
		_layer.queue_free()
	elif _frames == 32:
		_build(true)
	elif _frames == 50:
		_save("g4_1_ortsfenster.png")
		quit()


func _save(file: String) -> void:
	var path := _out.path_join(file)
	print("%s: %s" % [path, error_string(root.get_texture().get_image().save_png(path))])


# --- Aufbau -----------------------------------------------------------------------------

func _build(with_window: bool) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	root.add_child(_layer)
	var stage := Control.new()
	stage.size = Vector2(W, H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.theme = UiStyle.create_theme()
	_layer.add_child(stage)
	if with_window:
		stage.add_child(_rect(Vector2.ZERO, Vector2(W, H), UiStyle.DIM))
	_hud(stage)
	_buttons(stage, not with_window)
	_here(stage)
	if with_window:
		_window(stage)
	var note := _label("MOCKUP G4.1 · Beispielwerte · Insel links, Bedienung rechts", 15, Color(1, 1, 1, 0.55))
	note.position = Vector2(SAFE_L + 96, H - SAFE_B + 22)
	stage.add_child(note)
	stage.add_child(_device_frame())


func _hud(stage: Control) -> void:
	var bar := _panel(Vector2(SAFE_L, BAR_Y), Vector2(W - SAFE_L - SAFE_R, BAR_H), UiStyle.HUD_SURFACE, 16)
	stage.add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(18, 0)
	row.size = Vector2(bar.size.x - 36, BAR_H)
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	row.add_child(_label("Tag 3 · Mi", 22, UiStyle.MUTED))
	row.add_child(_label("14:35", 28, UiStyle.TEXT))
	row.add_child(_icon_value("target.png", "Studio", 22, UiStyle.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_stat_bar("power.png", 0.72, Color("#7FD38A")))
	row.add_child(_stat_bar("star.png", 0.6, Color("#F2C14E")))
	row.add_child(_money("Privat", "482,00 €", UiStyle.TEXT))
	row.add_child(_money("Firma", "1.250,00 €", UiStyle.TEXT))
	row.add_child(_money("Schwarz", "3.200,00 €", Color("#C9A7FF")))
	row.add_child(_money("Hitze", "34", Color("#FF8A5C")))
	var gear := _circle_button("gear.png", 44, UiStyle.SURFACE)
	row.add_child(gear)


func _buttons(stage: Control, show_touch: bool) -> void:
	var right_x := W - SAFE_R - CELL
	var groups := [
		["LEBEN", right_x - CELL - 10, [["Kalender", "menuGrid.png", 1], ["Fristen", "exclamation.png", 2], ["Kanal", "video.png", 0]]],
		["GESCHÄFT", right_x, [["Organisation", "multiplayer.png", 0], ["Aufträge", "flag.png", 1], ["Firma", "shoppingBasket.png", 0], ["Buchungen", "menuList.png", 0]]],
	]
	for group in groups:
		var x: float = group[1]
		var count: int = group[2].size()
		stage.add_child(_panel(Vector2(x - 4, BAR_Y + BAR_H + 6), Vector2(CELL + 8, 30 + count * (CELL + 6)),
				UiStyle.HUD_SURFACE, 16))
		var header := _label(group[0], 14, UiStyle.MUTED)
		header.size = Vector2(CELL, 18)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(x, BAR_Y + BAR_H + 10)
		stage.add_child(header)
		var y := BAR_Y + BAR_H + 32
		for entry in group[2]:
			stage.add_child(_side_button(Vector2(x, y), entry[0], entry[1], entry[2], show_touch))
			y += CELL + 6


func _side_button(pos: Vector2, text: String, icon: String, badge: int, show_touch: bool) -> Control:
	var cell := Control.new()
	cell.position = pos
	cell.size = Vector2(CELL, CELL)
	if show_touch:  # Tippfläche sichtbar machen (im Spiel unsichtbar)
		var touch := _panel(Vector2.ZERO, cell.size, Color(1, 1, 1, 0.0), 14)
		var box := touch.get_theme_stylebox("panel") as StyleBoxFlat
		box.border_color = Color(1, 1, 1, 0.22)
		box.set_border_width_all(1)
		cell.add_child(touch)
	var circle := _circle_button(icon, CIRCLE, UiStyle.HUD_SURFACE)
	circle.position = Vector2((CELL - CIRCLE) / 2, 0)
	cell.add_child(circle)
	var caption := _label(text, 14, UiStyle.TEXT)
	caption.size = Vector2(CELL + 16, 18)
	caption.position = Vector2(-8, CIRCLE + 1)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	if badge > 0:
		var dot := _panel(Vector2((CELL + CIRCLE) / 2 - 18, -4), Vector2(24, 24), RED, 12)
		var number := _label(str(badge), 15, Color.WHITE)
		number.size = dot.size
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_child(number)
		cell.add_child(dot)
	return cell


func _here(stage: Control) -> void:
	var here := _circle_button("target.png", 56, UiStyle.HUD_SURFACE)
	here.position = Vector2(SAFE_L + 10, H - SAFE_B - 66)
	stage.add_child(here)


func _window(stage: Control) -> void:
	var left := SAFE_L + 8
	var right := W - SAFE_R - 2 * CELL - 10 - 16
	var top := BAR_Y + BAR_H + 10
	var bottom := H - SAFE_B + 6
	var win := _panel(Vector2(left, top), Vector2(right - left, bottom - top), UiStyle.BACKGROUND, 20)
	var box := win.get_theme_stylebox("panel") as StyleBoxFlat
	box.border_color = UiStyle.SURFACE_PRESSED
	box.set_border_width_all(2)
	stage.add_child(win)
	var pad := 18.0
	# Kopf
	var title := _label("Studio", 34, UiStyle.TEXT)
	title.position = Vector2(pad, 10)
	win.add_child(title)
	var sub := _label("geöffnet 08:00–22:00 · du bist hier", 18, UiStyle.MUTED)
	sub.position = Vector2(pad + 120, 24)
	win.add_child(sub)
	var close := _circle_button("cross.png", 48, UiStyle.SURFACE)
	close.position = Vector2(win.size.x - pad - 48, 8)
	win.add_child(close)
	# Reiter
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(pad, 64)
	tabs.add_theme_constant_override("separation", 10)
	win.add_child(tabs)
	for t in [["Alltag", false, false], ["Content", true, false], ["Geschäft", false, false], ["Unterwelt", false, true]]:
		tabs.add_child(_tab(t[0], t[1], t[2]))
	# Kacheln
	var tiles := [
		["Livestream", "2 h · Ende 16:35", [["power.png", "−20", false], ["coin.png", "+25 €", true], ["multiplayer.png", "+17", true]], "Start", ""],
		["Langes Video", "4 h · Ende 18:35", [["power.png", "−35", false], ["coin.png", "+40 €", true], ["multiplayer.png", "+30", true]], "Start", "⚠ Termin 17:00"],
		["Q&A mit der Community", "1 h · Ende 15:35", [["power.png", "−10", false], ["star.png", "+4", true]], "Start", ""],
		["Schnitt & Planung", "1 h · Ende 15:35", [["power.png", "−5", false], ["star.png", "+2", true]], "Start", ""],
		["Kamera · Stufe 2", "sofort", [["coin.png", "−250 €", false], ["video.png", "+5 % Qualität", true]], "Kaufen", ""],
		["Mikrofon · Stufe 1", "sofort", [["coin.png", "−90 €", false], ["video.png", "+4 % Qualität", true]], "Kaufen", ""],
		["Licht · Stufe 2", "sofort", [["coin.png", "−600 €", false], ["video.png", "+6 % Qualität", true]], "", "Zu wenig Geld (600,00 €)"],
	]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2(pad, 126)
	var tile_w := (win.size.x - 2 * pad - 3 * 12) / 4
	var tile_h := (win.size.y - 126 - pad - 12) / 2
	win.add_child(grid)
	for t in tiles:
		grid.add_child(_tile(Vector2(tile_w, tile_h), t))


func _tile(size: Vector2, t: Array) -> Control:
	var tile := _panel(Vector2.ZERO, size, UiStyle.SURFACE, 14)
	tile.custom_minimum_size = size
	var locked: bool = String(t[3]).is_empty()
	var col := VBoxContainer.new()
	col.position = Vector2(14, 10)
	col.size = Vector2(size.x - 28, size.y - 20)
	col.add_theme_constant_override("separation", 6)
	tile.add_child(col)
	col.add_child(_label(t[0], 22, UiStyle.MUTED if locked else UiStyle.TEXT))
	col.add_child(_label(t[1], 17, UiStyle.MUTED))
	var effects := HFlowContainer.new()
	effects.add_theme_constant_override("h_separation", 12)
	for e in t[2]:
		effects.add_child(_icon_value(e[0], e[1], 17, UiStyle.POSITIVE if e[2] else UiStyle.NEGATIVE))
	col.add_child(effects)
	if not String(t[4]).is_empty() and not locked:
		col.add_child(_label(t[4], 15, Color("#F2C14E")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var button := Button.new()
	button.text = t[3] if not locked else t[4]
	button.custom_minimum_size.y = 74  # ≈ 44 pt
	button.add_theme_font_size_override("font_size", 20 if not locked else 15)
	button.disabled = locked
	button.focus_mode = Control.FOCUS_NONE
	col.add_child(button)
	return tile


func _tab(text: String, active: bool, locked: bool) -> Control:
	var pill := _panel(Vector2.ZERO, Vector2(150, 44), UiStyle.ACCENT if active else UiStyle.SURFACE, 22)
	pill.custom_minimum_size = Vector2(150, 44)
	var row := HBoxContainer.new()
	row.size = pill.size
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	if locked:
		row.add_child(_icon("locked.png", 18, UiStyle.MUTED))
	row.add_child(_label(text, 19, UiStyle.MUTED if locked else UiStyle.TEXT))
	return pill


# --- Bausteine --------------------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _panel(pos: Vector2, size: Vector2, color: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _icon(file: String, size: int, color := Color.WHITE) -> TextureRect:
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(_icons.path_join(file)))
	if err != OK:
		push_error("Icon fehlt: %s" % file)
	var r := TextureRect.new()
	r.texture = ImageTexture.create_from_image(img)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.modulate = color
	return r


func _icon_value(file: String, text: String, size: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.add_child(_icon(file, size, color))
	row.add_child(_label(text, size, color))
	return row


func _stat_bar(file: String, value: float, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon(file, 20, color))
	var track := _panel(Vector2.ZERO, Vector2(64, 10), UiStyle.SURFACE_PRESSED, 5)
	track.custom_minimum_size = Vector2(64, 10)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_child(_panel(Vector2.ZERO, Vector2(64 * value, 10), color, 5))
	row.add_child(track)
	return row


func _money(caption: String, value: String, color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_label(caption, 13, UiStyle.MUTED))
	col.add_child(_label(value, 21, color))
	return col


func _circle_button(file: String, diameter: float, color: Color) -> Control:
	var circle := _panel(Vector2.ZERO, Vector2(diameter, diameter), color, int(diameter / 2))
	circle.custom_minimum_size = circle.size
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := circle.get_theme_stylebox("panel") as StyleBoxFlat
	box.border_color = Color(1, 1, 1, 0.14)
	box.set_border_width_all(2)
	var icon := _icon(file, int(diameter * 0.5))
	icon.position = Vector2(diameter * 0.25, diameter * 0.25)
	circle.add_child(icon)
	return circle


## Gerätekontur: abgerundete Ecken (≈ 55 pt) und Dynamic Island links.
func _device_frame() -> Control:
	var frame := Control.new()
	frame.size = Vector2(W, H)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var r := 92.0
		for corner in [Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]:
			var center := Vector2(r if corner.x == 0 else W - r, r if corner.y == 0 else H - r)
			var points := PackedVector2Array([corner])
			var start := atan2(corner.y - center.y, corner.x - center.x)
			for i in 17:
				var a := start - PI / 4 + PI / 2 * i / 16.0
				points.append(center + Vector2(cos(a), sin(a)) * r)
			frame.draw_colored_polygon(points, Color.BLACK)
		var island := Rect2(Vector2(18, H / 2 - 105), Vector2(62, 210))
		frame.draw_rect(Rect2(island.position + Vector2(0, 31), Vector2(62, 148)), Color.BLACK)
		frame.draw_circle(island.position + Vector2(31, 31), 31, Color.BLACK)
		frame.draw_circle(island.position + Vector2(31, 179), 31, Color.BLACK)
		frame.draw_rect(Rect2(W / 2 - 110, H - 16, 220, 6), Color(1, 1, 1, 0.6)))
	return frame
