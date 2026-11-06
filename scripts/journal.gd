extends Node
## Public journal API; GameState owns the single persisted entry list.
## Refresh readers on entries_changed; entry_added is for new-discovery toasts.
signal entry_added(id: String)
signal entries_changed


func _ready() -> void:
	GameState.state_changed.connect(func(): entries_changed.emit())


func discover(id: String) -> void:
	if GameState.discover_entry(id):
		entry_added.emit(id)


func entries() -> Array[String]:
	return GameState.journal_entries()


func has(id: String) -> bool:
	return GameState.has_entry(id)
