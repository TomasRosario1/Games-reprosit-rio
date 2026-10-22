class_name AlbumVehicleManager
extends Node3D
## Owns the enter/ride/exit transaction while keeping the same player and camera.
signal driving_changed(driving: bool)
signal rider_crashed(force: float)
signal message(text: String)
signal collided_person(person: Node, strength: float)
signal fell_out_of_world(safe_position: Vector3)

const VEHICLE = preload("res://scripts/vehicle.gd")
var vehicles: Array[Node3D] = []
var active_vehicle: Node3D
var state := "on_foot"
var controls_enabled := true
var _player: CharacterBody3D
var _saved_layer := 1
var _saved_mask := 3
var _saved_physics := true
var _excluded_rid := RID()
var _transition_time := 0.0
var _walk_duration := 0.7
var _start_position := Vector3.ZERO
var _door_position := Vector3.ZERO
var _exit_position := Vector3.ZERO
var _orbit_yaw := 0.0
var _orbit_pitch := -0.20
var _horn: AudioStreamPlayer3D
var _safe_exit_position := Vector3.ZERO
var _safe_exit_timer := 0.0
var _impact_jolt := 0.0
var _impact_time := 0.0

func _ready() -> void:
	name = "VeiculosConduziveis"
	process_physics_priority = 10
	_ensure_inputs()
	if vehicles.is_empty():
		var kinds := ["car", "motorbike", "bicycle", "scooter"]
		var locations := [Vector3(8,0.5,1),Vector3(9,0.5,8),Vector3(30,0.5,16),Vector3(38,0.5,12)]
		for index in 4:
			var vehicle := VEHICLE.new()
			vehicle.type = kinds[index]
			vehicle.position = locations[index]
			vehicle.rotation.y = PI*0.5 if index == 0 else PI*0.15
			add_child(vehicle)
			register_vehicle(vehicle)
	_build_horn()

func _ensure_inputs() -> void:
	var bindings := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"vehicle_brake":KEY_SPACE,"vehicle_horn":KEY_H}
	for action in bindings:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action,event)
	for pair in [["vehicle_brake",JOY_BUTTON_A],["vehicle_horn",JOY_BUTTON_RIGHT_SHOULDER]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0],event)

func register_vehicle(vehicle: Node3D) -> void:
	if not is_instance_valid(vehicle) or vehicles.has(vehicle): return
	if not vehicle.has_method("get_seat_position"): return
	vehicles.append(vehicle)
	vehicle.set_meta("editable",true)
	vehicle.set_meta("editor_kind","vehicle")
	vehicle.set_meta("vehicle_id",vehicle.get_meta("vehicle_id","vehicle_%02d" % vehicles.size()))
	if vehicle.has_signal("frontal_crash"):
		vehicle.frontal_crash.connect(_on_crash.bind(vehicle))
	if vehicle.has_signal("hit_person"):
		vehicle.hit_person.connect(func(person: Node,strength: float): collided_person.emit(person,strength))
	if vehicle.has_signal("fell_out_of_world"):
		vehicle.fell_out_of_world.connect(_on_vehicle_void.bind(vehicle))
	if vehicle.has_signal("impact_occurred"):
		vehicle.impact_occurred.connect(_on_vehicle_impact.bind(vehicle))

func set_player(body: CharacterBody3D) -> void:
	if is_driving(): force_exit()
	_player = body

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	for vehicle in vehicles:
		if is_instance_valid(vehicle): vehicle.controls_enabled = value

func find_nearest(position: Vector3, maximum_distance: float = 2.5) -> Node3D:
	var result: Node3D
	var distance := maximum_distance
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle == active_vehicle or not vehicle.is_visible_in_tree() or vehicle.collision_layer==0: continue
		var current: float = position.distance_to(vehicle.get_entry_position())
		if current < distance:
			distance = current
			result = vehicle
	return result

func is_driving() -> bool:
	return state != "on_foot"

func is_transitioning() -> bool:
	return state in ["entering","exiting"]

func interact() -> bool:
	if not is_instance_valid(_player) or not controls_enabled: return false
	if state == "driving": return _begin_exit()
	if state != "on_foot": return false
	var nearest := find_nearest(_player.global_position)
	if not nearest: return false
	return _begin_enter(nearest)

