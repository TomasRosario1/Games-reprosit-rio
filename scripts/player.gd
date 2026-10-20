class_name AlbumPlayer
extends CharacterBody3D
## Character feet sit at the node origin. Assets are a textured procedural stand-in.

signal died

@export var display_name: String = "Artista 01"
@export var walk_speed: float = 1.85
@export var appearance_id: int = 0
@export var run_speed: float = 4.6
@export var mouse_sensitivity: float = 0.0025
@export var camera_idle_delay: float = 3.0
var movement_locked: bool = false
var health: float = 100.0
var spawn_transform: Transform3D = Transform3D.IDENTITY
var camera_distance: float = 4.3
var _gravity: float = 20.0
var _yaw: float = 0.0
var _pitch: float = -0.20
var _camera_idle: float = 0.0
var _animation_time: float = 0.0
var _dead: bool = false
var _crouched: bool = false
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _visuals: Node3D
var _camera_pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _name_label: Label3D
var _performing: bool = false
var _performance_bpm: float = 100.0
var _motion_speed: float = 0.0
var _footstep_distance: float = 0.0
var _footsteps: AudioStreamPlayer3D
var _lean: float = 0.0
var _punch_time: float = 0.0
var _punch_modifier: SkeletonModifier3D



func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.30
	floor_max_angle = deg_to_rad(48.0)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.28
	_capsule.height = 1.82
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = 0.91
	add_child(_collision)
	_build_visuals()
	_build_footsteps()
	_camera_pivot = Node3D.new()
	_camera_pivot.position.y = 1.42
	add_child(_camera_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = camera_distance
	_spring.margin = 0.16
	_spring.collision_mask = collision_mask
	var camera_shape: SphereShape3D = SphereShape3D.new()
	camera_shape.radius = 0.16
	_spring.shape = camera_shape
	_spring.add_excluded_object(get_rid())
	_camera_pivot.add_child(_spring)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 65.0
	_camera.near = 0.08
	_camera.far = 160.0
	_spring.add_child(_camera)
	_update_camera(1.0)
	spawn_transform = global_transform


func _unhandled_input(event: InputEvent) -> void:
	if movement_locked or _dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -0.95, 0.30)
		_camera_idle = 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var input_axis: Vector2 = Vector2.ZERO
	if not movement_locked:
		input_axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		_read_controller_camera(delta)
	var want_crouch: bool = not movement_locked and Input.is_action_pressed("crouch")
	if want_crouch != _crouched:
		if want_crouch or _can_stand():
			_crouched = want_crouch
			_capsule.height = 1.25 if _crouched else 1.82
			_collision.position.y = _capsule.height * 0.5
	var speed: float = walk_speed
	var running: bool = not movement_locked and Input.is_action_pressed("sprint") and not _crouched
	if running:
		speed = run_speed
	if _crouched:
		speed = 1.05
	var desired: Vector3 = Vector3(input_axis.x, 0.0, input_axis.y).rotated(Vector3.UP, _yaw)
	var target_velocity: Vector3 = desired * speed
	var accel: float = 22.0 if is_on_floor() else 7.0
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if not movement_locked and Input.is_action_just_pressed("jump") and is_on_floor() and not _crouched:
		velocity.y = 7.0
		if _low_ledge_ahead(desired):
			velocity.y = 8.8
			velocity.x += desired.x * 1.7
			velocity.z += desired.z * 1.7
	var falling_speed: float = -velocity.y
	var was_grounded: bool = is_on_floor()
	var approach_speed: float = Vector2(velocity.x, velocity.z).length()
	var before_move: Vector3 = global_position
	move_and_slide()
	var traveled: Vector3 = global_position - before_move
	_motion_speed = Vector2(traveled.x, traveled.z).length() / maxf(delta, 0.0001)
	if not movement_locked and approach_speed > 0.65:
		for index in get_slide_collision_count():
			var collider: Object = get_slide_collision(index).get_collider()
			if collider is Node and collider.has_method("receive_bump"):
				collider.receive_bump(global_position, approach_speed)
	_update_footsteps(delta, Vector2(traveled.x, traveled.z).length(), running)
	if is_on_floor() and not was_grounded and falling_speed > 13.5:
		# A street-level landing from the starting roof is fatal. Ordinary jumps
		# remain below the damage threshold, including the assisted low vault.
		if falling_speed >= 18.0:
			health = 0.0
		else:
			health = maxf(0.0, health - (falling_speed - 13.5) * 12.0)
		if health <= 0.0:
			_die()
	if global_position.y < -12.0:
		_die()
	if _dead:
		return
	if desired.length_squared() > 0.01:
		var facing: float = atan2(-desired.x, -desired.z)
		_visuals.rotation.y = lerp_angle(_visuals.rotation.y, facing, minf(1.0, 12.0 * delta))
		_camera_idle = 0.0
	else:
		_camera_idle += delta
		if _camera_idle > camera_idle_delay and not movement_locked:
			_yaw = lerp_angle(_yaw, _visuals.rotation.y, 1.0 - exp(-1.8 * delta))
			_pitch = lerpf(_pitch, -0.20, 1.0 - exp(-0.6 * delta))
	_animate(delta, _motion_speed, running)
	_update_camera(delta)
	_name_label.text = display_name


