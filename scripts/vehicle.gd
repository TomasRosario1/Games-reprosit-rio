class_name AlbumVehicle
extends CharacterBody3D
## Small original arcade vehicles. Rigidbody simulation is intentionally avoided.
signal frontal_crash(force: float)
signal hit_person(person: Node, strength: float)

@export var type: String = "car"
var vehicle_type: String:
	get: return type
	set(value): configure(value)
var display_name := "Carro"
var controlled := false
var controls_enabled := true
var forward_speed := 0.0
var steering := 0.0
var maximum_speed := 14.0
var acceleration := 5.0
var seat_offset := Vector3(-0.35, -0.37, -0.05)
var entry_offset := Vector3(-1.65, 0.0, -0.2)
var exit_offsets: Array[Vector3] = [Vector3(-1.85,0.1,-0.2), Vector3(1.85,0.1,-0.2)]
var visual: Node3D
var door_pivot: Node3D
var _wheels: Array[Node3D] = []
var _front_steering: Array[Node3D] = []
var _headlights: Array[SpotLight3D] = []
var _brakes: Array[StandardMaterial3D] = []
var _crash_cooldown := 0.0
var _door_open := false
var _wheel_radius := 0.34
var _wheel_angle := 0.0
var _frame_lean := 0.0
var _materials: Dictionary = {}
var _pedals: Node3D

func configure(kind: String) -> void:
	type = "motorbike" if kind == "motorcycle" else kind
	if type not in ["car","motorbike","bicycle","scooter"]: type = "car"

func _ready() -> void:
	type = type if type in ["car", "motorbike", "bicycle", "scooter"] else "car"
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(46)
	visual = Node3D.new()
	visual.name = "VeiculoVisual"
	add_child(visual)
	match type:
		"car": _build_car()
		"motorbike": _build_motorbike()
		"bicycle": _build_bicycle()
		"scooter": _build_scooter()
	_build_collision()
	name = "Veiculo_" + type
	add_to_group("album_vehicles")
	set_meta("editable", true)
	set_meta("editor_kind", "vehicle")

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.78,1.35,3.75) if type == "car" else Vector3(0.58,1.12,2.1 if type != "scooter" else 1.55)
	collider.shape = shape
	collider.position.y = shape.size.y * 0.5
	add_child(collider)

func _physics_process(delta: float) -> void:
	_crash_cooldown = maxf(0.0, _crash_cooldown - delta)
	var throttle := 0.0
	var turning := 0.0
	var braking := false
	if controlled and controls_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		turning = Input.get_axis("move_left", "move_right")
		braking = Input.is_action_pressed("vehicle_brake")
	if controlled and not controls_enabled:
		forward_speed = 0.0
	steering = lerpf(steering, turning, minf(6.0 * delta, 1.0))
	if braking:
		forward_speed = move_toward(forward_speed, 0.0, 13.0 * delta)
	elif absf(throttle) > 0.05:
		var speed_limit := maximum_speed if throttle > 0.0 else 3.5
		forward_speed = move_toward(forward_speed, throttle * speed_limit, acceleration * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, (1.7 if type == "bicycle" else 1.1) * delta)
	if absf(forward_speed) > 0.08:
		var turn_ratio := clampf(absf(forward_speed) / 3.0, 0.0, 1.0)
		rotation.y -= steering * (0.9 if type == "car" else 1.1) * turn_ratio * signf(forward_speed) * delta
	var direction := -global_basis.z
	velocity.x = direction.x * forward_speed
	velocity.z = direction.z * forward_speed
	velocity.y = -0.7 if is_on_floor() else velocity.y - 20.0 * delta
	var before_speed := absf(forward_speed)
	var travel_direction := direction * signf(forward_speed)
	move_and_slide()
	var blocked := false
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if absf(normal.y) > 0.70:
			continue
		var collider: Object = collision.get_collider()
		if controlled and before_speed > 1.7 and collider is Node and collider.has_method("receive_bump"):
			collider.receive_bump(global_position, before_speed)
			hit_person.emit(collider, before_speed)
		if normal.dot(travel_direction) < -0.35:
			blocked = true
			if type in ["bicycle", "motorbike"] and forward_speed > 9.0 and _crash_cooldown <= 0.0:
				_crash_cooldown = 1.8
				frontal_crash.emit(before_speed)
	if blocked:
		forward_speed = 0.0
	_animate_vehicle(delta, braking)

