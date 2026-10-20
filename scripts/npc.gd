class_name AlbumNPC
extends CharacterBody3D
## Original single-player pedestrian tasks, with perception before reaction.
## Clothing/appearance never selects the behavioural personality.

signal message(text: String)
signal reaction_started(kind: String)

const PERSONALITIES: Array[String] = ["calm", "intoxicated", "dreamy", "timid", "security"]
const PROFILE_SPEEDS := {"calm": 1.28, "intoxicated": 1.06, "dreamy": 0.86, "timid": 1.36, "security": 1.16}
const PROFILES := {
	"calm": {"bump_state": "startled", "duration": 1.35, "line": "Tem cuidado, por favor."},
	"intoxicated": {"bump_state": "irritated", "duration": 2.35, "line": "Então? Vê lá por onde andas!"},
	"dreamy": {"bump_state": "look", "duration": 1.65, "line": "Hã? Ah... tudo bem."},
	"timid": {"bump_state": "retreat", "duration": 1.90, "line": "Desculpa, deixa-me passar."},
	"security": {"bump_state": "guard_warning", "duration": 2.60, "line": "Calma. Dá espaço às pessoas."}
}

var health: float = 100.0
var appearance_id: int = 0
var personality: String = "calm"
var route: PackedVector3Array = PackedVector3Array()
var state: String = "walk"
var reaction_cooldown: float = 0.0
var visual: Node3D
var visual_enabled: bool = true
var simulation_enabled: bool = true
var player: Node3D
var perceived_player: bool = false
var speed: float = 1.28
var reaction_count: int = 0
var _route_index: int = 0
var _sense_timer: float = 0.0
var _reaction_timer: float = 0.0
var _stare_timer: float = 0.0
var _message_timer: float = 0.0
var _blocked_timer: float = 0.0
var _motion_time: float = 0.0
var _yield_direction := Vector3.ZERO
var _last_heading := Vector3.FORWARD
var _capsule: CollisionShape3D
var _rng := RandomNumberGenerator.new()


func configure(index: int, behavior: String, points: PackedVector3Array) -> void:
	health = 100.0
	state = "walk"
	reaction_cooldown = 0.0
	_reaction_timer = 0.0
	_stare_timer = 0.0
	perceived_player = false
	appearance_id = clampi(index, 0, 19)
	personality = behavior if PERSONALITIES.has(behavior) else "calm"
	speed = PROFILE_SPEEDS[personality]
	route = points.duplicate()
	_route_index = 1 if route.size() > 1 else 0
	_rng.seed = 7001 + appearance_id * 71
	_sense_timer = float(appearance_id % 6) * 0.027
	if not route.is_empty() and not is_inside_tree():
		position = route[0]
	if is_instance_valid(visual) and visual.has_method("setup"):
		visual.call("setup", appearance_id)


func _ready() -> void:
	name = "Peao_%02d" % appearance_id
	add_to_group("album_npcs")
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.26
	floor_max_angle = deg_to_rad(43.0)
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.73
	capsule.radius = 0.26
	_capsule = CollisionShape3D.new()
	_capsule.shape = capsule
	_capsule.position.y = 0.865
	add_child(_capsule)
	if visual_enabled:
		_ensure_visual()
	if route.size() > 1:
		_last_heading = (route[1] - route[0]).normalized()
		rotation.y = atan2(-_last_heading.x, -_last_heading.z)
	set_simulation_enabled(simulation_enabled)


func _ensure_visual() -> void:
	if visual != null:
		return
	var path := "res://scripts/character_visual.gd"
	if not ResourceLoader.exists(path):
		return
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		return
	visual = script.new()
	visual.set("appearance_id", appearance_id)
	add_child(visual)


func set_player(body: Node3D) -> void:
	player = body
	perceived_player = false
	_stare_timer = 0.0


func set_simulation_enabled(enabled: bool) -> void:
	simulation_enabled = enabled
	visible = enabled
	set_physics_process(enabled and health > 0.0)
	collision_layer = 2 if enabled and health > 0.0 else 0
	collision_mask = 3 if enabled and health > 0.0 else 0
	if not enabled:
		velocity = Vector3.ZERO
		perceived_player = false
	else:
		_sense_timer = 0.0


