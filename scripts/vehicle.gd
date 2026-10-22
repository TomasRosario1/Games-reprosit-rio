class_name AlbumVehicle
extends CharacterBody3D
## Small original arcade vehicles. Rigidbody simulation is intentionally avoided.
signal frontal_crash(force: float)
signal hit_person(person: Node, strength: float)
signal impact_occurred(force: float)
signal fell_out_of_world

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
var seat_offset := Vector3(-0.35, -0.27, -0.10)
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
var _saddle: MeshInstance3D
var damage_zones := Vector4.ZERO # front, rear, left, right; original visible mesh deformation.
var damage_level := 0.0
var step_height := 0.24
var last_step_height := 0.0
var _collider: CollisionShape3D
var _wheel_mounts: Array[Node3D] = []
var _wheel_rest: Array[Vector3] = []
var _deformable: Array[Dictionary] = []
var _damage_parts: Array[Dictionary] = []
var _front_lamps: Array[MeshInstance3D] = []
var _cracks: Node3D
var _impact_audio: AudioStreamPlayer3D
var _impact_cooldown := 0.0
var _impact_pitch := 0.0
var _impact_roll := 0.0
var _terrain_pitch := 0.0
var _terrain_roll := 0.0
var _step_spring := 0.0
var _terrain_timer := 0.0
var _wheel_ground: Array[float] = []
var _wheel_ground_valid: Array[bool] = []
var _last_grounded_transform := Transform3D.IDENTITY
var _has_grounded_recovery := false
var _void_reported := false

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
	step_height = {"car":0.24,"motorbike":0.20,"bicycle":0.16,"scooter":0.11}[type]
	_build_collision()
	_build_impact_audio()
	_last_grounded_transform = global_transform
	name = "Veiculo_" + type
	add_to_group("album_vehicles")
	set_meta("editable", true)
	set_meta("editor_kind", "vehicle")

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.78,1.65,3.75) if type == "car" else Vector3(0.58,1.12,2.1 if type != "scooter" else 1.55)
	collider.shape = shape
	collider.position.y = shape.size.y * 0.5
	add_child(collider)
	_collider = collider

func _physics_process(delta: float) -> void:
	_crash_cooldown = maxf(0.0, _crash_cooldown - delta)
	_impact_cooldown = maxf(0.0,_impact_cooldown-delta)
	last_step_height = 0.0
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
		var speed_limit := maximum_speed*(1.0-damage_level*0.12) if throttle > 0.0 else 3.5
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
	var stepped := false
	if absf(forward_speed)>0.4 and is_on_floor(): stepped = _try_curb_step(Vector3(velocity.x,0,velocity.z)*delta)
	var previous_snap := floor_snap_length
	if stepped:
		# Do not snap back to the lower road while the chassis nose enters the kerb.
		floor_snap_length = 0.0
		velocity.y = 0.0
	move_and_slide()
	floor_snap_length = previous_snap
	if is_on_floor() and absf(velocity.y)<2.0:
		_last_grounded_transform = global_transform
		_has_grounded_recovery = true
	if global_position.y < -12.0 and not _void_reported:
		_void_reported = true
		fell_out_of_world.emit()
		return
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
			if before_speed > 2.2 and _impact_cooldown<=0.0:
				apply_impact(before_speed,collision.get_position(),normal)
			if type in ["bicycle", "motorbike"] and forward_speed > 9.0 and _crash_cooldown <= 0.0:
				_crash_cooldown = 1.8
				frontal_crash.emit(before_speed)
	if blocked:
		forward_speed = -signf(forward_speed)*minf(0.75,before_speed*0.08) if before_speed>3.0 else 0.0
	_update_ground_contacts(delta)
	_animate_vehicle(delta, braking)

