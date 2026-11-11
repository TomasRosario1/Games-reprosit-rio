extends SceneTree
var checks := 0
var failures := 0
var max_contact_error := 0.0
var max_left_grip_error := 0.0
var max_joint_step := 0.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("REVIEW06 FAIL: " + message)
		failures += 1
func _initialize() -> void:
	call_deferred("_run")
func converted(raw: Array) -> Vector3:
	return Vector3(raw[0], raw[2], -raw[1])
func _run() -> void:
	var prefix := "res://arquivo/personagens/emmet/revisao_06/"
	var contacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + "contactos.json"))
	for clip in ["01_mota", "02_bicicleta"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file(prefix + clip + ".glb", state) == OK, "import: " + clip)
		var scene: Node3D = document.generate_scene(state, 24.0)
		root.add_child(scene)
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		check(player != null and player.has_animation(clip), "named clip: " + clip)
		check(player.get_animation_list().size() == 1, "one merged animation: " + clip)
		check(absf(player.get_animation(clip).length - 191.0 / 24.0) < .02, "duration: " + clip)
		var skeleton: Skeleton3D
		for node in scene.find_children("*", "Skeleton3D", true, false):
			skeleton = node
		check(skeleton != null and skeleton.get_bone_count() == 21, "approved bones: " + clip)
		var vehicle: Node3D = scene.find_child("Inclinacao_pela_mao_esquerda", true, false)
		check(vehicle != null, "separate tilt pivot")
		var skin: MeshInstance3D
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh.get_blend_shape_count() > 0:
				skin = mesh
		check(skin != null, "animated grip and clothing")
		var grip_index := -1
		for index in skin.mesh.get_blend_shape_count():
			if skin.mesh.get_blend_shape_name(index) == "Mao_esquerda_pega":
				grip_index = index
		check(grip_index >= 0, "left-finger grip morph")
		player.play(clip)
		var previous_joints := {}
		var clip_joint_step := 0.0
		for frame in 192:
			var time := float(frame) / 24.0
			player.seek(time, true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			for index in skeleton.get_bone_count():
				var position := skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
				if previous_joints.has(index):
					clip_joint_step = maxf(clip_joint_step, position.distance_to(previous_joints[index]))
				previous_joints[index] = position
			var record: Dictionary = contacts[clip][frame]
			for joint in record.targets:
				var pose := skeleton.get_bone_global_pose(skeleton.find_bone(joint))
				var point := pose.origin + (pose.basis.y * .065 if joint.begins_with("hand.") else Vector3.ZERO)
				var actual := skeleton.global_transform * point
				var error := actual.distance_to(converted(record.targets[joint].target))
				max_contact_error = maxf(max_contact_error, error)
				check(actual.is_finite() and error < .015, "%s frame %d %s error %.5f" % [clip, frame, joint, error])
				if joint == "hand.L" and time >= 1.0:
					max_left_grip_error = maxf(max_left_grip_error, error)
					check(error < .006, "left palm follows handlebar")
			for pair in [["thigh.R", "right_hip"], ["shin.R", "right_knee"], ["foot.R", "right_ankle"]]:
				var point := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(pair[0])).origin
				check(point.distance_to(converted(record[pair[1]])) < .001, "export preserves fitted right-leg path")
			check(absf(skin.get_blend_shape_value(grip_index) - float(record.left_grip)) < .002, "left-finger grip exports at correct time")
			if time <= 1.15:
				check(vehicle.basis.get_rotation_quaternion().get_angle() < .001, "left hand grasps before vehicle tilts")
			if time >= 1.083:
				check(skin.get_blend_shape_value(grip_index) > .99, "left fingers remain closed")
		max_joint_step = maxf(max_joint_step, clip_joint_step)
		check(clip_joint_step < .15, "continuous joints: " + clip + " step=" + str(clip_joint_step))
		player.seek(2.5, true); player.advance(0)
		check(vehicle.basis.get_rotation_quaternion().get_angle() > .15, "vehicle visibly tilted for leg clearance")
		player.seek(7.9, true); player.advance(0)
		check(vehicle.basis.get_rotation_quaternion().get_angle() < .02, "vehicle returns upright")
		scene.queue_free()
		await process_frame
	var output := FileAccess.open(prefix + "validacao_godot.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "checks": checks, "failures": failures, "max_contact_error_m": max_contact_error, "max_left_grip_error_m": max_left_grip_error, "max_joint_step_m": max_joint_step, "sample_fps": 24}, "\t"))
	output.close()
	print("REVIEW06 NATIVE: %d checks, %d failures; max left grip error %.6f m" % [checks, failures, max_left_grip_error])
	quit(0 if failures == 0 else 1)
