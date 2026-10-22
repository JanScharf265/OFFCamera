extends RefCounted

## Safe-Area-Abstände (aus app.gd herausgelöst, G5.1b), damit auch der leichte Ladebildschirm sie nutzen kann,
## ohne die ganze App zu laden.

## Abstände [links, oben, rechts, unten] in Viewport-Pixeln: Grundabstand + Bereich außerhalb der
## Safe Area. Die Safe Area kommt in Bildschirmpixeln und wird in Viewport-Koordinaten umgerechnet.
## Ohne gültige Fenstergröße (Desktop, Tests) nur der Grundabstand.
static func margins(window_size: Vector2, safe: Rect2, viewport_size: Vector2, padding: float) -> Array[float]:
	var result: Array[float] = [padding, padding, padding, padding]
	if window_size.x <= 0 or window_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return result
	var to_viewport := viewport_size / window_size
	result[0] += maxf(safe.position.x, 0.0) * to_viewport.x
	result[1] += maxf(safe.position.y, 0.0) * to_viewport.y
	result[2] += maxf(window_size.x - safe.end.x, 0.0) * to_viewport.x
	result[3] += maxf(window_size.y - safe.end.y, 0.0) * to_viewport.y
	return result


## Abstände für das laufende Gerät (auf dem Desktop nur der Grundabstand).
static func current(viewport_size: Vector2, padding: float) -> Array[float]:
	if not OS.has_feature("mobile"):
		return margins(Vector2.ZERO, Rect2(), viewport_size, padding)
	return margins(Vector2(DisplayServer.window_get_size()), Rect2(DisplayServer.get_display_safe_area()),
			viewport_size, padding)
