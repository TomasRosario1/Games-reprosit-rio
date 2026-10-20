extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
var checks: int = 0
var failures: Array[String] = []
var test_paths: Array[String] = []
var run_id: String = str(Time.get_ticks_usec())


func _initialize() -> void:
	_test_roundtrip()
	_test_inventory()
	_test_death()
	_test_backup_recovery()
	_test_invalid_data()
	_test_invalid_save_preserves_main()
	_test_write_failure_preserves_main()
	_test_path_restrictions()
	for path in test_paths:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for message in failures:
		printerr(message)
	print("Save rules: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _store(name: String):
	var store = SaveStore.new()
	store.save_path = "user://test_save_%s_%s.json" % [run_id, name]
	test_paths.append(store.save_path)
	return store


func _test_roundtrip() -> void:
	var store = _store("roundtrip")
	expect(not store.load_game(), "Missing main and backup must report no saved game")
	store.money = 325
	store.collect("wristband")
	store.collect("water")
	store.equipped = "ticket"
	store.bar_unlocked = true
	store.artist_index = 2
	store.performances = 4
	store.mission_state = "play_music"
	expect(store.save_game(), "Initial save must succeed")
	var loaded = SaveStore.new()
	loaded.save_path = store.save_path
	expect(loaded.load_game(), "Valid JSON must load")
	expect(loaded.money == 325 and loaded.bag == ["wristband", "water"], "Money and bag must roundtrip")
	expect(loaded.equipped == "ticket" and loaded.bar_unlocked, "Equipment and bar access must roundtrip")
	expect(loaded.artist_index == 2 and loaded.performances == 4 and loaded.mission_state == "play_music", "Artist and mission progress must roundtrip")
	expect(FileAccess.file_exists(store.save_path + ".bak"), "First save must leave a valid fallback")
	expect(not FileAccess.file_exists(store.save_path + ".tmp"), "Successful save must consume temporary file")
	store.reset_progress()
	expect(store.money == 0 and store.bag.is_empty() and not store.bar_unlocked, "Reset must restore initial in-memory progress")
	expect(loaded.load_game() and loaded.money == 325, "In-memory reset must not delete a saved game")


func _test_inventory() -> void:
	var store = _store("inventory")
	for index in 8:
		expect(store.collect("item_%d" % index), "Bag must accept up to eight objects")
	expect(not store.collect("extra") and store.bag.size() == 8, "Ninth object must be rejected")
	expect(not store.collect(""), "Empty item ID must be rejected")
	store.equip(2)
	expect(store.equipped == "item_2" and store.bag.size() == 7, "Equipping must move one object out of bag")
	store.equip(0)
	expect(store.equipped == "item_0" and store.bag.has("item_2") and store.bag.size() == 7, "Equipping again must store previous object without loss")
	expect(store.collect("extra"), "Equipped object is separate from eight bag spaces")
	store.unequip()
	expect(store.equipped == "item_0" and store.bag.size() == 8, "Full bag must not destroy or duplicate equipped object")
	expect(store.consume("item_0") and store.equipped.is_empty(), "Consume must search equipped object first")
	expect(store.consume("extra") and store.bag.size() == 7, "Consume must also search bag")
	expect(not store.consume("missing"), "Missing item cannot be consumed")
	store.equip(-1)
	store.equip(999)
	expect(store.equipped.is_empty() and store.bag.size() == 7, "Invalid equipment indices must be harmless")
	store.equipped = "item_2"
	expect(store.consume("item_2") and store.bag.has("item_2"), "Consuming equipped duplicate must preserve bag duplicate")
	store.equipped = "water"
	store.unequip()
	expect(store.equipped.is_empty() and store.bag.has("water") and store.bag.size() == 8, "Unequip must store object when a bag space is free")


func _test_death() -> void:
	var store = _store("death")
	store.money = 230
	store.collect("wristband")
	store.equipped = "water"
	store.bar_unlocked = true
	store.artist_index = 1
	store.performances = 2
	store.mission_state = "play_music"
	store.apply_death()
	expect(store.money == 0 and store.equipped.is_empty(), "Death must remove money and equipped item")
	expect(store.bag == ["wristband"], "Death must preserve bag contents")
	expect(store.bar_unlocked and store.artist_index == 1 and store.performances == 2 and store.mission_state == "play_music", "Death must preserve unlocked access and progression")
	expect(store.save_game(), "Post-death state must save")
	store.money = 100
	expect(store.load_game() and store.money == 0 and store.bag == ["wristband"], "Death persistence must roundtrip")


func _test_backup_recovery() -> void:
	var store = _store("backup")
	store.money = 10
	expect(store.save_game(), "Backup test first save must succeed")
	store.money = 20
	expect(store.save_game(), "Backup test second save must succeed")
	_write(store.save_path, "{incomplete")
	expect(store.load_game() and store.money == 10, "Corrupt main must recover previous valid snapshot")
	store.money = 30
	expect(store.save_game(), "Saving after backup recovery must succeed")
	_write(store.save_path, "{incomplete again")
	expect(store.load_game() and store.money == 10, "A corrupt old main must not replace the good backup during repair")


func _test_invalid_data() -> void:
	var store = _store("invalid")
	var valid: Dictionary = {
		"version": 1, "money": 10, "bag": ["wristband"], "equipped": "",
		"bar_unlocked": false, "artist_index": 0, "performances": 0, "mission_state": "find_wristband",
	}
	var invalid_values: Array[Dictionary] = [
		{"version": 2}, {"money": -1}, {"money": "100"}, {"money": 1.5},
		{"money": 1000000001}, {"artist_index": 3}, {"artist_index": true},
		{"performances": -1}, {"bar_unlocked": 1}, {"equipped": ["water"]},
		{"bag": [1]}, {"bag": ["a", "b", "c", "d", "e", "f", "g", "h", "i"]},
		{"mission_state": ""}, {"mission_state": "bad\nstate"},
	]
	for changes in invalid_values:
		var changed: Dictionary = valid.duplicate(true)
		changed.merge(changes, true)
		_write(store.save_path, JSON.stringify(changed))
		store.money = 999
		expect(not store.load_game() and store.money == 0, "Invalid field must reject the whole snapshot: %s" % str(changes))
	for invalid_json in ["[]", "null", "{}", "not json"]:
		_write(store.save_path, invalid_json)
		expect(not store.load_game(), "Invalid JSON root or missing required fields must be rejected")
	_write(store.save_path, " ".repeat(65537))
	expect(not store.load_game(), "Oversized file must be rejected before parsing")


func _test_invalid_save_preserves_main() -> void:
	var store = _store("preserve")
	store.money = 90
	expect(store.save_game(), "Preservation test initial save must succeed")
	store.money = -200
	expect(not store.save_game(), "Invalid in-memory data must not overwrite a saved game")
	expect(store.load_game() and store.money == 90, "Rejected save must leave valid main file intact")


func _test_write_failure_preserves_main() -> void:
	var store = _store("write_failure")
	store.money = 45
	expect(store.save_game(), "Write failure test initial save must succeed")
	var obstruction: String = ProjectSettings.globalize_path(store.save_path + ".bak.tmp")
	expect(DirAccess.make_dir_absolute(obstruction) == OK, "Write failure fixture must obstruct backup staging")
	store.money = 180
	expect(not store.save_game(), "Failed backup staging must abort replacement")
	expect(store.load_game() and store.money == 45, "I/O failure must preserve valid main snapshot")
	expect(not FileAccess.file_exists(store.save_path + ".tmp"), "Failed write must clean up staged new main")
	DirAccess.remove_absolute(obstruction)


func _test_path_restrictions() -> void:
	var store = SaveStore.new()
	for path in ["/tmp/not_allowed.json", "res://not_allowed.json", "user://../escape.json", "user://nested/test.json", "user://test.txt"]:
		store.save_path = path
		expect(not store.save_game() and not store.load_game(), "Save path must remain a simple JSON filename in user://")


func _write(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Test could not write fixture: " + path)
		return
	file.store_string(contents)
	file.close()
