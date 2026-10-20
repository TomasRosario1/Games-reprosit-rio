class_name AlbumWorld
extends Node3D
## A small, deliberately authored Lisbon-inspired block. Art is procedural study material.

var rooftop_spawn := Transform3D(Basis(), Vector3(-16, 9.7, 15))
var street_safe := Transform3D(Basis(), Vector3(-4, 0.5, 3))
var wristband_position := Vector3(-4, 0.7, 2)
var guard_position := Vector3(-12, 0, -4.2)
var stage_position := Vector3(-16, 0, -17)
var entrance_position := Vector3(-13, 0, -6)
var _materials: Dictionary = {}
var _door: StaticBody3D
var _door_mesh: MeshInstance3D
var _wristband: Node3D
var _guard_marker: MeshInstance3D
var _wristband_light: OmniLight3D
var _audience: Array[Node3D] = []
var _reactive_lights: Array[OmniLight3D] = []
var _emissive: Array[StandardMaterial3D] = []
var _cars: Array[Node3D] = []
var _time := 0.0
var _crowd_count := 6
var _unlocked := false

func _ready() -> void:
	name = "BairroDaMadrugada"
	_build_environment()
	_build_streets()
	_build_architecture()
	_build_rooftop()
	_build_stairway()
	_build_bar()
	_build_street_life()
	_build_background()
	set_bar_unlocked(false)
	set_audience(75.0)
	_batch_static_geometry()

