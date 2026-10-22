extends SceneTree
## Walk the same patrons through the authored Pink Street disco, at a rotated,
## elevated position. This catches legacy world-coordinate assumptions.
const ARCHITECTURE = preload("res://scripts/lisbon_architecture.gd")
const CLUB = preload("res://scripts/club_crowd.gd")
var checks := 0
var failures := 0
var club: AlbumClubCrowd
var venue: Dictionary
var identities: Array[int] = []
var crossed_out: Dictionary = {}
var crossed_in: Dictionary = {}
var previous: Array[Vector3] = []
var greatest_step := 0.0

func _initialize() -> void:
	Engine.max_fps = 0
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("VENUE CROWD: " + message)

func _run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Venue crowd test timed out"); quit(1))
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 0.4, 90)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector3(75, 7.8, 110)
	world.add_child(floor_body)
	var architecture: RefCounted = ARCHITECTURE.new()
	var district: Dictionary = architecture.build_nightlife(world, world, "pink_street", Vector3(75, 8, 110), PI)
	venue = district.performance
	club = CLUB.new()
	club.configure_layout(venue)
	world.add_child(club)
	club.set_physics_process(false)
	club._next_bar_visit = INF
	club.set_audience(100.0)
	await _step(60)
	check(club.patrons.size() == 8, "eight persistent bodies inhabit the actual disco")
	for patron in club.patrons:
		identities.append(patron.get_instance_id())
		previous.append(patron.global_position)
		check(absf(patron.global_position.y - 8.0) < 0.15, "patrons stand on the venue floor rather than legacy ground")
	var dance_phases: Dictionary = {}
	var shared_tempo := true
	for entry in club._entries:
		var animation: AnimationPlayer = entry.visual.animation_player
		dance_phases[roundi(fposmod(animation.current_animation_position / animation.current_animation_length, 1.0) * 1000.0)] = true
		shared_tempo = shared_tempo and is_equal_approx(animation.speed_scale, club._bpm / 100.0)
	check(dance_phases.size() == 8, "all eight dancers have distinct animation phases rather than synchronised poses")
	check(shared_tempo, "different dance phases retain the same musical tempo")
	var first_animation: AnimationPlayer = club._entries[0].visual.animation_player
	first_animation.advance(0.137)
	var advanced_position := first_animation.current_animation_position
	club._animate(club._entries[0], 0.0)
	check(is_equal_approx(first_animation.current_animation_position, advanced_position), "normal dance updates never reset the seeded phase")
	club.set_audience(0.0)
	check(club.get_engaged_count() == 8, "requesting zero audience leaves people present during their reaction")
	await _step(3300)
	var states := club.get_patron_states()
	for entry in states:
		check(entry.state == "outside" and entry.has_exited, "patron %d walks all the way out: %s %s" % [entry.id, entry.state, str(entry.position)])
		check(crossed_out.has(entry.id), "patron %d passes the real entrance going out" % entry.id)
	check(club.get_engaged_count() == 0, "the physical floor empties after departures")
	club.set_audience(100.0)
	check(club.get_engaged_count() == 0, "audience recovery does not instantly refill the room")
	await _step(3300)
	for entry in club.get_patron_states():
		check(entry.has_returned and entry.state == "dancing", "patron %d returns to the dance floor: %s %s" % [entry.id, entry.state, str(entry.position)])
		check(crossed_in.has(entry.id), "patron %d passes the actual doorway coming back" % entry.id)
		check(club.patrons[entry.id].get_instance_id() == identities[entry.id] and entry.visible, "patron %d keeps its body and visibility across the whole journey" % entry.id)
	check(club.get_engaged_count() == 8, "all eight patrons physically return")
	check(greatest_step < 0.12, "movement remains continuous without teleporting")
	club.set_performance(true, 108.0)
	club._next_bar_visit = club._time + 0.1
	await _step(120)
	var visitor_id := -1
	for entry in club.get_patron_states():
		if entry.state == "visiting_bar": visitor_id = entry.id
	check(visitor_id >= 0, "a dancer walks to the venue's bar during the performance")
	club._next_bar_visit = INF
	await _step(450)
	if visitor_id >= 0:
		var state: Dictionary = club.get_patron_states()[visitor_id]
		check(state.state in ["at_bar", "returning_dance", "dancing"], "bar visitor reaches the public side of the solid counter: " + str(state))
	await _step(900)
	if visitor_id >= 0:
		check(club.get_patron_states()[visitor_id].state == "dancing", "bar visitor returns to its original dance position")
	world.queue_free()
	await process_frame
	print("VENUE CROWD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _step(frames: int) -> void:
	var door: Vector3 = venue.entry_door
	var normal: Vector3 = (venue.entry_outside - venue.entry_inside).normalized()
	for frame in frames:
		await physics_frame
		club._physics_process(1.0 / 60.0)
		if previous.size() != club.patrons.size(): continue
		for index in club.patrons.size():
			var at := club.patrons[index].global_position
			greatest_step = maxf(greatest_step, previous[index].distance_to(at))
			var old_side := (previous[index] - door).dot(normal)
			var side := (at - door).dot(normal)
			var along := at - door - normal * side
			along.y = 0.0
			if along.length() < 0.8:
				if old_side < 0.0 and side >= 0.0: crossed_out[index] = true
				if old_side > 0.0 and side <= 0.0: crossed_in[index] = true
			previous[index] = at
