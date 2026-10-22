class_name AlbumClubCrowd
extends Node3D
## Persistent club patrons. Audience changes affect destinations, never visibility.
## The path through the real entrance is shared by arrivals, departures and recovery.

const PATRON_COUNT := 8
const VISUAL_SCRIPT := "res://scripts/character_visual.gd"
const APPEARANCES := [2, 11, 4, 15, 6, 17, 8, 19]
const ENTRY_INSIDE := Vector3(-13.0, 0.15, -7.35)
const ENTRY_OUTSIDE := Vector3(-13.0, 0.15, -4.0)
const STREET_CORNER := Vector3(-24.0, 0.15, -3.4)

var patrons: Array[CharacterBody3D] = []
var _entries: Array[Dictionary] = []
var _target_count := 6
var _door_open := false
var _performance := false
var _bpm := 96.0
var _time := 0.0
var _next_bar_visit := 17.0
var _visit_index := 0
var _player: Node3D
var _visual_probe_time := 0.0
var _visual_script: Script
var _layout: Dictionary = {}
var _entry_inside := ENTRY_INSIDE
var _entry_outside := ENTRY_OUTSIDE
var _entry_door := Vector3(-13.0, 0.15, -6.0)
var _street_corner := STREET_CORNER
var _exit_normal := Vector3.BACK
var _dance_yaw := PI


func configure_layout(data: Dictionary) -> void:
	# Venue markers are world positions. Configure before adding the crowd to the
	# tree; all physics destinations are converted into this crowd's local space.
	if not patrons.is_empty():
		return
	_layout = data.duplicate()


func _ready() -> void:
	name = "PublicoDoLadoB" if _layout.is_empty() else "Publico_" + String(_layout.get("id", "discoteca")).validate_node_name()
	if not _layout.is_empty():
		for key in ["entry_inside", "entry_outside", "entry_door", "street_corner", "dance_origin", "bar_position", "stage_position"]:
			if _layout.get(key) is Vector3:
				_layout[key] = to_local(_layout[key])
		var homes := PackedVector3Array()
		for point in _layout.get("dance_homes", PackedVector3Array()):
			homes.append(to_local(point))
		_layout["dance_homes"] = homes
		_entry_inside = _layout.get("entry_inside", ENTRY_INSIDE)
		_entry_outside = _layout.get("entry_outside", ENTRY_OUTSIDE)
		_entry_door = _layout.get("entry_door", (_entry_inside + _entry_outside) * 0.5)
		_street_corner = _layout.get("street_corner", STREET_CORNER)
		_exit_normal = (_entry_outside - _entry_inside).normalized()
		_exit_normal.y = 0.0
		var toward_stage: Vector3 = _layout.get("stage_position", _entry_inside) - _layout.get("dance_origin", _entry_outside)
		_dance_yaw = atan2(-toward_stage.x, -toward_stage.z)
		_door_open = true
	_build_patrons()
	set_audience(float(_target_count) / PATRON_COUNT * 100.0)


func _build_patrons() -> void:
	if not patrons.is_empty():
		return
	for index in PATRON_COUNT:
		var body := CharacterBody3D.new()
		body.name = "Cliente%02d" % (index + 1)
		body.collision_layer = 2
		# Other people and the player are steered around; world walls remain solid.
		body.collision_mask = 1
		body.floor_snap_length = 0.30
		body.floor_max_angle = deg_to_rad(48.0)
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.22
		capsule.height = 1.78
		var collider := CollisionShape3D.new()
		collider.shape = capsule
		collider.position.y = 0.89
		body.add_child(collider)
		var home := Vector3(-18.2 + float(index % 4) * 1.35, 0.16, -15.6 + float(index / 4) * 2.0)
		var outside := Vector3(-27.0 - float(index % 2) * 0.8, 0.1, -7.0 + float(index / 2) * 0.95)
		if not _layout.is_empty():
			var homes: PackedVector3Array = _layout.get("dance_homes", PackedVector3Array())
			if index < homes.size(): home = homes[index]
			var sidewalk := Vector3(_exit_normal.z, 0.0, -_exit_normal.x)
			outside = _street_corner + sidewalk * (float(index % 4) * 0.8) + _exit_normal * (float(index / 4) * 1.05)
		body.position = home
		body.rotation.y = _dance_yaw
		body.add_to_group("club_patrons")
		add_child(body)
		patrons.append(body)
		var entry := {
			"body": body, "visual": null, "id": index, "state": "dancing",
			"desired_inside": true, "home": home,
			"outside": outside,
			"path": PackedVector3Array(), "waypoint": 0, "delay": 0.0,
			"speed": 1.08 + float(index % 4) * 0.065, "last_speed": 0.0,
			"wait": 0.0, "has_exited": false, "has_returned": false,
			"phase": float(index) * 0.71, "was_dancing": false, "waiting_route_state": ""
		}
		_entries.append(entry)
	_try_attach_visuals()


