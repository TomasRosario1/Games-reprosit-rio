class_name GameMenu
extends Control
## Offline pause/settings UI. Root owns world state, save operations and scene changes.
signal resumed
signal save_requested
signal load_requested
signal exit_requested(save_first: bool)
signal editor_requested
signal quality_changed(index: int)
signal population_changed(count: int)
signal audio_changed(channel: String, value: float)
signal brightness_changed(value: float)
signal motion_blur_changed(value: float)
signal subtitles_changed(enabled: bool)
signal binding_changed(action: String, event: InputEvent)

const ACTION_LABELS := {
	"move_forward": "AVANÇAR", "move_back": "RECUAR", "move_left": "ESQUERDA", "move_right": "DIREITA",
	"sprint": "CORRER", "crouch": "AGACHAR", "jump": "SALTAR", "interact": "INTERAGIR",
	"inventory": "BOLSA", "pause": "PAUSA", "rhythm_0": "NOTA 1", "rhythm_1": "NOTA 2", "rhythm_2": "NOTA 3", "rhythm_3": "NOTA 4", "attack": "ATAQUE", "editor_toggle": "MODO CRIADOR", "vehicle_brake": "TRAVÃO / VEÍCULO", "vehicle_horn": "BUZINA"
}
const TAB_LABELS := {"brief": "JOGO / BRIEF", "map": "MAPA", "quality": "QUALIDADE", "hud": "HUD", "controls": "CONTROLOS", "audio": "ÁUDIO", "save": "GUARDAR / CARREGAR", "editor": "EDITOR", "exit": "SAIR"}
const DEFAULT_SETTINGS := {"quality": 0, "population": 10, "audio_master": 1.0, "audio_music": 0.8, "audio_ambient": 0.8, "audio_effects": 0.8, "brightness": 1.0, "motion_blur": 0.35, "subtitles": true, "binding_keys": {}, "binding_buttons": {}, "binding_mouse": {}}
var save_path := "user://menu_settings.cfg"
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var current_tab := "brief"
var _pending_config: Dictionary = {}
var _context: Dictionary = {}
var _tabs: Dictionary = {}
var _content: VBoxContainer
var _heading: Label
var _footer: Label
var _capture_label: Label
var _capture_action := ""
var _control_mode := "keyboard"
var _map: Control
var _confirm: Control
var _confirm_text: Label
var _confirm_save := false
var _font: Font
var _ready_ui := false
var _main_layout: Control
var _blocked_focus: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/Menu.ttf") if ResourceLoader.exists("res://assets/fonts/Menu.ttf") else ThemeDB.fallback_font
	_merge_settings(_pending_config)
	_load_settings()
	_apply_saved_bindings()
	_build_ui()
	_ready_ui = true
	_select_tab("brief")
	hide()


func configure(values: Dictionary = {}) -> void:
	if not _ready_ui:
		_pending_config.merge(values, true)
		return
	_merge_settings(values)
	_load_settings()
	_apply_saved_bindings()
	_select_tab(current_tab)


func get_settings() -> Dictionary:
	return settings.duplicate(true)


func open_menu(tab: String = "brief") -> void:
	show()
	_confirm.hide()
	_capture_action = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select_tab(tab)
	if _tabs.has(current_tab):
		_tabs[current_tab].grab_focus.call_deferred()


func close_menu() -> void:
	_capture_action = ""
	_confirm.hide()
	_restore_focus()
	hide()


func set_context(data: Dictionary) -> void:
	var changed := false
	for key in data:
		if not _context.has(key) or _context[key] != data[key]:
			changed = true
	_context.merge(data, true)
	if data.has("status"):
		show_notice(str(data.status))
	if _map and is_instance_valid(_map):
		_map.set("context", _context)
		_map.queue_redraw()
	if changed and is_visible_in_tree() and current_tab == "brief":
		_select_tab("brief")


func show_notice(message: String) -> void:
	if _footer:
		_footer.text = message.to_upper()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.echo:
		return
	if not _capture_action.is_empty():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_capture_action = ""
			_select_tab("controls")
		elif _control_mode == "keyboard" and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			_set_binding(_capture_action, event)
			_capture_action = ""
			_select_tab("controls")
		elif _control_mode == "controller" and event is InputEventJoypadButton and event.pressed:
			_set_binding(_capture_action, event)
			_capture_action = ""
			_select_tab("controls")
		get_viewport().set_input_as_handled()
		return
	var back: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	back = back or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if back:
		if _confirm.visible:
			_cancel_exit()
		else:
			_resume()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	close_menu()
	resumed.emit()


