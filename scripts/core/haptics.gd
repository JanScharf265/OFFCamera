extends RefCounted

## Vibration (G5.9): kleiner zentraler Dienst, der entscheidet, ob das iPhone kurz vibriert – bei Warnungen
## (Konflikt-Popup, Erinnerung, Termin verpasst, neue fällige Frist, Mahnung, Ereignis) und bei Geldänderungen ab
## MONEY_THRESHOLD_CENTS (Ein- und Ausgaben auf jedem Konto; Umbuchungen privat ↔ Firma zählen nicht).
## Geld, Termine, Fristen und Ereignisse kommen über die Signale der Systeme (attach), nicht aus der UI; die UI
## meldet nur ihre eigenen Warnungen (Konflikt-Popup, Erinnerung) über warn().
## Nur wenn der Geräte-Schalter „Vibration“ an ist. Höchstens einmal je LOCK_MSEC (eine Aktion mit mehreren
## Auslösern vibriert einmal). Solange `quiet` gilt (Laden/Aufbau der Spielansicht), passiert nichts.
## Testbar ohne Gerät: `count` und `history` zählen jede Vibration; Uhr und Ausgabe sind austauschbar.
## Am Mac passiert nichts Spürbares – Input.vibrate_handheld wirkt nur auf Mobilgeräten.

const SettingsScript := preload("res://scripts/core/settings.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

const DURATION_MSEC := 60
const MONEY_THRESHOLD_CENTS := 10000
const LOCK_MSEC := 1500

const REASON_CONFLICT := "conflict"
const REASON_REMINDER := "reminder"
const REASON_MISSED := "missed"
const REASON_OBLIGATION := "obligation"
const REASON_EVENT := "event"
const REASON_MONEY := "money"

## Anzahl der Vibrationen und ihre Gründe (nur fürs Testen und Prüfen, nicht gespeichert).
var count := 0
var history := PackedStringArray()
## true = still (z. B. während ein Spielstand geladen und die Spielansicht aufgebaut wird).
var quiet := false
## Uhr in Millisekunden (austauschbar für Tests).
var clock: Callable = func() -> int: return Time.get_ticks_msec()
## Ausgabe (austauschbar für Tests).
var output: Callable = func(duration_msec: int) -> void: Input.vibrate_handheld(duration_msec)

var _settings
var _game
var _last_msec := -1


func _init(settings = null) -> void:
	_settings = settings


func is_enabled() -> bool:
	return _settings == null or _settings.get_flag(SettingsScript.VIBRATION)


## Hört auf die Signale eines Spiels (ein vorheriges wird gelöst).
func attach(game) -> void:
	detach()
	_game = game
	game.ledger.entry_posted.connect(_on_entry_posted)
	game.appointments.appointment_missed.connect(_on_missed)
	game.obligations.obligation_due.connect(_on_obligation)
	game.obligations.obligation_reminded.connect(_on_obligation)
	game.events.event_triggered.connect(_on_event)


func detach() -> void:
	if _game == null:
		return
	for pair in [[_game.ledger.entry_posted, _on_entry_posted], [_game.appointments.appointment_missed, _on_missed],
			[_game.obligations.obligation_due, _on_obligation], [_game.obligations.obligation_reminded, _on_obligation],
			[_game.events.event_triggered, _on_event]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_game = null


## Warnung melden; vibriert, wenn erlaubt. Rückgabe: true = vibriert.
func warn(reason: String) -> bool:
	if quiet or not is_enabled():
		return false
	var now: int = clock.call()
	if _last_msec >= 0 and now - _last_msec < LOCK_MSEC:
		return false
	_last_msec = now
	count += 1
	history.append(reason)
	output.call(DURATION_MSEC)
	return true


## Geldänderung ab dem Schwellwert? (Betrag in Cent, beide Richtungen)
static func is_big_money(amount_cents: int) -> bool:
	return absi(amount_cents) >= MONEY_THRESHOLD_CENTS


func _on_entry_posted(entry) -> void:
	if entry.category != LedgerSystemScript.TRANSFER_CATEGORY and is_big_money(entry.amount_cents):
		warn(REASON_MONEY)


func _on_missed(_appointment_id: String) -> void:
	warn(REASON_MISSED)


func _on_obligation(_instance_id: String) -> void:
	warn(REASON_OBLIGATION)


func _on_event(_instance_id: String) -> void:
	warn(REASON_EVENT)
