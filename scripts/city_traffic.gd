class_name LisbonTraffic
extends Node3D
## Persistent cars circulate on district road loops; a player can take a stopped car.
const CAR = preload("res://scripts/vehicle.gd")
class DriverCar extends "res://scripts/vehicle.gd":
	var route := PackedVector3Array()
	var next_point := 1
	var cruising_speed := 5.0
	var stop_time := 0.0
	var driver: Node3D
	func _ready() -> void:
		super._ready()
		driver = load("res://scripts/character_visual.gd").new()
		driver.appearance_id = 7
		driver.position = seat_offset
		visual.add_child(driver)
		driver.set_vehicle_pose("car")
		driver.animate(0.01,0,false,false,false,100)
	func _physics_process(delta: float) -> void:
		if get_meta("player_owned",false):
			if is_instance_valid(driver): driver.hide()
			super._physics_process(delta)
			return
		if not visible or route.size()<2: return
		var offset := route[next_point]-global_position
		offset.y = 0
		if offset.length()<2.1:
			next_point = (next_point+1)%route.size()
			if next_point%6==0: stop_time = 1.8
			offset = route[next_point]-global_position; offset.y = 0
		stop_time = maxf(0,stop_time-delta)
		var heading := offset.normalized()
		var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.7,global_position+Vector3.UP*0.7-global_basis.z*4.5,3,[get_rid()])
		var blocked := not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var target_speed := 0.0 if blocked or stop_time>0 else cruising_speed
		forward_speed = move_toward(forward_speed,target_speed,delta*(7.0 if blocked else 2.8))
		rotation.y = lerp_angle(rotation.y,atan2(-heading.x,-heading.z),minf(1,delta*1.5))
		super._physics_process(delta)
		for light in _headlights: light.show()
var cars: Array[CharacterBody3D] = []
var viewer: Node3D
var budget := 5
var _timer := 0.0
func configure(routes: Array, count := 8) -> void:
	if not cars.is_empty() or routes.is_empty(): return
	for index in count:
		var points: Variant = routes[index%routes.size()]
		var path := PackedVector3Array()
		for p in points:
			if p is Vector3: path.append(p)
			elif p is Array: path.append(Vector3(p[0],p[1],p[2]) if p.size()==3 else Vector3(p[0],0.1,p[1]))
		if path.size()<3: continue
		var car := DriverCar.new()
		car.route = path
		var slot := posmod(index*3,path.size())
		car.next_point = (slot+1)%path.size()
		car.position = path[slot]+Vector3.UP*0.1
		var direction := path[car.next_point]-path[slot]
		car.rotation.y = atan2(-direction.x,-direction.z)
		car.cruising_speed = 4.2+float(index%3)*0.65
		car.set_meta("editor_stable_id","base/traffic/%02d"%index)
		car.name = "Transito_%02d"%index
		add_child(car)
		cars.append(car)
	_refresh()
func set_viewer(actor: Node3D) -> void:
	viewer = actor
	_refresh()
func set_quality_level(index: int) -> void:
	budget = [3,5,8][clampi(index,0,2)]
	_refresh()
func _process(delta: float) -> void:
	_timer -= delta
	if _timer<=0:
		_timer = 0.5
		_refresh()
func _refresh() -> void:
	if not is_instance_valid(viewer): return
	var nearby: Array[CharacterBody3D] = []
	for car in cars:
		if car.get_meta("player_owned",false): continue
		if car.get_meta("editor_hidden",false):
			car.hide(); car.collision_layer = 0; car.set_physics_process(false)
			continue
		if car.global_position.distance_to(viewer.global_position)<150: nearby.append(car)
	nearby.sort_custom(func(a: Node3D,b: Node3D):return a.global_position.distance_squared_to(viewer.global_position)<b.global_position.distance_squared_to(viewer.global_position))
	for car in cars:
		if car.get_meta("player_owned",false) or car.get_meta("editor_hidden",false): continue
		var active := nearby.find(car)>=0 and nearby.find(car)<budget
		car.visible = active
		car.collision_layer = 1 if active else 0
		car.set_physics_process(active)
