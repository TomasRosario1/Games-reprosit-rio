class_name AlbumRhythmGame
extends RefCounted
## Deterministic four-lane rhythm rules. The caller owns audio and bank balance.
## Sync with advance_to(audio_time) where possible; step(delta) is a fallback.
## `finished` is the only payout event and is emitted at most once per start().

signal finished(success: bool, money: int)
signal note_judged(lane: int, hit: bool)

const DIFFICULTY_EASY := 0
const DIFFICULTY_NORMAL := 1
const DIFFICULTY_HARD := 2
const NOTE_PATTERN := [0, 2, 1, 3, 0, 1, 3, 2, 1, 0, 2, 3, 2, 0, 3, 1]
const AUDIENCE_RECOVERY := 5.0
const MISSED_NOTE_PENALTY := 13.0
const WRONG_PRESS_PENALTY := 4.0

var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.0
var notes: Array[Dictionary] = []
var audience: float = 75.0
var hits: int = 0
var misses: int = 0
var score: int = 0
var pending_money: int = 0
var difficulty: int = DIFFICULTY_EASY
var bpm: float = 100.0
var hit_window: float = 0.22
var last_payout: int = 0
var last_success: bool = false
var _finished_emitted: bool = false


func start(song_duration: float, song_difficulty: int, song_bpm: float = 100.0) -> void:
	# A playable chart needs a short lead-in and a last-note judgement window.
	duration = maxf(1.0, song_duration)
	difficulty = clampi(song_difficulty, DIFFICULTY_EASY, DIFFICULTY_HARD)
	bpm = clampf(song_bpm, 40.0, 240.0)
	hit_window = [0.22, 0.18, 0.14][difficulty]
	elapsed = 0.0
	audience = 75.0
	hits = 0
	misses = 0
	score = 0
	pending_money = 0
	last_payout = 0
	last_success = false
	_finished_emitted = false
	notes.clear()
	var beat := 60.0 / bpm
	var spacing: float = beat * [2.0, 1.0, 0.5][difficulty]
	# The lead-in is beat-aligned for ordinary songs; very short tests get one note.
	var lead_in := minf(beat * 4.0, duration * 0.25)
	var final_note_time := duration - hit_window - 0.05
	var note_time := lead_in
	var index := 0
	while note_time <= final_note_time:
		notes.append({"lane": NOTE_PATTERN[index % NOTE_PATTERN.size()], "time": note_time, "state": "pending"})
		note_time = lead_in + float(index + 1) * spacing
		index += 1
	if notes.is_empty():
		notes.append({"lane": 0, "time": duration * 0.5, "state": "pending"})
	active = true


func step(delta: float) -> void:
	if active and delta > 0.0:
		advance_to(elapsed + delta)


func advance_to(song_time: float) -> void:
	if not active or not is_finite(song_time):
		return
	# A looped playback position must not rewind a performance or revive notes.
	elapsed = clampf(maxf(elapsed, song_time), 0.0, duration)
	for index in notes.size():
		var note: Dictionary = notes[index]
		if note["state"] == "pending" and elapsed > float(note["time"]) + hit_window:
			notes[index]["state"] = "miss"
			misses += 1
			audience = maxf(0.0, audience - MISSED_NOTE_PENALTY)
			note_judged.emit(int(note["lane"]), false)
			if audience <= 0.0:
				_finish(false)
				return
	if elapsed >= duration:
		_finish(audience > 0.0)


func press(lane: int) -> Dictionary:
	var result := {"hit": false, "judgement": "inactive", "lane": lane, "money_delta": 0, "note_index": -1}
	if not active or lane < 0 or lane > 3:
		return result
	var closest_index := -1
	var closest_offset := INF
	for index in notes.size():
		var note: Dictionary = notes[index]
		if note["state"] != "pending" or int(note["lane"]) != lane:
			continue
		var offset := absf(elapsed - float(note["time"]))
		if offset <= hit_window and offset < closest_offset:
			closest_index = index
			closest_offset = offset
	if closest_index >= 0:
		notes[closest_index]["state"] = "hit"
		hits += 1
		score += 100
		var reward := 15 if difficulty == DIFFICULTY_HARD else 10
		pending_money += reward
		audience = minf(100.0, audience + AUDIENCE_RECOVERY)
		result["hit"] = true
		result["judgement"] = "perfeito" if closest_offset <= hit_window * 0.4 else "bom"
		result["money_delta"] = reward
		result["note_index"] = closest_index
		note_judged.emit(lane, true)
		return result
	# One judgement per note. Repeated keyboard events cannot create money.
	misses += 1
	audience = maxf(0.0, audience - WRONG_PRESS_PENALTY)
	result["judgement"] = "falhou"
	note_judged.emit(lane, false)
	if audience <= 0.0:
		_finish(false)
	return result


func stop() -> void:
	# Voluntarily abandoning the performance forfeits its provisional earnings.
	active = false
	pending_money = 0
	last_payout = 0
	last_success = false


func _finish(success: bool) -> void:
	if _finished_emitted or not active:
		return
	active = false
	_finished_emitted = true
	last_success = success
	last_payout = pending_money if success else 0
	if not success:
		pending_money = 0
	finished.emit(success, last_payout)
