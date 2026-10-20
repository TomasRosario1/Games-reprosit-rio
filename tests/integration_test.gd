extends SceneTree
## Exercises the actual scene, interactions, rhythm payout and death/save flow.
var game: Node3D
var checks := 0
var failures := 0
var screenshots := false

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _audio_tick()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.store.save_path = "user://integration_progress.json"
	game.store.reset_progress()
	game.world.set_bar_unlocked(false)
	_check(game.state == "menu", "native main scene opens on character selection")
	_check(game.player.movement_locked, "menu locks world controls")
	await _capture("01-menu")
	game._begin_exploration(1)
	_check(game.state == "explore" and game.player.display_name == "Artista 02", "character selection enters exploration")
	_check(not game.player.movement_locked, "exploration unlocks controls")
	await _capture("02-telhado")
	game.player.global_position = game.world.guard_position + Vector3(0, 0.2, 1.6)
	game._interact()
	_check(not game.store.bar_unlocked, "guard blocks access before favor")
	game.player.global_position = game.world.wristband_position + Vector3(0, 0.1, 0.8)
	game._interact()
	_check(game.store.bag.has("Pulseira perdida"), "nearby interaction collects wristband into bag")
	game._interact()
	_check(game.store.bag.size() == 1, "pickup cannot be duplicated")
	game.player.global_position = game.world.guard_position + Vector3(0, 0.2, 1.6)
	game._interact()
	_check(game.store.bar_unlocked and not game.store.bag.has("Pulseira perdida"), "favor consumes wristband and opens bar")
	game.player.global_position = game.world.stage_position + Vector3(0, 0.25, 1.7)
	game.player.set("_yaw", 0.0)
	game.player.set("_pitch", -0.16)
	game.player._update_camera(1.0)
	game._interact()
	_check(game.state == "songs", "stage interaction opens repertoire")
	await _audio_tick()
	game._select_song(2)
	_check(game.selected_song == 2 and game.music.playing, "selection plays chosen preview")
	await _audio_tick()
	await _capture("03-repertorio")
	game._select_difficulty(2)
	game._start_performance()
	_check(game.state == "performance" and game.player.movement_locked, "performance locks exploration")
	_check(game.rhythm.difficulty == 2 and game.rhythm.elapsed == 0, "performance starts chosen chart from beginning")
	await _audio_tick()
	game._process(0.0)
	await _capture("04-atuacao")
	var notes: Array = game.rhythm.notes.duplicate(true)
	var expected_money := notes.size() * 15
	for note in notes:
		game.rhythm.advance_to(float(note.time))
		var ev := InputEventAction.new()
		ev.action = "rhythm_%d" % note.lane
		ev.pressed = true
		game._unhandled_input(ev)
	_check(game.store.money == 0, "earnings are provisional before song completes")
	game.rhythm.advance_to(game.rhythm.duration)
	_check(game.state == "result", "song completion shows result")
	_check(game.store.money == expected_money and game.store.performances == 1, "hard chart pays15 per successful note once")
	game.rhythm.advance_to(game.rhythm.duration + 1.0)
	_check(game.store.money == expected_money, "completed performance cannot pay twice")
	game._resume_explore()
	game._open_songs()
	await _audio_tick()
	game._start_performance()
	await _audio_tick()
	game.rhythm.advance_to(game.rhythm.duration)
	_check(game.store.money == expected_money and game.rhythm.last_payout == 0, "all-miss failure pays nothing")
	game._resume_explore()
	game._open_inventory()
	_check(game.state == "inventory" and game.player.movement_locked, "bag opens with world controls locked")
	game.store.collect("Objeto protegido")
	game.store.collect("Objeto equipado")
	game.store.equip(1)
	game._safe_transform = game.world.street_safe
	game._on_player_died()
	_check(game.store.money == 0 and game.store.equipped.is_empty(), "death removes money and held item")
	_check(game.store.bag.has("Objeto protegido") and game.store.bar_unlocked, "death keeps bag and unlocked progress")
	game._process(3.2)
	_check(game._death_button.visible, "revive button appears after funnel transition")
	game._revive()
	_check(game.state == "explore" and game.player.global_position.is_equal_approx(game.world.street_safe.origin), "revive returns to nearby safe point")
	var saved = load("res://scripts/save_store.gd").new()
	saved.save_path = game.store.save_path
	_check(saved.load_game() and saved.bar_unlocked and saved.bag.has("Objeto protegido"), "real scene mutations survive save reload")
	game._show_pause()
	_check(game.state == "paused", "pause menu accessible")
	game._resume_explore()
	_check(game.state == "explore", "resume restores exploration")
	game.music.stop()
	game.ambience.stop()
	await create_timer(0.15).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	game.queue_free()
	await process_frame
	print("INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	if not screenshots:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/album-" + label + ".png"
	var result := root.get_texture().get_image().save_png(path)
	_check(result == OK, "native screenshot " + label)

func _audio_tick() -> void:
	# A real user cannot replace several previews and performances in one mixer
	# tick. Let Godot start/release its OGG playback before the next UI action.
	await create_timer(0.08).timeout
