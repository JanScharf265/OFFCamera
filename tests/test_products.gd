extends "res://tests/base_test.gd"

## Ticket U.5: Produkte als Daten – die echte Datei lädt (Gras, Haschisch, Pillen, Koks mit Spielwerten je Einheit),
## jeder Fehler wird gemeldet und lädt nichts; die Spieldaten enthalten die Produkte.

const Helpers := preload("res://tests/helpers.gd")
const ProductCatalogScript := preload("res://scripts/systems/product_catalog.gd")


func _product(id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "display_name": "P", "description": "Text.", "buy_price_cents": 1000,
			"sell_price_cents": 2000, "quality": 50, "heat_per_unit": 2, "order": 0}
	result.merge(extra, true)
	return result


func test_real_products_load() -> void:
	var catalog := ProductCatalogScript.new()
	assert_true(catalog.load_file(), "; ".join(catalog.errors))
	assert_eq(catalog.get_ids(), PackedStringArray(["weed", "hash", "pills", "coke"]))
	var names := []
	for definition in catalog.get_all():
		names.append(definition.display_name)
		assert_true(definition.margin_cents() > 0, definition.id)
	assert_eq(names, ["Gras", "Haschisch", "Pillen", "Koks"])
	assert_eq(catalog.get_definition("coke").heat_per_unit, 4)
	assert_eq(catalog.has("nope"), false)


func test_game_data_contains_products() -> void:
	var data := Helpers.game_data()
	assert_eq(data.errors, PackedStringArray())
	assert_eq(data.products.get_all().size(), 4)


func test_bad_products_are_rejected() -> void:
	var catalog := ProductCatalogScript.new()
	for bad in [[_product("p_a", {"sell_price_cents": 1000})], [_product("p_a", {"buy_price_cents": 0})],
			[_product("p_a", {"quality": 101})], [_product("p_a", {"heat_per_unit": 0})],
			[_product("p_a", {"heat_per_unit": ProductCatalogScript.MAX_HEAT_PER_UNIT + 1})],
			[_product("p_a", {"grams": 5})], [_product("p_a"), _product("p_a")], [_product("p_a", {"order": -1})],
			[_product("p_a", {"description": "x".repeat(ProductCatalogScript.MAX_TEXT_LENGTH + 1)})],
			[{"display_name": "ohne ID"}], {"weed": {}}]:
		assert_eq(catalog.load_data(bad), false, "angenommen: %s" % [bad])
		assert_eq(catalog.get_all().size(), 0)
	# Ein fehlerhaftes neben gültigen: nichts geladen.
	assert_eq(catalog.load_data([_product("p_ok"), _product("p_bad", {"quality": -1})]), false)
	assert_eq(catalog.get_all().size(), 0)
