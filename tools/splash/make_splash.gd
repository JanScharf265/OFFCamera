extends SceneTree
## Startbild (Boot-Splash, auch iOS-Launch-Screen) neu erzeugen (Ticket G3.3) – braucht ein Fenster:
##   timeout 90 ~/Downloads/Godot.app/Contents/MacOS/Godot --path . --resolution 1280x720 --quit-after 120 \
##     -s tools/splash/make_splash.gd -- "$PWD/assets/splash/splash.png"
## Rendert denselben Schriftzug wie das Hauptmenü (scripts/ui/logo.gd) auf der Hintergrundfarbe der UI,
## in doppelter Basisauflösung (2560 × 1440). Ränder füllt Godot/iOS mit application/boot_splash/bg_color.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LogoScript := preload("res://scripts/ui/logo.gd")
const SIZE := Vector2i(2560, 1440)

var _frames := 0
var _viewport: SubViewport


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.size = SIZE
	_viewport.add_child(background)
	var center := CenterContainer.new()
	center.size = SIZE
	_viewport.add_child(center)
	var logo := LogoScript.new()
	logo.font_size = UiStyle.MENU_LOGO_FONT_SIZE * 2
	center.add_child(logo)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames == 10:
		var image := _viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		var path: String = OS.get_cmdline_user_args()[0]
		print("%s: %s" % [path, error_string(image.save_png(path))])
		quit()
