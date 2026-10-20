extends Node3D
## Native offline vertical slice. Music, people and textures are original stand-ins.
const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const WORLD_SCRIPT = preload("res://scripts/world.gd")
const RHYTHM_SCRIPT = preload("res://scripts/rhythm_game.gd")
const VIEW_SCRIPT = preload("res://scripts/rhythm_view.gd")
const SAVE_SCRIPT = preload("res://scripts/save_store.gd")
const SONGS = [
	{"title": "01 — Madrugada", "caption": "ENSAIO • 96 BPM • 40 s", "file": "res://assets/audio/demo_1.ogg", "bpm": 96.0},
	{"title": "02 — Última rua", "caption": "ENSAIO • 108 BPM • 36 s", "file": "res://assets/audio/demo_2.ogg", "bpm": 108.0},
	{"title": "03 — Depois das duas", "caption": "ENSAIO • 120 BPM • 32 s", "file": "res://assets/audio/demo_3.ogg", "bpm": 120.0}
]
const ARTISTS = ["Artista 01", "Artista 02", "Artista 03"]
var world: Node3D
var player: CharacterBody3D
var rhythm: RefCounted
var store: RefCounted
var state: String = "menu"
var selected_song: int = 0
var selected_difficulty: int = 0
var _ambient_song: int = 0
var elapsed_world: float = 0.0
var song_epoch: float = 0.0
var performance_elapsed: float = 0.0
var _safe_transform: Transform3D
var _checkpoint_time: float = 0.0
var _notice_timer: float = 0.0
var _death_time: float = 0.0
var _audio_distance: float = -60.0
var _light_pulse: float = 0.0
var _panner: AudioEffectPanner
var _held: Label
var _bus_distance: int
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _lowpass: AudioEffectLowPassFilter
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var _streams: Array[AudioStream] = []
var _ui: CanvasLayer
var _menu: Control
var _hud: Control
var _hint: Label
var _mission: Label
var _notice: Label
var _song_sheet: Control
var _pause: Control
var _inventory: Control
var _inventory_info: Label
var _inventory_grid: GridContainer
var _performance: Control
var _score: Label
var _crowd: Label
var _song_info: Label
var _judgement: Label
var _rhythm_view: Control
var _result: Control
var _result_title: Label
var _result_text: Label
var _death_screen: Control
var _death_button: Button
var _death_label: Label
var _death_material: ShaderMaterial
var _difficulty_buttons: Array[Button] = []
var _song_buttons: Array[Button] = []
var _song_start: Button
var _font: Font
var _serif: Font
var _preview: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_setup_input()
	store = SAVE_SCRIPT.new()
	store.load_game()
	rhythm = RHYTHM_SCRIPT.new()
	rhythm.finished.connect(_performance_finished)
	rhythm.note_judged.connect(_note_judged)
	world = WORLD_SCRIPT.new()
	add_child(world)
	world.set_bar_unlocked(store.bar_unlocked)
	world.set_wristband_visible(not store.bar_unlocked and not store.bag.has("Pulseira perdida") and store.equipped != "Pulseira perdida")
	player = PLAYER_SCRIPT.new()
	player.position = world.rooftop_spawn.origin
	player.display_name = ARTISTS[clampi(store.artist_index, 0, 2)]
	add_child(player)
	player.movement_locked = true
	player.died.connect(_on_player_died)
	_safe_transform = world.street_safe
	_setup_audio()
	_build_ui()
	_show_menu()


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT], JOY_BUTTON_LEFT_SHOULDER)
	_bind("crouch", [KEY_CTRL], JOY_BUTTON_RIGHT_STICK)
	_bind("jump", [KEY_SPACE], JOY_BUTTON_A)
	_bind("interact", [KEY_E], JOY_BUTTON_Y)
	_bind("inventory", [KEY_B, KEY_TAB], JOY_BUTTON_BACK)
	_bind("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	for i in 4:
		_bind("rhythm_%d" % i, [[KEY_D, KEY_F, KEY_J, KEY_K][i]], [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT][i])
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXIS_LEFT_X if action in ["move_left", "move_right"] else JOY_AXIS_LEFT_Y
		ev.axis_value = -1.0 if action in ["move_left", "move_forward"] else 1.0
		InputMap.action_add_event(action, ev)


func _bind(action: String, keycodes: Array, joy: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.20)
	for keycode in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)
	if joy >= 0:
		var ev := InputEventJoypadButton.new()
		ev.button_index = joy
		InputMap.action_add_event(action, ev)


