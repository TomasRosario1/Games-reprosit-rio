extends SceneTree
## Functional native scene checks for preview, virtual audio, EOF and gamepad input.
## Run with an isolated XDG_DATA_HOME so a developer's progress is never loaded.

var game: Node3D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MUSIC FLOW: " + description)


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.store.save_path = "user://music_flow_progress.json"
	game.store.reset_progress()
	game._show_menu()
	await process_frame
	_check(root.gui_get_focus_owner() != null and game._menu.is_ancestor_of(root.gui_get_focus_owner()), "character menu gives a visible button keyboard/gamepad focus")
	game._begin_exploration(0)
	game.elapsed_world = 21.25
	game.song_epoch = 3.0
	game._ambient_song = 0
	game.selected_song = 0
	game._play_virtual_loop()
	await create_timer(0.08).timeout
	_check(absf(game.music.get_playback_position() - 18.25) < 0.3, "virtual loop seeks to the current phase, not the beginning")

	game._open_songs()
	game._select_song(2)
	await process_frame
	_check(game.music.stream == game._streams[2], "song selection plays the selected preview")
	_check(game._ambient_song == 0 and game.song_epoch == 3.0, "preview cannot change the ambient song or its epoch")
	_check(root.gui_get_focus_owner() == game._song_buttons[0], "repertoire starts with keyboard/gamepad focus on first song")
	game.elapsed_world += 4.0
	game._resume_explore()
	await create_timer(0.08).timeout
	_check(game.music.stream == game._streams[0], "closing preview restores the original ambient song")
	_check(absf(game.music.get_playback_position() - 22.25) < 0.3, "closing preview preserves elapsed ambient time")

	game.player.global_position = game.world.stage_position + Vector3(100.0, 0.0, 0.0)
	game._update_audio(0.1)
	_check(not game.music.playing, "inaudible source is suspended beyond one block")
	game.elapsed_world += 12.5
	game.player.global_position = game.world.stage_position + Vector3(0.0, 1.0, 1.0)
	game._audio_distance = -65.0
	game._update_audio(0.1)
	await create_timer(0.08).timeout
	_check(game.music.playing, "approaching source resumes playback")
	_check(absf(game.music.get_playback_position() - 34.75) < 0.3, "distance resume advances the virtual loop while suspended")
	_check(game._audio_distance > -65.0 and game._audio_distance < -3.0, "approaching source fades smoothly instead of snapping to full volume")

	game._open_songs()
	game._select_song(1)
	game._select_difficulty(1)
	game._start_performance()
	_check(game._ambient_song == 1 and game.song_epoch == game.elapsed_world, "actual performance establishes the new ambient epoch")
	_check(game.music.stream != game._streams[1] and not game.music.stream.loop, "performance uses a separate non-looping audio stream")
	_check(game._streams[1].loop, "performance cannot disable the exploration stream's loop")
	_check(game.rhythm.elapsed == 0.0 and game.performance_elapsed == 0.0, "performance and chart reset to the beginning")
	await create_timer(0.08).timeout
	_check(game.music.get_playback_position() < 0.3, "real playback starts at zero instead of preview position")
	var first: Dictionary = game.rhythm.notes[0]
	game.performance_elapsed = first.time
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_LEFT
	pad.pressed = true
	game._unhandled_input(pad)
	_check(game.rhythm.hits == 1, "gamepad rhythm event synchronizes the clock before judging input")
	var earned: int = game.rhythm.pending_money
	game._unhandled_input(pad)
	_check(game.rhythm.hits == 1 and game.rhythm.pending_money == earned, "repeated gamepad event cannot farm a note")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_D
	echo.pressed = true
	echo.echo = true
	var misses_before: int = game.rhythm.misses
	game._unhandled_input(echo)
	_check(game.rhythm.misses == misses_before, "keyboard auto-repeat is ignored")
	game._abandon_performance()
	_check(game.store.money == 0 and game.rhythm.pending_money == 0, "interrupted performance never pays")

	# Exercise an actual AudioStreamPlayer.finished event, not a fabricated signal.
	game._open_songs()
	game._select_song(2)
	game._select_difficulty(0)
	game._start_performance()
	for note in game.rhythm.notes:
		game.rhythm.advance_to(note.time)
		game.rhythm.press(note.lane)
	var expected_money: int = game.rhythm.hits * 10
	game.music.seek(game.music.stream.get_length() - 0.10)
	await create_timer(0.65).timeout
	_check(game.state == "result" and not game.music.playing, "real audio EOF completes performance without waiting for a loop-detection window")
	_check(game.store.money == expected_money, "audio EOF settles the successful performance exactly once")
	game._music_finished()
	_check(game.store.money == expected_money, "duplicate EOF callback cannot pay again")

	game._resume_explore()
	game.store.collect("Objeto de teste")
	game._open_inventory()
	await process_frame
	_check(root.gui_get_focus_owner() == game._inventory_grid.get_child(0), "nested inventory item receives focus without later sibling overriding it")
	game.music.stop()
	game.ambience.stop()
	await create_timer(0.20).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	game.queue_free()
	await process_frame
	print("MUSIC FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