func _begin_enter(vehicle: Node3D) -> bool:
	if not is_instance_valid(vehicle) or not vehicle.is_visible_in_tree() or vehicle.collision_layer==0: return false
	if absf(vehicle.forward_speed) > 1.0: return false
	var entry: Vector3 = vehicle.get_entry_position()
	entry.y = _player.global_position.y
	var query := PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP,entry+Vector3.UP,1,[_player.get_rid(),vehicle.get_rid()])
	if not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		message.emit("Aproxima-te do lado livre do veículo.")
		return false
	active_vehicle = vehicle
	var mounted_visual := _get_visual()
	if mounted_visual and mounted_visual.has_method("get_body_height") and vehicle.has_method("fit_rider"):
		vehicle.fit_rider(mounted_visual.get_body_height())
	_saved_layer = _player.collision_layer
	_saved_mask = _player.collision_mask
	_saved_physics = _player.is_physics_processing()
	_player.set_physics_process(false)
	_player.movement_locked = true
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_player.set_meta("driving",true)
	_player.set_meta("vehicle_body",vehicle)
	var footsteps: Variant = _player.get("_footsteps")
	if footsteps is AudioStreamPlayer3D: footsteps.stop()
	var spring: Variant = _player.get("_spring")
	if spring is SpringArm3D:
		_excluded_rid = vehicle.get_rid()
		spring.add_excluded_object(_excluded_rid)
	_start_position = _player.global_position
	_safe_exit_position = _start_position
	_safe_exit_timer = 0
	_door_position = entry
	_transition_time = 0.0
	_walk_duration = clampf(_start_position.distance_to(entry)/1.8,0.35,1.4)
	_orbit_yaw = 0.0
	_orbit_pitch = -0.20
	state = "entering"
	vehicle.controlled = false
	vehicle.set_door_open(true)
	driving_changed.emit(true)
	return true

func _begin_exit() -> bool:
	if not is_instance_valid(active_vehicle):
		force_exit()
		return false
	if absf(active_vehicle.forward_speed) > 2.0:
		message.emit("Abranda antes de sair do veículo.")
		return false
	var candidate: Variant = _find_clear_exit()
	if candidate == null:
		message.emit("Não há espaço livre para sair. Move o veículo.")
		return false
	_exit_position = candidate
	_start_position = _player.global_position
	_door_position = active_vehicle.get_entry_position()
	_door_position.y = _exit_position.y
	_transition_time = 0.0
	state = "exiting"
	active_vehicle.controlled = false
	active_vehicle.forward_speed = 0.0
	active_vehicle.set_door_open(true)
	return true

func _find_clear_exit() -> Variant:
	if not is_instance_valid(_player) or not is_instance_valid(active_vehicle): return null
	var space := _player.get_world_3d().direct_space_state
	for offset: Vector3 in active_vehicle.exit_offsets:
		var candidate: Vector3 = active_vehicle.to_global(offset)
		var ray := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*2.0,candidate-Vector3.UP*3.0,1,[_player.get_rid(),active_vehicle.get_rid()])
		var floor_hit := space.intersect_ray(ray)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.65: continue
		candidate.y = floor_hit.position.y + 0.04
		var shape := CapsuleShape3D.new()
		shape.radius = 0.29
		shape.height = 1.82
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(),candidate+Vector3.UP*0.91)
		query.collision_mask = 3
		query.exclude = [_player.get_rid(),active_vehicle.get_rid()]
		if space.intersect_shape(query,1).is_empty(): return candidate
	return null

func force_exit() -> void:
	if not is_driving(): return
	var destination := _player.global_position + Vector3.UP*0.5 if is_instance_valid(_player) else Vector3.ZERO
	if is_instance_valid(active_vehicle):
		var safe: Variant = _find_clear_exit()
		if safe != null: destination = safe
		active_vehicle.controlled = false
		active_vehicle.forward_speed = 0.0
		active_vehicle.set_door_open(false)
	_restore_player(destination)

func _physics_process(delta: float) -> void:
	if not is_driving() or not is_instance_valid(_player): return
	if not is_instance_valid(active_vehicle):
		force_exit()
		return
	_player.movement_locked = true
	if not controls_enabled:
		active_vehicle.controls_enabled = false
		_update_camera(delta)
		return
	_safe_exit_timer -= delta
	if state=="driving" and _safe_exit_timer<=0 and active_vehicle.is_on_floor():
		_safe_exit_timer = 0.75
		var safe: Variant = _find_clear_exit()
		if safe!=null: _safe_exit_position = safe
	_transition_time += delta
	var visual := _get_visual()
	match state:
		"entering":
			if _transition_time <= _walk_duration:
				var t := clampf(_transition_time/_walk_duration,0.0,1.0)
				_player.global_position = _start_position.lerp(_door_position,t)
				_face_visual(visual,_door_position-_start_position)
				_animate_visual(delta,1.7,"")
			else:
				var t := smoothstep(0.0,1.0,clampf((_transition_time-_walk_duration)/0.65,0.0,1.0))
				_player.global_position = _door_position.lerp(active_vehicle.get_seat_position(),t)
				if visual: visual.rotation.y = active_vehicle.rotation.y
				_animate_visual(delta,0.0,active_vehicle.type)
				if t >= 1.0:
					state = "driving"
					active_vehicle.controlled = true
					active_vehicle.set_door_open(false)
		"driving":
			_player.global_position = active_vehicle.get_seat_position()
			if visual:
				visual.rotation.y = active_vehicle.rotation.y
				visual.rotation.z = active_vehicle.visual.rotation.z
				visual.rotation.x = active_vehicle.visual.rotation.x
			_animate_visual(delta,absf(active_vehicle.forward_speed),active_vehicle.type)
			_read_camera_stick(delta)
		"exiting":
			var t := clampf(_transition_time/0.85,0.0,1.0)
			_player.global_position = _start_position.lerp(_exit_position,smoothstep(0.0,1.0,t))
			_face_visual(visual,_exit_position-_start_position)
			_animate_visual(delta,1.0,"" if t>0.4 else active_vehicle.type)
			if t >= 1.0:
				active_vehicle.set_door_open(false)
				_restore_player(_exit_position)
	_update_camera(delta)

