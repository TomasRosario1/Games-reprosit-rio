extends SceneTree
## Real physics / visibility / contact checks plus stable population budgeting.
const NPC = preload("res://scripts/npc.gd")
const POPULATION = preload("res://scripts/npc_population.gd")

class TestPlayer extends CharacterBody3D:
	var movement_locked := false

var world: Node3D
var player: TestPlayer
var npc: CharacterBody3D
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("NPC FAIL: " + description)


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, -0.2, 0), Vector3(180, 0.4, 180))
	player = TestPlayer.new()
	player.collision_layer = 1
	player.collision_mask = 3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.82
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.91
	player.add_child(collision)
	world.add_child(player)
	player.position = Vector3(0, 0.05, -4)
	player.rotation.y = PI
	npc = NPC.new()
	npc.visual_enabled = false
	npc.configure(0, "calm", PackedVector3Array([Vector3(0,0.05,0), Vector3(0,0.05,-8), Vector3(8,0.05,-8), Vector3(8,0.05,0)]))
	world.add_child(npc)
	npc.set_player(player)
	npc.set_physics_process(false)
	await _step(3)
	_expect(npc.can_see_player(), "player ahead is visible")
	var wall := _box(Vector3(0, 1.2, -2), Vector3(3.0, 2.4, 0.35))
	await _step(3)
	_expect(not npc.can_see_player(), "wall prevents seeing or staring at player")
	wall.queue_free()
	await _step(3)
	player.position.z = 4
	_expect(not npc.can_see_player(), "field of view rejects player behind pedestrian")
	player.position.z = -4
	player.movement_locked = true
	_expect(not npc.can_see_player(), "protected menu/performance player does not trigger perception")
	player.movement_locked = false

	npc.receive_bump(player.position, 0.3)
	_expect(npc.reaction_count == 0, "tiny contact is not an aggressive encounter")
	npc.receive_bump(player.position, 2.0)
	_expect(npc.state == "startled" and npc.reaction_count == 1, "calm profile startles after strong contact")
	var cooldown: float = npc.reaction_cooldown
	npc.receive_bump(player.position, 2.0)
	_expect(npc.reaction_count == 1 and npc.reaction_cooldown == cooldown, "repeated collision cannot spam reaction")
	player.position = Vector3(-25,0.05,-25)
	npc.set_physics_process(true)
	await _step(105)
	_expect(npc.state == "walk", "pedestrian resumes walking after held reaction")
	_expect(npc.position.z < -0.2, "patrol physically advances after recovery")
	_expect(npc.velocity.length() < 2.0, "civilian locomotion stays at walking speed")
	npc.set_physics_process(false)
	npc.position = Vector3(0,0.05,0)
	npc.rotation.y = 0
	npc.configure(1, "intoxicated", npc.route)
	npc.receive_bump(Vector3(0,0.05,-1), 2.0)
	_expect(npc.state == "irritated", "intoxicated profile objects to a bump without attacking")
	npc.configure(2, "timid", npc.route)
	npc.receive_bump(Vector3(0,0.05,-1), 2.0)
	_expect(npc.state == "retreat" and npc._yield_direction.z > 0.9, "timid profile steps away from source of contact")
	npc.configure(3, "dreamy", npc.route)
	npc.receive_bump(Vector3(0,0.05,-1), 2.0)
	_expect(npc.state == "look" and npc.speed < 1.0, "dreamy profile responds slowly and looks")
	npc.configure(4, "security", npc.route)
	npc.receive_bump(Vector3(0,0.05,-1), 2.0)
	_expect(npc.state == "guard_warning", "security warns rather than entering combat")
	npc.configure(4, "security", npc.route)
	player.position = Vector3(0,0.05,-2.5)
	player.rotation.y = PI
	for i in 20:
		npc._perceive(0.16)
	_expect(npc.state == "guard_warning", "sustained player-facing stare can produce security warning")
	player.movement_locked = true
	var reaction_count: int = npc.reaction_count
	npc.reaction_cooldown = 0
	npc.receive_bump(player.position, 3.0)
	_expect(npc.reaction_count == reaction_count, "protected player is immune to contact reactions")
	player.movement_locked = false

	npc.configure(0, "calm", npc.route)
	player.position = Vector3(0,0.05,-1.8)
	player.velocity = Vector3(0,0,2)
	npc._perceive(0.16)
	_expect(npc.state == "yield" and absf(npc._yield_direction.x) > 0.8, "oncoming player causes sideways yielding before collision")
	player.position = Vector3(-25,0.05,-25)
	player.velocity = Vector3.ZERO
	wall = _box(Vector3(0, 1.0, -0.78), Vector3(0.65, 2.0, 0.2))
	await _step(3)
	var steered: Vector3 = npc._avoid_obstacles(Vector3(0,0,-1.28))
	_expect(absf(steered.x) > 0.5, "obstacle rays steer around a wall instead of walking through it")
	wall.queue_free()
	await _step(3)

	# A real capsule collision: no fabricated contact signal or teleport into NPC.
	npc.configure(0, "calm", PackedVector3Array([Vector3(0,0.05,0)]))
	npc.position = Vector3(0,0.05,0)
	npc.velocity = Vector3.ZERO
	npc.set_physics_process(true)
	player.position = Vector3(0,0.05,1.4)
	for i in 32:
		await physics_frame
		player.velocity = Vector3(0,-0.5,-2.0)
		player.move_and_slide()
	_expect(npc.reaction_cooldown > 0.0 and npc.state == "startled", "moving player capsule produces real contact reaction")
	npc.set_simulation_enabled(false)
	_expect(not npc.visible and npc.collision_layer == 0 and not npc.is_physics_processing(), "inactive pedestrian hides mesh and removes collision and physics")
	var frozen: Vector3 = npc.position
	await _step(15)
	_expect(npc.position == frozen, "distant suspended pedestrian does not simulate")

	var manager: Node3D = POPULATION.new()
	manager.visuals_enabled = false
	world.add_child(manager)
	var routes: Array = [PackedVector3Array([Vector3(6,0.05,0), Vector3(6,0.05,-8), Vector3(14,0.05,-8), Vector3(14,0.05,0)]), PackedVector3Array([Vector3(-6,0.05,0), Vector3(-6,0.05,-8), Vector3(-14,0.05,-8), Vector3(-14,0.05,0)])]
	player.position = Vector3(0,0.05,8)
	player.velocity = Vector3.ZERO
	manager.configure(routes, 73)
	manager.set_player(player)
	manager.set_process(false)
	for ped in manager.peds:
		ped.set_physics_process(false)
	_expect(manager.peds.size() == 20, "population pools twenty available appearance IDs")
	var unique: Dictionary = {}
	for ped in manager.peds:
		unique[ped.appearance_id] = true
	_expect(unique.size() == 20 and unique.has(0) and unique.has(19), "all catalogue IDs exist exactly once")
	_expect(manager.get_active_count() == 10, "default local budget is ten street pedestrians")
	manager.set_budget(6)
	_expect(manager.get_active_count() == 6, "low quality budget activates six pedestrians")
	var identities: Array[int] = []
	var positions: Dictionary = {}
	for ped in manager.peds:
		positions[ped.appearance_id] = ped.global_position
		if ped.simulation_enabled:
			identities.append(ped.appearance_id)
	manager._refresh_membership()
	var after: Array[int] = []
	for ped in manager.peds:
		if ped.simulation_enabled:
			after.append(ped.appearance_id)
	_expect(identities == after, "same local budget retains active identities")
	manager.set_budget(16)
	_expect(manager.get_active_count() == 16, "high quality budget activates sixteen")
	var moved := false
	for ped in manager.peds:
		if ped.global_position != positions[ped.appearance_id]:
			moved = true
	_expect(not moved, "budget changes never teleport a character near the camera")
	manager.set_budget(100)
	_expect(manager.get_active_count() == 20, "budget clamps to catalogue capacity")
	player.position = Vector3(85,0.05,85)
	manager._refresh_membership()
	_expect(manager.get_active_count() == 0, "far routes are fully suspended")
	player.position = Vector3(0,0.05,8)
	manager.set_budget(6)
	manager.set_enabled(false)
	_expect(manager.get_active_count() == 0, "disabled population removes all active pedestrians")
	manager.set_enabled(true)
	_expect(manager.get_active_count() == 6, "reenabling restores configured local budget")
	manager.set_budget(0)
	_expect(manager.get_active_count() == 0, "zero budget disables street simulation")

	world.queue_free()
	await process_frame
	print("NPC: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _step(frames: int) -> void:
	for i in frames:
		await physics_frame


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	world.add_child(body)
	return body