func _animate_vehicle(delta: float, braking: bool) -> void:
	_wheel_angle -= forward_speed / maxf(_wheel_radius, 0.1) * delta
	for wheel in _wheels:
		wheel.rotation.x = _wheel_angle
	for wheel in _front_steering:
		wheel.rotation.y = -steering * 0.35
	for index in _headlights.size():
		_headlights[index].visible = controlled and damage_zones.x < (0.45 if index==0 else 0.88)
	for material in _brakes:
		material.emission_energy_multiplier = 2.7 if braking else 0.65
	var corner_lean := -steering*clampf(forward_speed/maximum_speed,-1.0,1.0)*(0.055 if type=="car" else 0.18)
	_frame_lean = lerpf(_frame_lean,corner_lean,1.0-exp(-6.0*delta))
	_impact_pitch = lerpf(_impact_pitch,0.0,1.0-exp(-5.0*delta))
	_impact_roll = lerpf(_impact_roll,0.0,1.0-exp(-5.0*delta))
	_step_spring = lerpf(_step_spring,0.0,1.0-exp(-9.0*delta))
	visual.rotation.x = lerp_angle(visual.rotation.x,_terrain_pitch+_impact_pitch,1.0-exp(-8.0*delta))
	visual.rotation.z = lerp_angle(visual.rotation.z,_terrain_roll+_frame_lean+_impact_roll,1.0-exp(-8.0*delta))
	visual.position.y = -_step_spring
	if door_pivot:
		door_pivot.rotation.y = lerp_angle(door_pivot.rotation.y, -1.10 if _door_open else 0.0, minf(delta * 7.0, 1.0))
	if _pedals:
		_pedals.rotation.x = _wheel_angle * 0.45

func set_door_open(value: bool) -> void:
	_door_open = value

func get_entry_position() -> Vector3:
	return to_global(entry_offset)

func get_seat_position() -> Vector3:
	return visual.to_global(seat_offset) if is_instance_valid(visual) else to_global(seat_offset)

func get_rider_contacts() -> Dictionary:
	# Targets are measured from this vehicle's actual grips/footrests in the
	# seated avatar's coordinate frame, rather than a generic seated pose.
	var contacts := {}
	for side in ["L","R"]:
		var sign_side := -1.0 if side=="L" else 1.0
		var hand: Vector3
		var ankle: Vector3
		match type:
			"motorbike":
				hand = Vector3(sign_side*0.30,1.15,-0.52)
				ankle = Vector3(sign_side*0.26,0.48,0.05)
			"bicycle":
				hand = Vector3(sign_side*0.29,1.16,-0.33)
				# Pedals and feet use the same rotation, even after coasting,
				# reversing or stopping; the rider never pedals through thin air.
				ankle = _pedals.transform*Vector3(sign_side*0.22,sign_side*0.14,0.0)+Vector3(0,0.09,0.06)
			"scooter":
				hand = Vector3(sign_side*0.28,1.33,-0.42)
				ankle = Vector3(sign_side*0.055,0.255,0.22 if side=="L" else -0.08)
			_:
				hand = Vector3(-0.35+sign_side*0.16,1.01,-0.48)
				ankle = Vector3(-0.35+sign_side*0.16,0.44,-0.62)
		contacts["hand."+side] = hand-seat_offset
		contacts["foot."+side] = ankle-seat_offset
	return contacts

func fit_rider(height: float) -> void:
	if type!="bicycle" or not is_instance_valid(_saddle): return
	# A normal seat-post adjustment allows shorter adults to reach the same
	# crank. Keep the actual saddle and the skeleton anchor together.
	var drop := clampf((1.83-height)*0.38,0.0,0.085)
	_saddle.position.y = 1.0-drop
	seat_offset.y = 0.15-drop

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
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
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
			for vertex_index in [0,1,2,0,2,3]:
				var point: Vector3 = quad[vertex_index]
				st.set_uv((Vector2(point.x,point.z) if side in [0,2] else Vector2(point.z,point.y))*0.55)
				st.add_vertex(point)
	for pair in [[0,true],[rings.size()-1,false]]:
		var ring: PackedVector3Array = rings[pair[0]]
		for vertex_index in ([0,1,2,0,2,3] if pair[1] else [0,2,1,0,3,2]):
			st.set_uv(Vector2(ring[vertex_index].x,ring[vertex_index].y))
			st.add_vertex(ring[vertex_index])
	st.generate_normals()
	var node := _mesh(st.commit(),Vector3.ZERO,mat)
	_deformable.append({"node":node,"arrays":node.mesh.surface_get_arrays(0).duplicate(true)})
	return node

