extends SceneTree
## Asset readiness checks for every original adult in the catalogue.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found := find_type(child, type_name)
		if found: return found
	return null

func _run() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/catalog.json"))
	check(entries.size() == 20, "Catalogue contains twenty original adults")
	var men := 0
	var women := 0
	var wardrobes := {}
	for entry in entries:
		men += 1 if entry.gender == "male" else 0
		women += 1 if entry.gender == "female" else 0
		wardrobes[entry.outfit] = true
		var packed: PackedScene = load(entry.scene)
		check(packed != null, "Load GLB: " + entry.name)
		if not packed: continue
		var body := packed.instantiate()
		root.add_child(body)
		var rig := find_type(body, "Skeleton3D") as Skeleton3D
		var animation := find_type(body, "AnimationPlayer") as AnimationPlayer
		var mesh_node := find_type(body, "MeshInstance3D") as MeshInstance3D
		check(rig != null and rig.get_bone_count() >= 18, "Articulated limbs: " + entry.name)
		check(mesh_node != null and mesh_node.mesh is ArrayMesh, "Triangulated human mesh: " + entry.name)
		if mesh_node:
			check(mesh_node.skin != null, "Mesh has actual skin bindings: " + entry.name)
			var arrays := mesh_node.mesh.surface_get_arrays(0)
			check(not arrays[Mesh.ARRAY_BONES].is_empty() and not arrays[Mesh.ARRAY_WEIGHTS].is_empty(), "Vertices carry bone weights: " + entry.name)
			var material: Material = mesh_node.mesh.surface_get_material(0)
			check(material is StandardMaterial3D and material.albedo_texture != null, "Textured PBR surface: " + entry.name)
		check(animation != null and animation.get_animation_list().size() >= 7, "Idle/locomotion/reaction/performance clips: " + entry.name)
		body.queue_free()
		await process_frame
	check(men == 10 and women == 10, "Ten men and ten women")
	check(wardrobes.size() >= 12, "Wardrobe has silhouette combinations rather than just colour swaps")
	var visual = load("res://scripts/character_visual.gd").new()
	root.add_child(visual)
	visual.animate(0.1, 1.6)
	visual.animation_player.advance(0.3)
	var hand: int = visual.skeleton.find_bone("hand.R")
	var before: Transform3D = visual.skeleton.get_bone_global_pose(hand)
	visual.animation_player.advance(0.3)
	var after: Transform3D = visual.skeleton.get_bone_global_pose(hand)
	check(not before.is_equal_approx(after), "Walking changes the actual arm/hand skeleton")
	visual.set_vehicle_pose("car")
	visual.animate(0.1, 0.0)
	var thigh: int = visual.skeleton.find_bone("thigh.R")
	check(visual.skeleton.get_bone_pose_rotation(thigh).get_angle() > 0.8, "Driving bends articulated hips instead of hiding the avatar")
	visual.set_vehicle_pose("bicycle")
	visual.animate(0.1, 4.0)
	var pedal_before: Quaternion = visual.skeleton.get_bone_pose_rotation(thigh)
	visual.animate(0.3, 4.0)
	check(not pedal_before.is_equal_approx(visual.skeleton.get_bone_pose_rotation(thigh)), "Bicycle pedalling moves articulated legs")
	visual.set_vehicle_pose("")
	visual.animate(0.1, 0.0)
	check(visual.animation_player.active, "Leaving a vehicle restores locomotion animation")
	visual.queue_free()
	await process_frame
	print("CHARACTERS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
