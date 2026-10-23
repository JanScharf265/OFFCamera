extends RefCounted

## Justiz (U.21): Festnahme, Optionen, Kaution, Prozess, Haft – kein Game Over. Regeln: data/underworld/justice.json.
## Zustände: free → custody (Haftanstalt bis zum Prozess) → bail (Kaution gezahlt, frei bis zum Prozess) →
## Prozess am Tag `trial_day` (Ereignis) → Urteil: Freispruch (free) oder prison bis `release_day` (Spieltage über das
## TimeSystem, keine zweite Uhr). In Haft sitzt man am Ort „Haftanstalt“; Reisen ist gesperrt, Organisation, Crew und
## Telefon laufen weiter. Beweislage 0–100 bestimmt das Urteil. Optionen nur als Entscheidungen mit Zahlen (Anwalt,
## Bestechung – teuer und riskant –, schweigen, ein Crew-Mitglied belasten, kooperieren); jede Zahlung eine Buchung.
## Gericht, Richterin und Verfahren sind erfunden; keine realen Verfahrenstricks.

const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")

const DEFAULT_PATH := "res://data/underworld/justice.json"
const CATEGORY := "underworld_justice"
const SOURCE := "justice"
const PRISON := "prison"
const HOME := "home"
const FREE := "free"
const CUSTODY := "custody"
const BAIL := "bail"
const SERVING := "prison"
const STATE_LABELS := {FREE: "Frei", CUSTODY: "In Untersuchungshaft", BAIL: "Auf Kaution frei", SERVING: "In Haft"}
const EVENTS := {"arrest": "justice_arrest", "trial": "justice_trial", "verdict": "justice_verdict"}
const RULE_FIELDS := ["arrest_chance_percent", "start_evidence", "lawyer_cost_cents", "lawyer_evidence", "bribe_cost_cents",
		"bribe_success_percent", "bribe_fail_evidence", "bribe_fail_heat", "silent_evidence", "sacrifice_evidence",
		"sacrifice_stability", "sacrifice_loyalty", "cooperate_evidence", "cooperate_respect", "cooperate_stability",
		"trial_after_days", "bail_cents_per_evidence", "conviction_min_evidence", "days_per_10_evidence"]


## Regeln. Alles-oder-nichts.
class Rules extends RefCounted:
	var errors: PackedStringArray = []
	var values := {}

	func load_file(path: String = "res://data/underworld/justice.json") -> bool:
		var reader := DataReaderScript.new()
		var data: Variant = reader.read_json_file(path)
		if data == null:
			errors = reader.errors
			return false
		return load_data(data)

	func load_data(data: Variant) -> bool:
		errors = PackedStringArray()
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("Justizregeln müssen ein Objekt sein.")
			return false
		var result := {}
		for key in data:
			if String(key) not in RULE_FIELDS:
				errors.append("Justizregeln: unbekanntes Feld '%s'." % key)
		for key in RULE_FIELDS:
			if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
				errors.append("Justizregeln: '%s' muss eine ganze Zahl ≥ 0 sein." % key)
			else:
				result[key] = int(data[key])
		if errors.is_empty() and (result["trial_after_days"] < 1 or result["start_evidence"] > 100
				or result["arrest_chance_percent"] > 100 or result["bribe_success_percent"] > 100):
			errors.append("Justizregeln: trial_after_days ≥ 1, Prozentwerte ≤ 100.")
		if not errors.is_empty():
			return false
		values = result
		return true

	func get_value(key: String) -> int:
		return values.get(key, 0)


var _time
var _ledger: LedgerSystemScript
var _rules: Rules
var _organisation
var _locations
var _get_seed: Callable
var _trigger_scripted: Callable
var _sacrifice: Callable
var _get_case: Callable
var _state := FREE
var _evidence := 0
var _case := ""
var _trial_day := 0
var _release_day := 0
var _trial_triggered := false
var _last_verdict := ""
var _arrests := 0
var _last_processed_day := 0
var _notices := PackedStringArray()


func _init(time, ledger: LedgerSystemScript, rules: Rules, organisation, locations, get_seed: Callable,
		trigger_scripted: Callable) -> void:
	_time = time
	_ledger = ledger
	_rules = rules
	_organisation = organisation
	_locations = locations
	_get_seed = get_seed
	_trigger_scripted = trigger_scripted
	_last_processed_day = time.get_day()


## Vom GameState: Crew-Mitglied belasten (CrewSystem.sacrifice → Name oder "") und Aktenzeichen (PoliceSystem).
func set_hooks(sacrifice: Callable, get_case: Callable) -> void:
	_sacrifice = sacrifice
	_get_case = get_case


func get_rules() -> Rules:
	return _rules


func get_state() -> String:
	return _state


func state_label() -> String:
	return STATE_LABELS[_state]


func get_evidence() -> int:
	return _evidence


func get_case() -> String:
	return _case


func get_trial_day() -> int:
	return _trial_day


func get_release_day() -> int:
	return _release_day


