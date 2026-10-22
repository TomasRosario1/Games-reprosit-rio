extends SceneTree
## Geometry-facing regression tests: a valid animation clip can still bend backwards.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LOCOMOTION: "+message)
func pose(visual: Node3D, clip: String, phase: float) -> void:
	var animation: AnimationPlayer = visual.animation_player
	animation.play(visual._clips[clip],0.0)
	animation.seek(animation.current_animation_length*phase,true)
	visual.skeleton.force_update_all_bone_transforms()
func _run() -> void:
	var visual: Node3D = load("res://scripts/character_visual.gd").new()
	root.add_child(visual)
	var rig: Skeleton3D = visual.skeleton
	pose(visual,"idle",0.0)
	var standing_head := rig.get_bone_global_pose(rig.find_bone("head")).origin.y
	var feet_forward := true
	var knees_forward := true
	var stationary_crouch_lowered := true
	var crouch_inside_capsule := true
	for clip in ["idle","walk","run","crouch","crouch_idle"]:
		for phase in [0.0,0.125,0.25,0.375,0.5,0.625,0.75,0.875]:
			pose(visual,clip,phase)
			for side in ["L","R"]:
				var hip: Vector3 = rig.get_bone_global_pose(rig.find_bone("thigh."+side)).origin
				var knee: Vector3 = rig.get_bone_global_pose(rig.find_bone("shin."+side)).origin
				var ankle: Transform3D = rig.get_bone_global_pose(rig.find_bone("foot."+side))
				feet_forward = feet_forward and ankle.basis.y.dot(Vector3.FORWARD)>0.70
				var closest := Geometry3D.get_closest_point_to_segment(knee,hip,ankle.origin)
				knees_forward = knees_forward and (knee-closest).dot(Vector3.FORWARD)>0.002
			if clip in ["crouch","crouch_idle"]:
				var head: Vector3 = rig.get_bone_global_pose(rig.find_bone("head")).origin
				stationary_crouch_lowered = stationary_crouch_lowered and head.y<standing_head-0.45
				crouch_inside_capsule = crouch_inside_capsule and head.y+0.25<1.31
	check(feet_forward,"both toes face the same -Z direction as the face across all gait phases")
	check(knees_forward,"knees bend forward rather than folding backwards across every sampled phase")
	check(stationary_crouch_lowered,"crouch lowers the head vertically by at least45cm, including stationary crouch")
	check(crouch_inside_capsule,"crouched scalp fits the low clearance of the physical capsule")
	var opposing_swing := true
	for phase in [0.0,0.25,0.5,0.75]:
		pose(visual,"walk",phase)
		var feet: float = rig.get_bone_global_pose(rig.find_bone("foot.L")).origin.z-rig.get_bone_global_pose(rig.find_bone("foot.R")).origin.z
		var hands: float = rig.get_bone_global_pose(rig.find_bone("hand.L")).origin.z-rig.get_bone_global_pose(rig.find_bone("hand.R")).origin.z
		opposing_swing = opposing_swing and feet*hands < -0.005
	check(opposing_swing,"opposite arm follows the leading leg instead of swinging a quarter-cycle late")
	var riding_forward := true
	var riding_knees := true
	for kind in ["car","motorbike","bicycle","scooter"]:
		visual.set_vehicle_pose(kind)
		for frame in 8:
			visual.animate(0.12,4.0)
			for side in ["L","R"]:
				var hip: Vector3 = rig.get_bone_global_pose(rig.find_bone("thigh."+side)).origin
				var knee: Vector3 = rig.get_bone_global_pose(rig.find_bone("shin."+side)).origin
				var ankle: Transform3D = rig.get_bone_global_pose(rig.find_bone("foot."+side))
				riding_forward = riding_forward and ankle.basis.y.dot(Vector3.FORWARD)>0.9
				var closest := Geometry3D.get_closest_point_to_segment(knee,hip,ankle.origin)
				riding_knees = riding_knees and (knee-closest).dot(Vector3.FORWARD)>0.002
	check(riding_forward,"car and all three riding poses retain forward-facing shoes")
	check(riding_knees,"car and riding poses bend knees forward through their movement")
	visual.set_vehicle_pose("")
	visual.animate(0.2,0,false,true)
	check(visual._current=="crouch_idle","holding Ctrl at rest uses dedicated bent idle, not a zero-speed standing pose")
	visual.animate(0.2,1.85)
	visual.animation_player.advance(0.23)
	var cycle_before: float = visual.animation_player.current_animation_position/visual.animation_player.current_animation_length
	visual.animate(0.02,4.6,true)
	var cycle_after: float = visual.animation_player.current_animation_position/visual.animation_player.current_animation_length
	check(absf(cycle_after-cycle_before)<0.04,"walk to run preserves normalized footfall phase")
	visual.animate(0.02,0,false,false,false,100,false,5)
	check(visual._current=="jump","ascending airborne player uses a jumping pose")
	visual.animate(0.02,0,false,false,false,100,false,-5)
	check(visual._current=="fall","descending airborne player uses a falling pose")
	var before: int = visual.model.get_instance_id()
	visual.setup(0)
	check(visual.model.get_instance_id()==before,"unchanged appearance does not rebuild the skinned rig during editor updates")
	await test_mounted_contacts(visual)
	visual.queue_free();await process_frame
	await test_stairs()
	print("LOCOMOTION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func test_mounted_contacts(visual: Node3D) -> void:
	for kind in ["car","motorbike","bicycle","scooter"]:
		var vehicle: Node3D = load("res://scripts/vehicle.gd").new()
		vehicle.type = kind;root.add_child(vehicle);vehicle.set_physics_process(false)
		var palm_error := 0.0
		var foot_error := 0.0
		var seat_error := 0.0
		var highest_scalp := 0.0
		# Cover the complete wardrobe and its adult height range, not only the
		# first avatar. Inspect world-space skinned joints against physical grips.
		for appearance in 20:
			visual.setup(appearance)
			vehicle.fit_rider(visual.get_body_height())
			visual.global_position = vehicle.get_seat_position()
			visual.set_vehicle_pose(kind)
			for frame in 8:
				if kind=="bicycle": vehicle._pedals.rotation.x=float(frame)*TAU/8.0
				var contacts: Dictionary = vehicle.get_rider_contacts()
				visual.set_vehicle_contacts(contacts);visual.animate(0.1,4.0)
				var rig: Skeleton3D = visual.skeleton
				var hip: Transform3D = rig.get_bone_global_pose(rig.find_bone("pelvis"))
				var expected_hip: float = vehicle.get_seat_position().y+0.96
				if kind=="scooter": expected_hip=rig.to_global(rig.get_bone_global_rest(rig.find_bone("pelvis")).origin).y
				seat_error=maxf(seat_error,absf(rig.to_global(hip.origin).y-expected_hip))
				var head: Transform3D = rig.get_bone_global_pose(rig.find_bone("head"))
				var scalp := head*(rig.get_bone_global_rest(rig.find_bone("head")).affine_inverse()*Vector3(0,1.88,0))
				highest_scalp=maxf(highest_scalp,rig.to_global(scalp).y)
				for side in ["L","R"]:
					var hand: Transform3D = rig.get_bone_global_pose(rig.find_bone("hand."+side))
					var palm := rig.to_global(hand.origin+hand.basis.y*0.055)
					palm_error=maxf(palm_error,palm.distance_to(visual.to_global(contacts["hand."+side])))
					var ankle: Transform3D = rig.get_bone_global_pose(rig.find_bone("foot."+side))
					foot_error=maxf(foot_error,rig.to_global(ankle.origin).distance_to(visual.to_global(contacts["foot."+side])))
		check(palm_error<0.035,kind+" palms reach the real wheel/handlebars for all20adult heights, error="+str(palm_error))
		check(foot_error<0.045,kind+" ankles remain on actual footrests/pedal cycle for all20heights, error="+str(foot_error))
		check(seat_error<0.002,kind+" different-height riders keep the physical seat/deck anchor")
		if kind=="car": check(highest_scalp<1.615,"tallest seated scalp fits inside actual car roof, y="+str(highest_scalp))
		visual.set_vehicle_pose("");vehicle.queue_free();await process_frame
	visual.setup(0);visual.position=Vector3.ZERO
func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	var collider := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=size;collider.shape=shape
	node.add_child(collider);root.add_child(node);node.position=at
	return node
func test_stairs() -> void:
	for action in ["move_left","move_right","move_forward","move_back","sprint","crouch","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
		Input.action_release(action)
	var ground := box(Vector3(0,-0.25,0),Vector3(14,0.5,30))
	var stairs: Array[Node3D] = []
	for index in 10:
		var height := float(index+1)*0.18
		stairs.append(box(Vector3(0,height*0.5,-1.5-float(index)*0.38),Vector3(2.0,height,0.38)))
	var player: CharacterBody3D = load("res://scripts/player.gd").new()
	root.add_child(player);player.global_position=Vector3(0,0.1,0)
	for frame in 15:await physics_frame
	Input.action_press("move_forward")
	for frame in 150:await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.z < -4.1 and player.global_position.y>1.4,"real player walks ten 18cm wooden risers without jumping, position=%s" % player.global_position)
	check(player.health==100 and not player._dead,"walking stairs does not cause fall damage or false death")
	player.respawn_at(Transform3D(Basis.IDENTITY,Vector3(4,0.1,0)))
	var high := box(Vector3(4,0.45,-1.5),Vector3(2,0.9,2))
	for frame in 8:await physics_frame
	Input.action_press("move_forward")
	for frame in 90:await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.z>-0.4,"step solver cannot turn a90cm wall into a climbable step")
	player._footsteps.stop();player.queue_free();ground.queue_free();high.queue_free()
	for step in stairs:step.queue_free()
	await process_frame
