extends SceneTree
## Original heat rules + real police visibility, strikes, immunity and witnesses.
const WANTED = preload("res://scripts/wanted_system.gd")
const POLICE = preload("res://scripts/police_manager.gd")
const NPC = preload("res://scripts/npc.gd")

class TestPlayer extends CharacterBody3D:
	var movement_locked := false
	var health := 100.0
	var dead := false
	func _die():
		dead = true

var checks := 0
var failures := 0
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("WANTED FAIL: " + text)

func _run() -> void:
	var wanted = WANTED.new()
	_expect(not wanted.record_event("bump") and wanted.heat == 0, "ordinary bump never raises heat")
	_expect(not wanted.record_event("civilian_assault",false) and wanted.heat == 0, "unwitnessed civilian harm is not magically reported")
	_expect(wanted.record_event("civilian_assault",true) and wanted.heat == 10, "witnessed civilian assault increases heat")
	_expect(wanted.stars() == 1, "continuous heat maps to first of five segments")
	wanted.clear()
	wanted.crimes_include_civilians = false
	_expect(not wanted.record_event("civilian_kill",true) and wanted.heat == 0, "optional police-only crime policy excludes civilian events")
	wanted.crimes_include_civilians = true
	_expect(wanted.record_event("vehicle_collision",true) and wanted.heat == 20, "witnessed vehicle collision raises heat")
	wanted.record_event("police_assault",false)
	_expect(wanted.heat == 45, "assaulted officer is aware even without another witness")
	wanted.record_event("police_kill")
	_expect(wanted.heat == 90, "police death has stronger effect than one strike")
	wanted.record_event("police_kill")
	_expect(wanted.heat == 100 and wanted.stars() == 5, "heat clamps at100 and five segments")
	var heat_before: float = wanted.heat
	wanted.update(30,true)
	_expect(wanted.heat == heat_before, "heat cannot decay while police can see player")
	wanted.update(2,false)
	_expect(wanted.heat == 94, "unseen player loses heat gradually after grace period")
	wanted.clear()
	wanted.record_event("police_assault")
	wanted.update(19,false)
	_expect(wanted.heat == 25, "twenty second grace protects heat from immediate decay")
	wanted.update(2,false)
	_expect(wanted.heat == 22, "only time after grace boundary decays heat")
	wanted.update(100,false)
	_expect(wanted.heat == 0 and wanted.stars() == 0, "heat naturally reaches zero without going negative")
	wanted.record_event("police_assault")
	wanted.clear()
	_expect(wanted.heat == 0 and wanted.seconds_since_crime == 0, "death/session reset clears heat and its timer")
	_expect(not wanted.record_event("unknown_crime"), "unsupported events do not raise heat")

	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0,-0.2,0),Vector3(100,0.4,100))
	var player := TestPlayer.new()
	player.collision_layer = 1
	player.collision_mask = 3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.82
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.91
	player.add_child(collision)
	world.add_child(player)
	player.position = Vector3(0,0.05,-1.5)
	var police = POLICE.new()
	police.visuals_enabled = false
	world.add_child(police)
	police.set_player(player)
	police.set_wanted(wanted)
	var officer = police.officers[0]
	officer.position = Vector3(0,0.05,0)
	officer.rotation.y = 0
	officer.set_physics_process(false)
	police.officers[1].position = Vector3(100,0.05,100)
	police.officers[1].set_physics_process(false)
	await _step(3)
	_expect(police.officers.size() == 2 and officer.get_meta("is_police"), "two identifiable officers are available")
	_expect(police.can_see_crime(player.position), "officer can witness unobstructed nearby player")
	police.tick(2.0)
	_expect(player.health == 100, "zero wanted heat never causes an unprovoked baton strike")
	police.report_event("police_assault")
	police.tick(0.2)
	_expect(player.health == 100, "officer warns before first close-range strike")
	police.tick(0.7)
	_expect(player.health == 92, "wanted player in reach receives moderate baton damage")
	police.tick(0.1)
	_expect(player.health == 92, "baton cooldown prevents per-frame damage")
	player.movement_locked = true
	var protected_heat: float = wanted.heat
	police.tick(8.0)
	_expect(player.health == 92 and wanted.heat == protected_heat, "menu/performance lock blocks damage and wanted simulation")
	player.movement_locked = false
	player.set_meta("driving",true)
	police.tick(3.0)
	_expect(player.health == 92, "driver cannot be hit by a hand-held baton through a vehicle")
	player.set_meta("driving",false)
	wanted.clear()
	police.tick(0.1)
	_expect(player.health == 92, "officers disengage when heat reaches zero")

	_expect(not police.apply_player_attack(player.position,Vector3.FORWARD), "punch cone cannot hit an officer behind the strike direction")
	_expect(police.apply_player_attack(player.position,Vector3.BACK), "in-range aimed player strike connects with officer")
	_expect(officer.health == 70 and wanted.heat == 25, "successful police strike applies health loss and25heat")
	_expect(not police.apply_player_attack(player.position,Vector3.BACK) and officer.health == 70, "held attack input cannot bypass strike cooldown")
	for i in 3:
		police.tick(0.5)
		police.apply_player_attack(player.position,Vector3.BACK)
	_expect(officer.health == 0 and wanted.heat == 100, "repeated valid strikes kill officer and raise full heat")
	_expect(officer.collision_layer == 0 and not officer.is_physics_processing(), "downed police body cannot keep fighting or blocking the street")
	police.tick(0.6)
	_expect(not police.apply_player_attack(player.position,Vector3.BACK), "downed officer cannot be killed repeatedly for events")
	officer.revive_at_spawn()
	officer.position = Vector3(0,0.05,0)
	officer.rotation.y = 0
	officer.set_physics_process(false)
	wanted.clear()
	var wall := _box(Vector3(0,1.4,-0.75),Vector3(4,2.8,0.25))
	await _step(3)
	_expect(not police.can_see_crime(player.position), "wall blocks police crime witnessing")
	_expect(not police.apply_player_attack(player.position,Vector3.BACK) and officer.health == 100, "player cannot punch an officer through a wall")
	wall.queue_free()
	await _step(3)

	# A driver is visible as their vehicle rather than through an invisible capsule.
	var car := _box(player.position+Vector3(0,0.7,0),Vector3(1.8,1.4,3.2))
	player.collision_layer = 0
	player.set_meta("driving",true)
	player.set_meta("vehicle_body",car)
	await _step(3)
	_expect(police.can_see_crime(player.position), "police can maintain sight of the identified driven vehicle")
	player.remove_meta("vehicle_body")
	_expect(not police.can_see_crime(player.position), "unrelated car geometry still occludes player")
	car.queue_free()
	player.collision_layer = 1
	player.set_meta("driving",false)
	await _step(3)

	var ped = NPC.new()
	ped.visual_enabled = false
	ped.configure(2,"calm",PackedVector3Array([Vector3(5,0.05,0)]))
	world.add_child(ped)
	ped.set_player(player)
	ped.set_physics_process(false)
	_expect(not ped.take_damage(30,player.position) and ped.health == 70, "civilian strike reports nonfatal injury separately from crime policy")
	ped.set_meta("mission_guard",true)
	_expect(not ped.take_damage(500,player.position) and ped.health == 70, "protected mission guard cannot be removed and block first bar mission")
	ped.remove_meta("mission_guard")
	player.movement_locked = true
	ped.take_damage(30,player.position)
	_expect(ped.health == 70, "protected performance player cannot damage civilians")
	player.movement_locked = false
	_expect(ped.take_damage(100,player.position) and ped.health == 0 and ped.collision_layer == 0, "civilian death is reported once and disables collision")
	_expect(not ped.take_damage(100,player.position), "already downed civilian cannot create duplicate death events")
	ped.set_simulation_enabled(false)
	ped.set_simulation_enabled(true)
	_expect(ped.collision_layer == 0 and not ped.is_physics_processing(), "population visibility cannot revive a downed pedestrian")

	world.queue_free()
	await process_frame
	print("WANTED: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _step(count:int)->void:
	for i in count:
		await physics_frame

func _box(position:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new()
	body.position=position
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	world.add_child(body)
	return body
