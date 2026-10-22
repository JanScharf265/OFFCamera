class_name PlayerStats
extends RefCounted

## Abstrakte Spielerwerte, jeweils 0–100. Keine medizinische Simulation.
## Werte nur über apply() ändern – das hält die Grenzen ein.

signal stats_changed

const MIN_VALUE := 0
const MAX_VALUE := 100
## Warnstufen für die Anzeige (G5.8, Entscheidung 059): unter LOW_BELOW gelb, unter CRITICAL_BELOW rot.
const LOW_BELOW := 40
const CRITICAL_BELOW := 20
const LEVEL_OK := 0
const LEVEL_LOW := 1
const LEVEL_CRITICAL := 2
## Alle gültigen Schlüssel für Effekte in Daten (z. B. activities.json).
const KEYS := ["energy", "mood"]
const LABELS := {"energy": "Energie", "mood": "Stimmung"}

var energy: int
var mood: int


func _init(p_energy: int = 80, p_mood: int = 60) -> void:
	energy = clampi(p_energy, MIN_VALUE, MAX_VALUE)
	mood = clampi(p_mood, MIN_VALUE, MAX_VALUE)


## Warnstufe eines Werts (LEVEL_*): 40 und mehr normal, 20–39 niedrig, unter 20 kritisch.
static func level_of(value: int) -> int:
	if value < CRITICAL_BELOW:
		return LEVEL_CRITICAL
	if value < LOW_BELOW:
		return LEVEL_LOW
	return LEVEL_OK


func get_value(key: String) -> int:
	assert(key in KEYS)
	return get(key)


func to_dict() -> Dictionary:
	return {"energy": energy, "mood": mood}


## Stellt gespeicherte Werte her. "" = ok, sonst Fehlertext (dann unverändert).
func restore(data: Dictionary) -> String:
	var values := {}
	for key in KEYS:
		var value: Variant = data.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or value != floorf(value) \
				or value < MIN_VALUE or value > MAX_VALUE:
			return "Spielerwerte: '%s' fehlt oder liegt nicht zwischen %d und %d." % [key, MIN_VALUE, MAX_VALUE]
		values[key] = int(value)
	for key in values:
		set(key, values[key])
	return ""


## Wendet Änderungen wie {"energy": -20, "mood": 5} an und begrenzt auf 0–100.
func apply(deltas: Dictionary) -> void:
	if deltas.is_empty():
		return
	for key in deltas:
		if key not in KEYS:
			push_error("PlayerStats: unbekannter Wert '%s'." % key)
			continue
		set(key, clampi(get(key) + int(deltas[key]), MIN_VALUE, MAX_VALUE))
	stats_changed.emit()