func _read_controller_camera(delta: float) -> void:
	var joypads: Array[int] = Input.get_connected_joypads()
	if joypads.is_empty():
		return
	var pad: int = joypads[0]
	var look: Vector2 = Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	if look.length() < 0.18:
		return
	look = look.limit_length(1.0)
	_yaw -= look.x * delta * 2.3
	_pitch = clampf(_pitch - look.y * delta * 1.7, -0.95, 0.30)
	_camera_idle = 0.0


func _update_camera(delta: float) -> void:
	_camera_pivot.rotation.y = _yaw
	_spring.rotation.x = _pitch
	_camera_pivot.position.y = lerpf(_camera_pivot.position.y, 1.07 if _crouched else 1.42, minf(1.0, delta * 8.0))


func _can_stand() -> bool:
	var standing_shape: CapsuleShape3D = CapsuleShape3D.new()
	standing_shape.height = 1.82
	standing_shape.radius = 0.27
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = standing_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.92, 0.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _low_ledge_ahead(direction: Vector3) -> bool:
	if direction.length_squared() < 0.05:
		return false
	var start: Vector3 = global_position + Vector3.UP * 0.55
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start + direction.normalized() * 0.75, collision_mask, [get_rid()])
	var low_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if low_hit.is_empty():
		return false
	query.from += Vector3.UP * 0.85
	query.to += Vector3.UP * 0.85
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	died.emit()


func respawn_at(at: Transform3D) -> void:
	global_transform = at
	velocity = Vector3.ZERO
	health = 100.0
	_dead = false
	_crouched = false
	_capsule.height = 1.82
	_collision.position.y = 0.91
	_yaw = at.basis.get_euler().y
	_visuals.rotation.y = _yaw
	_camera_idle = 0.0
	movement_locked = false
	reset_physics_interpolation()


func get_camera() -> Camera3D:
	return _camera


func set_performing(active: bool, bpm: float = 100.0) -> void:
	_performing = active
	_performance_bpm = clampf(bpm, 40.0, 240.0)
	if is_instance_valid(_visuals) and _visuals.has_method("set_performance_style"):
		_visuals.set_performance_style("dj")


func set_appearance(index: int) -> void:
	appearance_id = clampi(index, 0, 19)
	if is_instance_valid(_visuals):
		_visuals.setup(appearance_id)


func face_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.001 and is_instance_valid(_visuals):
		_visuals.rotation.y = atan2(-direction.x, -direction.z)


func get_character_visual() -> Node3D:
	return _visuals


func _animate(delta: float, horizontal_speed: float, running: bool) -> void:
	if not is_instance_valid(_visuals):
		return
	_visuals.animate(delta, horizontal_speed, running, _crouched, _performing, _performance_bpm)
	_punch_time = maxf(0.0, _punch_time - delta)
	if not is_instance_valid(_punch_modifier) and is_instance_valid(_visuals.get("skeleton")):
		_punch_modifier = load("res://scripts/punch_modifier.gd").new()
		_visuals.skeleton.add_child(_punch_modifier)
	if is_instance_valid(_punch_modifier):
		_punch_modifier.strength = sin((1.0 - _punch_time / 0.36) * PI) if _punch_time > 0.0 else 0.0
	# A soft whole-body lean follows acceleration without scaling the anatomy.
	var target_lean: float = -0.045 if running and horizontal_speed > 1.0 else 0.0
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-5.0 * delta))
	_visuals.rotation.x = _lean


func _build_visuals() -> void:
	var visual_script: Script = load("res://scripts/character_visual.gd")
	_visuals = visual_script.new()
	_visuals.name = "CharacterVisual"
	_visuals.appearance_id = appearance_id
	add_child(_visuals)
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.position.y = 2.18
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 32
	_name_label.pixel_size = 0.004
	_name_label.modulate = Color(0.83, 0.87, 0.82, 0.90)
	_name_label.outline_size = 2
	_name_label.outline_modulate = Color(0.025, 0.035, 0.04, 0.65)
	_name_label.no_depth_test = false
	_name_label.visibility_range_end = 16.0
	add_child(_name_label)


func _build_footsteps() -> void:
	# Original quiet sole/concrete sound, generated once rather than fetched online.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	var samples: int = 1764
	bytes.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1701
	var filtered: float = 0.0
	for index in samples:
		var t: float = float(index) / stream.mix_rate
		filtered = filtered * 0.72 + random.randf_range(-1.0, 1.0) * 0.28
		var signal_value: float = (filtered * 0.45 + sin(t * TAU * 115.0) * 0.35) * exp(-t * 65.0)
		bytes.encode_s16(index * 2, int(clampf(signal_value, -1.0, 1.0) * 24000.0))
	stream.data = bytes
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.stream = stream
	_footsteps.volume_db = -15.0
	_footsteps.max_distance = 12.0
	add_child(_footsteps)


func _update_footsteps(_delta: float, distance: float, running: bool) -> void:
	if movement_locked or not is_on_floor() or _crouched or _performing:
		_footstep_distance = 0.0
		return
	_footstep_distance += distance
	var stride: float = 1.05 if running else 0.72
	if _footstep_distance > stride:
		_footstep_distance = fmod(_footstep_distance, stride)
		_footsteps.pitch_scale = 1.06 if running else 0.94
		_footsteps.play()


func perform_attack() -> void:
	if not movement_locked and not _dead:
		_punch_time = 0.36
