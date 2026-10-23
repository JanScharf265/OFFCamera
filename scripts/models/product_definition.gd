extends RefCounted

## Ein Produkt der Unterwelt aus data/underworld/products.json (U.5) – reine Spielwerte je abstrakter „Einheit“
## (keine echten Mengen, Gewichte oder Preise).

var id: String
var display_name: String
var description: String
## Einkaufspreis je Einheit (Cent)
var buy_price_cents: int
## Grund-Verkaufspreis je Einheit (Cent); Nachfrage je Gebiet kommt mit U.12
var sell_price_cents: int
## Grundqualität 0–100
var quality: int
## Hitze je verkaufter Einheit
var heat_per_unit: int
var order: int


## Marge je Einheit (Cent).
func margin_cents() -> int:
	return sell_price_cents - buy_price_cents
