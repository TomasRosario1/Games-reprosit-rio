class_name AlbumRhythmView
extends Control
## Draw-only note highway. Input, audio, score and audience belong to the caller.

const LOOKAHEAD := 2.0
const FLASH_SECONDS := 0.18

var rhythm: RefCounted
var keys: Array[String] = ["D", "F", "J", "K"]
var lane_colors: Array[Color] = [
	Color("6edacb"), Color("ed869a"), Color("e8bf78"), Color("b6a3f2")
]
var _flashes: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_hits: Array[bool] = [true, true, true, true]
var _font: Font
var _panel_style: StyleBoxFlat
var _note_styles: Array[StyleBoxFlat] = []
var _key_styles: Array[StyleBoxFlat] = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/Interface.ttf"):
		_font = load("res://assets/fonts/Interface.ttf") as Font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_panel_style = _style(Color(0.025, 0.035, 0.045, 0.88), 16)
	_panel_style.border_color = Color(0.75, 0.81, 0.83, 0.16)
	_panel_style.set_border_width_all(1)
	for color in lane_colors:
		var note := _style(color, 5)
		note.shadow_color = Color(color, 0.15)
		note.shadow_size = 5
		_note_styles.append(note)
		var key := _style(Color(0.06, 0.08, 0.09, 0.95), 8)
		key.set_border_width_all(1)
		key.border_color = Color(color, 0.55)
		_key_styles.append(key)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for lane in 4:
		_flashes[lane] = maxf(0.0, _flashes[lane] - delta)
	queue_redraw()


func flash_lane(lane: int, hit: bool) -> void:
	if lane < 0 or lane >= 4:
		return
	_flashes[lane] = FLASH_SECONDS
	_flash_hits[lane] = hit
	queue_redraw()


func _draw() -> void:
	if not is_node_ready() or _panel_style == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var panel_width := minf(480.0, size.x - 32.0)
	var left := (size.x - panel_width) * 0.5
	var top := minf(130.0, size.y * 0.22)
	var bottom := size.y - 55.0
	var target_y := size.y - 105.0
	var travel := maxf(40.0, target_y - top - 12.0)
	var inner_left := left + 16.0
	var lane_width := (panel_width - 32.0) / 4.0
	var song_time := 0.0
	var song_bpm := 100.0
	var song_notes: Array = []
	if rhythm != null:
		song_time = float(rhythm.get("elapsed"))
		song_bpm = float(rhythm.get("bpm"))
		song_notes = rhythm.get("notes")
	draw_style_box(_panel_style, Rect2(left, top, panel_width, bottom - top))
	# Four quiet columns keep the rhythm view readable over a lit 3D scene.
	for lane in 4:
		var x := inner_left + float(lane) * lane_width
		draw_rect(Rect2(x + 4.0, top + 10.0, lane_width - 8.0, target_y - top + 9.0), Color(lane_colors[lane], 0.035))
		if lane > 0:
			draw_line(Vector2(x, top + 14.0), Vector2(x, target_y + 10.0), Color(0.7, 0.8, 0.8, 0.09), 1.0)
	# Beat guides are derived from musical time, never from frame count.
	var beat := 60.0 / maxf(40.0, song_bpm)
	var first_beat := floori(song_time / beat)
	var guide_count := ceili(LOOKAHEAD / beat) + 2
	for index in guide_count:
		var beat_time := float(first_beat + index) * beat
		var y := target_y - ((beat_time - song_time) / LOOKAHEAD) * travel
		if y >= top + 10.0 and y <= target_y:
			draw_line(Vector2(inner_left, y), Vector2(inner_left + lane_width * 4.0, y), Color(0.8, 0.85, 0.85, 0.09), 1.0)
	# Window halo shows where the actual time-based hit window is located.
	var window := 0.18 if rhythm == null else float(rhythm.get("hit_window"))
	var window_height := window / LOOKAHEAD * travel
	draw_rect(Rect2(inner_left, target_y - window_height, lane_width * 4.0, window_height * 2.0), Color(0.82, 0.88, 0.85, 0.035))
	draw_line(Vector2(inner_left, target_y), Vector2(inner_left + lane_width * 4.0, target_y), Color(0.91, 0.94, 0.90, 0.75), 2.0)
	for note in song_notes:
		if note["state"] != "pending":
			continue
		var offset := float(note["time"]) - song_time
		if offset > LOOKAHEAD or offset < -window:
			continue
		var lane := int(note["lane"])
		if lane < 0 or lane > 3:
			continue
		var center_x := inner_left + (float(lane) + 0.5) * lane_width
		var y := target_y - offset / LOOKAHEAD * travel
		var note_width := lane_width - 26.0
		draw_style_box(_note_styles[lane], Rect2(center_x - note_width * 0.5, y - 7.0, note_width, 14.0))
		draw_line(Vector2(center_x - note_width * 0.5 + 8.0, y - 3.0), Vector2(center_x + note_width * 0.5 - 8.0, y - 3.0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
	for lane in 4:
		var center_x := inner_left + (float(lane) + 0.5) * lane_width
		var key_rect := Rect2(center_x - 21.0, target_y + 16.0, 42.0, 32.0)
		draw_style_box(_key_styles[lane], key_rect)
		if _flashes[lane] > 0.0:
			var strength := _flashes[lane] / FLASH_SECONDS
			var color := lane_colors[lane] if _flash_hits[lane] else Color("f08079")
			draw_rect(Rect2(inner_left + lane_width * lane + 4.0, top + 10.0, lane_width - 8.0, target_y - top + 2.0), Color(color, strength * 0.12))
			draw_circle(Vector2(center_x, target_y), 15.0 + (1.0 - strength) * 13.0, Color(color, strength * 0.45))
		var text := keys[lane] if lane < keys.size() else str(lane + 1)
		var label_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x
		draw_string(_font, Vector2(center_x - label_width * 0.5, target_y + 38.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, lane_colors[lane])


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
