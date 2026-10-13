extends SceneTree
## App-Symbol in allen iOS-Größen aus den SVG-Quellen erzeugen (Ticket G3.2; eigenes Mini-Projekt):
##   timeout 120 ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path tools/icon \
##     -s make_icon.gd -- "$PWD/assets/icon"
## Danach im Spielprojekt importieren (`--headless --path . --import`).
## Jede Größe wird direkt aus dem SVG gerendert (schärfer als Verkleinern). Bis SMALL_MAX px gilt die
## vereinfachte Quelle `app_icon_small.svg`, darüber `app_icon.svg`. Ausgabe ohne Transparenz (Vorgabe von iOS).

const SIZES := [40, 58, 60, 76, 80, 87, 114, 120, 128, 136, 152, 167, 180, 192, 1024]
const SMALL_MAX := 87


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var full := FileAccess.get_file_as_string(dir.path_join("app_icon.svg"))
	var small := FileAccess.get_file_as_string(dir.path_join("app_icon_small.svg"))
	for size in SIZES:
		var image := Image.new()
		var err := image.load_svg_from_string(small if size <= SMALL_MAX else full, size / 1024.0)
		if err != OK or image.get_width() != size:
			push_error("Größe %d: SVG nicht lesbar (%s)" % [size, error_string(err)])
			continue
		image.convert(Image.FORMAT_RGB8)
		var path := dir.path_join("app_icon_%d.png" % size)
		print("%s: %s" % [path, error_string(image.save_png(path))])
	quit()