func _wheel(pos: Vector3, radius: float, width: float, steering_wheel := false, spokes := false) -> void:
	var steering_node := Node3D.new()
	steering_node.position = pos
	visual.add_child(steering_node)
	steering_node.set_meta("wheel_radius",radius)
	_wheel_mounts.append(steering_node)
	_wheel_rest.append(pos)
	_wheel_ground.append(0.0)
	_wheel_ground_valid.append(false)
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
	var paint := _material("metal",Color("738b91"))
	_loft([Vector4(-1.9,0.72,0.63,0.72),Vector4(-1.55,0.87,0.88,0.83),Vector4(-0.55,0.88,0.90,0.83),Vector4(1.25,0.87,0.88,0.83),Vector4(1.85,0.75,0.72,0.75)],0.32,paint)
	var window := _material("glass",Color(0.47,0.58,0.6,0.46)).duplicate() as StandardMaterial3D
	window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window.roughness = 0.35
	_loft([Vector4(-0.58,0.79,0.90,0.78),Vector4(-0.18,0.78,1.64,0.65),Vector4(0.85,0.78,1.62,0.65),Vector4(1.30,0.78,0.89,0.76)],0.86,window)
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
	_box(Vector3(0,1.64,0.33),Vector3(1.32,0.05,1.02),paint)
	for side in [-1.0,1.0]:
		for z in [-1.2,1.15]: _wheel(Vector3(side*0.87,0.34,z),0.34,0.22,z<0)
		_box(Vector3(side*0.76,1.21,0.40),Vector3(0.05,0.78,0.055),paint)
		_pipe(Vector3(side*0.78,0.90,-0.58),Vector3(side*0.65,1.64,-0.18),0.032,paint)
		_pipe(Vector3(side*0.76,0.89,1.30),Vector3(side*0.65,1.62,0.85),0.038,paint)
		_box(Vector3(side*0.91,1.10,-0.50),Vector3(0.20,0.12,0.17),paint)
		var front_lamp := _box(Vector3(side*0.52,0.73,-1.87),Vector3(0.44,0.16,0.04),_material("marking",Color.WHITE,Color("ffe0a2")).duplicate())
		_front_lamps.append(front_lamp)
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
	var front_bumper := _box(Vector3(0,0.39,-1.91),Vector3(1.45,0.13,0.09),_material("coat"))
	var rear_bumper := _box(Vector3(0,0.39,1.91),Vector3(1.45,0.13,0.09),_material("coat"))
	_damage_parts.append({"node":front_bumper,"position":front_bumper.position,"zone":0})
	_damage_parts.append({"node":rear_bumper,"position":rear_bumper.position,"zone":1})
	_box(Vector3(0,0.58,1.895),Vector3(0.48,0.12,0.025),_material("marking"))
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-0.855,1.05,-0.33)
	visual.add_child(door_pivot)
	_box(Vector3(0,-0.15,0.56),Vector3(0.045,0.50,1.08),paint,door_pivot)
	_box(Vector3(-0.02,-0.02,0.93),Vector3(0.035,0.055,0.14),_material("metal"),door_pivot)
	_cracks = Node3D.new()
	visual.add_child(_cracks)
	var fracture := _material("marking",Color("9dafa8"))
	for pair in [[Vector3(-0.53,1.01,-0.50),Vector3(-0.15,1.31,-0.29)],[Vector3(-0.15,1.31,-0.29),Vector3(0.05,1.11,-0.44)],[Vector3(-0.15,1.31,-0.29),Vector3(-0.02,1.40,-0.23)]]:
		_pipe(pair[0],pair[1],0.007,fracture,_cracks)
	_cracks.hide()

