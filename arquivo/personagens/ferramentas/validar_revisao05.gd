extends SceneTree
var checks := 0
var failures := 0
var max_contact_error := 0.0
var max_joint_step := 0.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("REVIEW05 FAIL: " + message)
		failures += 1
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var prefix := "res://arquivo/personagens/emmet/revisao_05/"
	var contacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + "contactos.json"))
	for clip in ["01_carro", "02_mota", "03_bicicleta"]:
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
		check(skeleton != null and skeleton.get_bone_count() == 21, "approved 21 bones: " + clip)
		player.play(clip)
		var initial_feet := {}
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
			for joint in contacts[clip][frame].targets:
				var pose := skeleton.get_bone_global_pose(skeleton.find_bone(joint))
				var point := pose.origin + (pose.basis.y * .065 if joint.begins_with("hand.") else Vector3.ZERO)
				var actual := skeleton.global_transform * point
				var raw: Array = contacts[clip][frame].targets[joint].target
				var wanted := Vector3(raw[0], raw[2], -raw[1])
				var error := actual.distance_to(wanted)
				max_contact_error = maxf(max_contact_error, error)
				check(actual.is_finite() and error < .015, "%s frame %d %s error %.5f" % [clip, frame, joint, error])
				if clip == "01_carro" and joint.begins_with("foot.") and time < 2.7:
					if frame == 0:
						initial_feet[joint] = actual
					check(actual.distance_to(initial_feet[joint]) < .001, "car foot remains planted during opening")
		max_joint_step = maxf(max_joint_step, clip_joint_step)
		check(clip_joint_step < .15, "no abrupt joint-position jump: " + clip + " step=" + str(clip_joint_step))
		if clip == "01_carro":
			var door: Node3D = scene.find_child("Porta_condutor", true, false)
			player.seek(0, true); player.advance(0)
			var closed := door.basis.get_rotation_quaternion()
			player.seek(2.3, true); player.advance(0)
			check(closed.angle_to(door.basis.get_rotation_quaternion()) > 1., "car door opens while feet stay planted")
			player.seek(7.9, true); player.advance(0)
			check(closed.angle_to(door.basis.get_rotation_quaternion()) < .02, "car door closes")
		else:
			var vehicle: Node3D = scene.find_child("Inclinacao_veiculo", true, false)
			check(vehicle != null, "separate vehicle tilt animation")
			player.seek(2.5, true); player.advance(0)
			check(vehicle.basis.get_rotation_quaternion().get_angle() > .15, "vehicle tilts for mounting")
			player.seek(7.9, true); player.advance(0)
			check(vehicle.basis.get_rotation_quaternion().get_angle() < .02, "vehicle returns upright")
			var skin: MeshInstance3D
			for mesh in scene.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh.get_blend_shape_count() > 0:
					skin = mesh
			check(skin != null and skin.mesh.get_blend_shape_count() == 6, "six pose corrections for the clothing")
			var active_weights := 0.0
			for index in skin.mesh.get_blend_shape_count():
				active_weights += skin.get_blend_shape_value(index)
			check(active_weights > .99 and active_weights < 1.01, "clothing corrective is actually animated in the imported GLB")
		scene.queue_free()
		await process_frame
	var output := FileAccess.open(prefix + "validacao_godot.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "checks": checks, "failures": failures, "max_contact_error_m": max_contact_error, "max_joint_step_m": max_joint_step, "sample_fps": 24}, "\t"))
	output.close()
	print("REVIEW05 NATIVE: %d checks, %d failures; max contact error %.6f m" % [checks, failures, max_contact_error])
	quit(0 if failures == 0 else 1)
