extends VBoxContainer

## Einstellungen: Geräte-Schalter (G5.1, gespeichert in user://settings.cfg, nicht im Spielstand),
## „Tutorials zurücksetzen“ (T.4, mit Rückfrage, wirkt auf den aktuellen Spielstand), „Hilfe / Lexikon“ (T.4),
## Spielstand löschen (mit Rückfrage; die Schalter bleiben), Zurück.

signal delete_save_pressed
signal back_pressed
signal reset_tutorials_pressed
signal lexicon_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SettingsScript := preload("res://scripts/core/settings.gd")

## Schalter: Schlüssel -> [Knotenname, Text].
const TOGGLES := [
	[SettingsScript.CALENDAR_AUTO_OPEN, "SettingCalendarAutoOpen", "Kalender bei Tagesbeginn automatisch öffnen"],
	[SettingsScript.VIBRATION, "SettingVibration", "Vibration"],
	[SettingsScript.TUTORIALS, "SettingTutorials", "Tutorials anzeigen"],
]

const DELETE_TEXT := "Spielstand löschen"
const CONFIRM_TEXT := "Wirklich löschen? Nochmal tippen"
const RESET_TEXT := "Tutorials zurücksetzen"
const RESET_CONFIRM_TEXT := "Wirklich? Nochmal tippen"

## Vor dem Einfügen in den Baum setzen.
var has_save := false
var message := ""
## Anzahl aufbewahrter defekter Spielstände (Phase 6).
var corrupt_count := 0
## Geräte-Einstellungen (settings.gd); null = Schalter ausblenden.
var device_settings

var _delete_button: Button
var _confirming := false
var _reset_button: Button
var _reset_confirming := false


func _ready() -> void:
	name = "SettingsScreen"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)  # T.4: enger, damit die Seite ins Querformat passt

	var title := UiStyle.label("Einstellungen", UiStyle.LARGE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var status := UiStyle.wrapping_label(
			"Es gibt einen gespeicherten Spielstand." if has_save else "Es gibt keinen gespeicherten Spielstand.",
			UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	status.name = "SaveStatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status)
	if corrupt_count > 0:
		var corrupt := UiStyle.wrapping_label(
				"Aufbewahrte defekte Spielstände: %d (werden mit „Spielstand löschen“ entfernt)." % corrupt_count,
				UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
		corrupt.name = "CorruptCountLabel"
		corrupt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(corrupt)

	if device_settings != null:
		for toggle in TOGGLES:
			add_child(_toggle(toggle[0], toggle[1], toggle[2]))

	if not message.is_empty():
		var message_label := UiStyle.wrapping_label(message, UiStyle.SMALL_FONT_SIZE)
		message_label.name = "MessageLabel"
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(message_label)

	# T.4: beide Tutorial-Buttons in einer Zeile (die Seite muss ohne Scrollen ins Querformat passen).
	var tutorial_row := HBoxContainer.new()
	tutorial_row.name = "TutorialRow"
	tutorial_row.add_theme_constant_override("separation", 12)
	add_child(tutorial_row)
	_reset_button = UiStyle.button(RESET_TEXT)
	_reset_button.name = "ResetTutorialsButton"
	_reset_button.disabled = not has_save
	_reset_button.pressed.connect(_on_reset_pressed)
	tutorial_row.add_child(_reset_button)
	var lexicon := UiStyle.button("Hilfe / Lexikon")
	lexicon.name = "LexiconButton"
	lexicon.pressed.connect(func() -> void: lexicon_pressed.emit())
	tutorial_row.add_child(lexicon)
	for button in [_reset_button, lexicon]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)

	# „Spielstand löschen“ und „Zurück“ ebenfalls in einer Zeile.
	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.add_theme_constant_override("separation", 12)
	add_child(bottom_row)
	_delete_button = UiStyle.button(DELETE_TEXT)
	_delete_button.name = "DeleteSaveButton"
	_delete_button.disabled = not has_save and corrupt_count == 0
	_delete_button.pressed.connect(_on_delete_pressed)
	bottom_row.add_child(_delete_button)
	var back_button := UiStyle.button("Zurück")
	back_button.name = "BackButton"
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	bottom_row.add_child(back_button)
	for button in [_delete_button, back_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	# T.5: Nur der wichtigste Button („Hilfe / Lexikon“) bleibt voll rot; Löschen nur mit rotem Rahmen (Gefahr),
	# Zurücksetzen und Zurück neutral grau.
	UiStyle.style_danger_button(_delete_button)
	UiStyle.style_neutral_button(back_button)
	UiStyle.style_neutral_button(_reset_button)


## Zurücksetzen mit Rückfrage (zweimal tippen, wie beim Löschen).
func _on_reset_pressed() -> void:
	if not _reset_confirming:
		_reset_confirming = true
		_reset_button.text = RESET_CONFIRM_TEXT
		return
	_reset_confirming = false
	_reset_button.text = RESET_TEXT
	reset_tutorials_pressed.emit()


func _on_delete_pressed() -> void:
	if not _confirming:
		_confirming = true
		_delete_button.text = CONFIRM_TEXT
		return
	delete_save_pressed.emit()


## Schalter für eine Geräte-Einstellung; speichert sofort.
func _toggle(key: String, node_name: String, text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = text
	toggle.button_pressed = device_settings.get_flag(key)
	toggle.custom_minimum_size.y = UiStyle.TOUCH_SIZE
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
	UiStyle.style_setting_toggle(toggle)
	toggle.toggled.connect(func(on: bool) -> void:
		var error: String = device_settings.set_flag(key, on)
		if not error.is_empty():
			push_warning(error))
	return toggle
