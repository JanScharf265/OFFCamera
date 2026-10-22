extends RefCounted

## „Hinfahren und starten“ (G5.7): erst die Fahrt (LocationSystem), dann die Aktion (ActivitySystem, ContentSystem,
## CompanySystem) – beides über die normalen Systeme, keine eigene Regel. Vorher wird die Aktion so geprüft, als wäre
## man schon angekommen (Öffnungszeiten ab der Ankunft, Geld, Energie, fehlende Firma …); „Nur vor Ort“ entfällt, weil
## die Fahrt es löst. Gibt es einen anderen Grund, wird nichts angeboten, die UI zeigt den Grund. Termin-Konflikte
## für die Gesamtzeit prüft die UI wie bei jeder Aktion über AppointmentSystem.get_conflicts (G5.4).
## Käufe (Ausrüstung) gibt es hier nicht – nur vor Ort. Hat keinen Zustand (kein Spielstand).

const KIND_ACTIVITY := "activity"
const KIND_CONTENT := "content"
const KIND_FOUND := "found"
const KIND_BRANCH := "branch"

var _time
var _locations
var _activities
var _content
var _company


func _init(time, locations, activities, content, company) -> void:
	_time = time
	_locations = locations
	_activities = activities
	_content = content
	_company = company


## Ort der Aktion oder "" (unbekannt).
func target_location(kind: String, id: String) -> String:
	match kind:
		KIND_ACTIVITY:
			var activity = _activities.get_catalog().get_definition(id)
			return activity.location if activity != null else ""
		KIND_CONTENT:
			var format = _content.get_catalog().get_definition(id)
			return format.location if format != null else ""
		KIND_FOUND:
			var type = _company.get_catalog().get_definition(id)
			return type.found_location if type != null else ""
		KIND_BRANCH:
			var branch = _company.get_catalog().get_definition(id)
			return branch.branch_location if branch != null and branch.has_branch else ""
	return ""


## Spielzeit der Aktion selbst (ohne Fahrt).
func action_minutes(kind: String, id: String) -> int:
	match kind:
		KIND_ACTIVITY:
			var activity = _activities.get_catalog().get_definition(id)
			return activity.duration_minutes if activity != null else 0
		KIND_CONTENT:
			var format = _content.get_catalog().get_definition(id)
			return format.duration_minutes if format != null else 0
		KIND_FOUND:
			var type = _company.get_catalog().get_definition(id)
			return type.founding_minutes if type != null else 0
		KIND_BRANCH:
			var branch = _company.get_catalog().get_definition(id)
			return branch.branch_opening_minutes if branch != null else 0
	return 0


func travel_minutes(kind: String, id: String) -> int:
	return _locations.travel_minutes_to(target_location(kind, id))


## Fahrt + Aktion.
func total_minutes(kind: String, id: String) -> int:
	return travel_minutes(kind, id) + action_minutes(kind, id)


## true, wenn die Aktion an einem anderen Ort liegt – dann zeigt die Kachel statt „Nur vor Ort“ die Kombi
## (frei oder mit dem Grund aus check()).
func offers(kind: String, id: String) -> bool:
	var target := target_location(kind, id)
	return not target.is_empty() and target != _locations.get_current()


## "" = Fahrt + Aktion möglich, sonst der Grund – zuerst die Gründe, die Hinfahren nicht löst.
func check(kind: String, id: String) -> String:
	if not offers(kind, id):
		return "Nur von einem anderen Ort aus möglich."
	var target := target_location(kind, id)
	var arrival: int = _time.get_minutes() + _locations.travel_minutes_to(target)
	var reason := _check_action(kind, id, arrival)
	if not reason.is_empty():
		return reason
	return _locations.check_travel(target)


## Fährt hin und startet die Aktion. Rückgabe {"arrived": bool, "reason": String} – reason "" = beides geschafft.
## Scheitert die Aktion nach der Fahrt doch, ist man trotzdem angekommen (arrived = true, reason = Grund).
func run(kind: String, id: String) -> Dictionary:
	var reason := check(kind, id)
	if not reason.is_empty():
		return {"arrived": false, "reason": reason}
	reason = _locations.travel(target_location(kind, id))
	if not reason.is_empty():
		return {"arrived": false, "reason": reason}
	return {"arrived": true, "reason": _start_action(kind, id)}


func _check_action(kind: String, id: String, start_minutes: int) -> String:
	match kind:
		KIND_ACTIVITY:
			return _activities.check_on_arrival(id, start_minutes)
		KIND_CONTENT:
			return _content.check_on_arrival(id, start_minutes)
		KIND_FOUND:
			return _company.check_found_on_arrival(id, start_minutes)
		KIND_BRANCH:
			return _company.check_open_branch_on_arrival(start_minutes)
	return "Unbekannte Aktion: %s" % kind


func _start_action(kind: String, id: String) -> String:
	match kind:
		KIND_ACTIVITY:
			return _activities.start(id)
		KIND_CONTENT:
			return _content.produce(id)
		KIND_FOUND:
			return _company.found(id)
		KIND_BRANCH:
			return _company.open_branch()
	return "Unbekannte Aktion: %s" % kind
