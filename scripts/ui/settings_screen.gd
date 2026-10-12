extends VBoxContainer

## Einstellungen: Spielstand löschen (mit Rückfrage), Zurück.

signal delete_save_pressed
signal back_pressed

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const DELETE_TEXT := "Spielstand löschen"
const CONFIRM_TEXT := "Wirklich löschen? Nochmal tippen"

## Vor dem Einfügen in den Baum setzen.
var has_save := false
var message := ""
## Anzahl aufbewahrter defekter Spielstände (Phase 6).
var corrupt_count := 0

var _delete_button: Button
var _confirming := false


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)

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

	if not message.is_empty():
		var message_label := UiStyle.wrapping_label(message, UiStyle.SMALL_FONT_SIZE)
		message_label.name = "MessageLabel"
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(message_label)

	_delete_button = UiStyle.button(DELETE_TEXT)
	_delete_button.name = "DeleteSaveButton"
	_delete_button.disabled = not has_save and corrupt_count == 0
	_delete_button.pressed.connect(_on_delete_pressed)
	add_child(_delete_button)

	var back_button := UiStyle.button("Zurück")
	back_button.name = "BackButton"
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back_button)


func _on_delete_pressed() -> void:
	if not _confirming:
		_confirming = true
		_delete_button.text = CONFIRM_TEXT
		return
	delete_save_pressed.emit()
