extends RefCounted

## Tutorials (T.2): Systeme und Spielansicht melden Auslöser (report, IDs aus TutorialCatalog.TRIGGERS); fällig ist
## ein Tutorial, dessen Auslöser gemeldet wurde, das noch nicht gesehen ist und dessen `requires` alle gesehen sind –
## sortiert nach `order`. Gesehen erst nach Bestätigung (mark_seen); bis dahin bleibt es fällig, auch nach
## Speichern/Laden (gemeldete Auslöser werden mitgespeichert). Jedes Tutorial genau einmal. Kostet keine Spielzeit,
## ändert weder Geld noch Werte. Die Anzeige kommt in T.3.
##
## Gespeichert: `fired` (gemeldete Auslöser), `seen` (bestätigte Tutorial-IDs) und `seen_triggers` – alle Tutorials
## mit diesen Auslösern gelten als gesehen (Migration 14 → 15: „first_game_start“, wer schon spielt, braucht keine
## Spielstart-Erklärung; die Migration kennt die Tutorial-Daten nicht, daher der Auslöser statt einzelner IDs).

const TutorialCatalogScript := preload("res://scripts/systems/tutorial_catalog.gd")

signal tutorial_due(tutorial_id: String)

var _catalog: TutorialCatalogScript
## trigger -> true
var _fired := {}
## tutorial_id -> true
var _seen := {}
## trigger -> true
var _seen_triggers := {}


func _init(catalog: TutorialCatalogScript) -> void:
	_catalog = catalog


func get_catalog() -> TutorialCatalogScript:
	return _catalog


## Meldet einen Auslöser (mehrfach melden schadet nicht). false bei unbekannter ID (dann passiert nichts).
func report(trigger: String) -> bool:
	if trigger not in TutorialCatalogScript.TRIGGERS:
		push_error("TutorialSystem: unbekannter Auslöser '%s'." % trigger)
		return false
	if _fired.has(trigger):
		return true
	_fired[trigger] = true
	var next := get_next_due()
	if not next.is_empty():
		tutorial_due.emit(next)
	return true


func was_reported(trigger: String) -> bool:
	return _fired.has(trigger)


func is_seen(tutorial_id: String) -> bool:
	if _seen.has(tutorial_id):
		return true
	var definition = _catalog.get_definition(tutorial_id)
	return definition != null and _seen_triggers.has(definition.trigger)


## Jetzt fällige Tutorial-IDs, sortiert nach order (dann ID).
func get_due() -> PackedStringArray:
	var result := PackedStringArray()
	for definition in _catalog.get_all():  # sortiert nach order, dann ID
		if _fired.has(definition.trigger) and not is_seen(definition.id) and _requirements_met(definition):
			result.append(definition.id)
	return result


## Erstes fälliges Tutorial oder "".
func get_next_due() -> String:
	var due := get_due()
	return due[0] if not due.is_empty() else ""


## Bestätigt ein Tutorial („Verstanden“). "" = ok, sonst Fehlertext (nichts ändert sich).
func mark_seen(tutorial_id: String) -> String:
	if not _catalog.has(tutorial_id):
		return "Unbekanntes Tutorial: %s" % tutorial_id
	_seen[tutorial_id] = true
	return ""


## Alle gesehenen Tutorials (für das Lexikon), sortiert nach Bereich (mechanic), dann order und ID.
func get_seen() -> Array:
	var result := _catalog.get_all().filter(func(definition) -> bool: return is_seen(definition.id))
	result.sort_custom(func(a, b) -> bool:
		if a.mechanic != b.mechanic:
			return a.mechanic < b.mechanic
		return a.order < b.order or (a.order == b.order and a.id < b.id))
	return result


## „Tutorials zurücksetzen“ (T.4): nichts mehr gesehen (auch nicht über `seen_triggers`). Gemeldete Auslöser bleiben –
## ihre Tutorials sind sofort wieder fällig. Der Spielstart gilt als gemeldet (man ist ja in einem Spiel), damit die
## Spielstart-Tutorials auch in migrierten Spielständen wiederkommen. Kostet keine Spielzeit.
func reset_seen() -> void:
	_seen.clear()
	_seen_triggers.clear()
	_fired["first_game_start"] = true


func to_dict() -> Dictionary:
	return {"fired": _sorted(_fired), "seen": _sorted(_seen), "seen_triggers": _sorted(_seen_triggers)}


## Stellt einen gespeicherten Zustand her. Unbekannte Tutorial-IDs in `seen` bleiben erhalten (kommt das Tutorial
## zurück, gilt es weiter als gesehen). "" = ok, sonst Fehlertext (Zustand bleibt dann unverändert).
func restore(data: Dictionary) -> String:
	var parsed := {}
	for field in ["fired", "seen", "seen_triggers"]:
		var raw: Variant = data.get(field)
		if typeof(raw) != TYPE_ARRAY:
			return "Tutorials: '%s' fehlt oder ist keine Liste." % field
		var ids := {}
		for id in raw:
			if typeof(id) != TYPE_STRING or id.is_empty():
				return "Tutorials: ungültiger Eintrag in '%s'." % field
			ids[id] = true
		parsed[field] = ids
	_fired = parsed["fired"]
	_seen = parsed["seen"]
	_seen_triggers = parsed["seen_triggers"]
	return ""


func _requirements_met(definition) -> bool:
	for required in definition.requires:
		if not is_seen(required):
			return false
	return true


static func _sorted(ids: Dictionary) -> Array:
	var result := ids.keys()
	result.sort()
	return result