func _material(key: String, tint := Color.WHITE, glow := Color.BLACK, emission_power := 0.0) -> StandardMaterial3D:
	var cache_key := "%s:%s:%s:%s" % [key, tint.to_html(), glow.to_html(), emission_power]
	if _materials.has(cache_key):
		return _materials[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/%s.png" % key)
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/%s_normal.png" % key)
	mat.normal_scale = 0.45
	mat.roughness_texture = load("res://assets/textures/%s_rough.png" % key)
	mat.roughness = 0.82
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.45
	mat.uv1_triplanar_sharpness = 8.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emission_power > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = emission_power
	_materials[cache_key] = mat
	return mat

func _box(pos: Vector3, size: Vector3, material: Material, collision := false, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	(parent if parent else self).add_child(node)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
	return node

func _cylinder(pos: Vector3, radius: float, height: float, material: Material, parent: Node3D = null, top_radius := -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 10
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	(parent if parent else self).add_child(node)
	return node

func _label(text: String, pos: Vector3, size: int, color: Color, facing := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font = load("res://assets/fonts/Interface.ttf")
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.rotation.y = facing
	add_child(label)
	return label

func _light(pos: Vector3, color: Color, energy: float, radius: float, reactive := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	add_child(light)
	if reactive:
		_reactive_lights.append(light)
	return light

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101a2b")
	env.background_energy_multiplier = 0.65
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a9ab7")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Luar"
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color("9cbbd7")
	moon.light_energy = 0.34
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

func _build_streets() -> void:
	_box(Vector3(0, -0.3, 0), Vector3(73, 0.6, 73), _material("asphalt"), true)
	# Calçada walks frame the crossing while remaining easy to climb.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 5.3, 0.035, 0), Vector3(2.8, 0.07, 60), _material("calcada"), true)
		_box(Vector3(0, 0.036, side * 5.0), Vector3(60, 0.072, 2), _material("calcada"), true)
		for z in range(-27, 29, 7):
			if abs(z) < 7:
				continue
			_box(Vector3(side * 3.0, 0.012, z), Vector3(0.09, 0.02, 2.6), _material("marking", Color(0.8, 0.8, 0.7)))
	# Crosswalks on either side of the small square.
	for z in [-8.0, 8.0]:
		for x in range(-3, 4):
			_box(Vector3(float(x), 0.015, z), Vector3(0.55, 0.025, 1.8), _material("marking"))
	for pos in [Vector3(5.8, 0, -2), Vector3(-5.9, 0, -13), Vector3(7, 0, 3), Vector3(20, 0, 4)]:
		_streetlamp(pos)
	_box(Vector3(11.0, 0.055, 4.4), Vector3(3.0, 0.05, 0.7), _material("metal"))
	# Road limits are architectural walls, not invisible collisions.
	_box(Vector3(-32, 1.0, 0), Vector3(0.5, 2.0, 64), _material("stucco"), true)
	_box(Vector3(32, 1.0, 0), Vector3(0.5, 2.0, 64), _material("stucco"), true)
	_box(Vector3(0, 1.0, -32), Vector3(64, 2.0, 0.5), _material("stucco"), true)
	_box(Vector3(0, 1.0, 32), Vector3(64, 2.0, 0.5), _material("stucco"), true)

func _streetlamp(pos: Vector3) -> void:
	_cylinder(pos + Vector3(0, 2.2, 0), 0.055, 4.4, _material("metal"))
	_box(pos + Vector3(0, 4.35, 0), Vector3(0.55, 0.14, 0.55), _material("metal"))
	_box(pos + Vector3(0, 4.27, 0), Vector3(0.42, 0.05, 0.42), _material("marking", Color.WHITE, Color("ffc27e"), 2.2))
	_light(pos + Vector3(0, 4.0, 0), Color("ffc994"), 1.6, 8.5)

func _build_architecture() -> void:
	# Starting building. Other blocks have modest variations in height and colour.
	_building(Vector3(-16, 0, 15.5), Vector3(18, 9.3, 19), "ochre", false)
	_box(Vector3(-16, 9.4, 15.5), Vector3(18.1, 0.2, 19.1), _material("calcada"), true)
	_building(Vector3(16, 0, -15.5), Vector3(18, 13.0, 19), "pink", false)
	_building(Vector3(16, 0, 15.5), Vector3(18, 10.2, 19), "blue", false)
	# The bar building has a fully walkable ground-floor interior.
	_building(Vector3(-16, 0, -15.5), Vector3(18, 11.8, 19), "stucco", true)
	_box(Vector3(-16, 0.08, -15.5), Vector3(17.8, 0.12, 18.8), _material("wood"), true)
	# Low decorative azulejo bands on the street-facing walls.
	_box(Vector3(16, 0.68, 5.94), Vector3(18, 1.25, 0.06), _material("tiles"))
	_box(Vector3(6.94, 0.68, -15.5), Vector3(0.06, 1.25, 19), _material("tiles"))
	_box(Vector3(-16, 0.68, 5.94), Vector3(18, 1.25, 0.06), _material("tiles"))
	_label("RUA DA MADRUGADA", Vector3(7.0, 2.6, 6.0), 20, Color("d5d7cc"), -PI * 0.5)
	_box(Vector3(6.9, 2.6, 6.0), Vector3(0.12, 0.44, 2.9), _material("tiles"))
	_label("LISBOA\n02:17", Vector3(16, 8.0, 5.86), 62, Color("bad7cc"), PI)

func _building(center: Vector3, size: Vector3, material: String, open_bar: bool) -> void:
	var mat := _material(material)
	if open_bar:
		_box(center + Vector3(0, (size.y + 4.0) * 0.5, 0), Vector3(size.x, size.y - 4.0, size.z), mat, true)
		_box(center + Vector3(-size.x * 0.5 + 0.15, 2, 0), Vector3(0.3, 4, size.z), _material("tiles"), true)
		_box(center + Vector3(size.x * 0.5 - 0.15, 2, 0), Vector3(0.3, 4, size.z), _material("tiles"), true)
		_box(center + Vector3(0, 2, -size.z * 0.5 + 0.15), Vector3(size.x, 4, 0.3), _material("pink"), true)
		# South-facing façade, an actual three-metre opening at x=-13.
		_box(Vector3(-19.75, 2, -6), Vector3(10.5, 4, 0.3), _material("tiles"), true)
		_box(Vector3(-9.25, 2, -6), Vector3(4.5, 4, 0.3), _material("tiles"), true)
		_box(Vector3(-13, 3.6, -6), Vector3(3, 0.8, 0.3), _material("metal"), true)
	else:
		_box(center + Vector3(0, size.y * 0.5, 0), size, mat, true)
	# Cornices, roof, and corner pilasters create silhouettes without high-poly detail.
	_box(center + Vector3(0, size.y + 0.08, 0), Vector3(size.x + 0.35, 0.16, size.z + 0.35), _material("stucco"))
	for y in [3.4, 6.6, 9.7]:
		if y > size.y:
			continue
		_box(center + Vector3(0, y, -size.z * 0.5 - 0.03), Vector3(size.x, 0.14, 0.12), _material("stucco"))
		_box(center + Vector3(0, y, size.z * 0.5 + 0.03), Vector3(size.x, 0.14, 0.12), _material("stucco"))
	for floor_index in range(3):
		var y := 2.0 + floor_index * 3.1
		if open_bar and floor_index == 0:
			continue
		for column in range(4):
			var x := center.x - 6.6 + column * 4.4
			_window(Vector3(x, y, center.z + size.z * 0.5 + 0.04), floor_index + column, false)
			_window(Vector3(x, y, center.z - size.z * 0.5 - 0.04), floor_index + column + 1, true)
	# Side windows visible from the central street.
	for floor_index in range(3):
		if open_bar and floor_index == 0:
			continue
		for column in range(3):
			var xface := center.x + (size.x * 0.5 + 0.035) * (-1 if center.x > 0 else 1)
			var pos := Vector3(xface, 2.0 + floor_index * 3.1, center.z - 5.5 + column * 5.5)
			_box(pos, Vector3(0.08, 1.65, 1.1), _material("metal"))
			var tint := Color("d6b484") if (floor_index + column) % 3 == 0 else Color("557a8d")
			_box(pos + Vector3(-0.05 if center.x > 0 else 0.05, 0, 0), Vector3(0.04, 1.4, 0.85), _material("glass", Color.WHITE, tint, 0.7))

func _window(pos: Vector3, variant: int, back: bool) -> void:
	var outward := -1.0 if back else 1.0
	_box(pos, Vector3(1.4, 1.9, 0.12), _material("stucco"))
	_box(pos + Vector3(0, 0, outward * 0.08), Vector3(1.15, 1.65, 0.08), _material("metal"))
	var glow := Color("ffcc88") if variant % 3 == 0 else Color("4d7082")
	_box(pos + Vector3(0, 0, outward * 0.13), Vector3(0.95, 1.45, 0.04), _material("glass", Color.WHITE, glow, 0.85 if variant % 3 == 0 else 0.25))
	_box(pos + Vector3(0, 0, outward * 0.17), Vector3(0.05, 1.5, 0.03), _material("metal"))
	_box(pos + Vector3(0, -0.05, outward * 0.17), Vector3(1, 0.05, 0.03), _material("metal"))
	_box(pos + Vector3(-0.85, 0, 0), Vector3(0.4, 1.75, 0.12), _material("wood", Color(0.55, 0.8, 0.75)))

func _build_rooftop() -> void:
	# Rooftop edge is open only at the top stair landing.
	for x in [-24.85, -7.15]:
		_box(Vector3(x, 9.8, 14.0), Vector3(0.22, 0.6, 15.8), _material("stucco"), true)
	_box(Vector3(-16, 9.8, 6.15), Vector3(18, 0.6, 0.22), _material("stucco"), true)
	_box(Vector3(-17, 9.8, 24.85), Vector3(16, 0.6, 0.22), _material("stucco"), true)
	# Utility hut and weathered terracotta roof.
	_box(Vector3(-21.6, 10.6, 20.3), Vector3(4.2, 2.2, 4.1), _material("stucco"), true)
	var roof_a := _box(Vector3(-22.65, 11.9, 20.3), Vector3(2.35, 0.18, 4.45), _material("roof"))
	roof_a.rotation.z = 0.24
	var roof_b := _box(Vector3(-20.55, 11.9, 20.3), Vector3(2.35, 0.18, 4.45), _material("roof"))
	roof_b.rotation.z = -0.24
	_box(Vector3(-21.7, 10.25, 18.22), Vector3(0.9, 1.5, 0.05), _material("wood"))
	_box(Vector3(-10, 9.85, 9.2), Vector3(1.7, 0.7, 0.8), _material("metal"), true)
	for index in range(7):
		_box(Vector3(-10.6 + index * 0.2, 9.88, 8.78), Vector3(0.06, 0.4, 0.03), _material("metal", Color(0.35, 0.38, 0.4)))
	_box(Vector3(-22.0, 10.35, 9.1), Vector3(0.8, 1.7, 0.8), _material("roof"), true)
	_box(Vector3(-22.0, 11.25, 9.1), Vector3(1.0, 0.15, 1.0), _material("stucco"))
	# TV aerial, light string, and a textured rug at the starting position.
	_cylinder(Vector3(-23, 11.3, 14), 0.025, 3.6, _material("metal"))
	_box(Vector3(-23, 12.7, 14), Vector3(2.0, 0.03, 0.03), _material("metal"))
	for offset in [-0.7, -0.25, 0.25, 0.7]:
		_box(Vector3(-23 + offset, 12.7, 14), Vector3(0.02, 0.02, 0.8), _material("metal"))
	_box(Vector3(-16, 9.51, 15), Vector3(2.8, 0.015, 2.2), _material("tiles", Color(0.65, 0.7, 0.7)))
	for index in range(5):
		var pos := Vector3(-18.7 + index * 1.35, 11.7, 22.5)
		_cylinder(pos, 0.045, 0.11, _material("marking", Color.WHITE, Color("f7bf83"), 2.0))
	_light(Vector3(-16, 11, 20), Color("ffc38d"), 1.1, 9)
	_label("↓ RUA", Vector3(-7.2, 10.3, 23.9), 28, Color("d1c8a0"))

func _build_stairway() -> void:
	var x := -5.45
	var length := 17.0
	var rise := 9.5
	var ramp := StaticBody3D.new()
	ramp.name = "EscadaRampaSuave"
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(x-1.15,0,7),Vector3(x+1.15,0,7),Vector3(x-1.15,rise,24),Vector3(x+1.15,rise,24),
		Vector3(x-1.15,-0.1,24),Vector3(x+1.15,-0.1,24)])
	collider.shape = shape
	ramp.add_child(collider)
	add_child(ramp)
	for index in range(52):
		var step_h := rise / 52.0
		var step_l := length / 52.0
		var height := (index+1) * step_h
		_box(Vector3(x, height * 0.5 - 0.02, 7 + (index+0.5)*step_l), Vector3(2.3, height, step_l), _material("stucco"))
	_box(Vector3(-6.6, 9.4, 24.1), Vector3(4.0, 0.2, 1.1), _material("calcada"), true)
	# Metal outer handrail follows the slope. Posts stay off the walking line.
	var rail := _box(Vector3(x+1.2, rise * 0.5 + 0.85, 15.5), Vector3(0.06, 0.06, sqrt(length*length+rise*rise)), _material("metal"))
	rail.rotation.x = -atan2(rise, length)
	for index in range(7):
		var z := 7.0 + index * length / 6.0
		var y := (z-7.0)/length*rise
		_cylinder(Vector3(x+1.2,y+0.45,z),0.035,0.9,_material("metal"))
	_light(Vector3(-5.2, 4, 11), Color("a7b8c8"), 0.8, 8)

func _build_bar() -> void:
	_box(Vector3(-13, 3.0, -5.72), Vector3(4.4, 0.85, 0.2), _material("metal"))
	_label("L A D O   B", Vector3(-13, 3.1, -5.58), 51, Color("f5a89b"))
	_label("BAR  ·  MÚSICA AO VIVO", Vector3(-13, 2.73, -5.57), 16, Color("e8c4aa"))
	for x in [-14.6, -11.4]:
		var mat := _material("marking", Color.WHITE, Color("ed776b"), 2.2).duplicate() as StandardMaterial3D
		_emissive.append(mat)
		_box(Vector3(x, 1.5, -5.78), Vector3(0.04, 2.6, 0.05), mat)
	_door = StaticBody3D.new()
	_door.position = Vector3(-13, 1.55, -6)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.1, 0.3)
	collision.shape = shape
	_door.add_child(collision)
	add_child(_door)
	_door_mesh = _box(Vector3(-13, 1.45, -6), Vector3(2.8, 2.9, 0.12), _material("metal"))
	# Counter and wall shelves.
	_box(Vector3(-22.6, 0.6, -16), Vector3(1.5, 1.2, 11), _material("wood"), true)
	_box(Vector3(-22.4, 1.25, -16), Vector3(1.95, 0.12, 11.3), _material("metal"))
	for shelf in [1.9, 2.8]:
		_box(Vector3(-24.45, shelf, -17), Vector3(0.6, 0.1, 9), _material("wood"))
		for index in range(9):
			_cylinder(Vector3(-24.15, shelf+0.22, -21+index), 0.08, 0.34, _material("glass", Color(0.6, 0.8, 0.5)))
	# Small stage avoids stairs or collision snags and frames the musical interaction.
	_box(Vector3(-16, 0.07, -20.8), Vector3(8, 0.14, 4.7), _material("wood"), true)
	_box(Vector3(-16, 1.0, -20.5), Vector3(3, 0.12, 0.8), _material("metal"))
	for x in [-17.1, -14.9]:
		_box(Vector3(x, 0.5, -20.5), Vector3(0.08, 1, 0.6), _material("metal"))
	for x in [-16.7, -15.3]:
		_cylinder(Vector3(x, 1.1, -20.5), 0.28, 0.06, _material("metal", Color(0.6,0.65,0.7)))
	for x in [-19.0, -12.8]:
		_box(Vector3(x, 0.9, -21.5), Vector3(0.8, 1.65, 0.75), _material("coat"), true)
		for y in [0.6, 1.2]:
			var speaker := _cylinder(Vector3(x,y,-21.1),0.23,0.06,_material("metal"))
			speaker.rotation.x = PI * 0.5
	_box(Vector3(-16, 2.6, -24.72), Vector3(7.5, 2.4, 0.05), _material("coat"))
	_label("ÓDIO PURO\nNO MEU PEITO", Vector3(-16, 2.7, -24.65), 100, Color("d9d7c8"))
	_label("SESSÃO DE ENSAIO", Vector3(-16, 1.75, -24.64), 18, Color("8eaaa9"))
	# Tables and benches along the east wall leave a clear central path.
	for z in [-11.0, -16.0, -21.0]:
		_cylinder(Vector3(-9.2,0.4,z),0.06,0.8,_material("metal"))
		_cylinder(Vector3(-9.2,0.82,z),0.75,0.08,_material("wood"))
		_box(Vector3(-7.8,0.45,z),Vector3(0.9,0.9,2.0),_material("coat",Color(0.8,0.45,0.45)),true)
		_cylinder(Vector3(-9.1,0.96,z),0.06,0.23,_material("glass"))
	_light(Vector3(-13, 2.7, -5.1), Color("ef9980"), 1.6, 7, true)
	_light(Vector3(-16, 3, -18), Color("78b9c5"), 2.7, 11, true)
	_light(Vector3(-22, 2.8, -15), Color("e3a666"), 1.9, 9)
	_light(Vector3(-18, 2.6, -23), Color("f0bb7f"), 1.4, 7)
	_box(Vector3(-21.62,0.95,-16),Vector3(0.035,0.035,10.8),_material("marking",Color.WHITE,Color("e4ae70"),1.5))
	_box(Vector3(-16,3.85,-22),Vector3(7.3,0.035,0.035),_material("marking",Color.WHITE,Color("75bcc0"),1.4))
	_light(Vector3(-9, 2.8, -11), Color("b47887"), 1.1, 7)
	# Attendance is visible in-world and directly driven by rhythm success.
	for index in range(8):
		var angle := -0.9 + index * 1.8/7.0
		var pos := Vector3(-16+sin(angle)*3.3,0.14,-18.0+cos(angle)*3.4)
		var person := _person(pos, Color(0.6+index*0.025,0.62,0.65), 0.93+index*0.018)
		person.rotation.y = angle + PI
		_audience.append(person)
	# The actual interaction marker is at stage_position, ahead of the crowd.
	var marker_material := _material("metal",Color.WHITE,Color("88c8bf"),1.4)
	_cylinder(stage_position+Vector3(0,0.16,0),0.42,0.035,marker_material)

func _person(pos: Vector3, tint: Color, scale_factor: float) -> Node3D:
	var person := Node3D.new()
	person.position = pos
	person.scale = Vector3.ONE * scale_factor
	add_child(person)
	var cloth := _material("coat", tint)
	var skin := _material("stucco",Color(0.65,0.48,0.38))
	var pants := _material("coat",Color(0.55,0.6,0.65))
	_cylinder(Vector3(0,1.18,0),0.25,0.65,cloth,person,0.32)
	_cylinder(Vector3(0,1.72,0),0.15,0.31,skin,person,0.16)
	_box(Vector3(0,1.9,0),Vector3(0.29,0.09,0.28),_material("coat",Color(0.4,0.35,0.3)),false,person)
	for side in [-1.0,1.0]:
		_cylinder(Vector3(side*0.14,0.53,0),0.105,0.85,pants,person)
		_box(Vector3(side*0.14,0.11,-0.07),Vector3(0.22,0.17,0.4),_material("metal"),false,person)
		var arm := _cylinder(Vector3(side*0.33,1.2,0),0.09,0.68,cloth,person)
		arm.rotation.z = side * 0.11
		_cylinder(Vector3(side*0.37,0.82,0),0.07,0.17,skin,person)
	return person

func _build_street_life() -> void:
	var guard := _person(guard_position,Color(0.55,0.65,0.85),1.16)
	guard.name = "Seguranca"
	guard.rotation.y = PI
	# Blue is mission-person identification; red is the lost wristband.
	_guard_marker = _cylinder(guard_position+Vector3(0,0.08,0),0.42,0.04,_material("metal",Color.WHITE,Color("527fc8"),1.8))
	_wristband = Node3D.new()
	_wristband.position = wristband_position
	add_child(_wristband)
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.15
	torus.rings = 12
	torus.ring_segments = 8
	band.mesh = torus
	band.material_override = _material("marking",Color.WHITE,Color("ed7274"),2.4)
	band.rotation_degrees.x = 35
	_wristband.add_child(band)
	_wristband_light = _light(wristband_position,Color("e9726b"),0.6,2.5)
	for p in [Vector3(9,0,2),Vector3(21,0,-4.4),Vector3(4.8,0,-20),Vector3(-22,0,-3.8)]:
		var pedestrian := _person(p,Color(0.7,0.75,0.65),0.9+p.x*0.003)
		pedestrian.rotation.y = p.x * 0.19
	# Parked bicycle is scenery in this slice; drivable vehicles belong to the next stages.
	var wheelmat := _material("coat")
	for z in [-1.1,0.5]:
		var wheel := _cylinder(Vector3(8,0.39,z),0.36,0.07,wheelmat)
		wheel.rotation.z = PI*0.5
	var frame := _box(Vector3(8,0.7,-0.3),Vector3(0.055,0.055,1.8),_material("metal",Color(0.9,0.6,0.45)))
	frame.rotation.x = -0.23
	_box(Vector3(8,1.0,-0.3),Vector3(0.32,0.06,0.35),_material("coat"))
	_box(Vector3(8,1.1,-1.0),Vector3(0.65,0.05,0.05),_material("metal"))
	for index in range(2):
		var car := _car(Color(0.55,0.63,0.7) if index == 0 else Color(0.7,0.45,0.4))
		car.position = Vector3(1.9 if index == 0 else -1.9,0,index*26-13)
		car.rotation.y = 0 if index == 0 else PI
		_cars.append(car)

func _car(tint: Color) -> Node3D:
	var car := Node3D.new()
	add_child(car)
	_box(Vector3(0,0.62,0),Vector3(1.75,0.65,3.6),_material("metal",tint),false,car)
	_box(Vector3(0,1.12,0.15),Vector3(1.55,0.55,1.9),_material("glass",Color(0.65,0.8,0.85)),false,car)
	_box(Vector3(0,1.42,0.15),Vector3(1.6,0.08,1.95),_material("metal",tint),false,car)
	for x in [-0.9,0.9]:
		for z in [-1.05,1.05]:
			var wheel := _cylinder(Vector3(x,0.38,z),0.34,0.2,_material("coat"),car)
			wheel.rotation.z = PI*0.5
	for x in [-0.6,0.6]:
		_box(Vector3(x,0.65,-1.82),Vector3(0.35,0.13,0.035),_material("marking",Color.WHITE,Color("f9e5b4"),1.5),false,car)
		_box(Vector3(x,0.65,1.82),Vector3(0.28,0.12,0.035),_material("marking",Color.WHITE,Color("ce4844"),1.0),false,car)
	return car

func _build_background() -> void:
	for index in range(11):
		var x := -45.0 + index * 9.0
		var height := 12.0 + fmod(float(index*7),17.0)
		_box(Vector3(x,height*0.5,-43.0),Vector3(8,height,8),_material("blue",Color(0.48,0.55,0.68)))
		_box(Vector3(x,height*0.5,43.0),Vector3(8,height*0.8,8),_material("stucco",Color(0.4,0.45,0.6)))
		for y in range(3,int(height),4):
			_box(Vector3(x, y, -38.95),Vector3(0.8,1.1,0.04),_material("glass",Color.WHITE,Color("967b61"),0.4))
	for index in range(7):
		var z := -30.0 + index*10.0
		_box(Vector3(-43,9+index%3,z),Vector3(9,18+index%3*2,8),_material("pink",Color(0.4,0.45,0.55)))
		_box(Vector3(43,8+index%4,z),Vector3(9,16+index%4*2,8),_material("blue",Color(0.45,0.5,0.6)))

func set_bar_unlocked(value: bool) -> void:
	_unlocked = value
	if is_instance_valid(_door):
		_door.collision_layer = 0 if value else 1
		_door.collision_mask = 0 if value else 1
	if is_instance_valid(_door_mesh):
		_door_mesh.visible = not value

func set_wristband_visible(value: bool) -> void:
	if is_instance_valid(_wristband):
		_wristband.visible = value
	if is_instance_valid(_wristband_light):
		_wristband_light.visible = value

func set_nearby_highlights(viewer: Vector3) -> void:
	if is_instance_valid(_guard_marker):
		_guard_marker.visible = viewer.distance_to(guard_position) < 12.0

func set_audience(amount: float) -> void:
	_crowd_count = clampi(int(ceil(amount / 100.0 * 8.0)),0,8)
	for index in range(_audience.size()):
		_audience[index].visible = index < _crowd_count

func set_pulse(value: float) -> void:
	var level := clampf(value,0.0,1.0)
	for light in _reactive_lights:
		light.light_energy = 1.0 + level*2.2
	for material in _emissive:
		material.emission_energy_multiplier = 1.2 + level*3.0

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_wristband):
		_wristband.rotation.y += delta * 0.7
		_wristband.position.y = wristband_position.y + sin(_time*2.4)*0.07
	for index in range(_audience.size()):
		var person := _audience[index]
		person.rotation.z = sin(_time*2.3+index)*0.025
	for index in range(_cars.size()):
		var car := _cars[index]
		car.position.z += delta * (3.2 if index == 0 else -2.8)
		if car.position.z > 30.0:
			car.position.z = -30.0
		elif car.position.z < -30.0:
			car.position.z = 30.0

func _batch_static_geometry() -> void:
	# One instanced draw per material instead of hundreds of separate window frames.
	# Physics-bearing meshes, the door, characters and traffic remain individual.
	var groups: Dictionary = {}
	for child in get_children():
		if not child is MeshInstance3D or child == _door_mesh:
			continue
		var mesh_node := child as MeshInstance3D
		if not mesh_node.mesh is BoxMesh or mesh_node.get_child_count() > 0:
			continue
		var material := mesh_node.material_override
		var key := material.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material": material, "transforms": []}
		var box := mesh_node.mesh as BoxMesh
		var basis := mesh_node.transform.basis.scaled_local(box.size)
		groups[key]["transforms"].append(Transform3D(basis, mesh_node.position))
		remove_child(mesh_node)
		mesh_node.free()
	for key in groups:
		var data: Dictionary = groups[key]
		var batch := MultiMeshInstance3D.new()
		batch.name = "ArquiteturaInstanciada"
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = BoxMesh.new()
		instances.mesh.size = Vector3.ONE
		instances.instance_count = data["transforms"].size()
		for index in range(instances.instance_count):
			instances.set_instance_transform(index, data["transforms"][index])
		batch.multimesh = instances
		batch.material_override = data["material"]
		add_child(batch)
