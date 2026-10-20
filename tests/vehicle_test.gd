extends SceneTree
const MANAGER = preload("res://scripts/vehicle_manager.gd")
const VEHICLE = preload("res://scripts/vehicle.gd")
var checks := 0
var failures := 0
var manager: Node3D
var player: TestPlayer
var crashes := 0

class TestVisual extends Node3D:
	var pose := ""
	var animations := 0
	func set_vehicle_pose(kind: String) -> void: pose = kind
	func animate(_delta: float,_speed: float,_run: bool,_crouch: bool,_perform: bool,_bpm: float) -> void: animations += 1
	func react(_kind: String) -> void: pass

class TestPlayer extends CharacterBody3D:
	var movement_locked := false
	var _visuals: TestVisual
	var _spring: SpringArm3D
	var _footsteps: AudioStreamPlayer3D
	var _yaw := 0.0
	var _pitch := 0.0
	var camera_updates := 0
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 3
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.28
		capsule.height = 1.82
		collision.shape = capsule
		collision.position.y = 0.91
		add_child(collision)
		_visuals = TestVisual.new()
		add_child(_visuals)
		_spring = SpringArm3D.new()
		add_child(_spring)
	func _physics_process(delta: float) -> void:
		if movement_locked: return
		velocity.y = -0.5 if is_on_floor() else velocity.y - delta*20
		move_and_slide()
	func _update_camera(_delta: float) -> void: camera_updates += 1

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("VEHICLE FAIL: "+message)