func get_last_verdict() -> String:
	return _last_verdict


func count_arrests() -> int:
	return _arrests


## Verfahren läuft oder lief (für Anzeige des Fensters).
func has_case() -> bool:
	return _state != FREE or _arrests > 0


func is_locked_up() -> bool:
	return _state in [CUSTODY, SERVING]


## Für LocationSystem: Grund, warum man nicht reisen kann ("" = frei).
func travel_block() -> String:
	return "Du sitzt in Haft." if is_locked_up() else ""


func bail_cents() -> int:
	return _evidence * _rules.get_value("bail_cents_per_evidence")


func payment_account(cost_cents: int) -> String:
	return LedgerSystemScript.BLACK if _ledger.can_afford(cost_cents, LedgerSystemScript.BLACK) \
			else LedgerSystemScript.PRIVATE


## Vom PoliceSystem nach einer Razzia: mit `arrest_chance_percent` (Seed) folgt die Festnahme.
func after_raid(day: int) -> void:
	if _state != FREE:
		return
	var roll := EventSystemScript.fnv1a("%d:arrest:%d" % [_get_seed.call(), day]) % 100
	if roll < _rules.get_value("arrest_chance_percent"):
		arrest(day)


## Festnahme: Haftanstalt, Beweislage, Prozesstag, Ereignis.
func arrest(day: int) -> void:
	if _state != FREE:
		return
	_state = CUSTODY
	_arrests += 1
	_evidence = _rules.get_value("start_evidence")
	_case = String(_get_case.call()) if _get_case.is_valid() else ""
	if _case.is_empty():
		_case = "MB-%04d" % (EventSystemScript.fnv1a("%d:case" % _get_seed.call()) % 10000)
	_trial_day = day + _rules.get_value("trial_after_days")
	_trial_triggered = false
	_locations.place(PRISON)
	_trigger(EVENTS["arrest"], day)


## Für das EventSystem: Platzhalter ({case}, {days}, {evidence}, {verdict}).
func text_context(instance_id: String) -> Dictionary:
	for key in EVENTS.values():
		if instance_id.begins_with(key):
			return {"case": _case, "days": str(maxi(0, _trial_day - _time.get_day())), "evidence": str(_evidence),
					"verdict": _last_verdict}
	return {}


func _pay(cost: int, label: String, key: String) -> bool:
	var account := payment_account(cost)
	if not _ledger.can_afford(cost, account):
		return false
	return _ledger.post(-cost, CATEGORY, label, SOURCE, _case, key, false, account) != null


func _change_evidence(delta: int) -> void:
	_evidence = clampi(_evidence + delta, 0, 100)


## Vom EventSystem: Antwort bei Festnahme oder Prozess.
func apply_event_action(action: String, instance_id: String) -> void:
	var r := _rules
	match action:
		"lawyer":
			if _pay(r.get_value("lawyer_cost_cents"), "Anwalt im Verfahren %s" % _case, "justice:lawyer:%s" % instance_id):
				_change_evidence(-r.get_value("lawyer_evidence"))
				_notices.append("Der Anwalt ist dran – Beweislage jetzt %d %%." % _evidence)
			else:
				_change_evidence(-r.get_value("silent_evidence"))
				_notices.append("Kein Geld für einen Anwalt – du schweigst (Beweislage %d %%)." % _evidence)
		"bribe":
			if not _pay(r.get_value("bribe_cost_cents"), "Zahlung an einen Unbekannten", "justice:bribe:%s" % instance_id):
				_change_evidence(-r.get_value("silent_evidence"))
				_notices.append("Für Bestechung fehlt das Geld – du schweigst (Beweislage %d %%)." % _evidence)
			elif EventSystemScript.fnv1a("%d:bribe:%s" % [_get_seed.call(), instance_id]) % 100 < r.get_value("bribe_success_percent"):
				_close("Das Verfahren %s wurde eingestellt. Niemand sagt, warum." % _case)
			else:
				_change_evidence(r.get_value("bribe_fail_evidence"))
				_organisation.change({"heat": r.get_value("bribe_fail_heat")})
				_notices.append("Die Bestechung ist aufgeflogen – Beweislage %d %%, Hitze +%d." % [_evidence,
						r.get_value("bribe_fail_heat")])
		"silent":
			_change_evidence(-r.get_value("silent_evidence"))
			_notices.append("Du schweigst. Beweislage %d %%." % _evidence)
		"sacrifice":
			var name: String = _sacrifice.call(r.get_value("sacrifice_loyalty")) if _sacrifice.is_valid() else ""
			if name.is_empty():
				_notices.append("Es gibt niemanden, den du belasten könntest.")
			else:
				_change_evidence(-r.get_value("sacrifice_evidence"))
				_organisation.change({"stability": -r.get_value("sacrifice_stability")})
				_notices.append("Du belastest %s. Die Crew hat es gehört." % name)
			_verdict()
		"cooperate":
			_change_evidence(-r.get_value("cooperate_evidence"))
			_organisation.change({"respect": -r.get_value("cooperate_respect"), "stability": -r.get_value("cooperate_stability")})
			_verdict()
		"await":
			_verdict()


