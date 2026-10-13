extends RefCounted

## Reiter im Ortsfenster (G4.6): feste IDs, in dieser Reihenfolge. Jede Aktion an einem Ort (Aktivität, Content-
## Format, Ausrüstung, Unternehmensart) hat in ihren Daten das Pflichtfeld "tab" mit einer dieser IDs.

const IDS: Array[String] = ["alltag", "content", "geschaeft", "unterwelt"]
const LABELS := {"alltag": "Alltag", "content": "Content", "geschaeft": "Geschäft", "unterwelt": "Unterwelt"}
