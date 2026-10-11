class_name GameState
extends RefCounted

## Bündelt alle Systeme einer Spielsitzung. Kein Autoload: Wer ein Spiel
## startet, erzeugt einen GameState und reicht ihn weiter.
##
## Startwerte sind Platzhalter.

const GameDataScript := preload("res://scripts/core/game_data.gd")
const TimeSystemScript := preload("res://scripts/systems/time_system.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")
const PlayerStatsScript := preload("res://scripts/models/player_stats.gd")
const LocationSystemScript := preload("res://scripts/systems/location_system.gd")
const ActivitySystemScript := preload("res://scripts/systems/activity_system.gd")
const EventSystemScript := preload("res://scripts/systems/event_system.gd")
const AppointmentSystemScript := preload("res://scripts/systems/appointment_system.gd")
const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const ContentSystemScript := preload("res://scripts/systems/content_system.gd")
const EquipmentSystemScript := preload("res://scripts/systems/equipment_system.gd")

const START_DAY := 1
const START_HOUR := 8
const START_BALANCE_CENTS := 50000
const START_ENERGY := 80
const START_MOOD := 60
const START_FOLLOWERS := 120
const START_COMMUNITY := 50
const START_REPUTATION := 50

var data: GameDataScript
var time: TimeSystemScript
var ledger: LedgerSystemScript
var stats: PlayerStatsScript
var locations: LocationSystemScript
var activities: ActivitySystemScript
var events: EventSystemScript
var appointments: AppointmentSystemScript
var channel: ChannelSystemScript
var content: ContentSystemScript
var equipment: EquipmentSystemScript


## Neues Spiel mit Startwerten. Die Daten müssen bereits geladen sein.
## p_seed bestimmt die Zufallsereignisse (gleicher Seed = gleicher Verlauf);
## -1 = neuer zufälliger Seed (wird mit dem Spielstand gespeichert).
func _init(game_data: GameDataScript, p_seed: int = -1) -> void:
	data = game_data
	time = TimeSystemScript.new(TimeSystemScript.at(START_DAY, START_HOUR))
	ledger = LedgerSystemScript.new(time, START_BALANCE_CENTS)
	stats = PlayerStatsScript.new(START_ENERGY, START_MOOD)
	locations = LocationSystemScript.new(time, data.locations, GameDataScript.START_LOCATION)
	activities = ActivitySystemScript.new(time, ledger, stats, locations, data.activities)
	appointments = AppointmentSystemScript.new(time, ledger, stats, locations, data.appointments)
	channel = ChannelSystemScript.new(time, START_FOLLOWERS, START_COMMUNITY, START_REPUTATION)
	events = EventSystemScript.new(time, ledger, stats, channel, data.events, p_seed if p_seed >= 0 else new_seed())
	equipment = EquipmentSystemScript.new(time, ledger, locations, data.equipment)
	content = ContentSystemScript.new(time, ledger, stats, locations, channel, equipment, data.formats)


## Zufälliger Seed für ein neues Spiel (0 … 2^31 − 1).
static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7FFFFFFF


func to_dict() -> Dictionary:
	return {
		"time": time.to_dict(),
		"ledger": ledger.to_dict(),
		"stats": stats.to_dict(),
		"location": locations.to_dict(),
		"events": events.to_dict(),
		"appointments": appointments.to_dict(),
		"channel": channel.to_dict(),
		"equipment": equipment.to_dict(),
	}


## Überschreibt den Zustand mit gespeicherten Daten (aktuelles Format). "" = ok,
## sonst Fehlertext. Bei einem Fehler kann der GameState teilweise geändert sein –
## der Aufrufer verwirft ihn dann (SaveSystem erzeugt dafür immer einen frischen GameState).
func restore(saved: Dictionary) -> String:
	for section in ["time", "ledger", "stats", "location", "events", "appointments", "channel", "equipment"]:
		if typeof(saved.get(section)) != TYPE_DICTIONARY:
			return "Abschnitt '%s' fehlt oder ist ungültig." % section
	var error := time.restore(saved["time"])
	if error.is_empty():
		error = ledger.restore(saved["ledger"])
	if error.is_empty():
		error = stats.restore(saved["stats"])
	if error.is_empty():
		error = locations.restore(saved["location"])
	if error.is_empty():
		error = events.restore(saved["events"])
	if error.is_empty():
		error = appointments.restore(saved["appointments"])
	if error.is_empty():
		error = channel.restore(saved["channel"])
	if error.is_empty():
		error = equipment.restore(saved["equipment"])
	return error