func _setup_audio() -> void:
	if AudioServer.get_bus_index("AlbumDistance") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "AlbumDistance")
	_bus_distance = AudioServer.get_bus_index("AlbumDistance")
	AudioServer.set_bus_volume_db(_bus_distance, -60.0)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 18000.0
	AudioServer.add_bus_effect(_bus_distance, _lowpass)
	_panner = AudioEffectPanner.new()
	AudioServer.add_bus_effect(_bus_distance, _panner)
	if AudioServer.get_bus_index("AlbumAnalysis") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "AlbumAnalysis")
	var analysis := AudioServer.get_bus_index("AlbumAnalysis")
	AudioServer.set_bus_send(analysis, "AlbumDistance")
	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	AudioServer.add_bus_effect(analysis, effect)
	_spectrum = AudioServer.get_bus_effect_instance(analysis, 0)
	for song in SONGS:
		var stream: AudioStream = load(song.file)
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_streams.append(stream)
	music = AudioStreamPlayer.new()
	music.bus = "AlbumAnalysis"
	music.finished.connect(_music_finished)
	add_child(music)
	music.stream = _streams[0]
	ambience = AudioStreamPlayer.new()
	ambience.stream = load("res://assets/audio/city.ogg")
	if ambience.stream is AudioStreamOggVorbis:
		ambience.stream.loop = true
	ambience.volume_db = -4.0
	add_child(ambience)
	ambience.play()


