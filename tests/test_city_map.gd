extends "res://tests/base_test.gd"

## Isometrische Stadtkarte (Grafik-Ticket G1): Rasterplan, Fahrstrecken, Tippen vs. Wischen.
## Prüft nur Logik der Darstellung – wie es aussieht, zeigt erst der Editor bzw. das iPhone.

const LocationCatalogScript := preload("res://scripts/systems/location_catalog.gd")
const CityLayoutScript := preload("res://scripts/ui/city_layout.gd")
const CityMapScript := preload("res://scripts/ui/city_map.gd")

const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _catalog() -> LocationCatalogScript:
	var catalog := LocationCatalogScript.new()
	catalog.load_file()
	return catalog


func test_every_location_has_own_lot_next_to_a_road() -> void:
	var catalog := _catalog()
	var layout := CityLayoutScript.new(catalog)
	var used := {}
	for id in catalog.get_ids():
		var cell := layout.get_location_cell(id)
		assert_true(not used.has(cell), "%s teilt sich ein Grundstück" % id)
		used[cell] = true
		assert_true(cell.x >= 0 and cell.x < CityLayoutScript.SIZE, "%s außerhalb der Stadt" % id)
		assert_true(cell.y >= 0 and cell.y <= CityLayoutScript.LAND_LAST, "%s nicht über der Promenade" % id)
		assert_eq(layout.kind_at(cell), CityLayoutScript.Kind.LOCATION, "%s: Zellart" % id)
		assert_eq(layout.get_location_at(cell), id)
		assert_true(layout.is_road(layout.access_cell(id)), "%s hat keine Zufahrt" % id)


func test_layout_is_deterministic() -> void:
	var a := CityLayoutScript.new(_catalog())
	var b := CityLayoutScript.new(_catalog())
	for id in _catalog().get_ids():
		assert_eq(a.get_location_cell(id), b.get_location_cell(id), id)
	for cell in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(-4, 2), Vector2i(12, 11)]:
		assert_eq(a.kind_at(cell), b.kind_at(cell), str(cell))


func test_beach_and_sea_below_promenade() -> void:
	var layout := CityLayoutScript.new(_catalog())
	assert_true(layout.is_road(Vector2i(0, CityLayoutScript.PROMENADE)), "Promenade fehlt")
	assert_eq(layout.kind_at(Vector2i(4, CityLayoutScript.BEACH_ROW)), CityLayoutScript.Kind.BEACH)
	assert_eq(layout.kind_at(Vector2i(4, CityLayoutScript.BEACH_ROW + 1)), CityLayoutScript.Kind.SEA)


func test_travel_path_follows_roads_between_all_locations() -> void:
	var catalog := _catalog()
	var layout := CityLayoutScript.new(catalog)
	for from_id in catalog.get_ids():
		for to_id in catalog.get_ids():
			var path := layout.travel_path(from_id, to_id)
			if from_id == to_id:
				assert_true(path.is_empty(), "Fahrt zu sich selbst")
				continue
			var label := "%s → %s" % [from_id, to_id]
			assert_true(path.size() >= 3, label + ": zu kurz")
			if path.size() < 3:
				continue
			assert_eq(path[0], layout.get_location_cell(from_id), label + ": Start")
			assert_eq(path[path.size() - 1], layout.get_location_cell(to_id), label + ": Ziel")
			for i in range(1, path.size() - 1):
				assert_true(layout.is_road(path[i]), "%s: %s ist keine Straße" % [label, path[i]])
			for i in range(1, path.size()):
				assert_true(path[i] - path[i - 1] in NEIGHBORS, "%s: Sprung bei %s" % [label, path[i]])


func test_unknown_location_gives_empty_path() -> void:
	var layout := CityLayoutScript.new(_catalog())
	assert_true(layout.travel_path("home", "mond").is_empty(), "unbekanntes Ziel")


func test_world_and_cell_conversion_round_trip() -> void:
	for cell in [Vector2(0, 0), Vector2(3, 7), Vector2(-2, 5)]:
		assert_eq(CityLayoutScript.world_to_cell(CityLayoutScript.cell_to_world(cell)), cell)


func test_map_has_sign_per_location_and_marker() -> void:
	var map := _start_map()
	for id in _catalog().get_ids():
		assert_true(map.find_child("MapPin_%s" % id, true, false) != null, "Schild %s fehlt" % id)
	var marker := map.find_child("LocationMarker", true, false) as Control
	assert_true(marker != null and marker.visible, "Standortmarkierung fehlt")
	map.free()


