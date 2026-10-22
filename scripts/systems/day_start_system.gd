extends RefCounted

## Tagesbeginn (G5.3): Der Kalender soll sich zu Beginn eines neuen Spieltags genau einmal öffnen – auch wenn
## man mehrere Tage überspringt (dann einmal für den aktuellen Tag) und auch nach Speichern/Laden.
## Merkt sich dafür den zuletzt „gezeigten“ Tag (im Spielstand). Ob wirklich geöffnet wird, entscheidet der
## Geräte-Schalter („Kalender bei Tagesbeginn automatisch öffnen“); der Tag gilt aber in jedem Fall als erledigt,
## damit späteres Einschalten keinen alten Tag nachholt. Kostet keine Spielzeit.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

var _time: TimeSystemScript
## Tag, für den der Kalender zuletzt fällig war (gezeigt oder per Schalter übersprungen).
var _calendar_shown_day := 0


func _init(time: TimeSystemScript, shown_day: int) -> void:
	_time = time
	_calendar_shown_day = shown_day


func get_calendar_shown_day() -> int:
	return _calendar_shown_day


## true, solange für den aktuellen Tag noch nichts entschieden ist.
func is_calendar_due() -> bool:
	return _time.get_day() > _calendar_shown_day


## Genau einmal je Tag: Ist der Kalender fällig, wird der Tag als erledigt gemerkt; Rückgabe true, wenn er jetzt
## geöffnet werden soll (auto_open = Geräte-Schalter). Nicht während eines Zeitfortschritts aufrufen.
func take_calendar_due(auto_open: bool) -> bool:
	if _time.is_advancing() or not is_calendar_due():
		return false
	_calendar_shown_day = _time.get_day()
	return auto_open


func to_dict() -> Dictionary:
	return {"calendar_shown_day": _calendar_shown_day}


## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var value: Variant = data.get("calendar_shown_day")
	if not DataReaderScript.is_whole_number(value) or int(value) < 0:
		return "Tagesbeginn: 'calendar_shown_day' fehlt oder ist ungültig."
	_calendar_shown_day = int(value)
	return ""
