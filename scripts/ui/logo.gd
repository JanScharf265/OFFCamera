extends HBoxContainer

## Schriftzug „OFF CAMERA“ (Ticket G3.3): „OFF“ in Neon-Magenta mit weichem Leuchten, „CAMERA“ hell.
## Schrift Bebas Neue (OFL, `assets/fonts/bebas_neue/`). Wird im Hauptmenü genutzt und für das Startbild
## gerendert (`tools/splash/make_splash.gd`), damit beide gleich aussehen.

const FONT := preload("res://assets/fonts/bebas_neue/BebasNeue-Regular.ttf")
const OFF_COLOR := Color("#FF2D6F")
const CAMERA_COLOR := Color("#D9D3E6")
const GLOW_COLOR := Color(1.0, 0.18, 0.44, 0.28)

## Schriftgröße in px; vor dem Einfügen in den Baum setzen.
var font_size := 96


func _ready() -> void:
	name = "Logo"
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(font_size * 0.22))
	var font := FontVariation.new()
	font.base_font = FONT
	font.spacing_glyph = int(font_size * 0.06)
	var off := _word("OFF", font, OFF_COLOR)
	off.name = "Off"
	off.add_child(_glow())
	add_child(off)
	var camera := _word("CAMERA", font, CAMERA_COLOR)
	camera.name = "Camera"
	add_child(camera)


func _word(text: String, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Weiches, radiales Leuchten hinter „OFF“ (hängt am Wort, wächst mit ihm, zählt nicht zur Mindestgröße).
func _glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, GLOW_COLOR)
	gradient.set_color(1, Color(GLOW_COLOR, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.show_behind_parent = true
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -font_size * 1.4
	glow.offset_right = font_size * 1.4
	glow.offset_top = -font_size * 0.7
	glow.offset_bottom = font_size * 0.7
	return glow