func test_tap_on_building_selects_location() -> void:
	var map := _start_map()
	var pressed: Array[String] = []
	map.location_pressed.connect(func(id: String) -> void: pressed.append(id))
	var point := _building_point(map, "studio")
	_touch(map, point, true)
	_touch(map, point, false)
	assert_eq(pressed, ["studio"] as Array[String])
	map.free()


func test_swipe_moves_map_and_selects_nothing() -> void:
	var map := _start_map()
	var pressed: Array[String] = []
	map.location_pressed.connect(func(id: String) -> void: pressed.append(id))
	var point := _building_point(map, "home")
	var offset_before: Vector2 = map._offset
	_touch(map, point, true)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = point + Vector2(-40, -30)
	motion.relative = Vector2(-40, -30)
	map._gui_input(motion)
	_touch(map, motion.position, false)
	assert_true(pressed.is_empty(), "Wischen hat einen Ort ausgewählt")
	assert_true(map._offset != offset_before, "Karte hat sich nicht verschoben")
	# Auch ein Schild löst nach dem Wischen nichts aus.
	(map.find_child("MapPin_home", true, false) as Button).pressed.emit()
	assert_true(pressed.is_empty(), "Schild nach dem Wischen ausgelöst")
	map.free()


func test_travel_animation_ends_at_destination() -> void:
	var map := _start_map()
	map.set_state("studio", "studio")
	map.play_travel("home", "studio")
	assert_true(map.is_traveling(), "Fahrt startet nicht")
	map.finish_travel()
	assert_true(not map.is_traveling(), "Fahrt läuft noch")
	assert_eq(map.get_car_cell(), map.get_layout().access_cell("studio"))
	map.free()


func _start_map() -> CityMapScript:
	var map := CityMapScript.new()
	map.setup(_catalog())
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	map.size = Vector2(1280, 720)
	map.set_state("home", "home")
	map._on_resized()
	return map


func _building_point(map: CityMapScript, location_id: String) -> Vector2:
	var cell := map.get_layout().get_location_cell(location_id)
	return map._to_screen(CityLayoutScript.cell_to_world(Vector2(cell)) + Vector2(0, 20))


func _touch(map: CityMapScript, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	map._gui_input(event)


func test_zoom_is_limited_and_keeps_point_under_finger() -> void:
	var map := _start_map()
	var point := Vector2(640, 360)
	var world_before: Vector2 = (point - map._offset) / map.get_zoom()
	map.zoom_at(point, 1.2)
	var world_after: Vector2 = (point - map._offset) / map.get_zoom()
	assert_true(world_before.distance_to(world_after) < 1.0, "Punkt unter dem Finger verschoben")
	map.zoom_at(point, 10.0)
	assert_eq(map.get_zoom(), CityMapScript.MAX_ZOOM)
	map.zoom_at(point, 0.01)
	assert_eq(map.get_zoom(), CityMapScript.MIN_ZOOM)
	map.free()


func test_wheel_zooms() -> void:
	var map := _start_map()
	var before: float = map.get_zoom()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(640, 360)
	map._gui_input(wheel)
	assert_true(map.get_zoom() > before, "Mausrad zoomt nicht")
	map.free()


func test_two_finger_pinch_zooms_without_tap() -> void:
	var map := _start_map()
	var pressed: Array[String] = []
	map.location_pressed.connect(func(id: String) -> void: pressed.append(id))
	var before: float = map.get_zoom()
	_finger(map, 0, Vector2(600, 360), true)
	_finger(map, 1, Vector2(700, 360), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(760, 360)  # Abstand 100 -> 160
	map._gui_input(drag)
	assert_true(map.get_zoom() > before, "Zwei-Finger-Geste zoomt nicht")
	_finger(map, 1, Vector2(760, 360), false)
	_finger(map, 0, Vector2(600, 360), false)
	_touch(map, Vector2(600, 360), false)  # nachgebildetes Loslassen
	assert_true(pressed.is_empty(), "Zoomen hat einen Ort ausgewählt")
	map.free()


func _finger(map: CityMapScript, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	map._gui_input(event)


## Phase 7: Die Markierung wippt nur kurz – sonst müsste Godot im Stromsparmodus jedes Bild neu zeichnen.
func test_marker_stops_bobbing_after_a_few_seconds() -> void:
	var map := _start_map()
	var marker := map.find_child("LocationMarker", true, false) as Control
	assert_eq(marker.is_processing(), true)
	marker._process(CityMapScript.Marker.BOB_SECONDS + 0.1)
	assert_eq(marker.is_processing(), false)
	assert_eq(marker.position, marker.base_position)
	map.set_state("studio", "studio")  # Ankunft: kurz wieder wippen
	assert_eq(marker.is_processing(), true)
	map.free()