## Urteil nach der Beweislage: Freispruch oder Haft in Spieltagen.
@warning_ignore("integer_division")
func _verdict() -> void:
	var day: int = _time.get_day()
	if _evidence < _rules.get_value("conviction_min_evidence"):
		_last_verdict = "Freispruch im Verfahren %s: Die Beweislage (%d %%) reicht Richterin Vidal nicht. Du gehst nach Hause." % [
				_case, _evidence]
		_state = FREE
		_locations.place(HOME)
	else:
		var days: int = maxi(1, _evidence / 10 * _rules.get_value("days_per_10_evidence"))
		_release_day = day + days
		_last_verdict = "Schuldig im Verfahren %s: %d Tage Haft (Beweislage %d %%). Entlassung am Tag %d." % [_case, days,
				_evidence, _release_day]
		_state = SERVING
		_locations.place(PRISON)
	_trigger(EVENTS["verdict"], day)


func _close(text: String) -> void:
	_last_verdict = text
	_state = FREE
	_locations.place(HOME)
	_notices.append(text)


## "" wenn die Kaution jetzt gezahlt werden kann, sonst ein Grund.
func check_bail() -> String:
	if _state != CUSTODY:
		return "Keine Untersuchungshaft."
	var cost := bail_cents()
	if not _ledger.can_afford(cost, payment_account(cost)):
		return "Nicht genug Geld (%s)." % LedgerSystemScript.format_cents(cost)
	return ""


## Kaution: Buchung → frei bis zum Prozess (zu Hause). "" = gezahlt.
func pay_bail() -> String:
	var reason := check_bail()
	if not reason.is_empty():
		return reason
	if not _pay(bail_cents(), "Kaution im Verfahren %s" % _case, "justice:bail:%s:%d" % [_case, _arrests]):
		return "Die Buchung ist fehlgeschlagen."
	_state = BAIL
	_locations.place(HOME)
	return ""


## Tag, bis zu dem man warten kann (Prozess oder Entlassung), sonst 0.
func wait_target_day() -> int:
	if _state in [CUSTODY, BAIL] and not _trial_triggered:
		return _trial_day
	if _state == SERVING:
		return _release_day
	return 0


## Wartet bis zum Morgen des Prozess- bzw. Entlassungstags (TimeSystem). "" = gewartet.
func wait() -> String:
	var day := wait_target_day()
	if day <= 0:
		return "Es gibt nichts abzuwarten."
	if _time.is_advancing():
		return "Gerade läuft bereits ein Zeitfortschritt."
	var target := TimeSystemScript.at(day, 8)
	if target <= _time.get_minutes():
		return "Es ist schon so weit."
	_time.advance(target - _time.get_minutes())
	return ""


func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Vom DayCycle: Prozess am Prozesstag, Entlassung am Entlassungstag.
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	if _state in [CUSTODY, BAIL] and day >= _trial_day and not _trial_triggered:
		_trial_triggered = true
		_trigger(EVENTS["trial"], day)
	elif _state == SERVING and day >= _release_day:
		_state = FREE
		_locations.place(HOME)
		_notices.append("Entlassen: Du bist wieder draußen. Die Stadt hat sich in der Zeit weitergedreht.")


func _trigger(event_id: String, day: int) -> void:
	if _trigger_scripted.is_valid():
		_trigger_scripted.call(event_id, day)


func to_dict() -> Dictionary:
	return {"state": _state, "evidence": _evidence, "case": _case, "trial_day": _trial_day, "release_day": _release_day,
			"trial_triggered": _trial_triggered, "last_verdict": _last_verdict, "arrests": _arrests,
			"last_processed_day": _last_processed_day}


## "" = ok, sonst Fehlertext (nichts geändert).
func restore(data: Dictionary) -> String:
	if data.get("state") not in STATE_LABELS:
		return "Justiz: 'state' fehlt oder ist ungültig."
	for key in ["evidence", "trial_day", "release_day", "arrests", "last_processed_day"]:
		if not DataReaderScript.is_whole_number(data.get(key)) or int(data[key]) < 0:
			return "Justiz: '%s' fehlt oder ist ungültig." % key
	if int(data["evidence"]) > 100 or typeof(data.get("case")) != TYPE_STRING \
			or typeof(data.get("last_verdict")) != TYPE_STRING or typeof(data.get("trial_triggered")) != TYPE_BOOL:
		return "Justiz: Akte oder Urteil ungültig."
	_state = data["state"]
	_evidence = int(data["evidence"])
	_case = data["case"]
	_trial_day = int(data["trial_day"])
	_release_day = int(data["release_day"])
	_trial_triggered = data["trial_triggered"]
	_last_verdict = data["last_verdict"]
	_arrests = int(data["arrests"])
	_last_processed_day = int(data["last_processed_day"])
	_notices.clear()
	return ""