func _process(delta: float) -> void:
	elapsed_world += delta
	if state == "explore":
		_update_interaction()
		_checkpoint_time += delta
		if _checkpoint_time > 0.7 and player.is_on_floor() and player.health > 0.0:
			_checkpoint_time = 0.0
			_safe_transform = player.global_transform
	elif state == "performance":
		# Audio playback is the rhythm clock. Headless runs use deterministic elapsed.
		performance_elapsed += delta
		_sync_performance_clock()
		_score.text = "%06d\n%d € EM ATUAÇÃO" % [rhythm.score, rhythm.pending_money]
		_crowd.text = "PÚBLICO  %d%%\n%s" % [roundi(rhythm.audience), "O público está contigo" if rhythm.audience > 50 else "Recupera o ritmo"]
		world.set_audience(rhythm.audience)
	elif state == "death":
		_death_time += delta
		var progress := clampf(_death_time / 3.0, 0.0, 1.0)
		_death_material.set_shader_parameter("progress", progress)
		music.pitch_scale = lerpf(1.0, 0.48, progress)
		_lowpass.cutoff_hz = lerpf(18000.0, 400.0, progress)
		if _death_time > 3.1 and not _death_button.visible:
			_death_button.show()
			_death_button.grab_focus()
		_death_label.visible = _death_button.visible
	if _notice_timer > 0.0:
		_notice_timer -= delta
		_notice.visible = _notice_timer > 0.0 and state == "explore"
	_update_audio(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if state == "performance":
		for lane in 4:
			if event.is_action_pressed("rhythm_%d" % lane):
				_sync_performance_clock()
				rhythm.press(lane)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("pause"):
			_abandon_performance()
			return
	elif state == "explore":
		if event.is_action_pressed("interact"):
			_interact()
		elif event.is_action_pressed("inventory"):
			_open_inventory()
		elif event.is_action_pressed("pause"):
			_show_pause()
	elif state in ["songs", "inventory", "paused", "result"] and event.is_action_pressed("pause"):
		_resume_explore()


func _update_audio(delta: float) -> void:
	var target_db := -65.0
	if state in ["performance", "songs", "result", "death"]:
		target_db = -3.0
	elif state in ["menu", "paused", "inventory"]:
		target_db = -19.0 if music.playing else -65.0
	else:
		# Bar door / walls determine leakage. Distance is continuous, no sound toggle.
		var distance: float = player.global_position.distance_to(world.stage_position + Vector3.UP)
		var indoors: bool = player.global_position.x < -7.0 and player.global_position.x > -25.0 and player.global_position.z < -6.0 and player.global_position.z > -25.0 and player.global_position.y < 3.8
		var radius: float = 32.0
		var gain: float = pow(clampf(1.0 - distance / radius, 0.0, 1.0), 2.0)
		if not indoors:
			gain *= 0.22
		target_db = linear_to_db(maxf(gain, 0.0005)) - 3.0
		# Suspend inaudible audio outside one block, retaining the virtual loop time.
		if distance > 42.0:
			if music.playing:
				music.stop()
		elif not music.playing and distance < 38.0:
			_play_virtual_loop()
	_audio_distance = lerpf(_audio_distance, target_db, 1.0 - exp(-3.0 * delta))
	AudioServer.set_bus_volume_db(_bus_distance, _audio_distance)
	var energy: float = _spectrum.get_magnitude_for_frequency_range(40.0, 160.0).length() if _spectrum else 0.0
	_light_pulse = lerpf(_light_pulse, clampf(energy * 6.0, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	world.set_pulse(_light_pulse)
	var offset: Vector3 = world.stage_position - player.global_position
	var camera_right: Vector3 = player.get_camera().global_basis.x
	_panner.pan = clampf(offset.dot(camera_right) / 14.0, -0.65, 0.65) if state == "explore" else 0.0
	ambience.volume_db = lerpf(ambience.volume_db, -17.0 if state == "performance" else -4.0, minf(delta * 2.0, 1.0))


func _sync_performance_clock() -> void:
	if state != "performance" or not rhythm.active:
		return
	var song_time: float = performance_elapsed
	if DisplayServer.get_name() != "headless" and music.playing:
		song_time = maxf(0.0, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	rhythm.advance_to(song_time)


func _music_finished() -> void:
	if state == "performance" and rhythm.active:
		rhythm.advance_to(rhythm.duration)


func _play_virtual_loop() -> void:
	music.stream = _streams[_ambient_song]
	var length: float = music.stream.get_length()
	music.play(fposmod(elapsed_world - song_epoch, maxf(1.0, length)))


func _update_interaction() -> void:
	world.set_nearby_highlights(player.global_position)
	var distance_band: float = player.global_position.distance_to(world.wristband_position)
	world.set_wristband_visible(not store.bar_unlocked and not store.bag.has("Pulseira perdida") and store.equipped != "Pulseira perdida" and distance_band < 13.0)
	_hint.text = ""
	_held.text = "NA MÃO   " + store.equipped if not store.equipped.is_empty() else ""
	if distance_band < 2.1 and not store.bar_unlocked and not store.bag.has("Pulseira perdida") and store.equipped != "Pulseira perdida":
		_hint.text = "E / Y   RECOLHER PULSEIRA"
	elif player.global_position.distance_to(world.guard_position) < 2.8:
		_hint.text = "E / Y   FALAR COM O SEGURANÇA" if not store.bar_unlocked else "LADO B   •   ENTRADA LIVRE"
	elif player.global_position.distance_to(world.stage_position) < 2.8 and store.bar_unlocked:
		_hint.text = "E / Y   ESCOLHER UMA FAIXA"
	if store.bar_unlocked:
		_mission.text = "LADO B\nEntra no bar e aproxima-te da mesa de som."
	elif store.bag.has("Pulseira perdida") or store.equipped == "Pulseira perdida":
		_mission.text = "UMA ENTRADA PARA A NOITE\nEntrega a pulseira ao segurança do Lado B."
	else:
		_mission.text = "UMA ENTRADA PARA A NOITE\nDesce as escadas. Há uma pulseira vermelha na rua."


func _interact() -> void:
	if player.global_position.distance_to(world.wristband_position) < 2.1 and not store.bar_unlocked and not store.bag.has("Pulseira perdida") and store.equipped != "Pulseira perdida":
		if store.collect("Pulseira perdida"):
			store.mission_state = "return_wristband"
			world.set_wristband_visible(false)
			_persist()
			_notify("Pulseira guardada na bolsa. Leva-a à entrada do Lado B.")
		else:
			_notify("A bolsa está cheia.")
	elif player.global_position.distance_to(world.guard_position) < 2.8 and not store.bar_unlocked:
		if store.consume("Pulseira perdida"):
			store.bar_unlocked = true
			store.mission_state = "play_music"
			world.set_bar_unlocked(true)
			_persist()
			_notify("SEGURANÇA   /   Era esta. Podes entrar, a mesa está lá dentro.", 7.0)
		else:
			_notify("SEGURANÇA   /   Perdi uma pulseira aqui na rua. Traz-ma e falamos.", 7.0)
	elif player.global_position.distance_to(world.stage_position) < 2.8 and store.bar_unlocked:
		_open_songs()


func _begin_exploration(index: int) -> void:
	store.artist_index = clampi(index, 0, 2)
	player.display_name = ARTISTS[store.artist_index]
	# Placeholder differences. Final identities and authored animations are pending.
	player.walk_speed = [3.4, 3.6, 3.2][store.artist_index]
	player.run_speed = [5.9, 6.2, 5.6][store.artist_index]
	_persist()
	_resume_explore()
	_notify("WASD / stick: andar   •   Rato / stick direito: câmara   •   E / Y: interagir", 9.0)


func _show_menu() -> void:
	state = "menu"
	_hide_panels()
	_menu.show()
	_hud.hide()
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first(_menu)


func _resume_explore() -> void:
	state = "explore"
	_hide_panels()
	_hud.show()
	player.movement_locked = false
	music.pitch_scale = 1.0
	_lowpass.cutoff_hz = 18000.0
	if _preview:
		_preview = false
		_play_virtual_loop()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_pause() -> void:
	state = "paused"
	_hide_panels()
	_pause.show()
	_hud.hide()
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_persist()
	_focus_first(_pause)


func _open_songs() -> void:
	state = "songs"
	_hide_panels()
	_hud.hide()
	_song_sheet.show()
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select_song(selected_song)
	_select_difficulty(selected_difficulty)
	_focus_first(_song_sheet)


func _select_song(index: int) -> void:
	selected_song = clampi(index, 0, SONGS.size() - 1)
	for i in _song_buttons.size():
		_song_buttons[i].button_pressed = i == selected_song
	music.stream = _streams[selected_song]
	music.play(0.0)
	_preview = true
	_song_start.text = "ATUAR  /  %s" % SONGS[selected_song].title


func _select_difficulty(index: int) -> void:
	selected_difficulty = clampi(index, 0, 2)
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].button_pressed = i == selected_difficulty


func _start_performance() -> void:
	state = "performance"
	_hide_panels()
	_hud.hide()
	_performance.show()
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_preview = false
	music.stream = _streams[selected_song].duplicate()
	if music.stream is AudioStreamOggVorbis:
		music.stream.loop = false
	_ambient_song = selected_song
	song_epoch = elapsed_world
	music.pitch_scale = 1.0
	music.play(0.0)
	performance_elapsed = 0.0
	player.set_performing(true, SONGS[selected_song].bpm)
	rhythm.start(music.stream.get_length(), selected_difficulty, SONGS[selected_song].bpm)
	_song_info.text = "%s\n%s   •   D F J K / CRUZ DIRECIONAL" % [SONGS[selected_song].title, ["FÁCIL", "NORMAL", "DIFÍCIL"][selected_difficulty]]
	_judgement.text = "ENCONTRA O RITMO"
	world.set_audience(75.0)


func _note_judged(lane: int, hit: bool) -> void:
	if _rhythm_view:
		_rhythm_view.flash_lane(lane, hit)
	if _judgement:
		_judgement.text = "NO TEMPO" if hit else "RECUPERA O RITMO"
		_judgement.modulate = Color("79e3d6") if hit else Color("e78d8b")


func _performance_finished(success: bool, money: int) -> void:
	player.set_performing(false)
	store.money += money
	if success:
		store.performances += 1
	_persist()
	state = "result"
	_hide_panels()
	_result.show()
	_result_title.text = "A NOITE OUVIU-TE." if success else "O PÚBLICO FOI EMBORA."
	_result_text.text = "%d ACERTOS   /   %d PONTOS\n\n%s\nSALDO   %d €" % [rhythm.hits, rhythm.score, "Recebeste %d €." % money if success else "Sem pagamento. Podes voltar a tentar.", store.money]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first(_result)


func _abandon_performance() -> void:
	player.set_performing(false)
	rhythm.stop()
	world.set_audience(75.0)
	_resume_explore()
	_notify("Atuação interrompida. O valor provisório não foi recebido.")


func _open_inventory() -> void:
	state = "inventory"
	_hide_panels()
	_inventory.show()
	_hud.hide()
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_inventory()
	_focus_first(_inventory)


func _refresh_inventory() -> void:
	_inventory_info.text = "SALDO  %d €\nNA MÃO  %s\n\nAo morrer: perdes o dinheiro e o objeto equipado. A bolsa fica contigo." % [store.money, store.equipped if not store.equipped.is_empty() else "—"]
	for child in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)
		child.queue_free()
	for i in 8:
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 54)
		button.text = "%02d   %s" % [i + 1, store.bag[i] if i < store.bag.size() else "VAZIO"]
		button.disabled = i >= store.bag.size()
		if not button.disabled:
			button.pressed.connect(_equip_item.bind(i))
		_inventory_grid.add_child(button)


func _equip_item(index: int) -> void:
	store.equip(index)
	_persist()
	_refresh_inventory()
	_focus_first(_inventory)


func _unequip_item() -> void:
	store.unequip()
	_persist()
	_refresh_inventory()


func _on_player_died() -> void:
	if state == "death" or state == "menu":
		return
	rhythm.stop()
	player.set_performing(false)
	store.apply_death()
	_persist()
	state = "death"
	_hide_panels()
	_hud.hide()
	_death_screen.show()
	_death_button.hide()
	_death_label.hide()
	_death_time = 0.0
	player.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not music.playing:
		_play_virtual_loop()


func _revive() -> void:
	player.respawn_at(_safe_transform)
	_resume_explore()
	_notify("De volta à noite. Os objetos da bolsa foram preservados.")


func _persist() -> void:
	if not store.save_game():
		if _notice:
			_notify("Não foi possível gravar. Verifica o espaço e as permissões da pasta de dados.", 8.0)
		push_warning("Falha ao gravar progresso local.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if state == "closing":
		return
	state = "closing"
	player.movement_locked = true
	_persist()
	music.stop()
	ambience.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _notify(message: String, seconds: float = 5.0) -> void:
	_notice.text = message
	_notice.show()
	_notice_timer = seconds


func _hide_panels() -> void:
	for panel in [_menu, _song_sheet, _pause, _inventory, _performance, _result, _death_screen]:
		if panel:
			panel.hide()


func _full(parent: Node) -> Control:
	var c := Control.new()
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _text(parent: Node, text: String, size: int = 18, color: Color = Color("e8e2d4"), editorial: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _serif if editorial else _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65) if color.get_luminance() > 0.5 else Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 48
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _box(parent: Control, width: float = 600, height: float = 500, paper: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.066, 0.97)
	style.border_color = Color("577478")
	style.set_border_width_all(1)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	if paper:
		var parchment := StyleBoxTexture.new()
		parchment.texture = load("res://assets/textures/paper.png")
		parchment.content_margin_left = 28
		parchment.content_margin_right = 28
		parchment.content_margin_top = 24
		parchment.content_margin_bottom = 24
		panel.add_theme_stylebox_override("panel", parchment)
	else:
		panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


func _shade(parent: Control, alpha: float = 0.65) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.006, 0.012, 0.022, alpha)
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _focus_first(parent: Node) -> bool:
	for child in parent.get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			return true
		if _focus_first(child):
			return true
	return false


func _build_ui() -> void:
	_font = load("res://assets/fonts/Interface.ttf")
	_serif = load("res://assets/fonts/Editorial.ttf")
	_ui = CanvasLayer.new()
	add_child(_ui)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 16
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("18282f") if state_name == "normal" else Color("30575b")
		if state_name == "disabled":
			style.bg_color = Color("151f24")
		style.border_color = Color("76c6bd") if state_name in ["hover", "pressed", "focus"] else Color("3b5054")
		style.set_border_width_all(1)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		theme.set_stylebox(state_name, "Button", style)
	theme.set_color("font_color", "Button", Color("e9e1ce"))
	theme.set_color("font_disabled_color", "Button", Color("647579"))
	var root := _full(_ui)
	root.theme = theme

	_menu = _full(root)
	_shade(_menu, 0.56)
	var title := VBoxContainer.new()
	_menu.add_child(title)
	title.position = Vector2(65, 52)
	title.size = Vector2(540, 610)
	title.add_theme_constant_override("separation", 16)
	_text(title, "ÁLBUM VISUAL   /   ESTUDO JOGÁVEL 01", 14, Color("8de1d0"))
	_text(title, "ÓDIO PURO\nNO MEU PEITO", 43, Color("f2e5ce"), true)
	_text(title, "LISBOA. DEPOIS DAS DUAS.", 18)
	_text(title, "Uma entrada para a noite.\nDesce do telhado, encontra o bar e faz-te ouvir.", 17, Color("b8c7c5"))
	_text(title, "ESCOLHE UMA PERSONAGEM PROVISÓRIA", 12, Color("8ca4a6"))
	for i in 3:
		_button(title, "%02d   %s   /   %s" % [i + 1, ARTISTS[i], ["VOZ", "INSTRUMENTO", "DJ"][i]], _begin_exploration.bind(i))
	_text(title, "Faixas sintetizadas de teste. Música da banda ainda por integrar.\nPersonagens e cenário provisórios; jogo desktop totalmente offline.", 12, Color("a5b5b3"))
	var stamp := _text(_menu, "LISBOA\n02:17", 30, Color("d2d4c8"), true)
	stamp.position = Vector2(1060, 58)

	_hud = _full(root)
	_mission = _text(_hud, "", 15, Color("c9d8d0"))
	_mission.position = Vector2(30, 28)
	_hint = _text(_hud, "", 18, Color("f1e8cf"))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400
	_hint.offset_right = 400
	_hint.offset_top = -115
	_hint.offset_bottom = -65
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := _text(_hud, "WASD / STICK  andar     SHIFT / LB  correr     ESPAÇO / A  saltar     CTRL / R3  agachar\nE / Y  interagir     B / VIEW  bolsa     ESC / MENU  pausa", 12, Color("a5b6b6"))
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	keys.offset_left = 30
	keys.offset_top = -54
	keys.offset_right = 1150
	keys.offset_bottom = -10
	_held = _text(_hud, "", 14, Color("e9d7b4"))
	_held.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_held.offset_left = -330
	_held.offset_right = -28
	_held.offset_top = -95
	_held.offset_bottom = -60
	_held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice = _text(root, "", 16, Color("f1d7ab"))
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -530
	_notice.offset_right = 530
	_notice.offset_top = 95
	_notice.offset_bottom = 150
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.hide()

	_song_sheet = _full(root)
	_shade(_song_sheet)
	var paper_theme := theme.duplicate()
	for button_state in ["normal", "hover", "pressed", "focus"]:
		var paper_style := StyleBoxFlat.new()
		paper_style.bg_color = Color("c9b994") if button_state == "normal" else Color("9f8f70")
		paper_style.border_color = Color("756b52")
		paper_style.set_border_width_all(1)
		paper_style.content_margin_left = 16
		paper_style.content_margin_top = 8
		paper_style.content_margin_bottom = 8
		paper_theme.set_stylebox(button_state, "Button", paper_style)
	paper_theme.set_color("font_color", "Button", Color("302f2b"))
	paper_theme.set_color("font_hover_color", "Button", Color("171b1b"))
	paper_theme.set_color("font_pressed_color", "Button", Color("171b1b"))
	paper_theme.set_color("font_focus_color", "Button", Color("171b1b"))
	_song_sheet.theme = paper_theme
	var songs := _box(_song_sheet, 680, 620, true)
	_text(songs, "LADO B   /   LISTA DA NOITE", 13, Color("4f594d"))
	_text(songs, "Escolhe a tua faixa.", 30, Color("302f2b"), true)
	_text(songs, "Seleciona para ouvir uma prévia. A atuação começa do início.", 14, Color("4c4b40"))
	for i in SONGS.size():
		var button := _button(songs, "%s\n%s" % [SONGS[i].title, SONGS[i].caption], _select_song.bind(i))
		button.toggle_mode = true
		_song_buttons.append(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	songs.add_child(row)
	for i in 3:
		var button := _button(row, ["FÁCIL • 10 €", "NORMAL • 10 €", "DIFÍCIL • 15 €"][i], _select_difficulty.bind(i))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_difficulty_buttons.append(button)
	_text(songs, "Quatro teclas: D F J K / cruz direcional.\nOs acertos recuperam público. Sem público, não há pagamento.", 13, Color("4c4b40"))
	_song_start = _button(songs, "ATUAR", _start_performance)
	_button(songs, "VOLTAR AO BAR", _resume_explore)

	_pause = _full(root)
	_shade(_pause)
	var pause_box := _box(_pause, 640, 490)
	_text(pause_box, "A noite pode esperar.", 31, Color("f2e5ce"), true)
	_text(pause_box, "Progresso gravado localmente. Ao reabrir, voltas ao telhado.\n\nEste protótipo inclui exploração, uma missão e atuações.\nVeículos conduzíveis, combate e editor com IA são etapas seguintes.", 15)
	_button(pause_box, "CONTINUAR", _resume_explore)
	_button(pause_box, "ABRIR A BOLSA", _open_inventory)
	_button(pause_box, "TROCAR PERSONAGEM  /  PROVISÓRIO", _show_menu)
	_button(pause_box, "GUARDAR E SAIR", _quit_game)

	_inventory = _full(root)
	_shade(_inventory)
	var bag_box := _box(_inventory, 680, 600)
	_text(bag_box, "O que levas contigo.", 30, Color("f2e5ce"), true)
	_inventory_info = _text(bag_box, "", 14)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 2
	_inventory_grid.add_theme_constant_override("h_separation", 10)
	_inventory_grid.add_theme_constant_override("v_separation", 10)
	bag_box.add_child(_inventory_grid)
	_button(bag_box, "GUARDAR O OBJETO DA MÃO", _unequip_item)
	_button(bag_box, "FECHAR A BOLSA", _resume_explore)

	_performance = _full(root)
	_shade(_performance, 0.40)
	_rhythm_view = VIEW_SCRIPT.new()
	_rhythm_view.rhythm = rhythm
	_performance.add_child(_rhythm_view)
	_rhythm_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score = _text(_performance, "", 25, Color("f1e5cc"))
	_score.position = Vector2(35, 35)
	_song_info = _text(_performance, "", 16)
	_song_info.position = Vector2(400, 32)
	_crowd = _text(_performance, "", 19, Color("8de1d0"))
	_crowd.position = Vector2(1000, 35)
	_judgement = _text(_performance, "", 16, Color("8de1d0"))
	_judgement.position = Vector2(860, 350)
	var quit_hint := _text(_performance, "ESC / MENU  interromper\nO pagamento só chega no fim.", 12)
	quit_hint.position = Vector2(35, 620)

	_result = _full(root)
	_shade(_result)
	var result_box := _box(_result, 650, 390)
	_result_title = _text(result_box, "", 27, Color("f2e5ce"), true)
	_result_text = _text(result_box, "", 18)
	_button(result_box, "VOLTAR AO BAR", _resume_explore)
	_button(result_box, "ESCOLHER OUTRA FAIXA", _open_songs)

	_death_screen = _full(root)
	var death_rect := ColorRect.new()
	_death_screen.add_child(death_rect)
	death_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture:hint_screen_texture,filter_linear; uniform float progress=0.0; void fragment(){vec2 p=SCREEN_UV-vec2(0.5); float r=length(p*vec2(1.0,0.65)); float radius=mix(0.9,0.0,progress); vec2 uv=vec2(0.5)+p*(1.0+progress*r*2.0); vec3 c=texture(screen_texture,clamp(uv,vec2(0.0),vec2(1.0))).rgb; float mask=1.0-smoothstep(max(0.0,radius-0.12),radius+0.001,r); c=mix(c,vec3(dot(c,vec3(0.3,0.59,0.11)))*vec3(0.7,0.9,0.8),progress); COLOR=vec4(c*mask*(1.0-progress),1.0);}"
	_death_material = ShaderMaterial.new()
	_death_material.shader = shader
	death_rect.material = _death_material
	_death_label = _text(_death_screen, "A NOITE CONTINUA.", 30, Color("e4dbcb"), true)
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.offset_left = -230
	_death_label.offset_right = 230
	_death_label.offset_top = -75
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_button = _button(_death_screen, "VOLTAR À VIDA", _revive)
	_death_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_button.offset_left = -150
	_death_button.offset_right = 150
	_death_button.offset_top = 5
	_death_button.offset_bottom = 57
	_hide_panels()
