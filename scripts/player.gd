class_name AlbumPlayer
extends CharacterBody3D
## Character feet sit at the node origin. Assets are a textured procedural stand-in.

signal died

@export var display_name: String = "Artista 01"
@export var walk_speed: float = 3.4
@export var run_speed: float = 5.9
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
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_coat: Node3D
var _right_coat: Node3D
var _cloth_speed: float = 0.0
var _cloth_angle: float = 0.0
var _materials: Dictionary = {}
var _performing: bool = false
var _performance_bpm: float = 100.0
var _performance_time: float = 0.0
var _microphone: Node3D


func _ready() -> void:
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
		speed = 1.65
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
	move_and_slide()
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
	_animate(delta, Vector2(velocity.x, velocity.z).length(), running)
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
	if active:
		_performance_time = 0.0
	if is_instance_valid(_microphone):
		_microphone.visible = active


func _animate(delta: float, horizontal_speed: float, running: bool) -> void:
	if _performing:
		_animate_performance(delta)
		return
	var intensity: float = clampf(horizontal_speed / walk_speed, 0.0, 1.5)
	_animation_time += delta * (10.5 if running else 7.5) * minf(intensity, 1.3)
	var stride: float = sin(_animation_time) * 0.50 * intensity
	if not is_on_floor():
		stride = 0.16
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride, minf(delta * 15.0, 1.0))
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride, minf(delta * 15.0, 1.0))
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -stride * 0.8, minf(delta * 12.0, 1.0))
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, stride * 0.8, minf(delta * 12.0, 1.0))
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, 0.0, minf(delta * 8.0, 1.0))
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, 0.0, minf(delta * 8.0, 1.0))
	_visuals.rotation.z = lerpf(_visuals.rotation.z, 0.0, minf(delta * 8.0, 1.0))
	_visuals.scale.y = lerpf(_visuals.scale.y, 0.73 if _crouched else 1.0, minf(delta * 12.0, 1.0))
	_visuals.position.y = absf(sin(_animation_time * 2.0)) * 0.018 * minf(intensity, 1.0)
	# A tiny damped secondary bone substitute, deliberately cheaper than cloth simulation.
	var cloth_target: float = intensity * 0.12 + sin(_animation_time - 0.4) * intensity * 0.08
	_cloth_speed += (cloth_target - _cloth_angle) * 38.0 * delta
	_cloth_speed *= exp(-6.5 * delta)
	_cloth_angle += _cloth_speed * delta
	_left_coat.rotation.x = _cloth_angle
	_right_coat.rotation.x = _cloth_angle * 0.8
	_left_coat.rotation.z = sin(_animation_time * 0.65) * intensity * 0.035
	_right_coat.rotation.z = -_left_coat.rotation.z


func _animate_performance(delta: float) -> void:
	# A deliberately light placeholder for authored singing / DJ / instrument clips.
	# Only visual pivots move: the physical body and its collider remain untouched.
	_performance_time += delta * _performance_bpm / 60.0 * TAU
	var beat: float = sin(_performance_time)
	var half_beat: float = sin(_performance_time * 0.5)
	var blend: float = minf(delta * 9.0, 1.0)
	_visuals.position.y = lerpf(_visuals.position.y, absf(beat) * 0.035, blend)
	_visuals.rotation.z = lerpf(_visuals.rotation.z, half_beat * 0.025, blend)
	_visuals.scale.y = lerpf(_visuals.scale.y, 1.0, blend)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 1.95 + beat * 0.08, blend)
	_right_arm.rotation.z = lerpf(_right_arm.rotation.z, -0.13, blend)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.38 + half_beat * 0.34, blend)
	_left_arm.rotation.z = lerpf(_left_arm.rotation.z, 0.20 + beat * 0.10, blend)
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, half_beat * 0.075, blend)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -half_beat * 0.075, blend)
	_left_coat.rotation.x = lerpf(_left_coat.rotation.x, 0.04 + beat * 0.035, blend)
	_right_coat.rotation.x = lerpf(_right_coat.rotation.x, 0.04 - beat * 0.035, blend)
	_left_coat.rotation.z = lerpf(_left_coat.rotation.z, half_beat * 0.025, blend)
	_right_coat.rotation.z = -_left_coat.rotation.z


