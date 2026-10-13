extends "res://tests/base_test.gd"

## Ticket G3.2: Jedes App-Symbol im iOS-Export-Preset existiert, hat die Größe aus dem Schlüssel
## und keine Transparenz (Vorgabe von iOS).

const PRESETS := "res://export_presets.cfg"


func _icon_entries() -> Dictionary:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS), OK)
	var entries := {}
	for section in config.get_sections():
		if not section.ends_with(".options"):
			continue
		for key in config.get_section_keys(section):
			if key.begins_with("icons/") and not key.ends_with("_dark") and not key.ends_with("_tinted"):
				entries[key] = String(config.get_value(section, key))
	return entries


func test_all_icon_slots_are_filled() -> void:
	var entries := _icon_entries()
	assert_true(entries.size() >= 17, "zu wenige Icon-Einträge: %d" % entries.size())
	for key in entries:
		assert_true(not entries[key].is_empty(), "%s ist leer" % key)


func test_icons_have_matching_size_and_no_alpha() -> void:
	var entries := _icon_entries()
	for key in entries:
		var path: String = entries[key]
		if path.is_empty():
			continue
		var image := Image.new()  # aus den Bytes, ohne Import-Warnung
		var err := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		assert_eq(err, OK, "%s nicht lesbar: %s" % [key, path])
		if err != OK:
			continue
		var size := int(key.get_slice("_", key.get_slice_count("_") - 1).get_slice("x", 0))
		assert_eq(image.get_width(), size, key)
		assert_eq(image.get_height(), size, key)
		assert_true(not image.detect_alpha(), "%s hat Transparenz" % key)
