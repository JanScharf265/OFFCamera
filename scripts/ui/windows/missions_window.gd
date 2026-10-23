extends VBoxContainer

## Fenster „Aufträge“ (U.4): aktive Story-Aufträge (Kapitel, Titel, wer ihn gibt, Auftragstext, Ziel) und erledigte
## (Abschlusstext, Belohnung). Neues ist mit „Neu“ markiert; Öffnen gilt als gesehen (roter Punkt weg).
## Daten aus dem MissionSystem; zeigt nur an.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const MissionSystemScript := preload("res://scripts/systems/mission_system.gd")

var _game
## beim Öffnen ungesehen – bleibt in diesem Fenster als „Neu“ markiert
var _new := {}


func setup(_screen, game) -> void:
	_game = game


func _ready() -> void:
	name = "MissionsContent"
	add_theme_constant_override("separation", 12)
	for definition in _game.missions.get_catalog().get_all():
		if _game.missions.is_unseen(definition.id):
			_new[definition.id] = true
	_game.missions.mark_all_seen()
	refresh()


func get_title() -> String:
	return "Aufträge"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var active: Array = _game.missions.get_active()
	if active.is_empty():
		var empty := UiStyle.wrapping_label("Gerade kein offener Auftrag. El Capitán meldet sich.", UiStyle.SMALL_FONT_SIZE,
				UiStyle.MUTED)
		empty.name = "MissionsEmpty"
		add_child(empty)
	for definition in active:
		add_child(_card(definition, false))
	var completed: Array = _game.missions.get_completed()
	if not completed.is_empty():
		add_child(UiStyle.section_label("Erledigt"))
		for definition in completed:
			add_child(_card(definition, true))


func _card(definition, done: bool) -> Control:
	var card := UiStyle.card()
	card.name = "Mission_%s" % definition.id
	if done:
		card.modulate = Color(1, 1, 1, 0.7)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var chapter := UiStyle.label("%s · %s" % [definition.chapter, definition.giver], UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(chapter)
	if _new.has(definition.id):
		var badge := UiStyle.label("Neu" if not done else "Erledigt", UiStyle.MIN_READ_FONT_SIZE, UiStyle.BADGE)
		badge.name = "MissionNew_%s" % definition.id
		head.add_child(badge)
	var title := UiStyle.wrapping_label(definition.title, UiStyle.FONT_SIZE, UiStyle.TEXT)
	title.name = "MissionTitle_%s" % definition.id
	box.add_child(title)
	if done:
		box.add_child(UiStyle.wrapping_label(definition.debrief, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		var reward := MissionSystemScript.reward_suffix(definition.reward).strip_edges().trim_prefix("(").trim_suffix(")")
		if not reward.is_empty():
			box.add_child(UiStyle.label("Belohnung: %s" % reward, UiStyle.MIN_READ_FONT_SIZE, UiStyle.POSITIVE))
	else:
		box.add_child(UiStyle.wrapping_label(definition.briefing, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		var goal := UiStyle.wrapping_label("Ziel: %s" % definition.goal_text, UiStyle.SMALL_FONT_SIZE, UiStyle.ACCENT)
		goal.name = "MissionGoal_%s" % definition.id
		box.add_child(goal)
	return card