func _try_attach_visuals() -> void:
	if _visual_script == null:
		if not ResourceLoader.exists(VISUAL_SCRIPT) or not FileAccess.file_exists("res://assets/characters/catalog.json"):
			return
		_visual_script = load(VISUAL_SCRIPT) as Script
	if _visual_script == null:
		return
	for entry in _entries:
		if is_instance_valid(entry.visual):
			continue
		var visual := Node3D.new()
		visual.set_script(_visual_script)
		visual.set("appearance_id", APPEARANCES[int(entry.id)])
		entry.body.add_child(visual)
		if visual.has_method("setup"):
			visual.call("setup", APPEARANCES[int(entry.id)])
		entry.visual = visual


func set_audience(amount: float) -> void:
	_target_count = clampi(ceili(clampf(amount, 0.0, 100.0) / 100.0 * PATRON_COUNT), 0, PATRON_COUNT)
	# Stable identities allow exactly the same people to return after a recovery.
	for entry in _entries:
		var desired: bool = int(entry.id) < _target_count
		if bool(entry.desired_inside) == desired:
			continue
		entry.desired_inside = desired
		entry.delay = 0.65 + float(int(entry.id) % 4) * 0.48
		if desired and entry.state == "waiting_exit":
			entry.state = "dancing"
		elif desired and entry.state == "waiting_door" and _inside_door(entry.body.position):
			_start_home_route(entry)
		elif not desired and entry.state == "dancing":
			entry.state = "waiting_exit"


func set_door_open(value: bool) -> void:
	_door_open = value


func set_player(player: Node3D) -> void:
	_player = player


func set_performance(active: bool, bpm: float = 100.0) -> void:
	_performance = active
	_bpm = clampf(bpm, 40.0, 240.0)


func get_engaged_count() -> int:
	var count := 0
	for entry in _entries:
		if entry.state in ["dancing", "waiting_exit", "visiting_bar", "at_bar", "returning_dance"]:
			count += 1
	return count


func get_target_count() -> int:
	return _target_count


func get_patron_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append({
			"id": int(entry.id), "state": String(entry.state),
			"position": entry.body.global_position, "desired_inside": bool(entry.desired_inside),
			"has_exited": bool(entry.has_exited), "has_returned": bool(entry.has_returned),
			"visible": entry.body.visible, "speed": float(entry.last_speed)
		})
	return result


func _physics_process(delta: float) -> void:
	_time += delta
	_visual_probe_time -= delta
	if _visual_probe_time <= 0.0:
		_visual_probe_time = 1.0
		_try_attach_visuals()
	_schedule_bar_visit()
	for entry in _entries:
		_step_patron(entry, delta)


func _schedule_bar_visit() -> void:
	if _time < _next_bar_visit or _entries.is_empty():
		return
	_next_bar_visit = _time + (20.0 if _performance else 13.0)
	for offset in PATRON_COUNT:
		var index := (_visit_index + offset) % PATRON_COUNT
		var entry: Dictionary = _entries[index]
		if entry.state != "dancing" or not entry.desired_inside:
			continue
		_visit_index = (index + 3) % PATRON_COUNT
		var service := Vector3(-21.1, 0.15, -12.3 - float(index % 3) * 1.2)
		if _layout.is_empty():
			_set_route(entry, PackedVector3Array([Vector3(-19.8, 0.15, -11.25), service]), "visiting_bar")
		else:
			# The bar marker is in the counter. Stop on its public side, leaving
			# the solid counter intact, and use the same clear dance-floor aisle.
			var bar: Vector3 = _layout.get("bar_position", _entry_inside)
			var origin: Vector3 = _layout.get("dance_origin", _entry_inside)
			var approach := origin - bar
			approach.y = 0.0
			service = bar + approach.normalized() * 1.3
			service.y = origin.y
			_set_route(entry, PackedVector3Array([origin, service]), "visiting_bar")
		break