func _restore_player(destination: Vector3) -> void:
	if is_instance_valid(_player):
		_player.global_position = destination
		_player.collision_layer = _saved_layer
		_player.collision_mask = _saved_mask
		_player.movement_locked = false
		_player.set_meta("driving",false)
		if _player.has_meta("vehicle_body"): _player.remove_meta("vehicle_body")
		_player.set_physics_process(_saved_physics)
		var visual := _get_visual()
		if visual:
			visual.rotation.z = 0.0
			visual.rotation.x = 0.0
			if visual.has_method("set_vehicle_pose"): visual.set_vehicle_pose("")
		var spring: Variant = _player.get("_spring")
		if spring is SpringArm3D and _excluded_rid.is_valid(): spring.remove_excluded_object(_excluded_rid)
	if is_instance_valid(_player) and _player.has_method("get_camera"):
		var camera: Camera3D = _player.call("get_camera")
		camera.h_offset = 0.0; camera.v_offset = 0.0
	_impact_jolt = 0.0
	active_vehicle = null
	_excluded_rid = RID()
	state = "on_foot"
	driving_changed.emit(false)

func _on_crash(force: float, vehicle: Node3D) -> void:
	if active_vehicle != vehicle or state != "driving": return
	var direction: Vector3 = -vehicle.global_basis.z
	force_exit()
	if is_instance_valid(_player):
		_player.velocity = direction*3.2 + Vector3.UP*4.0
		var visual := _get_visual()
		if visual and visual.has_method("react"): visual.react("flinch")
	rider_crashed.emit(force)

func _get_visual() -> Node3D:
	if is_instance_valid(_player): return _player.get("_visuals") as Node3D
	return null

func _animate_visual(delta: float, speed: float, pose: String) -> void:
	var visual := _get_visual()
	if not visual: return
	if visual.has_method("set_vehicle_pose"): visual.set_vehicle_pose(pose)
	if not pose.is_empty() and visual.has_method("set_vehicle_contacts") and is_instance_valid(active_vehicle) and active_vehicle.has_method("get_rider_contacts"):
		visual.set_vehicle_contacts(active_vehicle.get_rider_contacts())
	if visual.has_method("animate"): visual.animate(delta,speed,false,false,false,100.0)

func _face_visual(visual: Node3D, direction: Vector3) -> void:
	if visual and Vector2(direction.x,direction.z).length() > 0.01:
		visual.rotation.y = atan2(-direction.x,-direction.z)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(active_vehicle): return
	_player.set("_yaw",active_vehicle.rotation.y+_orbit_yaw)
	_player.set("_pitch",_orbit_pitch)
	if _player.has_method("_update_camera"): _player.call("_update_camera",delta)
	_impact_time += delta
	_impact_jolt = lerpf(_impact_jolt,0.0,1.0-exp(-8.0*delta))
	if _player.has_method("get_camera"):
		var camera: Camera3D = _player.call("get_camera")
		camera.h_offset = sin(_impact_time*56.0)*_impact_jolt
		camera.v_offset = cos(_impact_time*43.0)*_impact_jolt*0.6

func _read_camera_stick(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): return
	var look := Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_X),Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_Y))
	if look.length() < 0.18: return
	_orbit_yaw -= look.x*delta*2.3
	_orbit_pitch = clampf(_orbit_pitch-look.y*delta*1.6,-0.8,0.25)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or state != "driving": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_orbit_yaw -= event.relative.x*0.0025
		_orbit_pitch = clampf(_orbit_pitch-event.relative.y*0.0025,-0.8,0.25)
	elif event.is_action_pressed("vehicle_horn") and _horn:
		_horn.global_position = active_vehicle.global_position
		_horn.play()

func _build_horn() -> void:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(6615*2)
	for i in 6615:
		var t := float(i)/22050.0
		var fade := minf(t*40.0,1.0)*minf((0.30-t)*25.0,1.0)
		var value := (sin(t*TAU*370.0)+0.4*sin(t*TAU*466.0))*0.12*fade
		bytes.encode_s16(i*2,int(value*32767))
	audio.data = bytes
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = audio
	_horn.max_distance = 35
	_horn.volume_db = -6
	add_child(_horn)

func _on_vehicle_impact(force: float, vehicle: Node3D) -> void:
	if active_vehicle==vehicle and is_driving(): _impact_jolt = minf(0.13,force*0.009)

func _on_vehicle_void(vehicle: Node3D) -> void:
	var lost_rider := active_vehicle==vehicle and is_driving()
	var safe := _safe_exit_position
	if lost_rider: force_exit()
	if vehicle.has_method("recover_from_void"): vehicle.recover_from_void()
	if lost_rider: fell_out_of_world.emit(safe)
