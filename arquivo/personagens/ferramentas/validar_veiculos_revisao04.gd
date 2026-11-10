extends SceneTree
## Compare native imported animation against the actual Blender contact samples.
var checks := 0
var failures := 0
var max_error := 0.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("REVIEW04 FAIL: " + message)
		failures += 1
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var prefix := "res://arquivo/personagens/emmet/revisao_04/"
	var contacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + "contactos.json"))
	for clip in ["04_montar_bicicleta", "05_subir_trotinete"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file(prefix + clip + ".glb", state) == OK, "GLB import: " + clip)
		var scene: Node3D = document.generate_scene(state, 24.0)
		root.add_child(scene)
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		check(player != null and player.has_animation(clip), "named animation: " + clip)
		check(player.get_animation_list().size() == 1, "one animation only: " + clip)
		check(absf(player.get_animation(clip).length - 191.0 / 24.0) < .02, "duration: " + clip)
		var skeleton: Skeleton3D
		for node in scene.find_children("*", "Skeleton3D", true, false):
			skeleton = node
		check(skeleton != null and skeleton.get_bone_count() == 21, "21 approved bones: " + clip)
		player.play(clip)
		for frame in 192:
			player.seek(float(frame) / 24.0, true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			var sample: Dictionary = contacts[clip][frame]
			for joint in sample.targets:
				var bone := skeleton.find_bone(joint)
				var pose := skeleton.get_bone_global_pose(bone)
				var actual := skeleton.global_transform * (pose.origin + (pose.basis.y * .065 if joint.begins_with("hand.") else Vector3.ZERO))
				var raw: Array = sample.targets[joint].target
				var expected := Vector3(raw[0], raw[2], -raw[1])
				var error := actual.distance_to(expected)
				max_error = maxf(max_error, error)
				check(actual.is_finite() and error < .015, "%s frame %d %s contact error %.5f" % [clip, frame, joint, error])
		# Physical final targets are independent of the generated diagnostics.
		for side in ["L", "R"]:
			var sign_side := 1.0 if side == "L" else -1.0
			var pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand." + side))
			var palm := skeleton.global_transform * (pose.origin + pose.basis.y * .065)
			var wanted := Vector3(sign_side * .29, 1.16, .33) if clip == "04_montar_bicicleta" else Vector3(sign_side * .28, 1.33, .42)
			check(palm.distance_to(wanted) < .015, "final palm on the actual handlebar: " + clip + side)
		scene.queue_free()
		await process_frame
	var file := FileAccess.open(prefix + "validacao_godot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "checks": checks, "failures": failures, "max_contact_error_m": max_error, "sample_fps": 24}, "\t"))
	file.close()
	print("REVIEW04 NATIVE GLTF: %d checks, %d failures; max contact error %.6f m" % [checks, failures, max_error])
	quit(0 if failures == 0 else 1)
