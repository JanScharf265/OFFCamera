extends VBoxContainer

## Fensterinhalt „Kanal“ (G2): Follower, Wachstumsbremse, Community-Stimmung, Ruf und der
## Kanal-Verlauf mit Begründungen (warum sich Werte geändert haben).

const ChannelSystemScript := preload("res://scripts/systems/channel_system.gd")
const ActivityText := preload("res://scripts/ui/activity_text.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")

const HISTORY_COUNT := 8

var _screen
var _game
var _summary: Label
var _followers: Label
var _growth: Label
var _score_labels := {}
var _score_bars := {}
var _history: VBoxContainer


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "ChannelWindowContent"
	add_theme_constant_override("separation", 12)
	var card := UiStyle.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	add_child(card)
	_followers = UiStyle.label("", UiStyle.LARGE_FONT_SIZE)
	_followers.name = "FollowersLabel"
	box.add_child(_followers)
	_summary = UiStyle.label("", UiStyle.SMALL_FONT_SIZE)
	_summary.name = "ChannelLabel"
	box.add_child(_summary)
	_growth = UiStyle.wrapping_label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	_growth.name = "GrowthLabel"
	box.add_child(_growth)
	for key in ["community", "reputation"]:
		var label := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		box.add_child(label)
		_score_labels[key] = label
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = ChannelSystemScript.MAX_SCORE
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		box.add_child(bar)
		_score_bars[key] = bar
	add_child(UiStyle.section_label("Kanal-Verlauf"))
	_history = VBoxContainer.new()
	_history.name = "ChannelHistory"
	_history.add_theme_constant_override("separation", 8)
	add_child(_history)
	refresh()


func get_title() -> String:
	return "Kanal"


func refresh() -> void:
	var channel = _game.channel
	_summary.text = "Kanal: %s Follower · Community %d · Ruf %d" % [
			ActivityText.format_int(channel.followers), channel.community, channel.reputation]
	_followers.text = "%s Follower" % ActivityText.format_int(channel.followers)
	_growth.text = "Wachstumsbremse: %d %% neuer Follower kommen an (Maximum %s)." % [
			channel.growth_percent(), ActivityText.format_int(ChannelSystemScript.MAX_FOLLOWERS)]
	for key in _score_labels:
		var value: int = channel.get_value(key)
		_score_labels[key].text = "%s %d/%d" % [ChannelSystemScript.LABELS[key], value, ChannelSystemScript.MAX_SCORE]
		_score_bars[key].value = value

	for child in _history.get_children():
		_history.remove_child(child)
		child.queue_free()
	var history: Array = channel.get_history()
	if history.is_empty():
		_history.add_child(UiStyle.label("Noch keine Änderungen.", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		return
	for i in range(history.size() - 1, maxi(history.size() - HISTORY_COUNT, 0) - 1, -1):
		var lines := ActivityText.channel_change_text(history[i])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(UiStyle.wrapping_label(lines[0], UiStyle.SMALL_FONT_SIZE))
		row.add_child(UiStyle.wrapping_label(lines[1], UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
		_history.add_child(row)
