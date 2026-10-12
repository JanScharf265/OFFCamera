extends SceneTree
## App-Symbol neu erzeugen (eigenes Mini-Projekt, damit die Einstellungen des Spiels nicht stören):
##   timeout 60 ~/Downloads/Godot.app/Contents/MacOS/Godot --path tools/icon --resolution 1024x1024 \
##     --quit-after 60 -s make_icon.gd -- "$PWD/assets/icon/app_icon_1024.png"
## Zeichnet das App-Symbol (1024 × 1024, ohne Transparenz) und speichert es als PNG.
var frames := 0
func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.84, 0.27, 0.35)
	bg.size = Vector2(1024, 1024)
	root.add_child(bg)
	# Kamerasymbol: Gehäuse, Sucher, Objektiv – durchgestrichen („off camera“)
	var cam := Control.new()
	cam.draw.connect(func() -> void:
		var white := Color(1, 1, 1)
		var red := Color(0.84, 0.27, 0.35)
		cam.draw_rect(Rect2(262, 250, 500, 320), white)
		cam.draw_rect(Rect2(420, 200, 180, 70), white)
		cam.draw_circle(Vector2(512, 410), 115, red)
		cam.draw_circle(Vector2(512, 410), 75, white)
		cam.draw_line(Vector2(250, 620), Vector2(780, 190), red, 46)
		cam.draw_line(Vector2(250, 620), Vector2(780, 190), white, 22))
	cam.size = Vector2(1024, 1024)
	root.add_child(cam)
	var label := Label.new()
	label.text = "OFF CAMERA"
	label.add_theme_font_size_override("font_size", 132)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 690)
	label.size = Vector2(1024, 200)
	root.add_child(label)
	process_frame.connect(_tick)
func _tick() -> void:
	frames += 1
	if frames == 5:
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)  # iOS-Symbole ohne Transparenz
		image.save_png(OS.get_cmdline_user_args()[0])
		quit()
