extends SceneTree
## Traverse actual kerbs/ramps and walls, then inspect impact deformation and rider recovery.
const VEHICLE = preload("res://scripts/vehicle.gd")
const MANAGER = preload("res://scripts/vehicle_manager.gd")
var checks := 0
var failures := 0
var car: CharacterBody3D
var manager: Node3D
var world: Node3D
var camera: Camera3D
var screenshots := false
class Rider extends CharacterBody3D:
	var movement_locked := false
	var _visuals: Node3D
	var _spring: SpringArm3D
	var _yaw := 0.0
	var _pitch := 0.0
	func _ready() -> void:
		_visuals = Node3D.new(); add_child(_visuals)
		_spring = SpringArm3D.new(); add_child(_spring)
	func _update_camera(_delta: float) -> void: pass
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("VEHICLE TERRAIN: "+message)
func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	world = Node3D.new(); root.add_child(world)
	_box(Vector3(0,-0.5,0),Vector3(200,1,200))
	_bindings()
	manager = MANAGER.new(); world.add_child(manager)
	manager.set_physics_process(false)
	for vehicle in manager.vehicles:
		vehicle.set_physics_process(false)
		vehicle.global_position = Vector3(60+manager.vehicles.find(vehicle)*4,0.1,40)
	for kind in ["car","motorbike","bicycle","scooter"]:
		await _test_kerb(kind)
	await _test_damage_and_slope()
	await _test_manager_lifecycle()
	for node in world.get_children():
		if node is AudioStreamPlayer3D: node.stop()
	world.queue_free(); await process_frame
	print("VEHICLE TERRAIN: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _test_kerb(kind: String) -> void:
	var vehicle: CharacterBody3D = VEHICLE.new()
	vehicle.configure(kind); vehicle.position = Vector3(0,0.2,5); world.add_child(vehicle)
	vehicle.set_physics_process(false); vehicle.controlled = true
	var rise := 0.18 if kind=="car" else 0.14 if kind=="motorbike" else 0.12 if kind=="bicycle" else 0.08
	var kerb := _box(Vector3(0,rise*0.5,-4),Vector3(8,rise,8))
	await _tick(vehicle,18)
	Input.action_press("move_forward")
	var highest := 0.0; var stepped := false
	for frame in 300:
		await physics_frame
		vehicle._physics_process(1.0/60.0)
		highest = maxf(highest,vehicle.global_position.y)
		stepped = stepped or vehicle.last_step_height>0.01
		if vehicle.global_position.z < -2: break
	Input.action_release("move_forward")
	check(vehicle.global_position.z < -2,kind+" crosses a real "+str(rise)+"m kerb without teleporting forward")
	check(stepped and highest>rise-0.03 and highest<rise+0.1,kind+" uses bounded step height")
	check(vehicle.damage_level==0.0,kind+" does not receive crash damage from ordinary kerb")
	check(vehicle._wheel_angle<0,kind+" wheel rotation agrees with forward rolling direction")
	vehicle.position = Vector3(14,0.2,5); vehicle.rotation = Vector3.ZERO; vehicle.velocity = Vector3.ZERO; vehicle.forward_speed = 0
	var wall := _box(Vector3(14,1.2,-0.2),Vector3(6,2.4,0.4))
	await _tick(vehicle,15)
	Input.action_press("move_forward")
	await _tick(vehicle,200)
	Input.action_release("move_forward")
	check(vehicle.global_position.z > 0.65,kind+" cannot climb a full-height wall")
	check(vehicle.global_position.y<0.2,kind+" stays grounded at a wall")
	wall.free()
	vehicle.position = Vector3(28,0.2,5); vehicle.velocity=Vector3.ZERO; vehicle.forward_speed=0
	var high_kerb := _box(Vector3(28,0.20,-4),Vector3(6,0.40,8))
	await _tick(vehicle,15)
	Input.action_press("move_forward"); await _tick(vehicle,160); Input.action_release("move_forward")
	check(vehicle.global_position.z>0.65 and vehicle.global_position.y<0.20,kind+" cannot step up an oversized 0.4m kerb")
	kerb.free(); high_kerb.free(); vehicle.queue_free(); await process_frame
func _test_damage_and_slope() -> void:
	car = VEHICLE.new(); car.position=Vector3(0,0.1,15); world.add_child(car); car.set_physics_process(false)
	await _tick(car,15)
	car.controlled = true
	var obstacle := _box(Vector3(0,1.4,7),Vector3(6,2.8,0.3))
	var original: PackedVector3Array = car._deformable[0].node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	car.forward_speed = 13
	await _tick(car,75)
	var damaged: PackedVector3Array = car._deformable[0].node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(car.damage_zones.x>0.4 and car.damage_level>0.2,"physical frontal impact accumulates significant front damage")
	check(original!=damaged,"physical impact deforms actual body mesh vertices")
	check(car._cracks.visible,"strong impact reveals windshield fractures")
	check(not car._front_lamps[0].material_override.emission_enabled,"strong impact breaks a headlamp")
	check(car._damage_parts[0].node.position!=car._damage_parts[0].position,"bumper is visibly pushed back and bent")
	check(car.forward_speed<1,"wall impact prevents continued acceleration through it")
	obstacle.free()
	await _native_capture()
	var ramp := _box(Vector3(-20,0.8,0),Vector3(7,0.4,12))
	ramp.rotation.x = 0.16
	car.global_position=Vector3(-20,1.8,0); car.forward_speed=0; car.damage_level=0; car.damage_zones=Vector4.ZERO
	await _tick(car,65)
	check(absf(car.visual.rotation.x)>0.07,"vehicle body pitches to match inclined wheel contacts")
	check(car._wheel_ground_valid.count(true)==4,"all car wheels query the slope surface")
	ramp.free(); car.queue_free(); await process_frame
func _test_manager_lifecycle() -> void:
	var rider := Rider.new(); world.add_child(rider); manager.set_player(rider)
	var vehicle: Node3D = manager.vehicles[0]
	vehicle.position = Vector3(0,0.1,30)
	await _tick(vehicle,15)
	rider.global_position = vehicle.get_entry_position()
	vehicle.hide()
	check(manager.find_nearest(rider.global_position)==null,"creator-hidden vehicle is excluded from interaction")
	check(not manager._begin_enter(vehicle),"direct entry also rejects hidden vehicle")
	vehicle.show(); vehicle.collision_layer=0
	check(manager.find_nearest(rider.global_position)==null,"noncollidable deleted vehicle is excluded")
	vehicle.collision_layer=1
	check(manager.interact(),"normal vehicle still enters after lifecycle checks")
	manager._physics_process(3.0)
	var loss := []
	manager.fell_out_of_world.connect(func(at: Vector3): loss.append(at))
	var recovered_from := vehicle.global_transform
	vehicle.global_position.y = -20
	vehicle._physics_process(1.0/60.0)
	check(loss.size()==1 and not manager.is_driving(),"falling vehicle emits one rider loss and restores rider state")
	check(vehicle.global_position.y>0 and vehicle.global_position.distance_to(recovered_from.origin)<0.3,"vehicle is recovered to its last grounded position")
	check(not rider.movement_locked and rider.collision_layer==1,"rider collision/control restored before normal death integration")
	rider.queue_free(); await process_frame
func _tick(vehicle: Node3D, frames: int) -> void:
	for frame in frames:
		await physics_frame
		vehicle._physics_process(1.0/60.0)
func _bindings() -> void:
	for action in ["move_forward","move_back","move_left","move_right","vehicle_brake"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
func _box(at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position=at
	var collider := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=dimensions
	collider.shape=shape; body.add_child(collider); world.add_child(body)
	return body
func _native_capture() -> void:
	if not screenshots or DisplayServer.get_name()=="headless": return
	var env := WorldEnvironment.new(); var resource := Environment.new()
	resource.background_mode=Environment.BG_COLOR; resource.background_color=Color("242b31")
	resource.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; resource.ambient_light_color=Color("c9c7b7"); resource.ambient_light_energy=0.65
	env.environment=resource; world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-35,-25,0); sun.light_energy=0.8; world.add_child(sun)
	camera = Camera3D.new(); camera.position=car.position+Vector3(-3.3,1.9,-3.2); world.add_child(camera); camera.look_at(car.position+Vector3(0,0.8,0)); camera.make_current()
	var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(40,40)
	floor_mesh.mesh=plane; floor_mesh.position=Vector3(0,0.002,10)
	var asphalt := StandardMaterial3D.new(); asphalt.albedo_texture=load("res://assets/textures/city_asphalt.png"); asphalt.uv1_scale=Vector3(8,8,8); asphalt.roughness=0.85
	floor_mesh.material_override=asphalt; world.add_child(floor_mesh)
	var impact_zones: Vector4 = car.damage_zones; var level: float = car.damage_level
	car.damage_zones=Vector4.ZERO; car.damage_level=0; car._rebuild_damage(); car._animate_vehicle(0,false)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var intact := root.get_texture().get_image()
	check(intact.save_png("/tmp/album-vehicle-intact.png")==OK,"native intact-car screenshot")
	car.damage_zones=impact_zones; car.damage_level=level; car._rebuild_damage(); car._animate_vehicle(0,false)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var damaged := root.get_texture().get_image()
	check(damaged.save_png("/tmp/album-vehicle-damage.png")==OK,"native damaged-car screenshot")
	check(intact.get_data()!=damaged.get_data(),"actual rendered car changes after impact")
