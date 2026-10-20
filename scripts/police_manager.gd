class_name AlbumPoliceManager
extends Node3D
## Two original local officers. A crime needs a witness unless the officer is its target.
## Decisions are ticked by the main game; officer collision/locomotion uses physics ticks.

signal message(text: String)
signal player_damaged(amount: float)
const BATON_DAMAGE := 8.0
const PLAYER_PUNCH_DAMAGE := 30.0

class Officer extends CharacterBody3D:
	var health := 100.0
	var persistent := false
	var visual: Node3D
	var visuals_enabled := true
	var desired := Vector3.ZERO
	var look_direction := Vector3.ZERO
	var spawn_position := Vector3.ZERO
	var patrol := PackedVector3Array()
	var patrol_index := 0
	var attack_cooldown := 0.0
	var engage_time := 0.0
	var dead_time := 0.0
	var strike_time := 0.0
	var baton: Node3D
	var enabled := true
	var _arm_index := -1

	func _ready() -> void:
		add_to_group("album_police")
		set_meta("is_police", true)
		collision_layer = 2
		collision_mask = 3
		floor_snap_length = 0.30
		var shape := CapsuleShape3D.new()
		shape.radius = 0.36
		shape.height = 2.60
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 1.30
		add_child(collider)
		if visuals_enabled and ResourceLoader.exists("res://scripts/character_visual.gd"):
			var script: Script = load("res://scripts/character_visual.gd")
			visual = script.new()
			visual.set("appearance_id", 9)
			visual.scale = Vector3.ONE * 1.45
			add_child(visual)
			_add_baton()
			var label := Label3D.new()
			label.text = "POLÍCIA"
			label.font_size = 28
			label.pixel_size = 0.004
			label.outline_size = 1
			label.modulate = Color("d4d8d6")
			label.position = Vector3(0,1.87,0.17)
			label.rotation.y = PI
			add_child(label)

	func _add_baton() -> void:
		var skeleton: Skeleton3D = visual.get("skeleton")
		if not skeleton:
			return
		_arm_index = skeleton.find_bone("upper_arm.R")
		var socket := BoneAttachment3D.new()
		socket.bone_name = "hand.R"
		skeleton.add_child(socket)
		baton = Node3D.new()
		socket.add_child(baton)
		var mesh := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.022
		stick.bottom_radius = 0.026
		stick.height = 0.46
		stick.radial_segments = 8
		mesh.mesh = stick
		var material := StandardMaterial3D.new()
		material.albedo_texture = load("res://assets/textures/metal.png")
		material.albedo_color = Color("343b41")
		material.roughness = 0.85
		mesh.material_override = material
		mesh.position.y = 0.12
		baton.add_child(mesh)

	func set_enabled(value: bool) -> void:
		enabled = value
		visible = value
		set_physics_process(value and health > 0)
		collision_layer = 2 if value and health > 0 else 0
		collision_mask = 3 if value and health > 0 else 0
		if not value:
			velocity = Vector3.ZERO
			desired = Vector3.ZERO

	func _physics_process(delta: float) -> void:
		if health <= 0 or not enabled:
			return
		var intent := desired
		if intent.length_squared() > 0.1:
			var direction := intent.normalized()
			var origin := global_position + Vector3(0,1.0,0)
			var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*0.85,1,[get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				intent = Vector3(-direction.z,0,direction.x) * intent.length() * 0.55
		velocity.x = move_toward(velocity.x,intent.x,7.0*delta)
		velocity.z = move_toward(velocity.z,intent.z,7.0*delta)
		velocity.y = -0.5 if is_on_floor() else velocity.y-20.0*delta
		move_and_slide()
		var facing := look_direction if look_direction.length_squared()>0.01 else Vector3(velocity.x,0,velocity.z)
		if facing.length_squared()>0.02:
			rotation.y=lerp_angle(rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-5.0*delta))
		strike_time=maxf(0.0,strike_time-delta)
		if visual:
			var speed := Vector2(velocity.x,velocity.z).length()
			visual.call("animate",delta,speed,speed>2.1,false,false,100.0)
		if baton:
			baton.rotation.x = -sin(strike_time/0.45*PI)*1.4 if strike_time>0 else 0.0

	func patrol_intent() -> Vector3:
		if patrol.is_empty():
			return Vector3.ZERO
		var offset := patrol[patrol_index]-global_position
		offset.y=0
		if offset.length()<0.6:
			patrol_index=(patrol_index+1)%patrol.size()
			offset=patrol[patrol_index]-global_position
			offset.y=0
		return offset.normalized()*1.18

	func take_damage(amount:float,_source:Vector3)->bool:
		if health<=0 or amount<=0:
			return false
		health=maxf(0,health-amount)
		if visual:
			visual.call("react","hit")
		if health<=0:
			collision_layer=0
			collision_mask=0
			velocity=Vector3.ZERO
			desired=Vector3.ZERO
			set_physics_process(false)
			if visual:
				visual.rotation.z=PI*0.5
				visual.position.y=0.35
			return true
		return false

	func receive_bump(_from:Vector3,_strength:float)->void:
		# Ordinary contact never raises wanted heat. Main reports actual assaults.
		pass

	func revive_at_spawn()->void:
		health=100
		dead_time=0
		global_position=spawn_position+Vector3(0,0.1,0)
		velocity=Vector3.ZERO
		if visual:
			visual.rotation=Vector3.ZERO
			visual.position=Vector3.ZERO
		set_enabled(enabled)

