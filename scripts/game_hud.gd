class_name GameHUD
extends Control
## Original compact status display. No artwork or typeface is taken from GTA.
var money: int = 0
var health: float = 100.0
var weapon: String = "DESARMADO"
var wanted: float = 0.0
var _wanted_display: float = 0.0
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Menu.ttf") if ResourceLoader.exists("res://assets/fonts/Menu.ttf") else ThemeDB.fallback_font

func set_status(cash: int, life: float, held_weapon: String, pressure: float) -> void:
	money = clampi(cash, 0, 999999999)
	health = clampf(life, 0.0, 100.0)
	weapon = held_weapon.to_upper() if not held_weapon.is_empty() else "DESARMADO"
	wanted = clampf(pressure, 0.0, 100.0)
	queue_redraw()

func get_money_text() -> String:
	return "€%09d" % money

func _process(delta: float) -> void:
	var previous := _wanted_display
	_wanted_display = move_toward(_wanted_display, wanted, maxf(0.0, delta) * 55.0)
	if previous != _wanted_display:
		queue_redraw()

func _draw() -> void:
	if not is_node_ready() or _font == null:
		return
	var right := size.x - 28.0
	var top := 26.0
	# An original fist icon uses drawn knuckles/thumb, with no external image.
	var icon := Rect2(right - 66, top, 66, 65)
	draw_style_box(_panel(), icon)
	if weapon in ["DESARMADO", "MÃOS", "PUNHO", "PUNHOS", "UNARMED"]:
		for i in 4:
			var knuckle := Rect2(icon.position + Vector2(12 + i * 10, 13 + absf(i - 1.5) * 1.5), Vector2(9, 18))
			draw_rect(knuckle, Color("d0d4cf"))
		draw_polygon(PackedVector2Array([icon.position + Vector2(14,29),icon.position + Vector2(49,29),icon.position + Vector2(48,47),icon.position + Vector2(35,55),icon.position + Vector2(21,49)]),PackedColorArray([Color("d0d4cf")]))
		draw_line(icon.position + Vector2(19,29),icon.position + Vector2(12,40),Color("858f91"),7.0,true)
	elif "PISTOLA" in weapon or "ARMA" in weapon:
		draw_line(icon.position + Vector2(13,27), icon.position + Vector2(53,27), Color("d0d4cf"), 9, true)
		draw_line(icon.position + Vector2(30,28), icon.position + Vector2(24,49), Color("d0d4cf"), 9, true)
	elif "PULSEIRA" in weapon:
		draw_arc(icon.get_center(), 18.0, -0.5, TAU - 0.8, 20, Color("d0d4cf"), 5.0, true)
	elif "GARRAFA" in weapon or "ÁLCOOL" in weapon:
		draw_rect(Rect2(icon.position + Vector2(25,12),Vector2(15,12)),Color("d0d4cf"))
		draw_style_box(_item_style(),Rect2(icon.position + Vector2(20,23),Vector2(25,30)))
	else:
		draw_style_box(_item_style(),Rect2(icon.position + Vector2(18,15),Vector2(30,37)))
		draw_line(icon.position + Vector2(24,26),icon.position + Vector2(42,26),Color("667372"),3.0,true)
	var cash := get_money_text()
	_draw_text_right(cash, Vector2(right - 80, top + 28), 27, Color("d0d4cf"))
	_draw_text_right("VIDA %03d" % roundi(health), Vector2(right - 80, top + 48), 12, Color("c5c9c3"))
	var life := Rect2(right - 273, top + 56, 193, 8)
	draw_rect(life, Color(0.08,0.11,0.12,0.7))
	draw_rect(Rect2(life.position,Vector2(life.size.x * health / 100.0,life.size.y)), Color("a0605d"))
	if wanted > 0.0:
		_draw_wanted(Vector2(right - 273, top + 83), 273.0)

func _draw_wanted(origin: Vector2, width: float) -> void:
	# One continuous body, five equal subdivisions; divider lines don't make gaps.
	var bar := Rect2(origin, Vector2(width, 15))
	draw_rect(bar, Color(0.62,0.67,0.67,0.18))
	var fill_width := bar.size.x * _wanted_display / 100.0
	if fill_width > 0.0:
		draw_rect(Rect2(bar.position,Vector2(fill_width,bar.size.y)),Color("ced4cf"))
	draw_rect(bar,Color("899491"),false,1.0)
	for i in range(1,5):
		var x := bar.position.x + bar.size.x / 5.0 * i
		draw_line(Vector2(x,bar.position.y),Vector2(x,bar.end.y),Color(0.08,0.12,0.13,0.8),1.0)
	# A subtle left handle and right tip establish the direction of fill.
	draw_rect(Rect2(origin + Vector2(-4,-2),Vector2(4,19)),Color("667372"))
	draw_line(Vector2(bar.end.x + 2,bar.position.y + 3),Vector2(bar.end.x + 2,bar.end.y - 3),Color("899491"),2.0)
	_draw_text_right("PRESSÃO", Vector2(bar.end.x,bar.end.y + 15),10,Color("9ba5a2"))

func _draw_text_right(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(_font, baseline - Vector2(width,0), text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.06,0.07,0.75)
	style.border_color = Color("899491")
	style.set_border_width_all(1)
	return style

func _item_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d0d4cf")
	style.set_corner_radius_all(4)
	return style
