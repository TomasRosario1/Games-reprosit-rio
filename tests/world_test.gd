extends SceneTree
## Checks public world controls and physically traverses the intended mission route.
const WORLD = preload("res://scripts/world.gd")
var checks := 0
var failures := 0
var body: CharacterBody3D
var world: AlbumWorld

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	world = WORLD.new()
	root.add_child(world)
	await physics_frame
	check(world._door.collision_layer == 1, "Bar must start closed")
	world.set_bar_unlocked(true)
	check(world._door.collision_layer == 0, "Unlocked door must remove collision")
	world.set_audience(0)
	check(world._crowd_count == 0, "Audience zero hides everybody")
	world.set_audience(100)
	check(world._crowd_count == 8, "Audience recovery restores eight people")
	world.set_wristband_visible(false)
	check(not world._wristband.visible, "Collected wristband must hide")
	world.set_wristband_visible(true)
	world.set_pulse(0.8)
	check(world._reactive_lights[0].light_energy > 1.0, "Spectrum pulse must affect lighting")
	body = CharacterBody3D.new()
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(48)
	var shape := CapsuleShape3D.new()
	shape.height = 1.82
	shape.radius = 0.28
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.91
	body.add_child(collision)
	root.add_child(body)
	body.global_transform = world.rooftop_spawn
	for waypoint in [Vector3(-16,9.5,23.7),Vector3(-5.45,9.5,23.7),Vector3(-5.45,0,6.7),Vector3(-4,0,2),Vector3(-12,0,-4.2),Vector3(-13,0,-8.5),Vector3(-16,0,-17)]:
		await _walk_to(waypoint)
	print("WORLD: %s checks, %s failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _walk_to(target: Vector3) -> void:
	var reached := false
	for frame in range(420):
		await physics_frame
		var offset := target - body.position
		offset.y = 0
		if offset.length() < 0.24:
			reached = true
			break
		var direction := offset.normalized()
		body.velocity.x = direction.x * 4.5
		body.velocity.z = direction.z * 4.5
		body.velocity.y = -1.0 if body.is_on_floor() else body.velocity.y - 20.0/60.0
		body.move_and_slide()
	check(reached,"Cannot walk to %s; stuck at %s" % [target,body.position])
	check(absf(body.position.y-target.y)<1.0,"Wrong floor near %s: %s" % [target,body.position])
