class_name ObligationSystem
extends RefCounted

## Fristen (Phase 5): wiederkehrende Zahlungen wie Miete oder die fiktive Stadtabgabe.
## Abstrakte Spielwerte – keine realen Steuer- oder Rechtsregeln.
##
## Fälligkeit: Der DayCycle ruft on_day_changed(tag) auf (nach dem Tagesabschluss). Ist `tag` der
## Wochentag einer Frist (ab first_day), entsteht genau einmal die Instanz "<frist>@<tag>", fällig
## am Tag um 00:00. Betrag: fest oder profit_percent vom positiven Ergebnis der Vorwoche auf dem
## Konto der Frist (LedgerSystem.summarize, nach Wertstellung, ohne Umbuchungen); 0 € = entfällt.
## Reicht das Konto, wird sofort bezahlt (Wertstellung = Fälligkeit), sonst bleibt die Instanz offen.
## Jeder Tag wird höchstens einmal verarbeitet (last_processed_day), auch nach dem Laden.
##
## Überfällig (Ticket 5.3): Ist eine Instanz länger als grace_days nach ihrem Fälligkeitstag offen,
## wird sie einmal gemahnt: Die Mahngebühr erhöht den OFFENEN Betrag (fee_cents) – gebucht wird sie
## erst beim Bezahlen, damit kein Konto negativ wird –, und die Folgen (Stimmung bzw. Ruf des
## Unternehmens) wirken einmal. pay() bucht Grundbetrag (Wertstellung = Fälligkeit) und Mahngebühr
## (Wertstellung = jetzt) zusammen – nur, wenn das Konto den ganzen offenen Betrag deckt.