func _build_motorbike() -> void:
	display_name = "Mota"
	maximum_speed = 16.0
	acceleration = 5.8
	seat_offset = Vector3(0,0.08,0.15)
	entry_offset = Vector3(-0.95,0,0.15)
	exit_offsets = [Vector3(-1.1,0.1,0.15),Vector3(1.1,0.1,0.15)]
	var metal := _material("metal")
	var paint := _material("metal",Color("895c4b"))
	_wheel(Vector3(0,0.35,-0.85),0.35,0.17,true)
	_wheel(Vector3(0,0.35,0.85),0.35,0.21)
	_pipe(Vector3(0,0.42,0.5),Vector3(0,1.02,-0.45),0.065,metal)
	_pipe(Vector3(0,0.35,-0.85),Vector3(0,1.15,-0.58),0.055,metal)
	_pipe(Vector3(0,1.15,-0.58),Vector3(0,1.15,-0.52),0.035,metal)
	_pipe(Vector3(-0.32,1.15,-0.52),Vector3(0.32,1.15,-0.52),0.035,metal)
	_loft([Vector4(-0.6,0.14,0.88,0.16),Vector4(-0.30,0.24,1.04,0.18),Vector4(0.12,0.22,0.93,0.16)],0.59,paint)
	_box(Vector3(0,0.89,0.38),Vector3(0.39,0.12,0.75),_material("coat"))
	_box(Vector3(0,0.50,0.0),Vector3(0.37,0.40,0.45),metal)
	for side in [-1.0,1.0]:
		_pipe(Vector3(side*0.16,0.39,0.05),Vector3(side*0.32,0.39,0.05),0.025,_material("coat"))
	_pipe(Vector3(-0.24,0.30,0),Vector3(-0.24,0.36,0.85),0.06,metal)
	_box(Vector3(0,0.97,-0.77),Vector3(0.25,0.22,0.12),_material("marking",Color.WHITE,Color("ffe2ad")))
	_box(Vector3(0,0.79,0.93),Vector3(0.22,0.12,0.08),_material("marking",Color.WHITE,Color("ed514a")))

func _build_bicycle() -> void:
	display_name = "Bicicleta"
	maximum_speed = 10.0
	acceleration = 2.7
	_wheel_radius = 0.37
	seat_offset = Vector3(0,0.15,0.28)
	entry_offset = Vector3(-0.9,0,0.15)
	exit_offsets = [Vector3(-1.0,0.1,0.1),Vector3(1.0,0.1,0.1)]
	var frame := _material("metal",Color("9d8a55"))
	var rear := Vector3(0,0.38,0.64)
	var front := Vector3(0,0.38,-0.59)
	var crank := Vector3(0,0.40,0.12)
	var seat := Vector3(0,0.94,0.28)
	var head := Vector3(0,1.04,-0.30)
	_wheel(front,0.37,0.06,true,true)
	_wheel(rear,0.37,0.06,false,true)
	for pair in [[rear,seat],[rear,crank],[crank,seat],[seat,head],[crank,head],[head,front]]:
		_pipe(pair[0],pair[1],0.026,frame)
	_pipe(head,Vector3(0,1.16,-0.33),0.022,_material("metal"))
	_pipe(Vector3(-0.32,1.16,-0.33),Vector3(0.32,1.16,-0.33),0.022,_material("metal"))
	_saddle = _box(Vector3(0,1.0,0.28),Vector3(0.25,0.07,0.32),_material("coat"))
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
	seat_offset = Vector3(0,0.12,0.08)
	entry_offset = Vector3(-0.8,0,0.18)
	exit_offsets = [Vector3(-0.9,0.1,0.1),Vector3(0.9,0.1,0.1)]
	var frame := _material("metal",Color("778d83"))
	_wheel(Vector3(0,0.16,-0.64),0.16,0.07,true)
	_wheel(Vector3(0,0.16,0.62),0.16,0.07)
	_box(Vector3(0,0.13,0.18),Vector3(0.27,0.08,0.94),_material("coat"))
	_pipe(Vector3(0,0.17,-0.38),Vector3(0,1.30,-0.42),0.035,frame)
	_pipe(Vector3(0,0.21,-0.38),Vector3(0,0.16,-0.64),0.028,frame)
	_pipe(Vector3(-0.30,1.33,-0.42),Vector3(0.30,1.33,-0.42),0.026,frame)
	_box(Vector3(0,1.17,-0.47),Vector3(0.10,0.08,0.06),_material("marking",Color.WHITE,Color("e4e4c6")))

