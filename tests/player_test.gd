extends SceneTree
## Run: godot --headless --path . --script tests/player_test.gd
## Exercises the real physics body in a tiny isolated test world.

const PlayerScript = preload("res://scripts/player.gd")
var failures: int = 0
var checks: int = 0
var deaths: int = 0
var player: AlbumPlayer
var world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "crouch", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
	world = Node3D.new()
	root.add_child(world)
	_add_platform(Vector3(40.0, 0.5, 40.0), Vector3(0.0, -0.25, 0.0))
	player = PlayerScript.new()
	world.add_child(player)
	player.position.y = 0.15
	player.died.connect(func(): deaths += 1)
	await _step(20)
	_expect(player.is_on_floor(), "lands on collision floor")
	_expect(player.get_camera() != null and player.get_camera().is_current(), "third-person camera active")

	Input.action_press("move_forward")
	await _step(30)
	Input.action_release("move_forward")
	_expect(player.position.z < -1.0, "moves forward relative to initial camera")
	await _step(16)

	Input.action_press("jump")
	await _step(3)
	Input.action_release("jump")
	_expect(player.position.y > 0.10, "jump raises character above ground")
	await _step(65)
	_expect(player.is_on_floor() and is_equal_approx(player.health, 100.0), "ordinary jump landing is safe")

	Input.action_press("crouch")
	await _step(3)
	_expect(player._capsule.height < 1.3, "crouching shortens collision capsule")
	var ceiling: StaticBody3D = _add_platform(Vector3(2.0, 0.2, 2.0), player.position + Vector3(0.0, 1.48, 0.0))
	await _step(3) # Let the physics broadphase register the newly created ceiling.
	Input.action_release("crouch")
	await _step(4)
	_expect(player._capsule.height < 1.3, "cannot stand through a low ceiling")
	ceiling.queue_free()
	await _step(4)
	_expect(player._capsule.height > 1.8, "standing restored after overhead clearance")

	player.movement_locked = true
	Input.action_press("move_forward")
	Input.action_press("jump")
	var locked_start: Vector3 = player.position
	await _step(20)
	Input.action_release("move_forward")
	Input.action_release("jump")
	_expect(player.position.distance_to(locked_start) < 0.1, "performance lock prevents movement and jumping")
	player.set_performing(true, 110.0)
	await _step(30)
	_expect(player._right_arm.rotation.x > 1.2 and player._microphone.visible, "performance raises microphone hand while movement stays locked")
	_expect(player.position.distance_to(locked_start) < 0.1, "performance pose moves visuals without moving the physical body")
	player.set_performing(false)
	await _step(25)
	_expect(not player._microphone.visible and absf(player._right_arm.rotation.x) < 0.1, "ending performance hides microphone and restores resting pose")
	player.movement_locked = false

	# Orbit away from the facing direction. The magnet must wait, then converge.
	player._yaw = 1.0
	player._camera_idle = 0.0
	await _step(120)
	_expect(absf(player._yaw - 1.0) < 0.01, "camera magnet does not move before idle delay")
	await _step(150)
	_expect(absf(player._yaw) < 0.25, "camera recentres behind character after idle delay")

	# An actual drop onto the same floor, not a manually injected damage value.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 9.5, 0.0)))
	await _step(100)
	_expect(player.health <= 0.0 and deaths == 1, "9.5 metre rooftop fall is fatal and emits one event")
	await _step(10)
	_expect(deaths == 1, "death event is not repeated on following frames")

	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0)))
	await _step(10)
	_expect(is_equal_approx(player.health, 100.0) and not player.movement_locked and player.is_on_floor(), "respawn restores health, movement and floor contact")

	player.position.y = -13.0
	await _step(3)
	_expect(deaths == 2, "falling outside the world also emits death")
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0)))
	await _step(10)
	_expect(player.is_on_floor() and player.health > 0.0, "second respawn works after out-of-world fall")

	world.queue_free()
	await process_frame
	print("Player checks: %d passed, %d failed, %d total" % [checks - failures, failures, checks])
	quit(1 if failures > 0 else 0)


func _add_platform(size: Vector3, at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	world.add_child(body)
	body.position = at
	return body


func _step(frames: int) -> void:
	for i: int in range(frames):
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)
