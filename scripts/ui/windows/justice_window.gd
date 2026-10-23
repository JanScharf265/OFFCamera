extends VBoxContainer

## Fenster „Verfahren“ (U.21): Zustand (frei, Untersuchungshaft, auf Kaution, Haft), Akte, Beweislage, Prozess- bzw.
## Entlassungstag, letztes Urteil; „Kaution zahlen“ und „Warten bis …“. Werte und Sperrgründe aus dem JusticeSystem.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LedgerSystemScript := preload("res://scripts/systems/ledger_system.gd")

var _screen
var _game


func setup(screen, game) -> void:
	_screen = screen
	_game = game


func _ready() -> void:
	name = "JusticeContent"
	add_theme_constant_override("separation", 12)
	refresh()


func get_title() -> String:
	return "Verfahren"


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var justice = _game.justice
	var state: String = justice.get_state()
	var status := UiStyle.label(justice.state_label(), UiStyle.FONT_SIZE,
			UiStyle.NEGATIVE if justice.is_locked_up() else UiStyle.WARNING if state == "bail" else UiStyle.TEXT)
	status.name = "JusticeStatus"
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(status)
	var text := ""
	match state:
		"custody", "bail":
			text = "Akte %s · Beweislage %d %% · Prozess am Tag %d vor dem Bezirksgericht an der Küste (Richterin Vidal). Unter %d %% gibt es einen Freispruch." % [
					justice.get_case(), justice.get_evidence(), justice.get_trial_day(),
					justice.get_rules().get_value("conviction_min_evidence")]
		"prison":
			text = "Akte %s · Entlassung am Tag %d. Bis dahin kein Reisen – Organisation, Crew und Telefon laufen weiter." % [
					justice.get_case(), justice.get_release_day()]
		_:
			text = "Kein laufendes Verfahren."
	var detail := UiStyle.wrapping_label(text, UiStyle.MIN_READ_FONT_SIZE, UiStyle.MUTED)
	detail.name = "JusticeDetail"
	add_child(detail)
	if not justice.get_last_verdict().is_empty():
		var verdict := UiStyle.wrapping_label("Zuletzt: " + justice.get_last_verdict(), UiStyle.MIN_READ_FONT_SIZE, UiStyle.TEXT)
		verdict.name = "JusticeVerdict"
		add_child(verdict)
	if state == "custody":
		var reason: String = justice.check_bail()
		var bail: Button = _screen.scroll_button("Kaution zahlen · %s" % LedgerSystemScript.format_cents(justice.bail_cents())
				if reason.is_empty() else reason, "JusticeBailButton")
		bail.disabled = not reason.is_empty()
		bail.custom_minimum_size.y = UiStyle.TOUCH_SIZE
		bail.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		bail.pressed.connect(_screen.on_justice_bail)
		add_child(bail)
	var target: int = justice.wait_target_day()
	if target > 0:
		var wait: Button = _screen.scroll_button("Warten bis Tag %d (%s)" % [target,
				"Prozess" if state in ["custody", "bail"] else "Entlassung"], "JusticeWaitButton")
		UiStyle.style_neutral_button(wait)
		wait.custom_minimum_size.y = UiStyle.TOUCH_SIZE
		wait.add_theme_font_size_override("font_size", UiStyle.SMALL_FONT_SIZE)
		wait.pressed.connect(_screen.on_justice_wait)
		add_child(wait)
	if state != "free":
		_game.tutorials.report("first_justice_open")