func _merge_settings(values: Dictionary) -> void:
	for key in DEFAULT_SETTINGS:
		if values.has(key):
			settings[key] = values[key]
	settings.quality = clampi(int(_numeric(settings.quality, 0)), 0, 2)
	var population_value := int(_numeric(settings.population, 10))
	settings.population = population_value if population_value in [6, 10, 16] else 10
	for channel in ["master", "music", "ambient", "effects"]:
		settings["audio_" + channel] = clampf(_numeric(settings["audio_" + channel], float(DEFAULT_SETTINGS["audio_" + channel])), 0.0, 1.0)
	settings.brightness = clampf(_numeric(settings.brightness, 1.0), 0.65, 1.45)
	settings.motion_blur = clampf(_numeric(settings.motion_blur, 0.35),0.0,1.0)
	settings.subtitles = settings.subtitles if settings.subtitles is bool else true
	for bindings in ["binding_keys", "binding_buttons", "binding_mouse"]:
		if not settings[bindings] is Dictionary:
			settings[bindings] = {}
		var clean: Dictionary = {}
		for action in settings[bindings]:
			var value = settings[bindings][action]
			if ACTION_LABELS.has(action) and (value is int or value is float) and int(value) >= 0:
				if bindings == "binding_buttons" and int(value) >= JOY_BUTTON_MAX:
					continue
				if bindings == "binding_mouse" and (int(value) < 1 or int(value) > 9):
					continue
				clean[action] = int(value)
		settings[bindings] = clean


func _numeric(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback


func _valid_save_path() -> bool:
	return save_path.begins_with("user://") and save_path.ends_with(".cfg") and not save_path.trim_prefix("user://").contains("/") and not save_path.contains("..")


func _load_settings() -> void:
	if not _valid_save_path():
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	var loaded: Dictionary = {}
	for key in DEFAULT_SETTINGS:
		loaded[key] = file.get_value("menu", key, settings[key])
	_merge_settings(loaded)


func _save_settings() -> bool:
	if not _valid_save_path():
		return false
	var file := ConfigFile.new()
	for key in DEFAULT_SETTINGS:
		file.set_value("menu", key, settings[key])
	var result := file.save(save_path)
	if result != OK:
		show_notice("Não foi possível guardar as definições.")
	return result == OK


func _apply_saved_bindings() -> void:
	for action in settings.binding_keys:
		var event := InputEventKey.new()
		event.physical_keycode = settings.binding_keys[action]
		_replace_binding(action, event)
	for action in settings.binding_mouse:
		var event := InputEventMouseButton.new()
		event.button_index = settings.binding_mouse[action]
		_replace_binding(action, event)
	for action in settings.binding_buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = settings.binding_buttons[action]
		_replace_binding(action, event)


func _replace_binding(action: String, event: InputEvent) -> void:
	if not ACTION_LABELS.has(action) or not InputMap.has_action(action):
		return
	for previous in InputMap.action_get_events(action):
		if ((event is InputEventKey or event is InputEventMouseButton) and (previous is InputEventKey or previous is InputEventMouseButton)) or (event is InputEventJoypadButton and previous is InputEventJoypadButton):
			InputMap.action_erase_event(action, previous)
	InputMap.action_add_event(action, event)


func _set_binding(action: String, event: InputEvent) -> void:
	if not ACTION_LABELS.has(action):
		return
	var normalized: InputEvent
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key.physical_keycode == 0:
			return
		settings.binding_keys[action] = key.physical_keycode
		settings.binding_mouse.erase(action)
		normalized = key
	elif event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		settings.binding_mouse[action] = mouse.button_index
		settings.binding_keys.erase(action)
		normalized = mouse
	elif event is InputEventJoypadButton:
		var button := InputEventJoypadButton.new()
		button.button_index = event.button_index
		settings.binding_buttons[action] = button.button_index
		normalized = button
	else:
		return
	_replace_binding(action, normalized)
	_save_settings()
	binding_changed.emit(action, normalized)


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.015, 0.018, 0.02, 0.94)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main := MarginContainer.new()
	_main_layout = main
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("margin_left", 52)
	main.add_theme_constant_override("margin_right", 52)
	main.add_theme_constant_override("margin_top", 34)
	main.add_theme_constant_override("margin_bottom", 26)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	main.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := _label(top, "PAUSA", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var signature := _label(top, "ÓDIO PURO NO MEU PEITO\nLISBOA / ÁLBUM VISUAL", 14, Color("92979a"))
	signature.custom_minimum_size.x = 285
	signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var line := HSeparator.new()
	line.modulate = Color("51575b")
	layout.add_child(line)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 48)
	layout.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 285
	sidebar.add_theme_constant_override("separation", 4)
	body.add_child(sidebar)
	for tab in TAB_LABELS:
		var button := _button(sidebar, TAB_LABELS[tab], _select_tab.bind(tab))
		button.custom_minimum_size.y = 43
		button.toggle_mode = true
		_tabs[tab] = button
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 18)
	body.add_child(right)
	_heading = _label(right, "", 29)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_content)
	_footer = _label(layout, "ESC / MENU  VOLTAR     ·     SETAS / CRUZ DIRECIONAL  NAVEGAR     ·     ENTER / A  ESCOLHER", 12, Color("979ea1"))
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d1d3d2") if state_name in ["pressed", "hover"] else Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = Color("c4c7c6") if state_name == "focus" else Color("353c40")
		style.border_width_bottom = 1 if state_name in ["normal", "focus"] else 0
		style.border_width_left = 2 if state_name == "focus" else 0
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		theme.set_stylebox(state_name, "Button", style)
	theme.set_color("font_color", "Button", Color("d1d3d2"))
	theme.set_color("font_hover_color", "Button", Color("13191c"))
	theme.set_color("font_pressed_color", "Button", Color("13191c"))
	theme.set_color("font_focus_color", "Button", Color("f0f1ee"))
	theme.set_color("font_disabled_color", "Button", Color("6b7377"))
	self.theme = theme
	_build_confirm()


