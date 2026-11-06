extends SceneTree
## Run: godot --headless --path . --script tests/test_save.gd
var failures := 0
var state: Node
var notifications := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func write_payload(payload: Variant) -> void:
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _run() -> void:
	state = root.get_node("GameState")
	var journal := root.get_node("Journal")
	state.save_path = "user://journal-regression-test.json"
	state.delete_save()
	state.new_game()
	journal.entry_added.connect(func(_id: String): notifications += 1)
	journal.discover("keeper_log")
	journal.discover("keeper_log")
	journal.discover("  ")
	journal.discover("future_entry")
	check(notifications == 2, "Only valid, new discoveries emit entry_added")
	var copy: Array = journal.entries()
	copy.clear()
	check(journal.entries().size() == 2, "Entry snapshots cannot mutate state")
	var expected_flags := {"trusted_edith": false, "skeptic": true,
		"radioed_tom": true, "lamp_relit": true, "unknown": {"value": "kept"}}
	for key in expected_flags:
		state.set_flag(key, expected_flags[key])
	state.current_scene = "res://scenes/lamp_room.tscn"
	check(state.save_game(), "v2 save succeeds")
	state.new_game()
	check(journal.entries().is_empty(), "New Game resets journal")
	check(state.load_game(), "v2 Continue succeeds")
	check(journal.entries() == ["keeper_log", "future_entry"], "Ordered IDs round trip")
	check(state.flags == expected_flags, "All story flags round trip")
	check(state.current_scene == "res://scenes/lamp_room.tscn", "Scene round trips")
	check(notifications == 2, "Loading never replays discovery notifications")
	for version in [1, null]:
		var legacy := {"flags": expected_flags}
		if version != null:
			legacy["version"] = version
		write_payload(legacy)
		check(state.load_game(), "Legacy save loads")
		check(state.flags == expected_flags, "Legacy flags preserved")
		check(journal.entries().is_empty(), "Legacy load clears stale journal")
		check(state.current_scene == state.DEFAULT_SCENE, "Missing scene defaults")
		check(state.save_game() and state.load_game(), "Legacy resave upgrades safely")
	var valid := {"version": 2, "flags": expected_flags,
		"journal_entries": ["second", "first", "second", "unknown"]}
	write_payload(valid)
	check(state.load_game(), "Duplicate IDs accepted")
	check(journal.entries() == ["second", "first", "unknown"], "Stable deduplication")
	var before: Array = journal.entries()
	for invalid in [null, [], {"version": 3}, {"version": "2"},
		{"version": 1.5}, {"scene": 7}, {"scene": "res://missing.tscn"},
		{"flags": []}, {"version": 2, "journal_entries": null},
		{"version": 2, "journal_entries": ["ok", 4]},
		{"version": 2, "journal_entries": [" "]}]:
		write_payload(invalid)
		check(not state.load_game(), "Invalid payload rejected: %s" % str(invalid))
		check(state.flags == expected_flags and journal.entries() == before,
			"Failed load preserves active state")
	check(state.save_game(), "Restore valid save")
	var original := FileAccess.get_file_as_string(state.save_path)
	DirAccess.make_dir_absolute(state.save_path + ".tmp")
	check(not state.save_game(), "Unwritable staging path reports failure")
	check(FileAccess.get_file_as_string(state.save_path) == original,
		"Failed save preserves prior file")
	DirAccess.remove_absolute(state.save_path + ".tmp")
	state.delete_save()
	check(not state.load_game(), "Missing save fails cleanly")
	print("Save/journal failures: ", failures)
	quit(1 if failures else 0)