func _run() -> void:
	_box(Vector3(0,-0.5,0),Vector3(120,1,120))
	manager = MANAGER.new()
	root.add_child(manager)
	player = TestPlayer.new()
	root.add_child(player)
	manager.set_player(player)
	manager.rider_crashed.connect(func(_force: float): crashes += 1)
	await _step(12)
	check(manager.vehicles.size() == 4,"all four vehicle types exist")
	var kinds: Array[String] = []
	for vehicle in manager.vehicles: kinds.append(vehicle.type)
	check(kinds.has("car") and kinds.has("motorbike") and kinds.has("bicycle") and kinds.has("scooter"),"car, motorcycle, bicycle and scooter available")
	var player_id := player.get_instance_id()
	var visual_id := player._visuals.get_instance_id()
	for vehicle in manager.vehicles:
		await _exercise_vehicle(vehicle,player_id,visual_id)
	var custom_parent := Node3D.new()
	root.add_child(custom_parent)
	var custom := VEHICLE.new()
	custom.configure("motorcycle")
	custom.position = Vector3(42,0.4,30)
	custom_parent.add_child(custom)
	manager.register_vehicle(custom)
	manager.register_vehicle(custom)
	check(custom.type == "motorbike" and manager.vehicles.size() == 5,"editor motorcycle alias and duplicate-safe registration")
	check(custom.get_parent() == custom_parent,"registered editor vehicle retains its parent")
	var car: Node3D = manager.vehicles[0]
	car.global_position = Vector3(-20,0.1,0)
	car.rotation.y = 0
	await _step(12)
	player.global_position = car.get_entry_position()+Vector3(-0.2,0.1,0)
	check(manager.interact(),"car can be entered for blocked-exit test")
	await _step(100)
	var left := _box(Vector3(-21.85,1.1,-0.2),Vector3(0.9,2.2,2.0))
	var right := _box(Vector3(-18.15,1.1,-0.2),Vector3(0.9,2.2,2.0))
	await _step(3)
	check(not manager.interact() and manager.state == "driving","exit is rejected when both sides are blocked")
	left.free()
	right.free()
	await _step(2)
	manager.force_exit()
	check(not manager.is_driving() and player.collision_layer == 1 and player.is_physics_processing(),"force_exit restores original player physics and collisions")
	var bike: Node3D = manager.vehicles[2]
	bike.global_position = Vector3(-20,0.1,10)
	bike.rotation.y = 0
	await _step(12)
	player.global_position = bike.get_entry_position()+Vector3(-0.2,0.1,0)
	check(manager.interact(),"bicycle can be entered before crash")
	await _step(100)
	var wall := _box(Vector3(-20,1.4,8),Vector3(4,2.8,0.2))
	bike.forward_speed = 11.0
	await _step(12)
	check(crashes == 1 and not manager.is_driving(),"strong frontal bicycle impact ejects rider and emits crash once")
	check(player.collision_layer == 1 and player.get_instance_id() == player_id,"crash restores same collidable player body")
	wall.free()
	await _step(6)
	bike.global_position = Vector3(-20,0.1,20)
	bike.forward_speed = 0
	player.global_position = bike.get_entry_position()+Vector3(-0.2,0.1,0)
	player.velocity = Vector3.ZERO
	check(manager.interact(),"bicycle can be re-entered after crash")
	await _step(100)
	wall = _box(Vector3(-20,1.4,18),Vector3(4,2.8,0.2))
	bike.forward_speed = 3.0
	await _step(30)
	check(crashes == 1 and manager.state == "driving","mild frontal impact does not eject the rider")
	manager.force_exit()
	wall.free()
	manager.set_controls_enabled(false)
	player.global_position = manager.vehicles[3].get_entry_position()
	check(not manager.interact(),"menus/performance can disable vehicle interaction")
	manager.queue_free()
	custom_parent.queue_free()
	player.queue_free()
	await process_frame
	print("VEHICLES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _exercise_vehicle(vehicle: Node3D, player_id: int, visual_id: int) -> void:
	vehicle.global_position = Vector3(-20,0.1,0)
	vehicle.rotation.y = 0.0
	vehicle.forward_speed = 0.0
	await _step(10)
	player.global_position = vehicle.get_entry_position()+Vector3(-0.2,0.1,0.1)
	player.velocity = Vector3.ZERO
	check(manager.find_nearest(player.global_position) == vehicle,"nearest interaction finds "+vehicle.type)
	check(manager.interact() and manager.is_transitioning(),"entry animation begins for "+vehicle.type)
	check(player.movement_locked and not player.is_physics_processing() and player.collision_layer == 0,"entry locks player locomotion and avoids self collision "+vehicle.type)
	var start := player.global_position
	await _step(10)
	check(player.global_position.distance_to(start) > 0.01,"entry visibly moves existing avatar "+vehicle.type)
	await _step(100)
	check(manager.state == "driving" and manager.active_vehicle == vehicle,"entry reaches driving state "+vehicle.type)
	check(player.get_instance_id() == player_id and player._visuals.get_instance_id() == visual_id,"rider uses same avatar body and model "+vehicle.type)
	check(player.global_position.distance_to(vehicle.get_seat_position()) < 0.1 and player._visuals.pose == vehicle.type,"rider follows vehicle seat with riding pose "+vehicle.type)
	check(player.camera_updates > 0,"same avatar camera continues updating "+vehicle.type)
	var before: Vector3 = vehicle.global_position
	Input.action_press("move_forward")
	await _step(60)
	check(vehicle.global_position.distance_to(before) > 0.5 and vehicle.forward_speed > 2.0,"vehicle responds to acceleration "+vehicle.type)
	check(not manager.interact(),"high-speed exit is rejected "+vehicle.type)
	Input.action_release("move_forward")
	Input.action_press("vehicle_brake")
	await _step(40)
	Input.action_release("vehicle_brake")
	check(absf(vehicle.forward_speed) < 0.2,"brake stops "+vehicle.type)
	check(manager.interact() and manager.state == "exiting","low-speed exit begins "+vehicle.type)
	await _step(70)
	check(manager.state == "on_foot" and player.collision_layer == 1 and player.collision_mask == 3,"exit restores player collisions "+vehicle.type)
	check(player.is_physics_processing() and not player.movement_locked and player._visuals.pose.is_empty(),"exit restores locomotion and normal pose "+vehicle.type)
	vehicle.global_position = Vector3(40+manager.vehicles.find(vehicle)*3,0.1,30)
	vehicle.forward_speed = 0

func _step(frames: int) -> void:
	for frame in frames: await physics_frame

func _box(position: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
	return body