var player: Node3D
var wanted: RefCounted
var enabled := true
var visuals_enabled := true
var officers: Array[CharacterBody3D] = []
var _last_seen_position := Vector3.ZERO
var _last_seen_age := 1000.0
var _attack_cooldown := 0.0
var _message_cooldown := 0.0
var _configured_routes: Array = []


func _ready()->void:
	var defaults:Array=[
		PackedVector3Array([Vector3(12,0.08,5),Vector3(12,0.08,-8),Vector3(20,0.08,-8),Vector3(20,0.08,5)]),
		PackedVector3Array([Vector3(35,0.08,-18),Vector3(40,0.08,-18),Vector3(40,0.08,8),Vector3(35,0.08,8)])]
	var selected:Array=_configured_routes if not _configured_routes.is_empty() else defaults
	for i in 2:
		var officer:=Officer.new()
		officer.name="PoliciaPersistente" if i==0 else "PoliciaTranquilo"
		officer.persistent=i==0
		officer.visuals_enabled=visuals_enabled
		officer.patrol=selected[i%selected.size()]
		officer.spawn_position=officer.patrol[0]
		officer.position=officer.spawn_position
		add_child(officer)
		officer.set_enabled(enabled)
		officers.append(officer)


func set_patrol_routes(routes:Array)->void:
	_configured_routes=routes
	if not officers.is_empty() and not routes.is_empty():
		for i in officers.size():
			officers[i].patrol=routes[i%routes.size()]
			officers[i].patrol_index=0


func set_player(body:Node3D)->void:
	player=body


func set_wanted(system:RefCounted)->void:
	wanted=system


func set_enabled(value:bool)->void:
	enabled=value
	for officer in officers:
		officer.set_enabled(value)


func get_heat()->float:
	return float(wanted.heat) if wanted else 0.0


func _protected_player()->bool:
	return not is_instance_valid(player) or (bool(player.get("movement_locked")) if "movement_locked" in player else false)


