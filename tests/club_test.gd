extends SceneTree
## Organic club flow: patrons are persistent bodies, not attendance visibility toggles.
const CLUB = preload("res://scripts/club_crowd.gd")
var checks := 0
var failures := 0
var club: AlbumClubCrowd
var door: StaticBody3D
var original_ids: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CLUB FAIL: " + message)

func _run() -> void:
	_build_floor_and_facade()
	club = CLUB.new()
	root.add_child(club)
	club.set_physics_process(false)
	club._next_bar_visit = INF
	await physics_frame
	check(club.patrons.size() == 8, "eight persistent patrons are created")
	check(club.get_target_count() == 6 and club.get_engaged_count() == 8, "target and physical attendance differ while departures are pending")
	var before: Array[Vector3] = []
	for patron in club.patrons:
		original_ids.append(patron.get_instance_id())
		before.append(patron.position)
	club.set_audience(0.0)
	check(club.get_target_count() == 0, "zero audience requests departure")
	check(club.get_engaged_count() == 8, "zero audience never immediately removes dancing patrons")
	for index in 8:
		check(club.patrons[index].visible and club.patrons[index].position == before[index], "patron%d does not disappear or teleport on audience change" % index)
	await _step(20)
	check(club.patrons[0].position.distance_to(before[0]) < 0.5, "departure starts after a human reaction delay")
	await _step(1500)
	var closed_states := club.get_patron_states()
	var waiting := 0
	for entry in closed_states:
		check(entry.position.z < -6.0 and entry.visible, "closed entrance keeps patron%d inside and visible" % entry.id)
		if entry.state == "waiting_door":
			waiting += 1
	check(waiting > 0, "patrons form a waiting group at a closed door")
	club.set_audience(100.0)
	await _step(900)
	check(club.get_engaged_count() == 8, "audience recovery can cancel departure even while door is closed")
	club.set_door_open(true)
	door.collision_layer = 0
	door.collision_mask = 0
	club.set_audience(0.0)
	var previous: Array[Vector3] = []
	for p in club.patrons:
		previous.append(p.position)
	var max_frame_motion := 0.0
	var passed_real_door := false
	var walking_seen := false
	for tick in 2700:
		await physics_frame
		club._physics_process(1.0/60.0)
		for index in 8:
			var patron: CharacterBody3D = club.patrons[index]
			max_frame_motion = maxf(max_frame_motion, patron.position.distance_to(previous[index]))
			if previous[index].z < -6.0 and patron.position.z >= -6.0:
				passed_real_door = passed_real_door or absf(patron.position.x + 13.0) < 1.3
			previous[index] = patron.position
		for entry in club.get_patron_states():
			walking_seen = walking_seen or entry.speed > 0.1
	check(max_frame_motion < 0.12, "departures move continuously at walking speed with no frame teleports")
	check(passed_real_door, "departures actually cross the physical entrance")
	check(walking_seen, "walking speed is reported for locomotion animation")
	var outside_count := 0
	for entry in club.get_patron_states():
		if entry.state == "outside" and entry.has_exited:
			outside_count += 1
	check(outside_count == 8, "all patrons reach the outside route when enthusiasm reaches zero")
	check(club.get_engaged_count() == 0, "physical dance floor eventually empties")
	for index in 8:
		check(club.patrons[index].get_instance_id() == original_ids[index] and club.patrons[index].visible, "outside patron%d remains the same visible actor" % index)
	club.set_audience(100.0)
	check(club.get_engaged_count() == 0, "recovering audience cannot instantly repopulate the dance floor")
	await _step(2700)
	check(club.get_engaged_count() == 8, "recovered patrons walk back to the dance floor")
	for entry in club.get_patron_states():
		check(entry.has_returned and entry.position.z < -10.0, "patron%d returns through the entrance to the inside" % entry.id)
	check(club.patrons.size() == 8, "repeated audience changes do not allocate extra people")
	club.set_performance(true, 120.0)
	club._next_bar_visit = club._time + 0.1
	await _step(180)
	var visiting := false
	for entry in club.get_patron_states():
		visiting = visiting or entry.state == "visiting_bar"
	check(visiting, "club patrons continue to circulate during performances")
	club.queue_free()
	await process_frame
	print("CLUB: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _step(frames: int) -> void:
	for frame in frames:
		await physics_frame
		club._physics_process(1.0/60.0)

func _build_floor_and_facade() -> void:
	_box(Vector3(-14, -0.5, -10), Vector3(80,1,80))
	_box(Vector3(-19.75, 2, -6), Vector3(10.5,4,0.3))
	_box(Vector3(-9.25, 2, -6), Vector3(4.5,4,0.3))
	door = _box(Vector3(-13, 1.55, -6), Vector3(3,3.1,0.3))

func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body
