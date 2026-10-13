App-Symbol „Halbes Objektiv“ (Ticket G3.2, Entwurf A aus G3.1): eigenes Werk, keine Fremdlizenz.
- `app_icon.svg`: Quelle für alle Größen ab 114 px.
- `app_icon_small.svg`: vereinfachte Quelle bis 87 px (größere Form, dickerer Ring, kein Glanzlicht, hellere
  Schattenhälfte, größere Pupille) – damit es in 40/60 px erkennbar bleibt.
- `app_icon_<px>.png`: erzeugt mit `tools/icon/make_icon.gd`, ohne Transparenz (Vorgabe von iOS),
  eingetragen in `export_presets.cfg` (icons/…). Die SVGs selbst sind vom Export ausgeschlossen.
