class_name AlbumWorld
extends Node3D
## Continuous Lisbon peninsula, keeping the original playable route and saved edits.
## Original Lisbon props/materials plus OSM footprints; Compatibility renderer.

var rooftop_spawn := Transform3D(Basis(), Vector3(-16, 9.7, 15))
var street_safe := Transform3D(Basis(), Vector3(-4, 0.5, 3))
var wristband_position := Vector3(-4, 0.7, 2)
var guard_position := Vector3(-12, 0, -4.2)
var stage_position := Vector3(-16, 0, -17)
var entrance_position := Vector3(-13, 0, -6)
signal npc_message(text: String)

var route_waypoints: Array[PackedVector3Array] = []
var plaza_center := Vector3(24.0, 0.0, 0.0)
var _environment: Environment
var _population: Node3D
var _club: Node3D
var _guard: CharacterBody3D
var _player: Node3D
var _population_budget := 10
var _npcs_enabled := false
var _club_performing := false
var _performance_bpm := 100.0
var _club_spots: Array[SpotLight3D] = []
var _static_people: Array[Node3D] = []
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
var imported_city: Node3D
var city_traffic: Node3D
var _venue_clubs: Dictionary = {}
var _performance_id := "lado_b"
var _club_visibility_timer := 0.0

func _ready() -> void:
	name = "BairroDaMadrugada"
	_build_environment()
	_build_streets()
	_build_architecture()
	_build_rooftop()
	_build_stairway()
	_build_bar()
	_build_square()
	_build_street_life()
	_build_background()
	_build_routes()
	_build_population()
	set_bar_unlocked(false)
	set_audience(75.0)
	_batch_static_geometry()
	imported_city = load("res://scripts/imported_city.gd").new()
	add_child(imported_city)
	for district in imported_city.manifest.districts:
		_population.append_region_routes(district.id,district.routes,Callable(imported_city,"ground_height") if imported_city.has_method("ground_height") else Callable())
	if imported_city.has_method("get_venue_routes"):
		var routes: Array = imported_city.get_venue_routes()
		if not routes.is_empty(): _population.append_region_routes("nightlife",routes,Callable(imported_city,"ground_height"))
	if imported_city.has_method("get_traffic_routes"):
		city_traffic = load("res://scripts/city_traffic.gd").new()
		add_child(city_traffic)
		var traffic_routes: Array = imported_city.get_traffic_routes()
		if FileAccess.file_exists("res://assets/maps/traffic_routes.json"):
			var road_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/traffic_routes.json"))
			traffic_routes = road_data.routes+traffic_routes
		city_traffic.configure(traffic_routes)
	for venue in imported_city.get_performance_venues():
		var crowd: Node3D = load("res://scripts/club_crowd.gd").new()
		crowd.configure_layout(venue)
		add_child(crowd)
		crowd.set_door_open(true)
		crowd.set_audience(75.0)
		_venue_clubs[str(venue.id)] = crowd