func place_on_route(progress: float) -> void:
	# Used only when the pool is first created, never to respawn near the player.
	if route.is_empty():
		return
	if route.size() == 1:
		global_position = route[0]
		return
	var lengths: Array[float] = []
	var total := 0.0
	for i in route.size():
		var length := route[i].distance_to(route[(i + 1) % route.size()])
		lengths.append(length)
		total += length
	var along := fposmod(progress, 1.0) * total
	for i in route.size():
		if along <= lengths[i] or i == route.size() - 1:
			var ratio := along / maxf(0.001, lengths[i])
			global_position = route[i].lerp(route[(i + 1) % route.size()], ratio)
			_route_index = (i + 1) % route.size()
			_last_heading = (route[_route_index] - global_position).normalized()
			rotation.y = atan2(-_last_heading.x, -_last_heading.z)
			return
		along -= lengths[i]


func can_see_player() -> bool:
	if not is_instance_valid(player) or _player_locked():
		return false
	var offset := player.global_position - global_position
	if offset.length_squared() > 11.0 * 11.0 or absf(offset.y) > 2.4:
		return false
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	if horizontal.length() > 1.0 and (-global_basis.z).dot(horizontal.normalized()) < 0.17:
		return false
	var from := global_position + Vector3(0, 1.48, 0)
	var to := player.global_position + Vector3(0, 1.38, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func receive_bump(from_position: Vector3, strength: float) -> void:
	if health <= 0.0 or not simulation_enabled or reaction_cooldown > 0.0 or _player_locked() or strength < 0.65:
		return
	var profile: Dictionary = PROFILES[personality]
	state = profile.bump_state
	_reaction_timer = float(profile.duration)
	reaction_cooldown = 4.0
	_stare_timer = 0.0
	var away := global_position - from_position
	away.y = 0.0
	_yield_direction = away.normalized() if away.length_squared() > 0.01 else global_basis.x
	reaction_count += 1
	reaction_started.emit(state)
	if visual != null and visual.has_method("react"):
		visual.call("react", "bump" if state == "startled" else state)
	_say(profile.line)


func take_damage(amount: float, from_position: Vector3) -> bool:
	# Main game reports the witnessed crime separately. Fashion never implies guilt.
	if health <= 0.0 or amount <= 0.0 or not simulation_enabled or _player_locked():
		return false
	if bool(get_meta("mission_guard", false)):
		reaction_cooldown = 0.0
		receive_bump(from_position, 2.0)
		return false
	health = maxf(0.0, health - amount)
	if visual != null and visual.has_method("react"):
		visual.call("react", "hit")
	if health <= 0.0:
		state = "down"
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		set_physics_process(false)
		if visual:
			visual.rotation.z = PI * 0.5
			visual.position.y = 0.22
		return true
	reaction_cooldown = 0.0
	receive_bump(from_position, maxf(1.0, amount / 10.0))
	return false


func _player_locked() -> bool:
	if not is_instance_valid(player):
		return false
	return bool(player.get("movement_locked")) if "movement_locked" in player else false


func _player_speed() -> float:
	return player.velocity.length() if player is CharacterBody3D else 0.0


func _perceive(interval: float) -> void:
	perceived_player = can_see_player()
	if not perceived_player:
		_stare_timer = maxf(0.0, _stare_timer - interval * 2.0)
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var player_forward := -player.global_basis.z
	if player.has_method("get_camera"):
		var camera: Camera3D = player.call("get_camera")
		if is_instance_valid(camera):
			player_forward = -camera.global_basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()
	var being_watched := player_forward.dot(-offset.normalized()) > 0.62 if distance > 0.05 else true
	if distance < 4.5 and _player_speed() < 0.35 and being_watched:
		_stare_timer += interval
	else:
		_stare_timer = maxf(0.0, _stare_timer - interval)
	if reaction_cooldown <= 0.0 and _stare_timer > (2.8 if personality == "security" else 3.7):
		if personality in ["security", "intoxicated"]:
			state = "guard_warning" if personality == "security" else "irritated"
			_reaction_timer = 1.8
			reaction_cooldown = 6.0
			_stare_timer = 0.0
			reaction_count += 1
			reaction_started.emit(state)
			_say("Precisas de alguma coisa?" if personality == "security" else "Que foi?")
			if visual != null and visual.has_method("react"):
				visual.call("react", "bump" if state == "startled" else state)
			return
	if _reaction_timer > 0.0:
		return
	var heading := _route_heading()
	# Yield early to an oncoming person; a physical contact is a separate event.
	if distance < 2.35 and distance > 0.35 and heading.dot(offset.normalized()) > 0.28:
		state = "yield"
		_reaction_timer = 0.60
		_yield_direction = Vector3(-heading.z, 0, heading.x)
		return
	if distance < 1.7 and _player_speed() < 0.35:
		state = "look"
		_reaction_timer = 0.65


func _route_heading() -> Vector3:
	if route.is_empty():
		return _last_heading
	var offset := route[_route_index] - global_position
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.02 else _last_heading


func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		return
	reaction_cooldown = maxf(0.0, reaction_cooldown - delta)
	_message_timer = maxf(0.0, _message_timer - delta)
	_motion_time += delta
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		var interval := 0.16
		if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) > 20.0 * 20.0:
			interval = 0.65
		_sense_timer = interval
		_perceive(interval)
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	if _reaction_timer <= 0.0 and state != "walk":
		state = "walk"
	var desired := Vector3.ZERO
	if state == "walk":
		desired = _walk_intent()
	elif state == "yield":
		desired = _yield_direction * speed * 0.75 + _route_heading() * 0.12
	elif state == "retreat":
		desired = _yield_direction * speed * 1.25
	var attempted_movement := desired.length_squared() > 0.3
	if desired.length_squared() > 0.02:
		desired = _avoid_obstacles(desired)
	var acceleration := 4.5
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if is_instance_valid(player) and collision.get_collider() == player and _player_speed() > 0.65:
			receive_bump(player.global_position, _player_speed())
	_detect_contact_bump()
	var moving := Vector3(velocity.x, 0, velocity.z)
	var facing := moving
	if state in ["look", "startled", "irritated", "guard_warning"] and perceived_player and is_instance_valid(player):
		facing = player.global_position - global_position
		facing.y = 0.0
	if facing.length_squared() > 0.04:
		var target_yaw := atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-4.8 * delta))
		_last_heading = facing.normalized()
	if visual != null and visual.has_method("animate"):
		visual.call("animate", delta, moving.length(), false, false, false, 100.0)
		# Movement style belongs to personality, not fashion or gender.
		visual.rotation.z = sin(_motion_time * 1.7 + appearance_id) * (0.035 if personality == "intoxicated" else 0.0)
	if attempted_movement and moving.length_squared() < 0.04:
		_blocked_timer += delta
		if _blocked_timer > 2.0 and route.size() > 1:
			_route_index = (_route_index + 1) % route.size()
			_blocked_timer = 0.0
	else:
		_blocked_timer = 0.0