const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const ObligationCatalogScript := preload("res://scripts/systems/obligation_catalog.gd")
const ObligationDefinitionScript := preload("res://scripts/models/obligation_definition.gd")
const CompanySystemScript := preload("res://scripts/systems/company_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const DataReaderScript := preload("res://scripts/systems/data_reader.gd")

signal obligation_due(instance_id: String)
signal obligation_paid(instance_id: String)
signal obligation_reminded(instance_id: String)

const STATUS_PAID := "paid"
const STATUS_OPEN := "open"
const STATUS_WAIVED := "waived"
const SOURCE := "obligation"
const FEE_CATEGORY := "reminder_fee"
## Gespeicherte Instanzen (älteste fallen weg, wenn bezahlt/entfallen).
const HISTORY_LIMIT := 100

var _time: TimeSystemScript
var _ledger: LedgerSystemScript
var _company: CompanySystemScript
var _stats: PlayerStatsScript
var _catalog: ObligationCatalogScript
## Instanzen in Fälligkeitsreihenfolge: {id, obligation, due_minutes, amount_cents, fee_cents,
## status, paid_minutes, reminded}
var _instances: Array[Dictionary] = []
var _last_processed_day := 0
## Hinweise seit dem letzten take_notices() (nicht gespeichert).
var _notices := PackedStringArray()


func _init(time: TimeSystemScript, ledger: LedgerSystemScript, stats: PlayerStatsScript,
		company: CompanySystemScript, catalog: ObligationCatalogScript) -> void:
	_time = time
	_ledger = ledger
	_stats = stats
	_company = company
	_catalog = catalog
	_last_processed_day = TimeSystemScript.day_of(time.get_minutes())


func get_catalog() -> ObligationCatalogScript:
	return _catalog


## Alle gespeicherten Instanzen, älteste zuerst (Kopie).
func get_instances() -> Array[Dictionary]:
	return _instances.duplicate(true)


## Offene (unbezahlte) Instanzen, älteste zuerst.
func get_open() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _instances:
		if instance["status"] == STATUS_OPEN:
			result.append(instance.duplicate())
	return result


func get_instance(instance_id: String) -> Dictionary:
	for instance in _instances:
		if instance["id"] == instance_id:
			return instance.duplicate()
	return {}


## Offener Betrag einer Instanz = Betrag + Mahngebühren (0, wenn bezahlt/entfallen).
func open_amount(instance_id: String) -> int:
	var instance := get_instance(instance_id)
	if instance.is_empty() or instance["status"] != STATUS_OPEN:
		return 0
	return int(instance["amount_cents"]) + int(instance["fee_cents"])


## Hinweise (Fälligkeiten, Zahlungen) seit dem letzten Aufruf, je einmal.
func take_notices() -> PackedStringArray:
	var result := _notices
	_notices = PackedStringArray()
	return result


## Betrag, der bei Fälligkeit `due_minutes` für eine Frist anfällt.
@warning_ignore("integer_division")
func amount_for(definition: ObligationDefinitionScript, due_minutes: int) -> int:
	if not definition.uses_profit():
		return definition.fixed_cents
	var week := TimeSystemScript.week_of(due_minutes)
	if week <= 1:
		return 0  # keine Vorwoche
	var summary := _ledger.summarize(definition.account, TimeSystemScript.week_start(week - 1),
			TimeSystemScript.week_start(week))
	var profit: int = summary["net_cents"]
	return profit * definition.profit_percent / 100 if profit > 0 else 0


## Vom DayCycle aufgerufen (nach dem Tagesabschluss, vor den Ereignissen).
func on_day_changed(day: int) -> void:
	if day <= _last_processed_day:
		return
	_last_processed_day = day
	var weekday := (day - 1) % TimeSystemScript.DAYS_PER_WEEK
	for id in _catalog.get_ids():
		var definition := _catalog.get_definition(id)
		if definition.weekday != weekday or day < definition.first_day:
			continue
		if definition.requires == "company" and not _company.is_founded():
			continue
		var instance_id := "%s@%d" % [id, day]
		if not get_instance(instance_id).is_empty():
			continue
		_create(definition, instance_id, TimeSystemScript.at(day, 0))
	for instance in _instances:
		if instance["status"] == STATUS_OPEN and not instance["reminded"]:
			var definition := _catalog.get_definition(instance["obligation"])
			if definition != null and day > TimeSystemScript.day_of(instance["due_minutes"]) + definition.grace_days:
				_remind(instance, definition)


## Anzahl offener (überfälliger) Fristen – z. B. für Behördenereignisse.
func count_open() -> int:
	return get_open().size()


## "" wenn die Instanz jetzt bezahlt werden kann, sonst ein Grund für die Anzeige.
func check_pay(instance_id: String) -> String:
	var instance := get_instance(instance_id)
	if instance.is_empty():
		return "Unbekannte Frist: %s" % instance_id
	if instance["status"] != STATUS_OPEN:
		return "Diese Frist ist nicht offen."
	var definition := _catalog.get_definition(instance["obligation"])
	if definition == null:
		return "Diese Frist gibt es nicht mehr."
	var total := open_amount(instance_id)
	if not _ledger.can_afford(total, definition.account):
		return "Nicht genug Geld auf dem %s (offen: %s)." % [LedgerSystemScript.ACCOUNT_LABELS[definition.account],
				LedgerSystemScript.format_cents(total)]
	return ""


## Bezahlt eine offene Instanz komplett (Grundbetrag + Mahngebühr). "" = bezahlt.
func pay(instance_id: String) -> String:
	var reason := check_pay(instance_id)
	if not reason.is_empty():
		return reason
	for instance in _instances:
		if instance["id"] == instance_id:
			var definition := _catalog.get_definition(instance["obligation"])
			_book_payment(instance, definition)
			_notices.append("%s bezahlt: %s." % [_label(definition, instance["due_minutes"]),
					LedgerSystemScript.format_cents(-(int(instance["amount_cents"]) + int(instance["fee_cents"])))])
			return ""
	return "Unbekannte Frist: %s" % instance_id


func _remind(instance: Dictionary, definition: ObligationDefinitionScript) -> void:
	instance["reminded"] = true
	instance["fee_cents"] = int(instance["fee_cents"]) + definition.reminder_fee_cents
	var label := _label(definition, instance["due_minutes"])
	if not definition.overdue_effects.is_empty():
		_stats.apply(definition.overdue_effects)
	if not definition.overdue_company_effects.is_empty():
		_company.apply(definition.overdue_company_effects, SOURCE, "Mahnung: %s" % label, instance["id"],
				"obligation:%s:reminder" % instance["id"])
	_notices.append("Mahnung: %s – offen jetzt %s (+%s Mahngebühr)." % [label,
			LedgerSystemScript.format_cents(int(instance["amount_cents"]) + int(instance["fee_cents"])),
			LedgerSystemScript.format_cents(definition.reminder_fee_cents)])
	obligation_reminded.emit(instance["id"])


func _create(definition: ObligationDefinitionScript, instance_id: String, due_minutes: int) -> void:
	var amount := amount_for(definition, due_minutes)
	var instance := {
		"id": instance_id, "obligation": definition.id, "due_minutes": due_minutes, "amount_cents": amount,
		"fee_cents": 0, "status": STATUS_OPEN, "paid_minutes": -1, "reminded": false,
	}
	_instances.append(instance)
	obligation_due.emit(instance_id)
	var label := _label(definition, due_minutes)
	if amount == 0:
		instance["status"] = STATUS_WAIVED
		_notices.append("%s: entfällt (kein Gewinn in der Vorwoche)." % label)
	elif _ledger.can_afford(amount, definition.account):
		_book_payment(instance, definition)
		_notices.append("%s automatisch bezahlt: %s." % [label, LedgerSystemScript.format_cents(-amount)])
	else:
		_notices.append("%s fällig (%s) – %s reicht nicht. Bitte bezahlen." % [label,
				LedgerSystemScript.format_cents(amount), LedgerSystemScript.ACCOUNT_LABELS[definition.account]])
	_trim()


## Bucht den offenen Betrag einer Instanz und markiert sie bezahlt: Grundbetrag (Wertstellung =
## Fälligkeit) und ggf. Mahngebühr (Wertstellung = jetzt). Der Aufrufer hat vorher geprüft, dass das
## Konto den ganzen offenen Betrag deckt – danach kann keine der Buchungen mehr scheitern.
func _book_payment(instance: Dictionary, definition: ObligationDefinitionScript) -> void:
	var label := _label(definition, instance["due_minutes"])
	var key := "obligation:%s" % instance["id"]
	_ledger.post(-int(instance["amount_cents"]), definition.category, label, SOURCE, instance["id"],
			key, false, definition.account, instance["due_minutes"])
	if int(instance["fee_cents"]) > 0:
		_ledger.post(-int(instance["fee_cents"]), FEE_CATEGORY, "Mahngebühr: %s" % label, SOURCE, instance["id"],
				key + ":fee", false, definition.account)
	instance["status"] = STATUS_PAID
	instance["paid_minutes"] = _time.get_minutes()
	obligation_paid.emit(instance["id"])


## z. B. "Miete Wohnung (Woche 2)" bzw. "Stadtabgabe (für Woche 1)".
func _label(definition: ObligationDefinitionScript, due_minutes: int) -> String:
	var week := TimeSystemScript.week_of(due_minutes)
	if definition.uses_profit():
		return "%s (für Woche %d)" % [definition.display_name, week - 1]
	return "%s (Woche %d)" % [definition.display_name, week]


func get_label(instance_id: String) -> String:
	var instance := get_instance(instance_id)
	var definition := _catalog.get_definition(instance.get("obligation", ""))
	return _label(definition, instance["due_minutes"]) if definition != null else instance_id


func _trim() -> void:
	while _instances.size() > HISTORY_LIMIT:
		var index := -1
		for i in _instances.size():
			if _instances[i]["status"] != STATUS_OPEN:
				index = i
				break
		if index < 0:
			return
		_instances.remove_at(index)


func to_dict() -> Dictionary:
	return {"last_processed_day": _last_processed_day, "instances": _instances.duplicate(true)}


## Stellt einen gespeicherten Zustand her (ohne Signale). Instanzen von Fristen, die es in den Daten
## nicht mehr gibt, bleiben erhalten (Geld war schon gebucht bzw. bleibt offen).
## "" = ok, sonst Fehlertext (dann unverändert).
func restore(data: Dictionary) -> String:
	var reader := DataReaderScript.new()
	var last_day := reader.int_field(data, "last_processed_day", "Fristen", true)
	var instances: Array[Dictionary] = []
	var raw: Variant = data.get("instances")
	if typeof(raw) != TYPE_ARRAY:
		reader.errors.append("Fristen: 'instances' fehlt oder ist keine Liste.")
	else:
		var seen := {}
		for i in raw.size():
			var entry: Variant = raw[i]
			var where := "Frist-Instanz #%d" % (i + 1)
			if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("reminded")) != TYPE_BOOL:
				reader.errors.append("%s: ungültig." % where)
				continue
			var error_count := reader.errors.size()
			var instance := {
				"id": reader.string_field(entry, "id", where, true),
				"obligation": reader.string_field(entry, "obligation", where, true),
				"due_minutes": reader.int_field(entry, "due_minutes", where, true),
				"amount_cents": reader.int_field(entry, "amount_cents", where, true),
				"fee_cents": reader.int_field(entry, "fee_cents", where, true),
				"status": reader.string_field(entry, "status", where, true),
				"paid_minutes": reader.int_field(entry, "paid_minutes", where, true),
				"reminded": entry["reminded"],
			}
			if instance["status"] not in [STATUS_PAID, STATUS_OPEN, STATUS_WAIVED] \
					or instance["amount_cents"] < 0 or instance["fee_cents"] < 0:
				reader.errors.append("%s: Status oder Betrag ungültig." % where)
			if seen.has(instance["id"]):
				reader.errors.append("%s: ID '%s' kommt doppelt vor." % [where, instance["id"]])
			if reader.errors.size() == error_count:
				seen[instance["id"]] = true
				instances.append(instance)
	if not reader.errors.is_empty():
		return "; ".join(reader.errors)
	_last_processed_day = last_day
	_instances = instances
	_notices = PackedStringArray()
	return ""
