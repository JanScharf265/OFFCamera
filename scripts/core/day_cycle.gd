extends RefCounted

## Fester Ablauf am Tageswechsel (Phase 5, vollständig seit U.24). Statt dass mehrere Systeme einzeln auf
## TimeSystem.day_changed hören (Reihenfolge = Reihenfolge der Verbindungen), ruft der DayCycle sie für jeden neuen
## Tag in dieser Reihenfolge auf (die Liste baut der GameState):
##   1. Abrechnung: Unternehmen (Vortag) · Einstiegs-Angebot · Lieferungen und Schulden · Standorte (Produktion,
##      Verkauf, Miete) · Crew (Straßenverkauf, Löhne, Vorfälle) · Gebiete · Rivalen
##   2. Hitze: Abkühlung (nach allen Hitze-Änderungen der Abrechnung)
##   3. Polizei (Stufe, Akte, Razzia) · Justiz (Prozess, Entlassung) · Kontakte
##   4. Fristen (ObligationSystem) – sehen alle Buchungen und neuen Fristen des Tages
##   5. Ereignisse (Zufall, Behörden) – sehen den fertigen Stand
##   6. Kalender – öffnet die Spielansicht danach (DayStartSystem), nicht Teil dieser Liste
## Ein Schritt ist ein Objekt mit on_day_changed(day) oder ein Callable(day).
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
		if step is Callable:
			step.call(day)
		else:
			step.on_day_changed(day)
	day_processed.emit(day)
