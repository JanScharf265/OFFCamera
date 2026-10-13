extends SceneTree
## Vorschau der Icon-Entwürfe (Ticket G3.1): je Entwurf ein PNG mit dem Icon in 1024 px und 60 px,
## oben auf hellem, unten auf dunklem Homescreen-Hintergrund, mit iOS-ähnlich abgerundeten Ecken.
##   timeout 120 ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path tools/icon \
##     -s make_previews.gd -- "$PWD/tools/icon/drafts"
## Die SVG-Quellen bleiben quadratisch (iOS rundet die Ecken selbst ab).

const DRAFTS := ["a_objektiv", "b_rec_schatten", "c_monogramm"]
const SIZE := 1024
const SMALL := 60
const PAD := 64
const LIGHT := Color("#F2F2F7")
const DARK := Color("#000000")


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	for draft in DRAFTS:
		var svg := _with_mask(FileAccess.get_file_as_string(dir.path_join(draft + ".svg")))
		var big := _render(svg, 1.0)
		var small := _render(svg, float(SMALL) / SIZE)
		var width := PAD * 3 + SIZE + SMALL
		var row := SIZE + PAD * 2
		var out := Image.create_empty(width, row * 2, false, Image.FORMAT_RGBA8)
		out.fill_rect(Rect2i(0, 0, width, row), LIGHT)
		out.fill_rect(Rect2i(0, row, width, row), DARK)
		for i in 2:
			var top := i * row + PAD
			out.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(PAD, top))
			out.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()),
					Vector2i(PAD * 2 + SIZE, top + (SIZE - SMALL) / 2))
		var path := dir.path_join("preview_%s.png" % draft)
		print("%s: %s" % [path, error_string(out.save_png(path))])
	quit()


func _render(svg: String, scale: float) -> Image:
	var image := Image.new()
	var err := image.load_svg_from_string(svg, scale)
	if err != OK:
		push_error("SVG nicht lesbar: %s" % error_string(err))
	image.convert(Image.FORMAT_RGBA8)
	return image


## Legt eine abgerundete Maske (Radius ~22 %) um den Inhalt – nur für die Vorschau.
func _with_mask(svg: String) -> String:
	var open_end := svg.find(">", svg.find("<svg")) + 1
	var close := svg.rfind("</svg>")
	return svg.substr(0, open_end) \
			+ "<defs><clipPath id=\"iosmask\"><rect width=\"1024\" height=\"1024\" rx=\"230\"/></clipPath></defs>" \
			+ "<g clip-path=\"url(#iosmask)\">" + svg.substr(open_end, close - open_end) + "</g></svg>"
