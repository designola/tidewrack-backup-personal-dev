extends Node
## Owns persisted story and journal state. Journal is a facade over this data.
signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const DEFAULT_SCENE := "res://scenes/game.tscn"
const RESUME_SCENES := [DEFAULT_SCENE, "res://scenes/lamp_room.tscn"]

var flags: Dictionary = {}
var current_scene: String = DEFAULT_SCENE
var _journal_entries: Array[String] = []
# Overridden by tests so they never touch a player's save.
var save_path: String = SAVE_PATH


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func discover_entry(id: String) -> bool:
	if id.strip_edges().is_empty() or id in _journal_entries:
		return false
	_journal_entries.append(id)
	state_changed.emit()
	return true


func journal_entries() -> Array[String]:
	return _journal_entries.duplicate()


func has_entry(id: String) -> bool:
	return id in _journal_entries


func new_game() -> void:
	flags.clear()
	_journal_entries.clear()
	current_scene = DEFAULT_SCENE
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	if current_scene not in RESUME_SCENES:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal_entries": _journal_entries,
	}
	# Write beside the destination before replacing it; failed writes leave the
	# previous save intact. A leftover temporary file is never used by Continue.
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return false
	var result := DirAccess.rename_absolute(temporary, save_path)
	if result != OK:
		DirAccess.remove_absolute(temporary)
	return result == OK


func load_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	# Unversioned saves use the original v1 schema. Never guess at future data.
	var version: Variant = data.get("version", 1)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if version != 1 and version != SAVE_VERSION:
		return false
	var scene: Variant = data.get("scene", DEFAULT_SCENE)
	var loaded_flags: Variant = data.get("flags", {})
	if typeof(scene) != TYPE_STRING or scene not in RESUME_SCENES:
		return false
	if typeof(loaded_flags) != TYPE_DICTIONARY:
		return false
	var entries: Array[String] = []
	if version == SAVE_VERSION:
		var raw_entries: Variant = data.get("journal_entries", [])
		if typeof(raw_entries) != TYPE_ARRAY:
			return false
		for id in raw_entries:
			if typeof(id) != TYPE_STRING or id.strip_edges().is_empty():
				return false
			if id not in entries:
				entries.append(id)
	# Commit together, only after the entire payload has passed validation.
	# Preserve all flag keys and values, including false and unknown flags.
	current_scene = scene
	flags = loaded_flags.duplicate(true)
	_journal_entries = entries
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(save_path + ".tmp"):
		DirAccess.remove_absolute(save_path + ".tmp")
