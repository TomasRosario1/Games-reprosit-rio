extends SceneTree

const RhythmGame = preload("res://scripts/rhythm_game.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_chart_difficulty()
	_test_hits_and_duplicate_presses()
	_test_miss_recovery_and_failure()
	_test_complete_payout()
	_test_frame_independence()
	_test_cancel()
	for message in failures:
		printerr(message)
	print("Rhythm rules: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_chart_difficulty() -> void:
	var counts: Array[int] = []
	for difficulty in 3:
		var game = RhythmGame.new()
		game.start(12.0, difficulty, 100.0)
		counts.append(game.notes.size())
		expect(not game.notes.is_empty(), "Every difficulty must contain playable notes")
		for note in game.notes:
			expect(note.lane >= 0 and note.lane < 4, "Chart lane outside four-lane range")
			expect(note.time + game.hit_window < game.duration, "Last note must have a judgement window before song ends")
	expect(counts[0] < counts[1] and counts[1] < counts[2], "Harder charts must have more notes")
	var short_game = RhythmGame.new()
	short_game.start(0.1, 0)
	expect(short_game.notes.size() >= 1, "Short track cannot silently create zero notes")


func _test_hits_and_duplicate_presses() -> void:
	for difficulty in 3:
		var game = RhythmGame.new()
		game.start(12.0, difficulty)
		var first: Dictionary = game.notes[0]
		game.advance_to(first.time)
		var result: Dictionary = game.press(first.lane)
		var reward := 15 if difficulty == 2 else 10
		expect(result.hit, "A note pressed exactly on time must hit")
		expect(game.hits == 1 and game.score == 100, "Hit must count exactly once")
		expect(game.pending_money == reward, "Wrong difficulty reward")
		expect(game.last_payout == 0, "Money cannot be paid before completion")
		game.press(first.lane)
		expect(game.hits == 1 and game.pending_money == reward, "Repeated press must not earn twice")
		expect(game.notes[0].state == "hit", "Hit note cannot return to pending")


func _test_miss_recovery_and_failure() -> void:
	var game = RhythmGame.new()
	game.start(30.0, 1)
	var first: Dictionary = game.notes[0]
	game.advance_to(first.time + game.hit_window + 0.001)
	expect(game.misses == 1 and game.notes[0].state == "miss", "Expired note must auto-miss once")
	var audience_after_miss: float = game.audience
	game.advance_to(first.time + game.hit_window + 0.002)
	expect(game.misses == 1, "Missed note cannot be charged again next frame")
	var second: Dictionary = game.notes[1]
	game.advance_to(second.time)
	game.press(second.lane)
	expect(game.audience > audience_after_miss, "Hits must let audience recover")
	expect(game.pending_money > 0, "Test must accumulate money before failure")
	game.advance_to(game.duration)
	expect(not game.active and not game.last_success, "No audience must end in failure")
	expect(game.audience == 0.0 and game.pending_money == 0 and game.last_payout == 0, "Audience failure must forfeit provisional earnings")
	var old_hits: int = game.hits
	game.press(second.lane)
	expect(game.hits == old_hits, "No input after a failed performance")


func _test_complete_payout() -> void:
	for difficulty in 3:
		var game = RhythmGame.new()
		var paid: Array[int] = []
		game.finished.connect(func(_success: bool, money: int): paid.append(money))
		game.start(12.0, difficulty)
		for note in game.notes:
			game.advance_to(note.time)
			game.press(note.lane)
		expect(paid.is_empty(), "No payout signal until the song finishes")
		game.advance_to(game.duration)
		var reward := 15 if difficulty == 2 else 10
		expect(game.last_success and not game.active, "Perfect performance must finish successfully")
		expect(game.last_payout == game.notes.size() * reward, "Payout must equal per-note reward times hits")
		expect(paid.size() == 1 and paid[0] == game.last_payout, "Exactly one payout signal per song")
		game.advance_to(game.duration + 5.0)
		game.step(5.0)
		game.press(0)
		expect(paid.size() == 1, "A completed song cannot pay again")


func _test_frame_independence() -> void:
	for fps in [30, 60, 144]:
		var game = RhythmGame.new()
		game.start(20.0, 1)
		var target: float = game.notes[0].time + 0.10
		while game.elapsed + 1.0 / float(fps) < target:
			game.step(1.0 / float(fps))
		game.advance_to(target)
		expect(game.press(game.notes[0].lane).hit, "Time-based window must work at %d FPS" % fps)
		var backwards: float = game.elapsed
		game.advance_to(0.0)
		expect(is_equal_approx(game.elapsed, backwards), "Audio clock cannot rewind chart state")


func _test_cancel() -> void:
	var game = RhythmGame.new()
	var payments: Array[int] = []
	game.finished.connect(func(_success: bool, money: int): payments.append(money))
	game.start(12.0, 0)
	game.advance_to(game.notes[0].time)
	game.press(game.notes[0].lane)
	game.stop()
	expect(not game.active and game.pending_money == 0, "Cancellation must discard provisional earnings")
	expect(payments.is_empty(), "Cancellation cannot pay")
	game.start(12.0, 0)
	expect(game.hits == 0 and game.misses == 0 and game.elapsed == 0.0, "Replay must reset all per-song state")
