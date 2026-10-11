class_name ChannelChange
extends RefCounted

## Ein Eintrag im Kanal-Protokoll: warum sich Follower, Community-Stimmung oder
## Ruf geändert haben. Wird nur vom ChannelSystem erzeugt und danach nicht mehr verändert.
##
## requested = gewünschte Änderung (z. B. vom Content-Format berechnet),
## applied   = tatsächlich angewendete Änderung nach Wachstumsbremse und Grenzen.

var id: String
var time_minutes: int
## Auslösendes System, z. B. "content", "event".
var source: String
## Begründung für die Anzeige, z. B. "Livestream (Basis 60, Equipment +20 %)".
var reason: String
## Optionale Referenz auf Format, Ereignis o. Ä. (ID).
var reference: String
## Schlüssel aus ChannelSystem.KEYS -> int (nur Werte ≠ 0)
var requested: Dictionary
var applied: Dictionary


func _init(p_id: String, p_time_minutes: int, p_source: String, p_reason: String,
		p_reference: String, p_requested: Dictionary, p_applied: Dictionary) -> void:
	id = p_id
	time_minutes = p_time_minutes
	source = p_source
	reason = p_reason
	reference = p_reference
	requested = p_requested
	applied = p_applied


## true, wenn Bremse oder Grenzen etwas abgeschnitten haben.
func was_limited() -> bool:
	for key in requested:
		if int(applied.get(key, 0)) != int(requested[key]):
			return true
	return false