func _can_see_position(officer:CharacterBody3D,at:Vector3)->bool:
	if officer.health<=0 or not officer.enabled:
		return false
	var offset:=at-officer.global_position
	if offset.length_squared()>24.0*24.0 or absf(offset.y)>6.0:
		return false
	var horizontal:=Vector3(offset.x,0,offset.z)
	if horizontal.length()>1.0 and (-officer.global_basis.z).dot(horizontal.normalized())<0.14:
		return false
	var from:=officer.global_position+Vector3(0,2.1,0)
	var to:=at+Vector3(0,1.1,0)
	var ray:=PhysicsRayQueryParameters3D.create(from,to,3,[officer.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (is_instance_valid(player) and hit.collider==player):
		return true
	if is_instance_valid(player) and bool(player.get_meta("driving",false)):
		var vehicle:Variant=player.get_meta("vehicle_body") if player.has_meta("vehicle_body") else null
		return vehicle is CollisionObject3D and is_instance_valid(vehicle) and hit.collider==vehicle
	return false


func can_see_crime(position:Vector3)->bool:
	if not enabled:
		return false
	for officer in officers:
		if _can_see_position(officer,position):
			return true
	return false


func report_event(kind:String,witnessed:bool=true)->bool:
	if not wanted:
		return false
	var accepted:bool=wanted.record_event(kind,witnessed)
	if accepted and is_instance_valid(player):
		_last_seen_position=player.global_position
		_last_seen_age=0.0
	return accepted


func try_player_attack()->bool:
	if not is_instance_valid(player):
		return false
	var forward:Vector3=-player.global_basis.z
	if player.has_method("get_camera"):
		var camera:Camera3D=player.call("get_camera")
		if camera:
			forward=-camera.global_basis.z
	return apply_player_attack(player.global_position,forward)


func apply_player_attack(origin:Vector3,direction:Vector3)->bool:
	if not enabled or _protected_player() or _attack_cooldown>0.0:
		return false
	var forward:=Vector3(direction.x,0,direction.z).normalized()
	var nearest:CharacterBody3D
	var nearest_distance:=2.25
	for officer in officers:
		if officer.health<=0 or not officer.enabled:
			continue
		var offset:=officer.global_position-origin
		if absf(offset.y)>1.8:
			continue
		offset.y=0
		var distance:=offset.length()
		if distance<nearest_distance and (distance<0.4 or forward.dot(offset.normalized())>0.42):
			var from:=origin+Vector3(0,1.2,0)
			var ray:=PhysicsRayQueryParameters3D.create(from,officer.global_position+Vector3(0,1.3,0),1,[player.get_rid()] if player is CollisionObject3D else [])
			var obstruction:=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty():
				continue
			nearest=officer
			nearest_distance=distance
	if nearest==null:
		return false
	_attack_cooldown=0.48
	var killed:bool=nearest.take_damage(PLAYER_PUNCH_DAMAGE,origin)
	report_event("police_kill" if killed else "police_assault",true)
	return true


func tick(delta:float)->void:
	if not enabled or not wanted or not is_instance_valid(player):
		return
	if _protected_player():
		for officer in officers:
			officer.desired=Vector3.ZERO
		return
	_attack_cooldown=maxf(0,_attack_cooldown-delta)
	_message_cooldown=maxf(0,_message_cooldown-delta)
	_last_seen_age+=delta
	var seen:=can_see_crime(player.global_position)
	if seen:
		_last_seen_position=player.global_position
		_last_seen_age=0.0
	wanted.update(delta,seen)
	for officer in officers:
		officer.attack_cooldown=maxf(0,officer.attack_cooldown-delta)
		if officer.health<=0:
			officer.dead_time+=delta
			if officer.dead_time>35.0 and officer.global_position.distance_to(player.global_position)>25.0:
				officer.revive_at_spawn()
			continue
		var pursuit:=get_heat()>0 and _last_seen_age<(22.0 if officer.persistent else 9.0)
		if not pursuit:
			officer.engage_time=0
			officer.look_direction=Vector3.ZERO
			officer.desired=officer.patrol_intent()
			continue
		var target:=_last_seen_position-officer.global_position
		target.y=0
		officer.look_direction=target
		var near:=target.length()<1.9 and _can_see_position(officer,player.global_position)
		if near:
			officer.desired=Vector3.ZERO
			officer.engage_time+=delta
			if _message_cooldown<=0:
				message.emit("POLÍCIA / Pára aí!")
				_message_cooldown=9.0
			if officer.engage_time>0.85 and officer.attack_cooldown<=0 and not bool(player.get_meta("driving",false)):
				officer.attack_cooldown=1.8
				officer.strike_time=0.45
				if officer.visual:
					officer.visual.call("react","talk")
				_damage_player(BATON_DAMAGE)
		else:
			officer.engage_time=0
			officer.desired=target.normalized()*(3.0 if officer.persistent else 2.65) if target.length()>0.65 else Vector3.ZERO


func _damage_player(amount:float)->void:
	if _protected_player() or bool(player.get_meta("driving",false)):
		return
	if "health" in player:
		player.health=maxf(0,float(player.health)-amount)
		player_damaged.emit(amount)
		if player.health<=0 and player.has_method("_die"):
			player.call("_die")
