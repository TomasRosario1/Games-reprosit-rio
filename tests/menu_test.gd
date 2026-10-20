extends SceneTree
## Exercises preferences, safe input rebinding, menu signals and exit confirmation.
const MENU = preload("res://scripts/game_menu.gd")
const HUD = preload("res://scripts/game_hud.gd")
var checks := 0
var failures := 0
var events := {"resumed": 0, "save": 0, "load": 0, "editor": 0, "exit": [], "quality": [], "population": [], "audio": [], "bindings": []}
var menu: GameMenu
var screenshots := false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _setup_actions() -> void:
	for action in MENU.ACTION_LABELS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var keyboard := InputEventKey.new()
		keyboard.physical_keycode = KEY_W
		InputMap.action_add_event(action, keyboard)
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_A
		InputMap.action_add_event(action, button)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = -1.0
	InputMap.action_add_event("move_forward", axis)

func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	_setup_actions()
	var path := "user://menu_test_%d.cfg" % Time.get_ticks_usec()
	menu = MENU.new()
	menu.save_path = path
	menu.configure({"quality": 1, "population": 6})
	menu.resumed.connect(func() -> void: events.resumed += 1)
	menu.save_requested.connect(func() -> void: events.save += 1)
	menu.load_requested.connect(func() -> void: events.load += 1)
	menu.editor_requested.connect(func() -> void: events.editor += 1)
	menu.exit_requested.connect(func(save_first: bool) -> void: events.exit.append(save_first))
	menu.quality_changed.connect(func(index: int) -> void: events.quality.append(index))
	menu.population_changed.connect(func(count: int) -> void: events.population.append(count))
	menu.audio_changed.connect(func(channel: String, value: float) -> void: events.audio.append([channel, value]))
	menu.binding_changed.connect(func(action: String, event: InputEvent) -> void: events.bindings.append([action, event]))
	root.add_child(menu)
	await process_frame
	check(not menu.visible, "menu starts closed")
	check(menu.settings.quality == 1 and menu.settings.population == 6, "initial defaults configure correctly")
	menu.open_menu()
	await process_frame
	check(menu.visible and menu.current_tab == "brief", "open menu selects brief")
	check(root.gui_get_focus_owner() == menu._tabs.brief, "keyboard/controller focus starts on selected tab")
	menu.set_context({"money": 123, "health": 74, "mission": "Encontrar a pulseira", "player_position": Vector3(12, 0, -9), "bar_unlocked": true})
	var brief_content := menu._content.get_child(0)
	menu.set_context({"money": 123, "health": 74, "mission": "Encontrar a pulseira", "player_position": Vector3(12, 0, -9), "bar_unlocked": true})
	check(menu._content.get_child(0) == brief_content, "unchanged live context preserves brief controls and keyboard focus")
	for tab in MENU.TAB_LABELS:
		menu._select_tab(tab)
		check(menu.current_tab == tab and menu._content.get_child_count() > 0, "tab has usable content: " + tab)
	menu._select_tab("map")
	check(menu._map.get("context").player_position == Vector3(12,0,-9), "map follows actual supplied position")
	menu._select_tab("quality")
	menu._change_quality(2)
	menu._change_population(2)
	check(events.quality == [2] and events.population == [16], "quality and population emit independent settings")
	check(FileAccess.file_exists(path), "preferences persist in separate config file")
	menu._change_audio(0.35, "master")
	menu._change_audio(0.65, "music")
	menu._change_audio(0.45, "ambient")
	menu._change_audio(0.55, "effects")
	check(events.audio == [["master",0.35],["music",0.65],["ambient",0.45],["effects",0.55]], "four audio channels emit correct normalized values")
	menu._change_brightness(2.0)
	menu._change_subtitles(false)
	check(menu.settings.brightness == 1.45 and not menu.settings.subtitles, "brightness clamps and subtitles update")
	await _capture("quality")
	menu._request_save()
	menu._request_load()
	menu._request_editor()
	check(events.save == 1 and events.load == 1 and events.editor == 1, "game operations emit signals for root ownership")
	menu._select_tab("exit")
	check(events.exit.is_empty(), "selecting exit never closes game immediately")
	menu._request_exit(true)
	await process_frame
	check(menu._confirm.visible and events.exit.is_empty(), "save and exit requires confirmation")
	check(menu._confirm.is_ancestor_of(root.gui_get_focus_owner()), "confirmation owns controller focus")
	check(menu._tabs.brief.focus_mode == Control.FOCUS_NONE, "confirmation prevents underlying tabs taking focus")
	await _capture("exit-confirm")
	menu._cancel_exit()
	check(menu.visible and events.exit.is_empty(), "cancel exit keeps menu open")
	check(menu._tabs.brief.focus_mode == Control.FOCUS_ALL, "cancel restores navigation focus")
	menu._request_exit(false)
	menu._confirm_exit()
	check(events.exit == [false] and not menu.visible, "confirmed no-save exit emits once with false")
	menu._confirm_exit()
	check(events.exit.size() == 1, "duplicate confirmation cannot emit twice")
	menu.open_menu("exit")
	menu._request_exit(true)
	menu._confirm_exit()
	check(events.exit == [false,true], "confirmed save-and-exit carries save intent")
	menu.open_menu("controls")
	menu._choose_mode("keyboard")
	menu._begin_capture("move_forward")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	check(menu._capture_action.is_empty() and menu.visible and events.resumed == 0, "escape cancels capture without closing menu")
	menu._begin_capture("move_forward")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	menu._input(key)
	var keyboard_count := 0
	var controller_count := 0
	var axis_count := 0
	for event in InputMap.action_get_events("move_forward"):
		if event is InputEventKey:
			keyboard_count += 1
			check(event.physical_keycode == KEY_T, "new physical keyboard binding is applied")
		elif event is InputEventJoypadMotion:
			axis_count += 1
		elif event is InputEventJoypadButton:
			controller_count += 1
	check(keyboard_count == 1 and controller_count == 1 and axis_count == 1, "keyboard rebind preserves controller button and stick axis")
	menu._choose_mode("controller")
	menu._begin_capture("jump")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	pad.pressed = true
	menu._input(pad)
	check(menu.settings.binding_buttons.jump == JOY_BUTTON_B, "controller button rebinding persists")
	check(InputMap.action_get_events("jump").size() == 2, "controller rebind preserves keyboard mapping")
	menu._choose_mode("keyboard")
	menu._begin_capture("attack")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	menu._input(mouse)
	check(menu.settings.binding_mouse.attack == MOUSE_BUTTON_LEFT and not menu.settings.binding_keys.has("attack"), "mouse can be bound in keyboard/mouse mode")
	check(events.bindings.size() == 3, "binding callback fires once per accepted capture")
	await _capture("controls")
	var restored := MENU.new()
	restored.save_path = path
	restored.configure({"quality":0,"subtitles":true})
	root.add_child(restored)
	await process_frame
	check(restored.settings.quality == 2 and not restored.settings.subtitles, "persisted preferences take precedence over supplied defaults")
	check(restored.settings.binding_keys.move_forward == KEY_T and restored.settings.binding_buttons.jump == JOY_BUTTON_B, "keyboard and controller bindings survive reload")
	var detached := restored.get_settings()
	detached.binding_keys.move_forward = KEY_Q
	check(restored.settings.binding_keys.move_forward == KEY_T, "settings getter cannot mutate internal nested bindings")
	menu._input(escape)
	check(events.resumed == 1 and not menu.visible, "escape outside capture requests resume")
	var invalid := MENU.new()
	invalid.save_path = "user://menu_invalid_%d.cfg" % Time.get_ticks_usec()
	invalid.configure({"quality":{}, "population":999, "audio_music":"invalid", "brightness":NAN, "binding_buttons":{"jump":-1,"unknown":0}})
	root.add_child(invalid)
	await process_frame
	check(invalid.settings.quality == 0 and invalid.settings.population == 10 and invalid.settings.brightness == 1.0, "invalid preferences fall back without crashing")
	check(invalid.settings.binding_buttons.is_empty(), "invalid bindings are rejected")
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_status(123, 74.0, "punhos", 60.0)
	check(hud.get_money_text() == "€000000123", "HUD uses euro symbol and nine digits")
	check(hud.weapon == "PUNHOS" and hud.health == 74.0, "HUD receives root status")
	hud._process(0.5)
	check(hud._wanted_display > 0.0 and hud._wanted_display < 60.0, "wanted baton fills gradually rather than snapping")
	hud._process(2.0)
	check(hud._wanted_display == 60.0, "wanted fill reaches normalized target")
	hud.set_status(-5, 150.0, "", 0.0)
	check(hud.get_money_text() == "€000000000" and hud.health == 100.0 and hud.wanted == 0.0, "HUD clamps input and zero pressure hides wanted")
	hud.set_status(12345, 82.0, "punhos", 67)
	hud._process(2.0)
	await _capture("hud")
	menu.queue_free()
	restored.queue_free()
	invalid.queue_free()
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("MENU/HUD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	if not screenshots or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/album-menu-" + label + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "native screenshot: " + label)
