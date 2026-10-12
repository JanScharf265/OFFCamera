extends RefCounted

## Fester Ablauf am Tageswechsel (Phase 5). Statt dass mehrere Systeme einzeln auf
## TimeSystem.day_changed hören (Reihenfolge = Reihenfolge der Verbindungen), ruft der
## DayCycle sie für jeden neuen Tag in dieser Reihenfolge auf:
##   1. Tagesabschluss des Unternehmens (Vortag)
##   2. Fristen (ObligationSystem)
##   3. Zufalls- und Behördenereignisse
## So sehen Fristen den fertigen Tagesabschluss und Ereignisse den Stand nach den Fristen.
## Überspringt ein Zeitfortschritt mehrere Tage, läuft der Ablauf für jeden Tag einzeln (aufsteigend).

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")

## Nach jedem vollständig abgearbeiteten Tageswechsel (für Tests und Anzeige).
signal day_processed(day: int)

## Die Schritte in Reihenfolge: Objekte mit on_day_changed(day).
var _steps: Array = []


func _init(time: TimeSystemScript, steps: Array) -> void:
	_steps = steps
	time.day_changed.connect(_on_day_changed)


func _on_day_changed(day: int) -> void:
	for step in _steps:
		step.on_day_changed(day)
	day_processed.emit(day)