func _step_patron(entry: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = entry.body
	entry.delay = maxf(0.0, float(entry.delay) - delta)
	match String(entry.state):
		"dancing":
			if not entry.desired_inside:
				entry.state = "waiting_exit"
				entry.delay = 0.6 + float(int(entry.id) % 4) * 0.5
		"waiting_exit":
			if entry.desired_inside:
				entry.state = "dancing"
			elif entry.delay <= 0.0:
				_start_departure(entry)
		"outside":
			if entry.desired_inside and entry.delay <= 0.0:
				_start_arrival(entry)
			else:
				# Loitering remains visible and belongs to the same persistent actor.
				body.rotation.y = lerp_angle(body.rotation.y, PI * 0.5 + sin(_time * 0.23 + entry.phase) * 0.4, minf(delta, 1.0))
		"waiting_door":
			if entry.desired_inside and _inside_door(body.position):
				_start_home_route(entry)
			elif _door_open:
				if entry.waiting_route_state == "entering" and entry.desired_inside:
					entry.state = "entering"
				elif not entry.desired_inside:
					entry.state = "leaving"
				else:
					_start_home_route(entry)
		"at_bar":
			entry.wait -= delta
			if entry.wait <= 0.0:
				_start_home_route(entry)
	var moving: bool = entry.state in ["leaving", "entering", "visiting_bar", "returning_dance"]
	if moving:
		_walk_route(entry, delta)
	else:
		_idle_body(entry, delta)
	_animate(entry, delta)


func _start_departure(entry: Dictionary) -> void:
	if not _layout.is_empty():
		# Clear the awning posts and terrace planters before turning along the
		# pavement. Cutting diagonally across a furnished terrace can trap a queue.
		var pavement := _entry_outside + _exit_normal * 3.0
		_set_route(entry, PackedVector3Array([_entry_inside, _entry_door, _entry_outside, pavement, _street_corner, entry.outside]), "leaving")
		return
	var body: CharacterBody3D = entry.body
	var corridor := Vector3(-13.0 + float(int(entry.id) % 2) * 0.22, 0.15, -9.15)
	var front := Vector3(body.position.x, 0.15, -11.0)
	_set_route(entry, PackedVector3Array([front, corridor, ENTRY_INSIDE, ENTRY_OUTSIDE, STREET_CORNER, entry.outside]), "leaving")


func _start_arrival(entry: Dictionary) -> void:
	if _layout.is_empty():
		_set_route(entry, PackedVector3Array([STREET_CORNER, ENTRY_OUTSIDE, ENTRY_INSIDE, Vector3(-13, 0.15, -10.4), entry.home]), "entering")
	else:
		var pavement := _entry_outside + _exit_normal * 3.0
		_set_route(entry, PackedVector3Array([_street_corner, pavement, _entry_outside, _entry_door, _entry_inside, entry.home]), "entering")


func _start_home_route(entry: Dictionary) -> void:
	if _layout.is_empty():
		_set_route(entry, PackedVector3Array([Vector3(-19.4 if entry.body.position.x < -19 else -13.0, 0.15, -10.8), entry.home]), "returning_dance")
	else:
		_set_route(entry, PackedVector3Array([_layout.get("dance_origin", _entry_inside), entry.home]), "returning_dance")


func _inside_door(point: Vector3) -> bool:
	return (point - _entry_door).dot(_exit_normal) < -0.1


func _set_route(entry: Dictionary, route: PackedVector3Array, state_name: String) -> void:
	entry.path = route
	entry.waypoint = 0
	entry.state = state_name


func _walk_route(entry: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = entry.body
	var path: PackedVector3Array = entry.path
	var waypoint: int = int(entry.waypoint)
	if waypoint >= path.size():
		_route_finished(entry)
		_idle_body(entry, delta)
		return
	var target: Vector3 = path[waypoint]
	var offset := target - body.position
	offset.y = 0.0
	if offset.length() < 0.22:
		entry.waypoint = waypoint + 1
		if entry.waypoint >= path.size():
			_route_finished(entry)
		_idle_body(entry, delta)
		return
	# Stop on the correct side of an actually closed door, never phase through it.
	if not _door_open and entry.state in ["leaving", "entering"]:
		var before_door := (body.position - _entry_door).dot(_exit_normal)
		var after_door := (target - _entry_door).dot(_exit_normal)
		var crossing: bool = (before_door < -0.1 and after_door > 0.0) or (before_door > 0.1 and after_door < 0.0)
		if crossing:
			entry.waiting_route_state = entry.state
			entry.state = "waiting_door"
			_idle_body(entry, delta)
			return
	var desired := offset.normalized() * minf(float(entry.speed), offset.length() / maxf(delta, 0.001))
	# Small personal-space corrections make the queue flow instead of overlapping.
	for other in _entries:
		if other == entry:
			continue
		var difference: Vector3 = body.position - other.body.position
		difference.y = 0.0
		var distance := difference.length()
		if distance > 0.01 and distance < 0.60:
			desired += difference / distance * (0.60 - distance) * 0.8
	body.velocity.x = move_toward(body.velocity.x, desired.x, 5.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, desired.z, 5.0 * delta)
	_apply_gravity(body, delta)
	var before := body.position
	_step_over_threshold(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * delta)
	body.move_and_slide()
	var moved := body.position - before
	moved.y = 0.0
	entry.last_speed = moved.length() / maxf(delta, 0.001)
	if moved.length_squared() > 0.00001:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-moved.x, -moved.z), minf(6.0 * delta, 1.0))