func _animate_vehicle(delta: float, braking: bool) -> void:
	_wheel_angle += forward_speed / maxf(_wheel_radius, 0.1) * delta
	for wheel in _wheels:
		wheel.rotation.x = _wheel_angle
	for wheel in _front_steering:
		wheel.rotation.y = -steering * 0.35
	for light in _headlights:
		light.visible = controlled
	for material in _brakes:
		material.emission_energy_multiplier = 2.7 if braking else 0.65
	if type != "car":
		_frame_lean = lerpf(_frame_lean, -steering * clampf(forward_speed / maximum_speed, -1.0, 1.0) * 0.18, minf(delta * 6.0, 1.0))
		visual.rotation.z = _frame_lean
	if door_pivot:
		door_pivot.rotation.y = lerp_angle(door_pivot.rotation.y, -1.10 if _door_open else 0.0, minf(delta * 7.0, 1.0))
	if _pedals:
		_pedals.rotation.x = _wheel_angle * 0.45

func set_door_open(value: bool) -> void:
	_door_open = value

func get_entry_position() -> Vector3:
	return to_global(entry_offset)

func get_seat_position() -> Vector3:
	return to_global(seat_offset)

func _material(texture: String, tint := Color.WHITE, glow := Color.BLACK) -> StandardMaterial3D:
	var key := texture + tint.to_html() + glow.to_html()
	if _materials.has(key): return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/%s.png" % texture)
	mat.albedo_color = tint
	mat.roughness_texture = load("res://assets/textures/%s_rough.png" % texture)
	mat.roughness = 0.72
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/%s_normal.png" % texture)
	mat.normal_scale = 0.25
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = 0.8
	_materials[key] = mat
	return mat

