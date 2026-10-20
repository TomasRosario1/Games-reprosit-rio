extends SceneTree
const EDITOR = preload("res://scripts/world_editor.gd")
var checks := 0
var failures := 0
var skipped := 0
var world: Node3D
var editor: AlbumWorldEditor
var wall: MeshInstance3D
var batch: MultiMeshInstance3D
var wall_id := ""
var batch_id := ""
var fixture_material: StandardMaterial3D
var vehicle: CharacterBody3D
var vehicle_id := ""

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("EDITOR FAIL: "+description)

func _run() -> void:
	for path in ["user://editor_test.json","user://editor_test.json.bak","user://editor_test.json.tmp","user://editor_test.json.bak.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	world = Node3D.new()
	root.add_child(world)
	fixture_material = StandardMaterial3D.new()
	fixture_material.albedo_texture = load("res://assets/textures/stucco.png")
	wall = MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.mesh.size = Vector3(2,2,0.3)
	wall.material_override = fixture_material
	wall.position = Vector3(0,1,0)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wall.mesh.size
	collision.shape = shape
	body.add_child(collision)
	wall.add_child(body)
	world.add_child(wall)
	batch = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 2
	mm.set_instance_transform(0,Transform3D(Basis(),Vector3(6,1,0)))
	mm.set_instance_transform(1,Transform3D(Basis(),Vector3(10,1,0)))
	batch.multimesh = mm
	batch.material_override = fixture_material
	world.add_child(batch)
	vehicle = load("res://scripts/vehicle.gd").new()
	vehicle.configure("car")
	vehicle.position = Vector3(18,0.2,0)
	world.add_child(vehicle)
	var player := Node3D.new()
	world.add_child(player)
	var camera := Camera3D.new()
	player.add_child(camera)
	camera.position = Vector3(0,3,8)
	camera.current = true
	editor = EDITOR.new()
	editor.save_path = "user://editor_test.json"
	root.add_child(editor)
	editor.configure(world,player)
	check(editor.targets.size() == 4,"indexes a collider-bearing mesh and each individual batch instance")
	for id in editor.targets:
		if editor.targets[id].node == wall: wall_id = id
		elif editor.targets[id].instance == 0: batch_id = id
		elif editor.targets[id].node == vehicle: vehicle_id = id
	check(not wall_id.is_empty() and not batch_id.is_empty(),"stable identifiers available")
	var window: MeshInstance3D = vehicle.visual.get_child(1)
	var original_window: Material = window.material_override
	check(not vehicle_id.is_empty() and editor.edit_target(vehicle_id,{"color":"b95f85ff","preset":"metal"}),"default world vehicle is individually editable")
	check(vehicle.visual.get_child(0).material_override.albedo_color.is_equal_approx(Color("b95f85")),"vehicle body receives new paint")
	check(window.material_override == original_window,"vehicle paint preserves glass and unrelated materials")
	editor.enter_editor()
	check(editor.active and editor.camera.current,"creator camera takes control")
	check(editor.edit_target(wall_id,{"position":[3.0,1.0,0.0],"rotation":[0.0,30.0,0.0],"scale":[1.5,1.0,1.0]}),"numeric transform edit accepted")
	await physics_frame
	check(wall.global_position.is_equal_approx(Vector3(3,1,0)),"mesh moves to inspector position")
	check(body.global_position.is_equal_approx(wall.global_position),"child physics collider moves with edited wall")
	check(editor.undo() and wall.global_position.is_equal_approx(Vector3(0,1,0)),"undo restores actual mesh and collision transform")
	check(editor.redo() and wall.global_position.is_equal_approx(Vector3(3,1,0)),"redo reapplies transform")
	check(editor.edit_target(batch_id,{"position":[7,2,1]}),"individual instanced prop can be moved")
	if DisplayServer.get_name() != "headless":
		check(batch.multimesh.get_instance_transform(0).origin.is_equal_approx(Vector3(7,2,1)),"MultiMesh instance receives changed transform")
		check(batch.multimesh.get_instance_transform(1).origin.is_equal_approx(Vector3(10,1,0)),"neighbor instance remains unchanged")
	else:
		skipped += 2
		print("SKIP:2 renderer-backed MultiMesh transform reads unavailable in Godot's dummy headless renderer; run native under Xvfb.")
	check(editor.edit_target(batch_id,{"color":"ff3355ff","preset":"wood"}),"individual batch material override accepted")
	check(editor._overrides.has(batch_id),"batch material edit splits only the selected visual instance")
	check(batch.material_override == fixture_material,"batch neighbors retain original material")
	check(not editor.edit_target(wall_id,{"position":[NAN,0,0]}),"nonfinite transform rejected")
	check(not editor.edit_target(wall_id,{"scale":[-1,1,1]}),"negative and collapsing scale rejected")
	check(not editor.edit_target(wall_id,{"script":"print('x')"}),"arbitrary scripts cannot be assigned by data edit")
	editor.select_target(wall_id)
	editor.delete_selected()
	check(not wall.visible and body.collision_layer == 0,"deleting base wall also disables collider")
	check(editor.undo() and wall.visible and body.collision_layer == 1,"undo deletion restores collider")
	editor.select_target(wall_id)
	editor.duplicate_selected()
	var duplicate_id := editor.selected_id
	check(duplicate_id.begins_with("added/"),"base box geometry can be duplicated into persistent catalog")
	var duplicate: Node3D = editor.targets[duplicate_id].node
	check(duplicate.global_position.is_equal_approx(Vector3(4,1,0)),"duplicate preserves geometry pivot and adds horizontal offset")
	var wall_added := editor.spawn_catalog("Parede",Vector3(12,0,0))
	check(not wall_added.is_empty(),"wall catalog creates a real object")
	var added_node: Node3D = editor.targets[wall_added].node
	check(added_node.get_child(0) is StaticBody3D,"placed wall has real physics")
	editor.select_target(wall_added)
	editor.delete_selected()
	check(added_node.get_child(0).collision_layer == 0,"removing placed object disables nested collider")
	editor.undo()
	check(added_node.visible and added_node.get_child(0).collision_layer == 1,"undo placed-object deletion restores collision")
	var light_id := editor.spawn_catalog("Luz",Vector3(4,3,4))
	check(editor.edit_target(light_id,{"color":"ffaa88ff","energy":2.5,"range":9.0}),"light color and physical light properties editable")
	var light: OmniLight3D = editor.targets[light_id].node
	check(is_equal_approx(light.light_energy,2.5) and is_equal_approx(light.omni_range,9.0),"light edits change actual renderer node")
	var mission_id := editor.spawn_catalog("Missão",Vector3(1,0,4))
	check(editor.edit_target(mission_id,{"mission":{"title":"Encontro no Saldanha","kind":"encontro","reward":80,"completed":false}}),"mission parameters edited as data")
	check(editor.get_nearest_mission(Vector3(1,0,4)).id == mission_id,"new mission is discoverable near its real world position")
	var reward := editor.interact_mission(mission_id)
	check(reward.reward == 80 and reward.completed,"mission can complete and reports configured reward")
	check(editor.interact_mission(mission_id).is_empty(),"completed mission cannot pay twice")
	check(editor.spawn_catalog("GLB",Vector3.ZERO,{},"/etc/passwd").is_empty(),"GLB importer rejects paths outside project")
	var before_preview: Array = editor.get_target_state(wall_id).position
	check(editor.preview_actions([{"id":wall_id,"position":[6,1,0]}]),"structured AI proposal can be previewed without model")
	check(wall.global_position.is_equal_approx(Vector3(6,1,0)),"AI preview is visible in scene")
	check(not editor.save_world(),"unconfirmed AI preview is not saved")
	editor.cancel_ai_preview()
	check(editor.get_target_state(wall_id).position == before_preview,"cancel restores exact pre-preview state")
	check(not editor.preview_actions([{"id":wall_id,"position":[5,1,0]},{"id":"unknown","color":"ffffffff"}]),"proposal validation rejects entire batch if one ID is invalid")
	check(editor.get_target_state(wall_id).position == before_preview,"invalid proposal has no partial effects")
	check(editor.preview_actions([{"id":wall_id,"position":[5,1,0]}]) and editor.apply_ai_preview(),"valid preview can be applied")
	check(editor.undo() and editor.get_target_state(wall_id).position == before_preview,"AI apply creates one undo transaction")
	check(editor.save_world(),"editor world JSON saved")
	check(editor.edit_target(wall_id,{"position":[20,1,0]}) and editor.load_world(),"saved world can be loaded after further edits")
	check(editor.get_target_state(wall_id).position == before_preview,"load restores base geometry edits")
	check(editor.targets.has(mission_id) and editor.interact_mission(mission_id).is_empty(),"mission completion survives world save/load")
	check(editor.save_world(),"second save preserves valid backup")
	var file := FileAccess.open(editor.save_path,FileAccess.WRITE)
	file.store_string('{"version":1,"base":{},"added":{"added/99":{"catalog":"Parede","resource":"","state":{}}}}')
	file.close()
	check(editor.load_world(),"corrupt incomplete state falls back to valid backup")
	file = FileAccess.open(editor.save_path+".bak",FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var preserved := editor.get_target_state(wall_id)
	check(not editor.load_world(),"two invalid snapshots do not load")
	check(editor.get_target_state(wall_id) == preserved,"failed load preserves current scene")
	editor.exit_editor()
	check(not editor.active and camera.current,"leaving editor restores game camera")
	print("EDITOR: %d checks, %d failures, %d renderer checks skipped" % [checks,failures,skipped])
	editor.queue_free()
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