func _try_curb_step(horizontal_motion: Vector3) -> bool:
	if horizontal_motion.length_squared()<0.000001 or _collider==null: return false
	var contact := KinematicCollision3D.new()
	if not test_move(global_transform,horizontal_motion+horizontal_motion.normalized()*0.045,contact,0.001,false,4): return false
	var has_riser := false
	for i in contact.get_collision_count():
		if contact.get_normal(i).y<0.65: has_riser = true
	if not has_riser: return false
	var raised := global_transform
	var lift := step_height+0.035
	if test_move(raised,Vector3.UP*lift): return false
	raised.origin.y += lift
	var reach := horizontal_motion+horizontal_motion.normalized()*0.32
	if test_move(raised,reach): return false
	var local_direction := global_basis.inverse()*horizontal_motion.normalized()
	var half: Vector3 = (_collider.shape as BoxShape3D).size*0.5
	var support := absf(local_direction.x)*half.x+absf(local_direction.z)*half.z
	var probe := global_position+horizontal_motion.normalized()*(support+reach.length())
	probe.y = global_position.y+lift
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe,probe-Vector3.UP*(lift+0.10),1,[get_rid()]))
	if hit.is_empty() or hit.normal.y<0.70: return false
	var rise: float = hit.position.y-global_position.y
	if rise<0.012 or rise>step_height+0.006: return false
	global_position.y += rise+0.006
	_step_spring += rise*0.60
	last_step_height = rise
	return true

func _update_ground_contacts(delta: float) -> void:
	_terrain_timer -= delta
	if not controlled and _terrain_timer>0: return
	_terrain_timer = 0.10
	var space := get_world_3d().direct_space_state
	var front := 0.0; var rear := 0.0; var left := 0.0; var right := 0.0
	var fronts := 0; var rears := 0; var lefts := 0; var rights := 0
	var front_z := 0.0; var rear_z := 0.0
	for i in _wheel_mounts.size():
		var rest := _wheel_rest[i]
		var from := to_global(rest)+Vector3.UP*0.6
		var to := to_global(rest)-Vector3.UP*0.9
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[get_rid()]))
		_wheel_ground_valid[i] = not hit.is_empty()
		if hit.is_empty(): continue
		var level: float = hit.position.y
		_wheel_ground[i] = level
		if rest.z < 0: front+=level; fronts+=1; front_z+=rest.z
		else: rear+=level; rears+=1; rear_z+=rest.z
		if rest.x < -0.1: left+=level; lefts+=1
		elif rest.x>0.1: right+=level; rights+=1
	if fronts>0 and rears>0:
		var wheelbase := absf(front_z/float(fronts)-rear_z/float(rears))
		_terrain_pitch = clampf(atan2(front/float(fronts)-rear/float(rears),maxf(wheelbase,0.4)),-0.48,0.48)
	else: _terrain_pitch = lerpf(_terrain_pitch,0.0,minf(delta*3.0,1.0))
	if lefts>0 and rights>0:
		_terrain_roll = clampf(atan2(right/float(rights)-left/float(lefts),1.74),-0.30,0.30)
	else: _terrain_roll = 0.0
	for i in _wheel_mounts.size():
		var rest := _wheel_rest[i]
		var target := rest
		if _wheel_ground_valid[i]:
			var wanted := to_global(rest)
			wanted.y = _wheel_ground[i]+float(_wheel_mounts[i].get_meta("wheel_radius",_wheel_radius))
			target.y = clampf(visual.to_local(wanted).y,rest.y-0.28,rest.y+0.28)
		_wheel_mounts[i].position = _wheel_mounts[i].position.lerp(target,1.0-exp(-14.0*delta))