func _mesh(mesh: Mesh, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.visibility_range_end = 58.0
	(parent if parent else visual).add_child(instance)
	return instance

func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(shape,pos,mat,parent)

func _pipe(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 8
	var instance := _mesh(shape,(a+b)*0.5,mat,parent)
	var up := (b-a).normalized()
	var right := Vector3.FORWARD.cross(up).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	instance.basis = Basis(right,up,right.cross(up).normalized()).orthonormalized()
	return instance

func _loft(rows: Array[Vector4], base_y: float, mat: Material) -> MeshInstance3D:
	# Row = z, half-width, topheight, upper half-width; shoulder contour follows the car.
	var rings: Array[PackedVector3Array] = []
	for row in rows:
		rings.append(PackedVector3Array([Vector3(-row.y,base_y,row.x),Vector3(row.y,base_y,row.x),Vector3(row.w,row.z,row.x),Vector3(-row.w,row.z,row.x)]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size()-1:
		for side in 4:
			var next := (side+1)%4
			var quad := [rings[i][side],rings[i+1][side],rings[i+1][next],rings[i][next]]
			for vertex_index in [0,2,1,0,3,2]:
				st.set_uv(Vector2(quad[vertex_index].x,quad[vertex_index].z)*0.55)
				st.add_vertex(quad[vertex_index])
	for pair in [[0,true],[rings.size()-1,false]]:
		var ring: PackedVector3Array = rings[pair[0]]
		for vertex_index in ([0,2,1,0,3,2] if pair[1] else [0,1,2,0,2,3]):
			st.set_uv(Vector2(ring[vertex_index].x,ring[vertex_index].y))
			st.add_vertex(ring[vertex_index])
	st.generate_normals()
	return _mesh(st.commit(),Vector3.ZERO,mat)

func _wheel(pos: Vector3, radius: float, width: float, steering_wheel := false, spokes := false) -> void:
	var steering_node := Node3D.new()
	steering_node.position = pos
	visual.add_child(steering_node)
	if steering_wheel: _front_steering.append(steering_node)
	var roll := Node3D.new()
	steering_node.add_child(roll)
	_wheels.append(roll)
	if spokes:
		var torus := TorusMesh.new()
		torus.inner_radius = radius-0.045
		torus.outer_radius = radius
		torus.rings = 16
		torus.ring_segments = 6
		var tire := _mesh(torus,Vector3.ZERO,_material("coat",Color(0.38,0.38,0.38)),roll)
		tire.rotation.z = PI*0.5
		for i in 8:
			var angle := float(i)*TAU/8.0
			_pipe(Vector3.ZERO,Vector3(0,sin(angle)*radius*0.88,cos(angle)*radius*0.88),0.008,_material("metal"),roll)
	else:
		var tire := CylinderMesh.new()
		tire.top_radius = radius
		tire.bottom_radius = radius
		tire.height = width
		tire.radial_segments = 16
		var node := _mesh(tire,Vector3.ZERO,_material("coat",Color(0.35,0.35,0.35)),roll)
		node.rotation.z = PI*0.5
		var cap := CylinderMesh.new()
		cap.top_radius = radius*0.53
		cap.bottom_radius = radius*0.53
		cap.height = width+0.012
		cap.radial_segments = 10
		var wheelcap := _mesh(cap,Vector3.ZERO,_material("metal",Color(0.85,0.86,0.82)),roll)
		wheelcap.rotation.z = PI*0.5

func _build_car() -> void:
	display_name = "Carro"
	maximum_speed = 14.0
	acceleration = 5.1
	var paint := _material("metal",Color("5e747b"))
	_loft([Vector4(-1.9,0.72,0.63,0.72),Vector4(-1.55,0.87,0.88,0.83),Vector4(-0.55,0.88,0.90,0.83),Vector4(1.25,0.87,0.88,0.83),Vector4(1.85,0.75,0.72,0.75)],0.32,paint)
	var window := _material("glass",Color(0.47,0.58,0.6,0.46)).duplicate() as StandardMaterial3D
	window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window.roughness = 0.35
	_loft([Vector4(-0.58,0.79,0.90,0.78),Vector4(-0.18,0.78,1.46,0.65),Vector4(0.85,0.78,1.44,0.65),Vector4(1.30,0.78,0.89,0.76)],0.86,window)
	for seat_x in [-0.35,0.35]:
		_box(Vector3(seat_x,0.59,0.13),Vector3(0.45,0.13,0.57),_material("coat"))
		var seat_back := _box(Vector3(seat_x,0.88,0.43),Vector3(0.45,0.59,0.13),_material("coat"))
		seat_back.rotation.x = -0.10
	var steering_ring := TorusMesh.new()
	steering_ring.inner_radius = 0.15
	steering_ring.outer_radius = 0.18
	steering_ring.rings = 12
	steering_ring.ring_segments = 6
	var steering_mesh := _mesh(steering_ring,Vector3(-0.35,1.01,-0.48),_material("coat"))
	steering_mesh.rotation.x = PI*0.5
	_box(Vector3(0,1.46,0.33),Vector3(1.32,0.05,1.02),paint)
	for side in [-1.0,1.0]:
		for z in [-1.2,1.15]: _wheel(Vector3(side*0.87,0.34,z),0.34,0.22,z<0)
		_box(Vector3(side*0.82,1.12,0.40),Vector3(0.05,0.60,0.055),paint)
		_box(Vector3(side*0.91,1.10,-0.50),Vector3(0.20,0.12,0.17),paint)
		_box(Vector3(side*0.52,0.73,-1.87),Vector3(0.44,0.16,0.04),_material("marking",Color.WHITE,Color("ffe0a2")))
		var brake := _material("marking",Color("8f3e3b"),Color("ff493d")).duplicate() as StandardMaterial3D
		_brakes.append(brake)
		_box(Vector3(side*0.53,0.69,1.84),Vector3(0.43,0.17,0.045),brake)
		var light := SpotLight3D.new()
		light.position = Vector3(side*0.53,0.74,-1.88)
		light.light_color = Color("ffe3b4")
		light.light_energy = 1.6
		light.spot_range = 18
		light.spot_angle = 35
		light.shadow_enabled = false
		visual.add_child(light)
		_headlights.append(light)
	_box(Vector3(0,0.39,-1.91),Vector3(1.45,0.13,0.09),_material("coat"))
	_box(Vector3(0,0.39,1.91),Vector3(1.45,0.13,0.09),_material("coat"))
	_box(Vector3(0,0.58,1.895),Vector3(0.48,0.12,0.025),_material("marking"))
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-0.855,1.05,-0.33)
	visual.add_child(door_pivot)
	_box(Vector3(0,-0.15,0.56),Vector3(0.045,0.50,1.08),paint,door_pivot)
	_box(Vector3(-0.02,-0.02,0.93),Vector3(0.035,0.055,0.14),_material("metal"),door_pivot)

func _build_motorbike() -> void:
	display_name = "Mota"
	maximum_speed = 16.0
	acceleration = 5.8
	seat_offset = Vector3(0,-0.23,0.15)
	entry_offset = Vector3(-0.95,0,0.15)
	exit_offsets = [Vector3(-1.1,0.1,0.15),Vector3(1.1,0.1,0.15)]
	var metal := _material("metal")
	var paint := _material("metal",Color("895c4b"))
	_wheel(Vector3(0,0.35,-0.85),0.35,0.17,true)
	_wheel(Vector3(0,0.35,0.85),0.35,0.21)
	_pipe(Vector3(0,0.42,0.5),Vector3(0,1.02,-0.45),0.065,metal)
	_pipe(Vector3(0,0.35,-0.85),Vector3(0,1.15,-0.58),0.055,metal)
	_pipe(Vector3(-0.32,1.15,-0.58),Vector3(0.32,1.15,-0.58),0.035,metal)
	_loft([Vector4(-0.6,0.14,0.88,0.16),Vector4(-0.30,0.24,1.04,0.18),Vector4(0.12,0.22,0.93,0.16)],0.59,paint)
	_box(Vector3(0,0.89,0.38),Vector3(0.39,0.12,0.75),_material("coat"))
	_box(Vector3(0,0.50,0.0),Vector3(0.37,0.40,0.45),metal)
	_pipe(Vector3(-0.24,0.30,0),Vector3(-0.24,0.36,0.85),0.06,metal)
	_box(Vector3(0,0.97,-0.77),Vector3(0.25,0.22,0.12),_material("marking",Color.WHITE,Color("ffe2ad")))
	_box(Vector3(0,0.79,0.93),Vector3(0.22,0.12,0.08),_material("marking",Color.WHITE,Color("ed514a")))

func _build_bicycle() -> void:
	display_name = "Bicicleta"
	maximum_speed = 10.0
	acceleration = 2.7
	_wheel_radius = 0.37
	seat_offset = Vector3(0,-0.17,0.28)
	entry_offset = Vector3(-0.9,0,0.15)
	exit_offsets = [Vector3(-1.0,0.1,0.1),Vector3(1.0,0.1,0.1)]
	var frame := _material("metal",Color("9d8a55"))
	var rear := Vector3(0,0.38,0.85)
	var front := Vector3(0,0.38,-0.85)
	var crank := Vector3(0,0.40,0.12)
	var seat := Vector3(0,0.94,0.34)
	var head := Vector3(0,1.02,-0.55)
	_wheel(front,0.37,0.06,true,true)
	_wheel(rear,0.37,0.06,false,true)
	for pair in [[rear,seat],[rear,crank],[crank,seat],[seat,head],[crank,head],[head,front]]:
		_pipe(pair[0],pair[1],0.026,frame)
	_pipe(Vector3(-0.32,1.08,-0.59),Vector3(0.32,1.08,-0.59),0.022,_material("metal"))
	_box(Vector3(0,1.0,0.34),Vector3(0.25,0.07,0.32),_material("coat"))
	_pedals = Node3D.new()
	_pedals.position = crank
	visual.add_child(_pedals)
	for side in [-1.0,1.0]:
		_pipe(Vector3.ZERO,Vector3(side*0.16,side*0.14,0),0.016,_material("metal"),_pedals)
		_box(Vector3(side*0.22,side*0.14,0),Vector3(0.15,0.035,0.10),_material("coat"),_pedals)

func _build_scooter() -> void:
	display_name = "Trotinete"
	maximum_speed = 8.0
	acceleration = 3.2
	_wheel_radius = 0.16
	seat_offset = Vector3(0,0.19,0.18)
	entry_offset = Vector3(-0.8,0,0.18)
	exit_offsets = [Vector3(-0.9,0.1,0.1),Vector3(0.9,0.1,0.1)]
	var frame := _material("metal",Color("778d83"))
	_wheel(Vector3(0,0.16,-0.64),0.16,0.07,true)
	_wheel(Vector3(0,0.16,0.62),0.16,0.07)
	_box(Vector3(0,0.19,0.18),Vector3(0.22,0.10,0.94),_material("coat"))
	_pipe(Vector3(0,0.20,-0.53),Vector3(0,1.11,-0.66),0.035,frame)
	_pipe(Vector3(-0.30,1.13,-0.66),Vector3(0.30,1.13,-0.66),0.026,frame)
	_box(Vector3(0,0.98,-0.71),Vector3(0.10,0.08,0.06),_material("marking",Color.WHITE,Color("e4e4c6")))
