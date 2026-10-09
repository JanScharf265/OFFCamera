extends Control

## Phase-0-Startbildschirm: zeigt nur, dass die App läuft,
## und mit welcher App- und Engine-Version sie gebaut wurde.

@onready var _version_label: Label = $Center/Content/VersionLabel


func _ready() -> void:
	var app_version: String = ProjectSettings.get_setting("application/config/version", "?")
	var engine_version: String = Engine.get_version_info()["string"]
	_version_label.text = "v%s · Godot %s" % [app_version, engine_version]
