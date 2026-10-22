extends RefCounted

## Zeitstempel für den Start (G5.1b/G5.1c): „[Start] <ms seit Engine-Start>  Text“ ins Log – auf dem iPhone in der
## Xcode-Konsole lesbar. watch_frames() schreibt danach die Dauer jedes gezeichneten Bildes, bis eines schneller als
## FAST_FRAME_MS ist (oder MAX_FRAMES erreicht sind) – so sieht man, wo eine „schwarze“ Pause liegt.
## Jede Bezeichnung wird nur beim ersten Mal protokolliert (Tests bauen die App viele Male).

const FAST_FRAME_MS := 50.0
const MAX_FRAMES := 30

static var _seen := {}
static var _watches: Array = []


static func mark(text: String, once_key: String = "") -> void:
	if not once_key.is_empty():
		if _seen.has(once_key):
			return
		_seen[once_key] = true
	print("[Start] %6d ms  %s" % [Time.get_ticks_msec(), text])


## Protokolliert die nächsten gezeichneten Bilder (nach RenderingServer.frame_post_draw), nur beim ersten Mal je label.
static func watch_frames(label: String) -> void:
	if _seen.has("frames:" + label):
		return
	_seen["frames:" + label] = true
	var watch := FrameWatch.new(label)
	_watches.append(watch)
	RenderingServer.frame_post_draw.connect(watch.on_drawn)


class FrameWatch extends RefCounted:
	var label: String
	var count := 0
	var last_usec := 0

	func _init(p_label: String) -> void:
		label = p_label
		last_usec = Time.get_ticks_usec()

	func on_drawn() -> void:
		var now := Time.get_ticks_usec()
		var ms := (now - last_usec) / 1000.0
		last_usec = now
		count += 1
		print("[Start] %6d ms  %s: Bild %d gezeichnet (%.0f ms)" % [Time.get_ticks_msec(), label, count, ms])
		if ms < FAST_FRAME_MS or count >= MAX_FRAMES:
			RenderingServer.frame_post_draw.disconnect(on_drawn)