func apply_impact(speed: float, point: Vector3, normal: Vector3) -> void:
	if speed<2.2: return
	_impact_cooldown = 0.35
	var local := to_local(point)
	var zone := 0 if absf(local.z)>=absf(local.x) and local.z<0 else 1 if absf(local.z)>=absf(local.x) else 2 if local.x<0 else 3
	var amount := clampf((speed-2.2)/17.0,0.025,0.70)
	damage_zones[zone] = clampf(damage_zones[zone]+amount,0.0,1.0)
	damage_level = clampf((damage_zones.x+damage_zones.y+damage_zones.z+damage_zones.w)*0.60,0.0,1.0)
	_impact_pitch = clampf(-normal.dot(-global_basis.z)*speed*0.009,-0.12,0.12)
	_impact_roll = clampf(normal.dot(global_basis.x)*speed*0.008,-0.10,0.10)
	_rebuild_damage()
	if _impact_audio and DisplayServer.get_name()!="headless":
		_impact_audio.volume_db = lerpf(-19.0,-6.0,clampf(speed/16.0,0,1))
		_impact_audio.pitch_scale = lerpf(1.20,0.75,clampf(speed/16.0,0,1))
		_impact_audio.play()
	impact_occurred.emit(speed)

func _rebuild_damage() -> void:
	for entry in _deformable:
		var arrays: Array = entry.arrays.duplicate(true)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			var p := points[i]
			var front := clampf((-p.z-0.35)/1.55,0,1)*damage_zones.x
			var rear := clampf((p.z-0.65)/1.20,0,1)*damage_zones.y
			var side := clampf(absf(p.x)/0.88,0,1)*(damage_zones.z if p.x<0 else damage_zones.w)
			p.z += front*0.48-rear*0.38
			p.x *= 1.0-side*0.18
			p.y += front*0.14*sin(p.x*3.7)-rear*0.09
			points[i] = p
		arrays[Mesh.ARRAY_VERTEX] = points
		var raw := ArrayMesh.new(); raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var surface := SurfaceTool.new(); surface.create_from(raw,0); surface.generate_normals()
		entry.node.mesh = surface.commit()
	for part in _damage_parts:
		var amount: float = damage_zones[int(part.zone)]
		part.node.position = part.position+Vector3(0,-amount*0.07,(0.25 if int(part.zone)==0 else -0.20)*amount)
		part.node.rotation.x = amount*(0.14 if int(part.zone)==0 else -0.10)
		part.node.rotation.z = amount*0.045
	for i in _front_lamps.size():
		var broken := damage_zones.x > (0.45 if i==0 else 0.88)
		var material := _front_lamps[i].material_override as StandardMaterial3D
		material.emission_enabled = not broken
		material.albedo_color = Color("333936") if broken else Color.WHITE
	if _cracks: _cracks.visible = damage_zones.x>0.35 or damage_zones.z+damage_zones.w>0.7

func recover_from_void() -> bool:
	forward_speed = 0; velocity = Vector3.ZERO
	if not _has_grounded_recovery:
		hide(); collision_layer = 0; set_physics_process(false)
		return false
	global_transform = _last_grounded_transform
	global_position.y += 0.10
	_void_reported = false
	return true

func _build_impact_audio() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray(); bytes.resize(5292*2)
	var rng := RandomNumberGenerator.new(); rng.seed = 9051
	for i in 5292:
		var t := float(i)/22050.0
		var sound := (rng.randf_range(-1,1)*0.65+sin(t*TAU*72)*0.35)*exp(-t*24)
		bytes.encode_s16(i*2,int(sound*20000))
	stream.data = bytes
	_impact_audio = AudioStreamPlayer3D.new()
	_impact_audio.stream = stream
	_impact_audio.max_distance = 38
	_impact_audio.bus = "AlbumEffects" if AudioServer.get_bus_index("AlbumEffects")>=0 else "Master"
	add_child(_impact_audio)