func _label(parent: Node, text: String, font_size := 18, color := Color("d1d3d2")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _clear_content() -> void:
	_map = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _select_tab(tab: String) -> void:
	if not TAB_LABELS.has(tab):
		tab = "brief"
	current_tab = tab
	_clear_content()
	for key in _tabs:
		_tabs[key].button_pressed = key == tab
	_heading.text = TAB_LABELS[tab]
	match tab:
		"brief":
			_label(_content, "A NOITE CONTINUA", 23)
			_label(_content, str(_context.get("mission", "Explora a praça, encontra uma entrada para o Lado B e faz-te ouvir.")).to_upper(), 17, Color("a8afb2"))
			_label(_content, "SALDO   €%09d\nVIDA   %03d" % [maxi(0, int(_context.get("money", 0))), clampi(roundi(float(_context.get("health", 100))), 0, 100)], 21)
			_label(_content, "MAPAS: © OPENSTREETMAP CONTRIBUTORS · ODbL 1.0\nopenstreetmap.org/copyright · opendatacommons.org/licenses/odbl/1-0/", 12, Color("8e999d"))
			_button(_content, "VOLTAR À NOITE", _resume)
		"map":
			_map = NeighborhoodMap.new()
			_map.set("context", _context)
			_map.custom_minimum_size = Vector2(520, 360)
			_content.add_child(_map)
			_label(_content, "LISBOA COMPACTA   ·   VERDE: JOGADOR   ·   AZUL: MÚSICA", 13, Color("8e999d"))
		"quality":
			_option("QUALIDADE GRÁFICA", ["BAIXA / LEVE", "MÉDIA / EQUILIBRADA", "ALTA"], int(settings.quality), _change_quality)
			_option("POPULAÇÃO PRÓXIMA", ["6 PESSOAS", "10 PESSOAS", "16 PESSOAS"], [6, 10, 16].find(int(settings.population)), _change_population)
			_slider("MOTION BLUR DA CÂMARA · 0 DESLIGA",float(settings.motion_blur),0.0,1.0,_change_motion_blur)
			_label(_content, "A QUALIDADE CONTROLA DETALHE, DISTÂNCIA E ILUMINAÇÃO. A POPULAÇÃO É AJUSTADA SEPARADAMENTE. O OBJETIVO DE 60 FPS NO HP PRECISA DE MEDIÇÃO NO PORTÁTIL.", 15, Color("939c9f"))
		"hud":
			var checkbox := CheckButton.new()
			checkbox.text = "LEGENDAS DOS DIÁLOGOS"
			checkbox.button_pressed = bool(settings.subtitles)
			checkbox.toggled.connect(_change_subtitles)
			_content.add_child(checkbox)
			_slider("BRILHO", float(settings.brightness), 0.65, 1.45, _change_brightness)
		"controls":
			_build_controls()
		"audio":
			_slider("GERAL", float(settings.audio_master), 0.0, 1.0, _change_audio.bind("master"))
			_slider("MÚSICA", float(settings.audio_music), 0.0, 1.0, _change_audio.bind("music"))
			_slider("AMBIENTE", float(settings.audio_ambient), 0.0, 1.0, _change_audio.bind("ambient"))
			_slider("EFEITOS", float(settings.audio_effects), 0.0, 1.0, _change_audio.bind("effects"))
		"save":
			_label(_content, "PROGRESSO LOCAL", 23)
			_label(_content, "GUARDA DINHEIRO, BOLSA E ACESSOS. AO REABRIR A APLICAÇÃO, COMEÇAS NO TELHADO. AS DEFINIÇÕES DESTE MENU SÃO GUARDADAS À PARTE.", 16, Color("a8afb2"))
			_button(_content, "GUARDAR AGORA", _request_save)
			_button(_content, "CARREGAR ÚLTIMA GRAVAÇÃO", _request_load)
		"editor":
			_label(_content, "MODO CRIADOR", 23)
			_label(_content, "ENTRAR NO EDITOR DISPONÍVEL NESTA VERSÃO. A CÂMARA DE VOO E AS FERRAMENTAS DO MUNDO SÃO SEPARADAS DO PROGRESSO DO JOGADOR.", 16, Color("a8afb2"))
			_button(_content, "ABRIR EDITOR", _request_editor)
		"exit":
			_label(_content, "SAIR DO JOGO", 23)
			_label(_content, "ESCOLHE COMO QUERES FECHAR A APLICAÇÃO. O PASSO SEGUINTE PEDE CONFIRMAÇÃO.", 16, Color("a8afb2"))
			_button(_content, "GUARDAR E SAIR", _request_exit.bind(true))
			_button(_content, "SAIR SEM GUARDAR NOVAMENTE", _request_exit.bind(false))
			_button(_content, "CANCELAR / VOLTAR AO JOGO", _resume)


func _option(title: String, captions: Array, selected: int, callback: Callable) -> void:
	_label(_content, title, 16, Color("969fa3"))
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	for caption in captions:
		option.add_item(str(caption))
	option.select(maxi(selected, 0))
	option.item_selected.connect(callback)
	_content.add_child(option)


func _slider(title: String, value: float, minimum: float, maximum: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_content.add_child(row)
	var caption := _label(row, title, 17)
	caption.custom_minimum_size.x = 135
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = value
	row.add_child(slider)
	var number := _label(row, "%d%%" % roundi(value * 100), 15, Color("929da1"))
	number.custom_minimum_size.x = 65
	slider.value_changed.connect(func(v: float) -> void:
		number.text = "%d%%" % roundi(v * 100)
		callback.call(v))


func _change_quality(index: int) -> void:
	settings.quality = clampi(index, 0, 2)
	_save_settings()
	quality_changed.emit(settings.quality)


func _change_population(index: int) -> void:
	settings.population = [6, 10, 16][clampi(index, 0, 2)]
	_save_settings()
	population_changed.emit(settings.population)


func _change_audio(value: float, channel: String) -> void:
	if channel not in ["master", "music", "ambient", "effects"]:
		return
	settings["audio_" + channel] = clampf(value, 0.0, 1.0)
	_save_settings()
	audio_changed.emit(channel, settings["audio_" + channel])


func _change_brightness(value: float) -> void:
	settings.brightness = clampf(value, 0.65, 1.45)
	_save_settings()
	brightness_changed.emit(settings.brightness)


func _change_subtitles(enabled: bool) -> void:
	settings.subtitles = enabled
	_save_settings()
	subtitles_changed.emit(enabled)

func _change_motion_blur(value: float) -> void:
	settings.motion_blur = clampf(value,0.0,1.0)
	_save_settings()
	motion_blur_changed.emit(settings.motion_blur)


func _build_controls() -> void:
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	_content.add_child(modes)
	_button(modes, "TECLADO", _choose_mode.bind("keyboard"))
	_button(modes, "COMANDO", _choose_mode.bind("controller"))
	_capture_label = _label(_content, "ESC CANCELA A CAPTURA. CLICA NUMA AÇÃO E PRESSIONA A NOVA TECLA OU BOTÃO.", 14, Color("9da6a9"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 5)
	_content.add_child(grid)
	for action in ACTION_LABELS:
		var title := _label(grid, ACTION_LABELS[action], 16)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var binding := _button(grid, _binding_name(action), _begin_capture.bind(action))
		binding.custom_minimum_size = Vector2(240, 38)


func _binding_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "NÃO DEFINIDO"
	for event in InputMap.action_get_events(action):
		if _control_mode == "keyboard" and event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode).to_upper()
		if _control_mode == "keyboard" and event is InputEventMouseButton:
			return "RATO %d" % event.button_index
		if _control_mode == "controller" and event is InputEventJoypadButton:
			return event.as_text().to_upper()
		if _control_mode == "controller" and event is InputEventJoypadMotion:
			return "STICK ESQUERDO"
	return "DEFINIR TECLA" if _control_mode == "keyboard" else "DEFINIR BOTÃO"


func _choose_mode(mode: String) -> void:
	_control_mode = mode
	_select_tab("controls")
	_tabs.controls.grab_focus.call_deferred()


func _begin_capture(action: String) -> void:
	_capture_action = action
	_capture_label.text = "PRESSIONA %s PARA %s. ESC CANCELA." % ["UMA TECLA" if _control_mode == "keyboard" else "UM BOTÃO", ACTION_LABELS.get(action, action)]


func _request_save() -> void:
	save_requested.emit()


func _request_load() -> void:
	load_requested.emit()


func _request_editor() -> void:
	editor_requested.emit()


func _build_confirm() -> void:
	_confirm = Control.new()
	add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.8)
	_confirm.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_confirm.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -130
	panel.offset_bottom = 130
	var background := StyleBoxFlat.new()
	background.bg_color = Color("151c20")
	background.border_color = Color("aeb7b7")
	background.set_border_width_all(1)
	background.content_margin_left = 28
	background.content_margin_right = 28
	background.content_margin_top = 24
	background.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", background)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	_confirm_text = _label(box, "", 23)
	_button(box, "CONFIRMAR SAÍDA", _confirm_exit)
	_button(box, "CANCELAR", _cancel_exit)
	_confirm.hide()


func _request_exit(save_first: bool) -> void:
	_confirm_save = save_first
	_confirm_text.text = "GUARDAR O PROGRESSO E FECHAR O JOGO?" if save_first else "FECHAR SEM GUARDAR NOVAMENTE?"
	_confirm.show()
	_block_focus(_main_layout)
	_focus_first(_confirm)


func _confirm_exit() -> void:
	if not _confirm.visible:
		return
	var save_first := _confirm_save
	_confirm.hide()
	close_menu()
	exit_requested.emit(save_first)


func _cancel_exit() -> void:
	_confirm.hide()
	_restore_focus()
	_tabs.exit.grab_focus.call_deferred()


func _block_focus(parent: Node) -> void:
	for child in parent.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			_blocked_focus.append(child)
			child.focus_mode = Control.FOCUS_NONE
		_block_focus(child)


func _restore_focus() -> void:
	for control in _blocked_focus:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_ALL
	_blocked_focus.clear()


func _focus_first(parent: Node) -> bool:
	for child in parent.get_children():
		if child is BaseButton and not child.disabled:
			child.grab_focus.call_deferred()
			return true
		if _focus_first(child):
			return true
	return false


class NeighborhoodMap extends Control:
	var context: Dictionary = {}
	func _draw() -> void:
		var bounds := Rect2(Vector2(4, 4), Vector2(size.x - 8, 350))
		draw_style_box(_background_style(), bounds)
		if not context.get("map_overlay",{}).is_empty():
			_draw_city(bounds)
			return
		var center := bounds.get_center()
		var scale_factor := minf(bounds.size.x, bounds.size.y) / 90.0
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(center + Vector2(side * 12 - 8, -31) * scale_factor, Vector2(14, 25) * scale_factor), Color("3d484d"))
			draw_rect(Rect2(center + Vector2(side * 12 - 8, 9) * scale_factor, Vector2(14, 22) * scale_factor), Color("3d484d"))
		draw_line(center + Vector2(-37, 0) * scale_factor, center + Vector2(37, 0) * scale_factor, Color("8d9694"), 10.0)
		draw_line(center + Vector2(0, -36) * scale_factor, center + Vector2(0, 36) * scale_factor, Color("8d9694"), 10.0)
		draw_circle(center, scale_factor * 8.0, Color("222d31"))
		draw_arc(center, scale_factor * 8.0, 0, TAU, 40, Color("707c80"), 2.0)
		var player_position: Vector3 = context.get("player_position", Vector3.ZERO)
		var marker := center + Vector2(player_position.x, player_position.z) * scale_factor
		marker.x = clampf(marker.x, bounds.position.x + 10, bounds.end.x - 10)
		marker.y = clampf(marker.y, bounds.position.y + 10, bounds.end.y - 10)
		draw_circle(marker, 6.0, Color("85c29d"))
		draw_circle(center + Vector2(-16, -17) * scale_factor, 5.0, Color("8caec5"))
	func _draw_city(bounds: Rect2) -> void:
		var data: Dictionary = context.map_overlay
		var extent := Rect2(Vector2(-120,-200),Vector2(780,1480))
		var factor := minf((bounds.size.x-110)/extent.size.x,(bounds.size.y-16)/extent.size.y)
		var offset := bounds.get_center()-extent.get_center()*factor
		var font: Font = load("res://assets/fonts/Interface.ttf")
		draw_rect(bounds,Color("18313b"))
		var peninsula: Variant = data.get("peninsula",{})
		var coast: Array = peninsula.get("coastline",peninsula.get("polygon",[])) if peninsula is Dictionary else peninsula if peninsula is Array else []
		if coast.size()>2:
			var polygon := PackedVector2Array()
			for point in coast: polygon.append(offset+Vector2(point[0],point[1])*factor)
			draw_colored_polygon(polygon,Color("394748"))
			polygon.append(polygon[0])
			draw_polyline(polygon,Color("b6a587"),1.5,true)
		for district in data.districts:
			var b: Array = district.bounds
			draw_rect(Rect2(offset+Vector2(b[0],b[1])*factor,Vector2(b[2]-b[0],b[3]-b[1])*factor),Color(0.28,0.35,0.35,0.6))
			for road in district.major_roads:
				var points := PackedVector2Array()
				for point in road.points: points.append(offset+Vector2(point[0],point[1])*factor)
				if points.size()>1: draw_polyline(points,Color("b0a58d"),1.5,true)
			var at := offset+Vector2(district.spawn[0],district.spawn[1])*factor
			draw_circle(at,3.5,Color("8caec5"))
			draw_string(font,Vector2(offset.x+480*factor,at.y+4),district.label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e3d8bd"))
		for link in data.get("roads",data.links):
			var points := PackedVector2Array()
			for point in link.points: points.append(offset+Vector2(point[0],point[1])*factor)
			if points.size()>1: draw_polyline(points,Color("aaa38c"),2.0,true)
		for place in data.get("places",[]):
			var point: Array = place.get("position",[])
			if point.size()>=2: draw_circle(offset+Vector2(point[0],point[-1])*factor,1.8,Color("d2a766"))
		draw_line(offset+Vector2(240,1020)*factor,offset+Vector2(240,1170)*factor,Color("c87951"),3)
		draw_string(font,offset+Vector2(460,1090)*factor,"Tejo / Ponte",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d9d4c6"))
		draw_circle(offset+Vector2(-16,-17)*factor,3.5,Color("8caec5"))
		var at: Vector3 = context.get("player_position",Vector3.ZERO)
		draw_circle(offset+Vector2(at.x,at.z)*factor,5.0,Color("85c29d"))
	func _background_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("131d22")
		style.border_color = Color("566369")
		style.set_border_width_all(1)
		return style