func _material(key: String, tint := Color.WHITE, glow := Color.BLACK, emission_power := 0.0) -> StandardMaterial3D:
	var aliases := {"stucco":"city_plaster", "ochre":"city_ochre", "pink":"city_pink", "blue":"city_blue", "calcada":"city_calcada", "asphalt":"city_asphalt", "roof":"city_roof"}
	key = aliases.get(key, key)
	var cache_key := "%s:%s:%s:%s" % [key, tint.to_html(), glow.to_html(), emission_power]
	if _materials.has(cache_key):
		return _materials[cache_key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/%s.png" % key)
	mat.albedo_color = tint
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/%s_normal.png" % key)
	mat.normal_scale = 0.23
	mat.roughness_texture = load("res://assets/textures/%s_rough.png" % key)
	mat.roughness = 0.76 if key == "city_asphalt" else 0.88
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.45
	mat.uv1_triplanar_sharpness = 8.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emission_power > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_texture = mat.albedo_texture
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
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
	node.visibility_range_end = 96.0
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
	node.visibility_range_end = 96.0
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
	label.visibility_range_end = 50.0
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
	light.distance_fade_enabled = true
	light.distance_fade_begin = 28.0
	light.distance_fade_length = 12.0
	add_child(light)
	if reactive:
		_reactive_lights.append(light)
	return light

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("191a20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b1a28c")
	env.ambient_light_energy = 0.29
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("36312e")
	env.fog_light_energy = 0.52
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 150.0
	env.fog_depth_curve = 1.45
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = false
	_environment = env
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Luar"
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color("8f9aab")
	moon.light_energy = 0.26
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 42.0
	add_child(moon)

func _build_streets() -> void:
	_box(Vector3(10, -0.3, 0), Vector3(104, 0.6, 104), _material("asphalt"), true)
	# Main avenue and the west lane retain the tested first playable route.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 5.3, 0.035, 0), Vector3(2.8, 0.07, 90), _material("calcada"), true)
		_box(Vector3(0, 0.036, side * 5.0), Vector3(60, 0.072, 2), _material("calcada"), true)
		for z in range(-45, 46, 7):
			if abs(z) < 7: continue
			_box(Vector3(side * 2.8, 0.012, z), Vector3(0.09, 0.02, 2.6), _material("marking", Color(0.8, 0.78, 0.65)))
	for z in [-8.0, 8.0, -24.0, 24.0]:
		for x in range(-3, 4):
			_box(Vector3(float(x), 0.015, z), Vector3(0.55, 0.025, 1.8), _material("marking", Color(0.84,0.82,0.74)))
	# East side of the square: two traffic directions separated by a worn line.
	for z in [-25.0, 25.0]:
		_box(Vector3(25,0.035,z + signf(z)*4),Vector3(43,0.07,3.0),_material("calcada"),true)
		for x in range(9,44,6):
			_box(Vector3(x,0.014,z),Vector3(2.9,0.018,0.10),_material("marking",Color(0.8,0.78,0.65)))
	_box(Vector3(48,0.035,0),Vector3(3,0.07,56),_material("calcada"),true)
	for z in range(-20,24,7):
		_box(Vector3(44,0.014,z),Vector3(0.1,0.018,3.0),_material("marking",Color(0.8,0.78,0.65)))
	for x in range(8,42):
		if x % 2 == 0:
			for z in [-21.8,21.8]: _box(Vector3(x,0.014,z),Vector3(0.65,0.018,2.0),_material("marking",Color(0.83,0.82,0.76)))
	# Architectural edges rather than invisible blockers define the study's boundary.
	_box(Vector3(-36,1.15,0),Vector3(0.6,2.3,98),_material("city_stone"),true)
	for z in [-28.0,28.0]: _box(Vector3(60,1.15,z),Vector3(0.6,2.3,42),_material("city_stone"),true)
	_label("SALDANHA →",Vector3(58,2.8,-5),34,Color("dfc797"),-PI*0.5)
	for z in [-49.0,49.0]: _box(Vector3(12,1.15,z),Vector3(96,2.3,0.6),_material("city_stone"),true)
	for pos in [Vector3(5.8,0,-14),Vector3(5.8,0,16),Vector3(-5.9,0,-22),Vector3(-5.9,0,29),Vector3(8,0,-20),Vector3(39,0,-20),Vector3(8,0,20),Vector3(39,0,20),Vector3(47,0,4)]:
		_streetlamp(pos)
	for pos in [Vector3(4.5,0,-8.5),Vector3(-4.5,0,8.5),Vector3(42,0,-21),Vector3(42,0,21)]: _traffic_signal(pos)
	_label("AVENIDA DA REPÚBLICA",Vector3(8,2.3,-21.1),24,Color("d5cfb9"))

func _streetlamp(pos: Vector3) -> void:
	_cylinder(pos+Vector3(0,3.2,0),0.065,6.4,_material("metal",Color(0.65,0.65,0.57)))
	_box(pos+Vector3(0,6.25,0),Vector3(1.6,0.09,0.09),_material("metal"))
	for side in [-1.0,1.0]:
		var light_at := pos+Vector3(side*0.65,6.2,0)
		_box(light_at,Vector3(0.53,0.11,0.35),_material("metal"))
		_box(light_at-Vector3(0,0.07,0),Vector3(0.44,0.04,0.28),_material("marking",Color.WHITE,Color("ffd18b"),3.0))
		_flare(light_at-Vector3(0,0.1,0),0.72)
	_light(pos+Vector3(0,5.9,0),Color("ffd095"),2.4,12.0)

func _flare(at: Vector3, diameter: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/city_flare.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * diameter
	var flare := MeshInstance3D.new()
	flare.mesh = mesh
	flare.material_override = mat
	flare.position = at
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.visibility_range_end = 82.0
	add_child(flare)

func _traffic_signal(pos: Vector3) -> void:
	_cylinder(pos+Vector3(0,1.6,0),0.055,3.2,_material("metal"))
	_box(pos+Vector3(0,2.75,0),Vector3(0.30,0.85,0.26),_material("metal",Color(0.5,0.5,0.5)))
	for i in 3:
		var color: Color = [Color("ed503d"),Color("c78930"),Color("364939")][i]
		var lamp := _cylinder(pos+Vector3(0,3.01-i*0.25,0.15),0.084,0.035,_material("glass",Color.WHITE,color,2.3 if i == 0 else 0.12))
		lamp.rotation.x = PI*0.5

func _build_architecture() -> void:
	# Starting building. Other blocks have modest variations in height and colour.
	_building(Vector3(-16, 0, 15.5), Vector3(18, 9.3, 19), "ochre", false)
	_box(Vector3(-16, 9.4, 15.5), Vector3(18.1, 0.2, 19.1), _material("calcada"), true)
	# The bar building has a fully walkable ground-floor interior.
	_building(Vector3(-16, 0, -15.5), Vector3(18, 11.8, 19), "stucco", true)
	_box(Vector3(-16, 0.08, -15.5), Vector3(17.8, 0.12, 18.8), _material("wood"), true)
	# Low decorative azulejo bands on the street-facing walls.
	_box(Vector3(-16, 0.68, 5.94), Vector3(18, 1.25, 0.06), _material("tiles"))
	_label("RUA DA MADRUGADA", Vector3(7.0, 2.6, 6.0), 20, Color("d5d7cc"), -PI * 0.5)
	_box(Vector3(6.9, 2.6, 6.0), Vector3(0.12, 0.44, 2.9), _material("tiles"))


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
	# A worn dance floor and indirect bands give the Lisbon bar a club identity.
	_box(Vector3(-16,0.145,-14.5),Vector3(9.8,0.025,8.2),_material("wood",Color(0.34,0.33,0.39)))
	for side in [-1.0,1.0]:
		_box(Vector3(-16+side*5.0,0.18,-14.5),Vector3(0.035,0.035,8.4),_material("marking",Color.WHITE,Color("bb547d"),1.8))
		_box(Vector3(-16+side*4.0,3.4,-20.3),Vector3(0.7,0.05,2.6),_material("marking",Color.WHITE,Color("5481ae"),1.1))
	_box(Vector3(-16,1.02,-20.0),Vector3(3.0,0.6,0.08),_material("metal",Color(0.25,0.29,0.33),Color("596da8"),0.8))
	_label("L A D O  B",Vector3(-16,1.05,-19.93),26,Color("9a96c4"))
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
	# A warm low bar and two slow, bounded stage spots evoke a small Lisbon club.
	_box(Vector3(-16,0.145,-14.5),Vector3(6.8,0.008,6.2),_material("wood",Color(0.58,0.47,0.42)))
	for x in [-19.35,-12.65]:
		_box(Vector3(x,0.16,-14.5),Vector3(0.025,0.02,6.2),_material("marking",Color.WHITE,Color("b26477"),0.8))
	for i in 2:
		var spot := SpotLight3D.new()
		spot.position = Vector3(-20.6 if i == 0 else -11.4,3.65,-20.1)
		spot.rotation_degrees = Vector3(-56.0, -35.0 if i == 0 else 35.0, 0.0)
		spot.light_color = Color("7bb5c2") if i == 0 else Color("b76989")
		spot.light_energy = 1.8
		spot.spot_range = 13.0
		spot.spot_angle = 30.0
		spot.spot_attenuation = 1.5
		spot.shadow_enabled = false
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 24.0
		spot.distance_fade_length = 10.0
		add_child(spot)
		_club_spots.append(spot)
	# Patrons move through the door when attendance changes, rather than disappearing.
	if FileAccess.file_exists("res://scripts/club_crowd.gd"):
		_club = load("res://scripts/club_crowd.gd").new()
		add_child(_club)
		_club.set_audience(75.0)
		_club.set_door_open(false)
	# The actual interaction marker is at stage_position, ahead of the crowd.
	var marker_material := _material("metal",Color.WHITE,Color("88c8bf"),1.4)
	_cylinder(stage_position+Vector3(0,0.16,0),0.42,0.035,marker_material)

func _person(pos: Vector3, _tint: Color, scale_factor: float, appearance_id: int = 0) -> Node3D:
	var person := Node3D.new()
	person.position = pos
	person.scale = Vector3.ONE * scale_factor
	add_child(person)
	if FileAccess.file_exists("res://scripts/character_visual.gd"):
		var visual: Node3D = load("res://scripts/character_visual.gd").new()
		visual.appearance_id = appearance_id
		person.add_child(visual)
		person.set_meta("character_visual",visual)
		_static_people.append(person)
	return person

func _build_street_life() -> void:
	if FileAccess.file_exists("res://scripts/npc.gd"):
		_guard = load("res://scripts/npc.gd").new()
		_guard.configure(8,"security",PackedVector3Array([guard_position]))
		add_child(_guard)
		_guard.name = "Seguranca"
		_guard.rotation.y = PI
		_guard.message.connect(func(text: String): npc_message.emit(text))
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
	# Parked bicycle is scenery in this slice; drivable vehicles belong to the next stages.
	var wheelmat := _material("coat")
	for z in [-1.1,0.5]:
		var wheel := _cylinder(Vector3(8,0.39,z),0.36,0.07,wheelmat)
		wheel.rotation.z = PI*0.5
	var frame := _box(Vector3(8,0.7,-0.3),Vector3(0.055,0.055,1.8),_material("metal",Color(0.9,0.6,0.45)))
	frame.rotation.x = -0.23
	_box(Vector3(8,1.0,-0.3),Vector3(0.32,0.06,0.35),_material("coat"))
	_box(Vector3(8,1.1,-1.0),Vector3(0.65,0.05,0.05),_material("metal"))
	for index in range(5):
		var car := _car(Color(0.55,0.63,0.7) if index == 0 else Color(0.7,0.45,0.4))
		car.position = Vector3(1.9 if index % 2 == 0 else -1.9,0,index*18-40)
		car.rotation.y = 0 if index % 2 == 0 else PI
		car.set_meta("traffic_speed",3.2 if index % 2 == 0 else -2.8)
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
	# Taller background has simpler silhouettes and actual drawing limits.
	for index in range(9):
		var x := -31.0+index*11.0
		var h := 16.0+float(index*7%13)
		for z in [-56.0,56.0]:
			var block := _box(Vector3(x,h*0.5,z),Vector3(10.0,h,10.0),_material("city_stone",Color(0.58,0.61,0.59)))
			block.visibility_range_end = 112.0
	for z in [-38.0,-18.0,2.0,23.0,43.0]:
		_box(Vector3(-44,12,z),Vector3(12,24,17),_material("city_plaster",Color(0.56,0.59,0.61)))
		if z != 2: _box(Vector3(68,13,z),Vector3(13,26,17),_material("city_stone",Color(0.57,0.59,0.59)))

func set_bar_unlocked(value: bool) -> void:
	_unlocked = value
	if is_instance_valid(_club):
		_club.set_door_open(value)
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
	var crowd := _get_performance_crowd()
	if is_instance_valid(crowd): crowd.set_audience(amount)

func set_pulse(value: float) -> void:
	if is_instance_valid(imported_city): imported_city.set_pulse(value)
	var level := clampf(value,0.0,1.0)
	for light in _reactive_lights:
		light.light_energy = 1.0 + level*2.2
	for material in _emissive:
		material.emission_energy_multiplier = 1.2 + level*3.0

func _process(delta: float) -> void:
	_time += delta
	_club_visibility_timer -= delta
	if _club_visibility_timer <= 0.0 and is_instance_valid(_player):
		_club_visibility_timer = 0.5
		for venue in imported_city.get_performance_venues():
			var crowd: Node3D = _venue_clubs.get(str(venue.id))
			if not is_instance_valid(crowd): continue
			var nearby: bool = _player.global_position.distance_to(venue.stage_position) < 150.0
			crowd.visible = nearby
			crowd.process_mode = Node.PROCESS_MODE_INHERIT if nearby else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_wristband):
		_wristband.rotation.y += delta * 0.7
		_wristband.position.y = wristband_position.y + sin(_time*2.4)*0.07
	for person in _static_people:
		if person.has_meta("character_visual"):
			person.get_meta("character_visual").animate(delta,0.0)
	for index in range(_cars.size()):
		var car := _cars[index]
		car.position.z += delta * float(car.get_meta("traffic_speed",3.0))
		if car.position.z > 46.0: car.position.z = -46.0
		elif car.position.z < -46.0: car.position.z = 46.0
	for i in _club_spots.size():
		_club_spots[i].rotation_degrees.y = sin(_time*0.21+float(i)*PI)*18.0

func _batch_static_geometry() -> void:
	# Bound batches by 16m city sectors: a whole district no longer shares one AABB.
	var groups: Dictionary = {}
	for child in get_children():
		if not child is MeshInstance3D or child == _door_mesh: continue
		var mesh_node := child as MeshInstance3D
		if not mesh_node.mesh is BoxMesh or mesh_node.get_child_count() > 0: continue
		var material := mesh_node.material_override
		var sector := Vector2i(floori(mesh_node.position.x/16.0),floori(mesh_node.position.z/16.0))
		var key := "%s:%d:%d" % [material.get_instance_id(),sector.x,sector.y]
		var center := Vector3(float(sector.x)*16.0+8.0,0,float(sector.y)*16.0+8.0)
		if not groups.has(key): groups[key] = {"material":material,"transforms":[],"center":center}
		var box := mesh_node.mesh as BoxMesh
		var basis := mesh_node.transform.basis.scaled_local(box.size)
		groups[key]["transforms"].append(Transform3D(basis,mesh_node.position-center))
		remove_child(mesh_node)
		mesh_node.free()
	for key in groups:
		var data: Dictionary = groups[key]
		var batch := MultiMeshInstance3D.new()
		batch.name = "SetorUrbano"
		batch.position = data["center"]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = BoxMesh.new()
		instances.mesh.size = Vector3.ONE
		instances.instance_count = data["transforms"].size()
		for index in range(instances.instance_count): instances.set_instance_transform(index,data["transforms"][index])
		batch.multimesh = instances
		batch.material_override = data["material"]
		batch.visibility_range_end = 96.0
		add_child(batch)

func _build_square() -> void:
	# Broad calçada and a central stone monument establish the Saldanha silhouette.
	_box(Vector3(24,0.045,0),Vector3(33,0.09,41),_material("calcada",Color(0.88,0.85,0.76)),true)
	var base := _cylinder(Vector3(24,0.13,0),6.4,0.10,_material("city_granite"))
	base.name = "PracaSaldanha"
	_box(Vector3(24,0.26,0),Vector3(6.0,0.42,6.0),_material("city_stone"),true)
	_box(Vector3(24,0.56,0),Vector3(4.9,0.20,4.9),_material("city_stone"),true)
	_box(Vector3(24,1.02,0),Vector3(4.05,0.75,4.05),_material("city_stone"),true)
	_box(Vector3(24,4.3,0),Vector3(2.55,5.9,2.55),_material("city_stone"),true)
	for y in [1.5,6.9,7.3]:
		_box(Vector3(24,y,0),Vector3(3.0,0.25,3.0),_material("city_stone"))
	for x in [22.55,25.45]:
		for z in [-1.45,1.45]:
			_cylinder(Vector3(x,4.15,z),0.12,4.9,_material("city_stone"))
	_label("SALDANHA",Vector3(24,3.15,1.32),37,Color("b5a88c"))
	_label("MADRUGADA",Vector3(22.68,3.15,0),37,Color("b5a88c"),-PI*0.5)
	_monument_figure(Vector3(24,7.48,0))
	_light(Vector3(20.5,0.6,2.5),Color("e7c18a"),1.2,10.5)
	_light(Vector3(27.5,0.6,-2.5),Color("dfc695"),1.0,10.5)
	for pos in [Vector3(12,0,-16),Vector3(35,0,-16),Vector3(12,0,16),Vector3(35,0,16)]:
		_tree(pos)
	for pos in [Vector3(13,0,-11),Vector3(35,0,-11),Vector3(13,0,11),Vector3(35,0,11)]:
		_bench(pos)
	for z in [-18.7,18.7]:
		for x in range(10,40,4):
			_cylinder(Vector3(x,0.34,z),0.085,0.68,_material("metal",Color(0.65,0.62,0.52)))
	# A restrained family of long façades replaces the former solid east blocks.
	_facade(Vector3(21,0,-36),29,23.5,10.0,0.0,"city_stone","SALDANHA\nRESIDENCE")
	_facade(Vector3(21,0,36),29,19.0,10.0,PI,"city_plaster","AVENIDA")
	_facade(Vector3(54,0,-12),25,21.0,10.0,-PI*0.5,"city_stone","ÁTRIUM SALDANHA")
	_facade(Vector3(54,0,19),26,17.8,10.0,-PI*0.5,"city_ochre","GALERIAS")
	# A dark set-back building makes the avenue continue through the fog.
	_facade(Vector3(-17,0,-38),23,15.5,10.0,0.0,"city_pink","LISBOA")
	_parking_sign(Vector3(40,0,13))
	_box(Vector3(10.1,1.8,-20.1),Vector3(0.16,0.75,1.2),_material("city_stone"))
	_label("M",Vector3(10,2.0,-19.45),75,Color("d1463c"))
	# Three low flower beds provide the small interruptions of a real city square.
	for x in [12.0,24.0,36.0]:
		_box(Vector3(x,0.14,-19),Vector3(5.0,0.22,1.0),_material("city_granite"),true)
		_box(Vector3(x,0.29,-19),Vector3(4.8,0.18,0.82),_material("city_leaf"))

func _local_box(origin: Vector3, yaw: float, local: Vector3, dimensions: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var node := _box(origin+local.rotated(Vector3.UP,yaw),dimensions,mat,solid)
	node.rotation.y = yaw
	return node

func _facade(origin: Vector3, width: float, height: float, depth: float, yaw: float, key: String, sign_text: String) -> void:
	_local_box(origin,yaw,Vector3(0,height*0.5,0),Vector3(width,height,depth),_material(key),true)
	_local_box(origin,yaw,Vector3(0,0.55,depth*0.5+0.08),Vector3(width,1.1,0.15),_material("city_granite"))
	var columns := int(width/3.4)
	var floors := int((height-4.0)/3.2)
	for floor_index in floors:
		var y := 5.1+float(floor_index)*3.2
		_local_box(origin,yaw,Vector3(0,y-1.22,depth*0.5+0.07),Vector3(width,0.15,0.18),_material("city_stone",Color(0.83,0.81,0.73)))
		for column in columns:
			var x := -width*0.5+1.8+float(column)*3.4
			_local_box(origin,yaw,Vector3(x,y,depth*0.5+0.06),Vector3(2.05,2.05,0.18),_material("city_stone",Color(0.79,0.78,0.72)))
			_local_box(origin,yaw,Vector3(x,y,depth*0.5+0.17),Vector3(1.70,1.78,0.05),_material("metal",Color(0.59,0.57,0.50)))
			var lit := (column*3+floor_index*7)%7 < 2
			var glow := Color("d5bd78") if lit else Color("4c5b5d")
			_local_box(origin,yaw,Vector3(x,y,depth*0.5+0.205),Vector3(1.54,1.62,0.035),_material("glass",Color(0.74,0.76,0.69),glow,0.75 if lit else 0.08))
			_local_box(origin,yaw,Vector3(x,y,depth*0.5+0.24),Vector3(0.06,1.65,0.025),_material("metal"))
			if floor_index == 0 and column%3 == 0:
				_local_box(origin,yaw,Vector3(x,y-1.10,depth*0.5+0.50),Vector3(2.1,0.10,0.8),_material("city_stone"))
	# Ground-floor shop windows and actual readable Portuguese place cues.
	var shop_names := ["PASTELARIA", "CAFÉ REPÚBLICA", "TABACARIA", "LIVRARIA"]
	for column in int(width/5.4):
		var x := -width*0.5+2.8+float(column)*5.4
		_local_box(origin,yaw,Vector3(x,1.68,depth*0.5+0.10),Vector3(4.5,2.7,0.18),_material("metal",Color(0.55,0.54,0.48)))
		_local_box(origin,yaw,Vector3(x,1.68,depth*0.5+0.21),Vector3(4.12,2.35,0.035),_material("glass",Color(0.55,0.62,0.57),Color("ae9160"),0.18))
		_local_box(origin,yaw,Vector3(x,3.26,depth*0.5+0.38),Vector3(4.7,0.63,0.5),_material("metal",Color(0.53,0.51,0.42)))
		var label := _label(shop_names[column%shop_names.size()],origin+Vector3(x,3.28,depth*0.5+0.66).rotated(Vector3.UP,yaw),28,Color("d6c9a4"),yaw)
		label.visibility_range_end = 38.0
		_local_box(origin,yaw,Vector3(x,1.67,depth*0.5+0.26),Vector3(0.07,2.35,0.04),_material("metal"))
		_local_box(origin,yaw,Vector3(x-2.55,1.8,depth*0.5+0.24),Vector3(0.31,3.6,0.35),_material("city_stone"))
	_local_box(origin,yaw,Vector3(0,height+0.10,0),Vector3(width+0.55,0.22,depth+0.4),_material("city_stone"))
	var roof_sign := _label(sign_text,origin+Vector3(0,height+1.35,depth*0.5+0.2).rotated(Vector3.UP,yaw),102,Color("b8b7aa"),yaw)
	roof_sign.visibility_range_end = 78.0

func _bench(pos: Vector3) -> void:
	for offset in [-0.7,0.7]:
		_box(pos+Vector3(offset,0.25,0),Vector3(0.09,0.5,0.45),_material("metal"),true)
	for offset in [-0.18,0.0,0.18]:
		_box(pos+Vector3(0,0.51,offset),Vector3(1.9,0.065,0.15),_material("wood"))
	for y in [0.72,0.93]:
		_box(pos+Vector3(0,y,0.27),Vector3(1.9,0.13,0.07),_material("wood"))

func _tree(pos: Vector3) -> void:
	var trunk := _cylinder(pos+Vector3(0,2.0,0),0.14,4.0,_material("wood"),null,0.08)
	trunk.name = "JacarandaEstudo"
	for side in [-1.0,1.0]:
		var branch := _cylinder(pos+Vector3(side*0.5,3.3,0),0.07,1.7,_material("wood"))
		branch.rotation.z = -side*0.65
	for offset in [Vector3(-1.1,4.15,0.0),Vector3(1.1,4.4,-0.1),Vector3(0.0,4.9,0.6)]:
		var canopy := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 10
		mesh.rings = 5
		mesh.radius = 1.5
		mesh.height = 2.1
		canopy.mesh = mesh
		canopy.material_override = _material("city_leaf",Color(0.78,0.85,0.71))
		canopy.position = pos+offset
		canopy.visibility_range_end = 78.0
		add_child(canopy)

func _parking_sign(pos: Vector3) -> void:
	_cylinder(pos+Vector3(0,1.5,0),0.045,3.0,_material("metal"))
	_box(pos+Vector3(0,2.2,0),Vector3(1.0,1.1,0.13),_material("metal",Color(0.48,0.55,0.7)))
	_label("P",pos+Vector3(0,2.3,0.08),92,Color("d8d7bf"))
	_label("Saldanha",pos+Vector3(0,1.85,0.08),27,Color("d8d7bf"))

func _monument_figure(at: Vector3) -> void:
	var stone := _material("city_granite",Color(0.55,0.58,0.54))
	# Contoured stone anatomy is an original prop, with a cape and bent arms.
	var torso := _contour_mesh([Vector3(0,0.78,0),Vector3(0,1.08,0),Vector3(0,1.45,0),Vector3(0,1.78,0),Vector3(0,1.92,0)], [Vector2(0.25,0.17),Vector2(0.24,0.17),Vector2(0.35,0.20),Vector2(0.40,0.21),Vector2(0.21,0.16)],stone)
	torso.position = at
	for side in [-1.0,1.0]:
		var leg := _contour_mesh([Vector3(side*0.16,0.04,-0.01),Vector3(side*0.16,0.38,0),Vector3(side*0.15,0.77,0),Vector3(side*0.13,1.0,0)], [Vector2(0.13,0.2),Vector2(0.10,0.12),Vector2(0.14,0.15),Vector2(0.16,0.15)],stone)
		leg.position = at
		var arm := _contour_mesh([Vector3(side*0.31,1.77,0),Vector3(side*0.44,1.40,-0.02),Vector3(side*0.29,1.20,-0.19)], [Vector2(0.13,0.13),Vector2(0.11,0.12),Vector2(0.08,0.10)],stone)
		arm.position = at
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.45
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = stone
	head.position = at+Vector3(0,2.09,-0.025)
	add_child(head)
	var cape := _contour_mesh([Vector3(0,0.55,0.15),Vector3(0,1.15,0.12),Vector3(0,1.80,0.08)], [Vector2(0.36,0.11),Vector2(0.36,0.14),Vector2(0.36,0.14)],stone)
	cape.position = at

func _contour_mesh(centers: Array[Vector3], radii: Array[Vector2], mat: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 10
	for row in centers.size()-1:
		for segment in segments:
			var vertices: Array[Vector3] = []
			for pair in [Vector2i(row,segment),Vector2i(row+1,segment),Vector2i(row+1,(segment+1)%segments),Vector2i(row,(segment+1)%segments)]:
				var a := float(pair.y)*TAU/float(segments)
				vertices.append(centers[pair.x]+Vector3(cos(a)*radii[pair.x].x,0,sin(a)*radii[pair.x].y))
			for index in [0,1,2,0,2,3]:
				surface.set_uv(Vector2(vertices[index].x,vertices[index].y)*0.5)
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	add_child(node)
	return node

func _build_routes() -> void:
	route_waypoints = [
		PackedVector3Array([Vector3(8.2,0.13,-16),Vector3(18,0.13,-16),Vector3(37,0.13,-16),Vector3(37,0.13,16),Vector3(8.2,0.13,16)]),
		PackedVector3Array([Vector3(-5.2,0.13,-28),Vector3(-5.2,0.13,-8),Vector3(-14,0.13,-3.8),Vector3(-24,0.13,-3.8),Vector3(-5.2,0.13,-3.8)]),
		PackedVector3Array([Vector3(5.4,0.13,-34),Vector3(5.4,0.13,-10),Vector3(5.4,0.13,10),Vector3(5.4,0.13,34)]),
		PackedVector3Array([Vector3(47.3,0.13,-26),Vector3(47.3,0.13,0),Vector3(47.3,0.13,26),Vector3(38,0.13,29),Vector3(47.3,0.13,29)]),
		PackedVector3Array([Vector3(8,0.13,-29),Vector3(38,0.13,-29),Vector3(47.3,0.13,-26),Vector3(47.3,0.13,-18)]),
		PackedVector3Array([Vector3(17,0.13,-9),Vector3(31,0.13,-9),Vector3(31,0.13,9),Vector3(17,0.13,9)])
	]

func _build_population() -> void:
	if not FileAccess.file_exists("res://scripts/npc_population.gd"): return
	_population = load("res://scripts/npc_population.gd").new()
	add_child(_population)
	_population.configure(route_waypoints)
	_population.set_budget(_population_budget)
	_population.set_enabled(_npcs_enabled)
	if _population.has_signal("message"):
		_population.message.connect(func(text: String): npc_message.emit(text))

func set_player(player: Node3D) -> void:
	_player = player
	if is_instance_valid(city_traffic): city_traffic.set_viewer(player)
	if is_instance_valid(imported_city): imported_city.viewer = player
	if is_instance_valid(_population): _population.set_player(player)
	if is_instance_valid(_guard): _guard.set_player(player)
	if is_instance_valid(_club): _club.set_player(player)
	for crowd in _venue_clubs.values(): crowd.set_player(player)

func set_population_budget(count: int) -> void:
	_population_budget = clampi(count,0,20)
	if is_instance_valid(_population): _population.set_budget(_population_budget)

func set_npcs_enabled(value: bool) -> void:
	_npcs_enabled = value
	if is_instance_valid(_population): _population.set_enabled(value)

func set_performance(active: bool, bpm: float = 100.0) -> void:
	_club_performing = active
	_performance_bpm = bpm
	var crowd := _get_performance_crowd()
	if is_instance_valid(crowd): crowd.set_performance(active,bpm)

func set_performance_venue(id: String) -> void:
	if id == _performance_id: return
	set_performance(false)
	_performance_id = id if _venue_clubs.has(id) else "lado_b"

func _get_performance_crowd() -> Node3D:
	return _venue_clubs.get(_performance_id,_club)

func get_nearby_performance(at: Vector3, include_lado_b: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var distance := 2.8
	if include_lado_b and at.distance_to(stage_position) < distance:
		best = {"id":"lado_b","stage_position":stage_position,"facing":Vector3(0,0,1),"camera_position":stage_position+Vector3(7.5,3.2,-4.8),"camera_target":stage_position+Vector3(0,1.1,2.7)}
		distance = at.distance_to(stage_position)
	for venue in imported_city.get_performance_venues():
		var other: float = at.distance_to(venue.stage_position)
		if other < distance:
			best = venue
			distance = other
	return best

func get_population_count() -> int:
	return _population.get_active_count() if is_instance_valid(_population) else 0

func is_inside_bar(at: Vector3) -> bool:
	return at.x < -7.0 and at.x > -25.0 and at.z < -6.0 and at.z > -25.0 and at.y < 3.8

func get_environment() -> Environment:
	return _environment

func get_editor_bookmarks() -> Array:
	var views: Array = [
		{"label":"Praça inicial","position":Vector3(10,7,19),"target":Vector3(24,4,0)},
		{"label":"Telhado","position":rooftop_spawn.origin+Vector3(4,3,5),"target":rooftop_spawn.origin},
		{"label":"Lado B","position":stage_position+Vector3(6,3,-4),"target":stage_position+Vector3(0,1,3)}
	]

	if is_instance_valid(imported_city): views.append_array(imported_city.get_bookmarks())
	return views

func get_city_metrics() -> Dictionary:
	var batches := 0
	var static_instances := 0
	for child in get_children():
		if child is MultiMeshInstance3D:
			batches += 1
			static_instances += child.multimesh.instance_count
	return {"static_batches":batches,"static_instances":static_instances,"population":get_population_count(),"fog_enabled":_environment.fog_enabled,"sector_size":16}

func set_quality(low: bool) -> void:
	for child in get_children():
		if child is DirectionalLight3D: child.shadow_enabled = not low
		if child is MultiMeshInstance3D: child.visibility_range_end = 82.0 if low else 108.0
		if child is MeshInstance3D and child.visibility_range_end > 70.0:
			child.visibility_range_end = 82.0 if low else 108.0
	_environment.fog_depth_end = 150.0 if low else 200.0


func set_quality_level(level: int) -> void:
	var index := clampi(level, 0, 2)
	for child in get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = index > 0
		if child is MultiMeshInstance3D:
			child.visibility_range_end = [82.0, 106.0, 130.0][index]
	for spot in _club_spots:
		spot.shadow_enabled = index == 2
	_environment.fog_depth_begin = [45.0,65.0,85.0][index]
	_environment.fog_depth_end = [150.0,200.0,250.0][index]
	if is_instance_valid(imported_city) and imported_city.has_method("set_quality_level"): imported_city.set_quality_level(index)
	if is_instance_valid(city_traffic): city_traffic.set_quality_level(index)

func ensure_position(at: Vector3) -> void:
	if is_instance_valid(imported_city): imported_city.ensure_position(at)

func is_valid_save_position(at: Vector3) -> bool:
	if not at.is_finite() or at.y < -0.2 or at.y > 70: return false
	if at.x > -36 and at.x < 60 and absf(at.z) < 49: return true
	return is_instance_valid(imported_city) and imported_city.is_valid_position(at)

func get_map_overlay() -> Dictionary:
	return imported_city.manifest if is_instance_valid(imported_city) else {}

func get_music_zone(at: Vector3) -> Dictionary:
	var result := {"position":stage_position+Vector3.UP,"song":-1,"indoors":is_inside_bar(at),"radius":32.0,"id":"lado_b"}
	var distance := at.distance_to(result.position)
	if is_instance_valid(imported_city):
		for venue in imported_city.get_performance_venues():
			var source: Vector3 = venue.stage_position+Vector3.UP
			var other := at.distance_to(source)
			if other < distance:
				distance = other
				result = {"position":source,"song":2,"indoors":other<19.0,"radius":32.0,"id":venue.id}
		for district in imported_city.manifest.districts:
			var source := Vector3(district.music.position[0],ground_height(district.music.position[0],district.music.position[1])+1,district.music.position[1])
			var other := at.distance_to(source)
			if other < distance:
				distance = other
				result = {"position":source,"song":int(district.music.song),"indoors":true,"radius":35.0,"id":district.music.id}
	return result

func get_test_spawn(at: Vector3) -> Vector3:
	var best := street_safe.origin
	var distance := at.distance_to(best)
	for district in imported_city.manifest.districts:
		var point := Vector3(district.spawn[0],ground_height(district.spawn[0],district.spawn[1])+0.15,district.spawn[1])
		if at.distance_to(point) < distance:
			best = point
			distance = at.distance_to(point)
	var quay := Vector3(240,0.15,990)
	return quay if at.distance_to(quay) < distance else best

func ground_height(x: float, z: float) -> float:
	return imported_city.ground_height(x,z) if is_instance_valid(imported_city) and imported_city.has_method("ground_height") else 0.0

func get_initial_spawn() -> Transform3D:
	return imported_city.get_start_transform() if is_instance_valid(imported_city) and imported_city.has_method("get_start_transform") else rooftop_spawn

func get_initial_safe() -> Transform3D:
	return imported_city.get_start_street() if is_instance_valid(imported_city) and imported_city.has_method("get_start_street") else street_safe