func _build_visuals() -> void:
	_materials["coat"] = _worn_material(Color(0.075, 0.095, 0.105), 23, 0.93)
	_materials["pants"] = _worn_material(Color(0.10, 0.12, 0.14), 47, 0.88)
	_materials["shirt"] = _worn_material(Color(0.48, 0.45, 0.37), 17, 0.85)
	_materials["skin"] = _worn_material(Color(0.53, 0.36, 0.26), 71, 0.78)
	_materials["hair"] = _worn_material(Color(0.045, 0.035, 0.03), 83, 0.95)
	_materials["shoes"] = _worn_material(Color(0.045, 0.04, 0.035), 91, 0.67)
	_visuals = Node3D.new()
	_visuals.name = "CharacterVisual"
	add_child(_visuals)
	_box(_visuals, Vector3(0.40, 0.49, 0.24), Vector3(0.0, 1.23, 0.0), _materials["coat"])
	_box(_visuals, Vector3(0.21, 0.38, 0.025), Vector3(0.0, 1.27, -0.132), _materials["shirt"])
	_box(_visuals, Vector3(0.30, 0.17, 0.22), Vector3(0.0, 0.96, 0.0), _materials["pants"])
	_capsule_mesh(_visuals, 0.065, 0.16, Vector3(0.0, 1.53, 0.0), _materials["skin"])
	var head: MeshInstance3D = _capsule_mesh(_visuals, 0.145, 0.33, Vector3(0.0, 1.74, -0.005), _materials["skin"])
	head.scale.z = 0.88
	var hair: MeshInstance3D = _capsule_mesh(_visuals, 0.148, 0.19, Vector3(0.0, 1.84, 0.018), _materials["hair"])
	hair.scale.z = 0.85
	_box(_visuals, Vector3(0.045, 0.065, 0.055), Vector3(0.0, 1.74, -0.143), _materials["skin"])
	# A subtle dark brow/eye line keeps the head legible at gameplay distance.
	_box(_visuals, Vector3(0.19, 0.021, 0.015), Vector3(0.0, 1.78, -0.135), _materials["hair"])
	_left_arm = _limb_pivot(_visuals, Vector3(-0.26, 1.43, 0.0))
	_right_arm = _limb_pivot(_visuals, Vector3(0.26, 1.43, 0.0))
	for arm: Node3D in [_left_arm, _right_arm]:
		_capsule_mesh(arm, 0.075, 0.33, Vector3(0.0, -0.13, 0.0), _materials["coat"])
		_capsule_mesh(arm, 0.062, 0.29, Vector3(0.0, -0.39, -0.015), _materials["coat"])
		_capsule_mesh(arm, 0.055, 0.14, Vector3(0.0, -0.58, -0.025), _materials["skin"])
	_microphone = _limb_pivot(_right_arm, Vector3(0.0, -0.58, -0.04))
	_microphone.rotation.x = -1.95
	_microphone.visible = _performing
	_capsule_mesh(_microphone, 0.022, 0.16, Vector3(0.0, 0.03, 0.0), _materials["shoes"])
	_capsule_mesh(_microphone, 0.038, 0.078, Vector3(0.0, 0.13, 0.0), _materials["shirt"])
	_left_leg = _limb_pivot(_visuals, Vector3(-0.105, 0.94, 0.0))
	_right_leg = _limb_pivot(_visuals, Vector3(0.105, 0.94, 0.0))
	for leg: Node3D in [_left_leg, _right_leg]:
		_capsule_mesh(leg, 0.089, 0.46, Vector3(0.0, -0.21, 0.0), _materials["pants"])
		_capsule_mesh(leg, 0.073, 0.43, Vector3(0.0, -0.61, 0.0), _materials["pants"])
		_box(leg, Vector3(0.15, 0.12, 0.29), Vector3(0.0, -0.87, -0.06), _materials["shoes"])
	_left_coat = _limb_pivot(_visuals, Vector3(-0.11, 1.02, 0.05))
	_right_coat = _limb_pivot(_visuals, Vector3(0.11, 1.02, 0.05))
	for flap: Node3D in [_left_coat, _right_coat]:
		_box(flap, Vector3(0.21, 0.40, 0.18), Vector3(0.0, -0.19, 0.0), _materials["coat"])
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.position.y = 2.18
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 40
	_name_label.pixel_size = 0.005
	_name_label.modulate = Color(0.83, 0.87, 0.82, 0.90)
	_name_label.outline_size = 2
	_name_label.outline_modulate = Color(0.025, 0.035, 0.04, 0.65)
	_name_label.no_depth_test = false
	_name_label.visibility_range_end = 16.0
	add_child(_name_label)


func _limb_pivot(parent: Node3D, at: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


func _capsule_mesh(parent: Node3D, radius: float, height: float, at: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 5
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item


func _worn_material(base_color: Color, seed_value: int, roughness_value: float) -> StandardMaterial3D:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	for y: int in range(64):
		for x: int in range(64):
			var grain: float = random.randf_range(0.76, 1.18)
			var weave: float = 0.94 if (x + y) % 3 == 0 else 1.0
			var worn: float = 1.18 if x % 29 == 0 else 1.0
			image.set_pixel(x, y, Color(base_color.r * grain * weave * worn, base_color.g * grain * weave * worn, base_color.b * grain * weave * worn))
	image.generate_mipmaps()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.roughness = roughness_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat
