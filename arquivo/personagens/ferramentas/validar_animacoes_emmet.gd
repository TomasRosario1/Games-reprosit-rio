extends SceneTree
# Import the archived GLBs directly, without installing them in the game project.
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		push_error("REVIEW03 FAIL: "+text)
		failures += 1
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for clip in ["01_andar","02_entrar_carro","03_montar_mota"]:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		check(doc.append_from_file("res://arquivo/personagens/emmet/revisao_03/"+clip+".glb",state)==OK,"GLB imports: "+clip)
		var scene: Node3D = doc.generate_scene(state,24.0)
		root.add_child(scene)
		var player: AnimationPlayer = scene.find_child("AnimationPlayer",true,false)
		check(player!=null,"animation player: "+clip)
		check(player.has_animation(clip),"named clip present: "+clip)
		check(absf(player.get_animation(clip).length-191.0/24.0)<.02,"duration: "+clip)
		var skeleton: Skeleton3D
		for node in scene.find_children("*","Skeleton3D",true,false):skeleton=node
		check(skeleton!=null and skeleton.get_bone_count()==21,"approved 21-bone rig: "+clip)
		player.play(clip)
		var last_feet := {};var stance := {};var max_slip := 0.0
		for frame in 192:
			var t := float(frame)/24.0
			player.seek(t,true);player.advance(0)
			skeleton.force_update_all_bone_transforms()
			var head := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
			check(head.is_finite() and head.length()<30,"finite bounded animated skeleton: "+clip)
			if clip=="01_andar":
				for side in ["L","R"]:
					var phase := fposmod(t/.9+(0.0 if side=="L" else .5),1.0)
					var foot := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("foot."+side)).origin
					var planted := phase<.59
					if planted and stance.get(side,false):
						var previous: Vector3=last_feet[side]
						max_slip=maxf(max_slip,Vector2(foot.x,foot.z).distance_to(Vector2(previous.x,previous.z)))
					last_feet[side]=foot;stance[side]=planted
		if clip=="01_andar":check(max_slip<.003,"feet remain planted horizontally, slip=%f"%max_slip)
		if clip=="02_entrar_carro":
			var hinge: Node3D=scene.find_child("Porta_condutor",true,false)
			check(hinge!=null,"real hinged door exists")
			player.seek(0,true);player.advance(0);var closed := hinge.transform.basis
			player.seek(3,true);player.advance(0)
			check(closed.get_rotation_quaternion().angle_to(hinge.transform.basis.get_rotation_quaternion())>.9,"door really opens")
			player.seek(7.9,true);player.advance(0)
			check(closed.get_rotation_quaternion().angle_to(hinge.transform.basis.get_rotation_quaternion())<.03,"door closes at the end")
		if clip!="01_andar":
			player.seek(7.5,true);player.advance(0);skeleton.force_update_all_bone_transforms()
			for side in ["L","R"]:
				var sign_side:=1.0 if side=="L" else -1.0
				var hand_pose:=skeleton.get_bone_global_pose(skeleton.find_bone("hand."+side))
				var palm:=skeleton.global_transform*(hand_pose.origin+hand_pose.basis.y*.065)
				var expected_palm:=Vector3(.35+sign_side*.16,1.04,.28) if clip=="02_entrar_carro" else Vector3(sign_side*.30,1.15,.52)
				check(palm.distance_to(expected_palm)<.02,"exported hand reaches wheel/grip: "+clip+side)
				var ankle:=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("foot."+side)).origin
				var expected_ankle:=Vector3(.51 if side=="L" else .19,.46,.55) if clip=="02_entrar_carro" else Vector3(sign_side*.30,.535,-.05)
				check(ankle.distance_to(expected_ankle)<.02,"exported foot reaches floor/peg: "+clip+side)
		scene.queue_free();await process_frame
	print("REVIEW03 NATIVE GLTF: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
