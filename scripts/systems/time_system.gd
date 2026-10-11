class_name TimeSystem
extends RefCounted

## Einzige Autorität für die Spielzeit.
##
## Kanonische Einheit: ganze Minuten seit Spielbeginn (Tag 1, 00:00, Montag).
## Zeit vergeht ausschließlich über advance(); es gibt keine Echtzeit-Simulation.
##
## Signal-Reihenfolge bei advance():
##   1. day_changed – einmal pro überschrittenem Tag, aufsteigend
##   2. time_advanced – genau einmal mit (von, bis)
## Wenn die Signale feuern, ist die neue Zeit bereits gesetzt.

signal time_advanced(from_minutes: int, to_minutes: int)
signal day_changed(day: int)

const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24
const MINUTES_PER_DAY := MINUTES_PER_HOUR * HOURS_PER_DAY
const DAYS_PER_WEEK := 7
const WEEKDAY_NAMES := ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

var _minutes: int = 0
var _is_advancing := false


func _init(start_minutes: int = 0) -> void:
	if start_minutes < 0:
		push_error("TimeSystem: Startzeit darf nicht negativ sein (%d), verwende 0." % start_minutes)
		start_minutes = 0
	_minutes = start_minutes


## Minuten für einen Zeitpunkt. day beginnt bei 1.
static func at(day: int, hour: int, minute: int = 0) -> int:
	assert(day >= 1 and hour >= 0 and hour < HOURS_PER_DAY and minute >= 0 and minute < MINUTES_PER_HOUR)
	return (day - 1) * MINUTES_PER_DAY + hour * MINUTES_PER_HOUR + minute


@warning_ignore("integer_division")
static func day_of(minutes: int) -> int:
	return minutes / MINUTES_PER_DAY + 1


func get_minutes() -> int:
	return _minutes


## true, solange advance() seine Signale verschickt.
func is_advancing() -> bool:
	return _is_advancing


func get_day() -> int:
	return day_of(_minutes)


func get_minute_of_day() -> int:
	return _minutes % MINUTES_PER_DAY


@warning_ignore("integer_division")
func get_hour() -> int:
	return get_minute_of_day() / MINUTES_PER_HOUR


func get_minute() -> int:
	return _minutes % MINUTES_PER_HOUR


## 0 = Montag … 6 = Sonntag.
func get_weekday() -> int:
	return (get_day() - 1) % DAYS_PER_WEEK


## z. B. "08:05"
func format_clock() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


## Zeitpunkt beliebiger Minuten, z. B. "Tag 2 · 14:30".
@warning_ignore("integer_division")
static func format_stamp(minutes: int) -> String:
	var minute_of_day := minutes % MINUTES_PER_DAY
	return "Tag %d · %02d:%02d" % [day_of(minutes), minute_of_day / MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR]


## Dauer, z. B. 45 -> "45 min", 60 -> "1 h", 90 -> "1 h 30 min".
@warning_ignore("integer_division")
static func format_duration(minutes: int) -> String:
	var hours := minutes / MINUTES_PER_HOUR
	var rest := minutes % MINUTES_PER_HOUR
	if hours == 0:
		return "%d min" % rest
	if rest == 0:
		return "%d h" % hours
	return "%d h %d min" % [hours, rest]


## z. B. "Tag 3 · Mi"
func format_date() -> String:
	return "Tag %d · %s" % [get_day(), WEEKDAY_NAMES[get_weekday()]]


func to_dict() -> Dictionary:
	return {"minutes": _minutes}


## Stellt einen gespeicherten Zustand her, ohne Signale zu senden.
## "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var value: Variant = data.get("minutes")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or value != floorf(value) or value < 0:
		return "Zeit: 'minutes' fehlt oder ist ungültig."
	if _is_advancing:
		return "Zeit: Laden während eines Zeitfortschritts ist nicht möglich."
	_minutes = int(value)
	return ""


## Lässt genau `minutes` Spielminuten vergehen.
## Gibt false zurück und ändert nichts, wenn minutes <= 0 ist oder
## advance() aus einem Signal-Handler heraus erneut aufgerufen wird.
func advance(minutes: int) -> bool:
	if minutes <= 0:
		push_error("TimeSystem: advance() braucht eine positive Dauer, erhalten: %d." % minutes)
		return false
	if _is_advancing:
		push_error("TimeSystem: advance() während eines laufenden Zeitfortschritts ist nicht erlaubt.")
		return false

	var from := _minutes
	var to := _minutes + minutes
	_minutes = to

	_is_advancing = true
	for day in range(day_of(from) + 1, day_of(to) + 1):
		day_changed.emit(day)
	time_advanced.emit(from, to)
	_is_advancing = false
	return true
