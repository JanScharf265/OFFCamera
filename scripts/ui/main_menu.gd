extends VBoxContainer

## Hauptmenü: Fortsetzen (nur wenn eine Sitzung existiert), Neues Spiel, Einstellungen.

signal new_game_pressed
signal continue_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

## Vor dem Einfügen in den Baum setzen.
var continue_available := false


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)

	var title := UiStyle.label("OFF CAMERA", UiStyle.TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := UiStyle.label("Prototyp · Phase 1", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 48
	add_child(spacer)

	if continue_available:
		var continue_button := UiStyle.button("Fortsetzen")
		continue_button.name = "ContinueButton"
		continue_button.pressed.connect(func() -> void: continue_pressed.emit())
		add_child(continue_button)

	var new_game_button := UiStyle.button("Neues Spiel")
	new_game_button.name = "NewGameButton"
	new_game_button.pressed.connect(func() -> void: new_game_pressed.emit())
	add_child(new_game_button)

	var settings_button := UiStyle.button("Einstellungen (folgt)")
	settings_button.name = "SettingsButton"
	settings_button.disabled = true
	add_child(settings_button)

	var version := UiStyle.label("v%s · Godot %s" % [
			ProjectSettings.get_setting("application/config/version", "?"),
			Engine.get_version_info()["string"]], UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(version)
