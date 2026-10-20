class_name AlbumSaveStore
extends RefCounted
## Local player progress. World/editor data deliberately belongs to a separate file.
## Mutations affect memory; callers choose when to save so a transaction pays only once.

const SAVE_VERSION: int = 1
const MAX_BAG_SIZE: int = 8
const MAX_MONEY: int = 1000000000
const MAX_FILE_BYTES: int = 65536

var money: int = 0
var bag: Array[String] = []
var equipped: String = ""
var bar_unlocked: bool = false
var artist_index: int = 0
var performances: int = 0
var mission_state: String = "find_wristband"
var save_path: String = "user://album_save.json"


func load_game() -> bool:
	reset_progress()
	if not _valid_save_path():
		return false
	var data: Dictionary = _read_snapshot(save_path)
	if data.is_empty():
		data = _read_snapshot(save_path + ".bak")
	if data.is_empty():
		return false
	_apply_snapshot(data)
	return true


func save_game() -> bool:
	if not _valid_save_path():
		return false
	var data: Dictionary = _snapshot()
	if not _valid_snapshot(data):
		return false
	var directory: String = ProjectSettings.globalize_path("user://")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var temporary: String = save_path + ".tmp"
	var backup: String = save_path + ".bak"
	var backup_temporary: String = backup + ".tmp"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(temporary)):
		return false
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or _read_snapshot(temporary).is_empty():
		_remove_file(temporary)
		return false
	# Keep the previous valid main file. A corrupt main must never replace a good backup.
	var backup_source: String = ""
	if not _read_snapshot(save_path).is_empty():
		backup_source = save_path
	elif _read_snapshot(backup).is_empty():
		backup_source = temporary
	if not backup_source.is_empty():
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup_temporary)):
			_remove_file(temporary)
			return false
		var copy_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup_source),
			ProjectSettings.globalize_path(backup_temporary)
		)
		if copy_error != OK or _read_snapshot(backup_temporary).is_empty():
			_remove_file(temporary)
			_remove_file(backup_temporary)
			return false
		if _rename_file(backup_temporary, backup) != OK:
			_remove_file(temporary)
			_remove_file(backup_temporary)
			return false
	# Renaming within the same directory replaces the file atomically. Never delete
	# the valid main file first: on failure it must remain available to load_game().
	if _rename_file(temporary, save_path) != OK:
		_remove_file(temporary)
		return false
	return true


func reset_progress() -> void:
	money = 0
	bag.clear()
	equipped = ""
	bar_unlocked = false
	artist_index = 0
	performances = 0
	mission_state = "find_wristband"


func apply_death() -> void:
	money = 0
	equipped = ""


func collect(item: String) -> bool:
	if bag.size() >= MAX_BAG_SIZE or not _valid_label(item):
		return false
	bag.append(item)
	return true


func equip(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	var previous: String = equipped
	equipped = bag[index]
	bag.remove_at(index)
	if not previous.is_empty():
		bag.append(previous)


func unequip() -> void:
	if equipped.is_empty() or bag.size() >= MAX_BAG_SIZE:
		return
	bag.append(equipped)
	equipped = ""


func consume(item: String) -> bool:
	if item.is_empty():
		return false
	if equipped == item:
		equipped = ""
		return true
	var index: int = bag.find(item)
	if index < 0:
		return false
	bag.remove_at(index)
	return true


func _snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"bag": bag.duplicate(),
		"equipped": equipped,
		"bar_unlocked": bar_unlocked,
		"artist_index": artist_index,
		"performances": performances,
		"mission_state": mission_state,
	}


func _apply_snapshot(data: Dictionary) -> void:
	money = int(data.money)
	bag.clear()
	for item in data.bag:
		bag.append(String(item))
	equipped = String(data.equipped)
	bar_unlocked = bool(data.bar_unlocked)
	artist_index = int(data.artist_index)
	performances = int(data.performances)
	mission_state = String(data.mission_state)


func _read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {}
	var contents: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(contents) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not _valid_snapshot(parsed):
		return {}
	return parsed


func _valid_snapshot(data: Dictionary) -> bool:
	for key in ["version", "money", "bag", "equipped", "bar_unlocked", "artist_index", "performances", "mission_state"]:
		if not data.has(key):
			return false
	if not _bounded_integer(data.version, SAVE_VERSION, SAVE_VERSION):
		return false
	if not _bounded_integer(data.money, 0, MAX_MONEY):
		return false
	if not _bounded_integer(data.artist_index, 0, 2):
		return false
	if not _bounded_integer(data.performances, 0, 1000000):
		return false
	if not data.bar_unlocked is bool:
		return false
	if not data.bag is Array or data.bag.size() > MAX_BAG_SIZE:
		return false
	for item in data.bag:
		if not item is String or not _valid_label(item):
			return false
	if not data.equipped is String or not _valid_label(data.equipped, true):
		return false
	if not data.mission_state is String or not _valid_label(data.mission_state):
		return false
	return true


func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


func _valid_label(value: String, allow_empty: bool = false) -> bool:
	if value.is_empty():
		return allow_empty
	if value.length() > 96 or value != value.strip_edges():
		return false
	for character in value.length():
		if value.unicode_at(character) < 32:
			return false
	return true


func _valid_save_path() -> bool:
	# Configuration may choose another local filename for tests; save files cannot
	# redirect access to resources, external files, or parent directories.
	if not save_path.begins_with("user://"):
		return false
	var filename: String = save_path.trim_prefix("user://")
	if filename.is_empty() or filename.length() > 96 or not filename.ends_with(".json"):
		return false
	if filename.contains(".."):
		return false
	for character in filename:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-":
			return false
	return true


func _rename_file(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination)
	)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