func _detect_contact_bump() -> void:
	if not is_instance_valid(player) or _player_locked() or reaction_cooldown > 0.0 or not player is CharacterBody3D:
		return
	var offset := global_position - player.global_position
	if absf(offset.y) > 1.3:
		return
	offset.y = 0.0
	if offset.length() > 0.66 or offset.length() < 0.01:
		return
	var player_motion: Vector3 = player.velocity
	player_motion.y = 0.0
	if player_motion.length() < 0.7 or player_motion.normalized().dot(offset.normalized()) < 0.25:
		return
	var from := global_position + Vector3(0, 0.85, 0)
	var to := player.global_position + Vector3(0, 0.85, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider == player:
		receive_bump(player.global_position, player_motion.length())


func _walk_intent() -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	var offset := route[_route_index] - global_position
	offset.y = 0.0
	if offset.length() < 0.42:
		_route_index = (_route_index + 1) % route.size()
		if _rng.randf() < 0.10:
			state = "idle"
			_reaction_timer = _rng.randf_range(0.8, 2.0)
			return Vector3.ZERO
		offset = route[_route_index] - global_position
		offset.y = 0.0
	var slowdown := clampf(offset.length() / 0.9, 0.45, 1.0)
	return offset.normalized() * speed * slowdown


func _avoid_obstacles(desired: Vector3) -> Vector3:
	var direction := desired.normalized()
	if _direction_clear(direction, 0.90):
		return desired
	var right := Vector3(-direction.z, 0.0, direction.x)
	for sign_value in [1.0, -1.0]:
		var alternative: Vector3 = (direction * 0.25 + right * float(sign_value)).normalized()
		if _direction_clear(alternative, 0.75):
			return alternative * speed * 0.75
	return Vector3.ZERO


func _direction_clear(direction: Vector3, distance: float) -> bool:
	var from := global_position + Vector3(0, 0.85, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, 3, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _say(line: String) -> void:
	if _message_timer > 0.0 or not is_instance_valid(player) or global_position.distance_to(player.global_position) > 8.0:
		return
	_message_timer = 8.0
	message.emit(line)
