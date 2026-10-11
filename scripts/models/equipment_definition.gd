class_name EquipmentDefinition
extends RefCounted

## Ein Ausrüstungsteil aus data/equipment/equipment.json (Phase 3), z. B. Kamera mit 3 Stufen.
## Wird vom EquipmentCatalog erzeugt und geprüft, danach nicht verändert.

var id: String
var display_name: String
## Ort, an dem man es kaufen kann.
var location: String
## Content-Formate, deren Qualität es verbessert.
var formats: PackedStringArray
## Stufen 1..n als {"name": String, "price_cents": int, "quality_percent": int};
## levels[0] ist Stufe 1. Der Qualitätsbonus gilt für die erreichte Stufe (nicht addiert).
var levels: Array[Dictionary] = []


func max_level() -> int:
	return levels.size()


## Stufe 1..max_level(); leer bei ungültiger Stufe.
func get_level(level: int) -> Dictionary:
	return levels[level - 1] if level >= 1 and level <= levels.size() else {}