func _step_over_threshold(body: CharacterBody3D, motion: Vector3) -> void:
	# Door sills are real geometry. Give walking patrons a small, collision-checked
	# step instead of making them phase through the sill or stall at the entrance.
	if not body.is_on_floor() or motion.length_squared() < 0.000001:
		return
	var hit := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, motion, hit):
		return
	# Compare with this body's actual floor limit. The rounded capsule contacts
	# a 7.5cm sill with normal.y≈0.665: just too steep for its 48° floor limit.
	if not hit.get_collider() is StaticBody3D or hit.get_normal().y >= cos(body.floor_max_angle):
		return
	const SILL_HEIGHT := 0.10
	if body.test_move(body.global_transform, Vector3.UP * SILL_HEIGHT):
		return
	var raised := body.global_transform
	raised.origin.y += SILL_HEIGHT
	var probe := motion.normalized() * maxf(motion.length(), 0.28)
	if body.test_move(raised, probe):
		return
	raised.origin += probe
	var landing := KinematicCollision3D.new()
	if not body.test_move(raised, Vector3.DOWN * (SILL_HEIGHT + 0.04), landing) or landing.get_normal().y < 0.7:
		return
	var rise := SILL_HEIGHT + landing.get_travel().y
	if rise >= 0.012 and rise <= SILL_HEIGHT:
		body.global_position.y += rise


func _idle_body(entry: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = entry.body
	body.velocity.x = move_toward(body.velocity.x, 0.0, 7.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, 0.0, 7.0 * delta)
	_apply_gravity(body, delta)
	var before := body.position
	body.move_and_slide()
	var moved := body.position - before
	moved.y = 0.0
	entry.last_speed = moved.length() / maxf(delta, 0.001)
	if entry.state in ["dancing", "waiting_exit"]:
		body.rotation.y = lerp_angle(body.rotation.y, _dance_yaw + sin(_time * 0.7 + entry.phase) * 0.12, minf(delta * 3.0, 1.0))


func _apply_gravity(body: CharacterBody3D, delta: float) -> void:
	body.velocity.y = -0.8 if body.is_on_floor() else body.velocity.y - 20.0 * delta


func _route_finished(entry: Dictionary) -> void:
	match String(entry.state):
		"leaving":
			entry.state = "outside"
			entry.has_exited = true
		"entering":
			entry.state = "dancing"
			entry.has_returned = true
		"visiting_bar":
			entry.state = "at_bar"
			entry.wait = 3.5 + float(int(entry.id) % 3) * 0.8
		"returning_dance":
			entry.state = "dancing"
	entry.path = PackedVector3Array()
	entry.waypoint = 0


func _animate(entry: Dictionary, delta: float) -> void:
	if not is_instance_valid(entry.visual):
		return
	if entry.visual.has_method("animate"):
		var dancing: bool = entry.state in ["dancing", "waiting_exit"]
		entry.visual.call("animate", delta, float(entry.last_speed), false, false, dancing, _bpm)
		if dancing and not bool(entry.get("was_dancing", false)):
			var animation: AnimationPlayer = entry.visual.get("animation_player")
			if animation and animation.current_animation_length > 0.0:
				# Seed once on entering dance, then let the shared musical tempo
				# advance normally. People keep the beat without copying one pose.
				animation.seek(fposmod(float(entry.phase) / TAU, 1.0) * animation.current_animation_length, true)
				entry.was_dancing = true
		elif not dancing:
			entry.was_dancing = false
