extends VBoxContainer

## Hauptmenü: Fortsetzen (nur wenn es eine Sitzung oder einen Spielstand gibt),
## Neues Spiel (mit Rückfrage, wenn dabei ein Spielstand überschrieben wird),
## Einstellungen.

signal new_game_pressed
signal continue_pressed
signal settings_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const NEW_GAME_TEXT := "Neues Spiel"
const CONFIRM_TEXT := "Wirklich neu beginnen? Nochmal tippen"

## Vor dem Einfügen in den Baum setzen.
var continue_available := false
## Hinweis- oder Fehlertext unter dem Titel (z. B. beschädigter Spielstand).
var message := ""
## „Neues Spiel“ braucht einen zweiten Tipp, wenn dabei etwas verloren gehen könnte – ein Spiel oder
## aufbewahrte defekte Spielstände (Phase 6). Standard: wie continue_available.
var confirm_new_game := false
## Kurzinfo zum Spielstand unter „Fortsetzen“ (Phase 6), z. B. "Tag 9 · Di, 08:00 · 400,00 € · gespeichert …".
var save_info := ""

var _new_game_button: Button
var _confirming := false


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)

	var title := UiStyle.label("OFF CAMERA", UiStyle.TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := UiStyle.label("Prototyp", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	if not message.is_empty():
		var message_label := UiStyle.wrapping_label(message, UiStyle.SMALL_FONT_SIZE, UiStyle.NEGATIVE)
		message_label.name = "MessageLabel"
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(message_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	add_child(spacer)

	if continue_available:
		var continue_button := UiStyle.button("Fortsetzen")
		continue_button.name = "ContinueButton"
		continue_button.pressed.connect(func() -> void: continue_pressed.emit())
		add_child(continue_button)
		if not save_info.is_empty():
			var info := UiStyle.wrapping_label(save_info, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
			info.name = "SaveInfoLabel"
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(info)

	_new_game_button = UiStyle.button(NEW_GAME_TEXT)
	_new_game_button.name = "NewGameButton"
	_new_game_button.pressed.connect(_on_new_game_pressed)
	add_child(_new_game_button)

	var settings_button := UiStyle.button("Einstellungen")
	settings_button.name = "SettingsButton"
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings_button)

	var version := UiStyle.label("v%s · Godot %s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			Engine.get_version_info()["string"]], UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(version)


## Gibt es schon ein Spiel, braucht "Neues Spiel" einen zweiten Tipp.
func _on_new_game_pressed() -> void:
	if (continue_available or confirm_new_game) and not _confirming:
		_confirming = true
		_new_game_button.text = CONFIRM_TEXT
		return
	new_game_pressed.emit()
