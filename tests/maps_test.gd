extends SceneTree
## Production map data, physical connections, streaming edits and save/music integration.
var game: Node3D
var city: Node3D
var checks := 0
var failures := 0
var screenshots := false
var body: CharacterBody3D
func _initialize() -> void:
	Engine.max_fps = 0 if DisplayServer.get_name()=="headless" else 60
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAPS: "+message)
func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	create_timer(150).timeout.connect(func(): push_error("Maps test timeout"); quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._begin_exploration(0)
	game._set_world_paused(true)
	game.player.set_physics_process(false)
	game.world.process_mode = Node.PROCESS_MODE_INHERIT
	city = game.world.imported_city
	city.set_process(false)
	game._editor.save_path = "user://maps_edits.json"
	check(city.manifest.districts.size()==3 and city.manifest.sectors.size()==90,"three uploaded districts split into 90 sectors")
	check(game.world._population.peds.size()==80,"persistent pools reuse twenty appearances across four regions")
	check(game.world.get_editor_bookmarks().size()==7,"editor exposes new district and river bookmarks, preserving three old views")
	var old_id := ""
	var old_sector := ""
	var changed_position: Array = []
	for district in city.manifest.districts:
		var at := Vector3(district.spawn[0],0.1,district.spawn[1])
		game.world.ensure_position(at)
		await physics_frame
		check(city.loaded.size()>0 and city.loaded.size()<60,"nearby sectors load without loading all districts")
		check(game.world.is_valid_save_position(at),"save validator accepts "+str(district.id))
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*2,1))
		check(not hit.is_empty() and absf(hit.position.y)<0.1,"focus street has walkable ground: "+str(district.id))
		var roof_checked := false
		for sector_spec in city.manifest.sectors:
			if not city.loaded.has(sector_spec.id) or sector_spec.district!=district.id: continue
			var sector_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sector_spec.path))
			if sector_data.buildings.is_empty(): continue
			var building: Dictionary = sector_data.buildings[0]
			var roof: Array = building.roof
			var center := Vector3(building.position[0]+(roof[0][0]+roof[1][0]+roof[2][0])/3,building.height,building.position[1]+(roof[0][1]+roof[1][1]+roof[2][1])/3)
			var roof_hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP*0.5,1))
			check(not roof_hit.is_empty(),"roof front face collides from above: "+str(district.id))
			roof_checked = true
			break
		check(roof_checked,"at least one roof tested in "+str(district.id))
		game.player.global_position = at
		game.world._population.set_enabled(true)
		game.world._population._refresh_membership()
		check(game.world.get_population_count()>0 and game.world.get_population_count()<=game.world._population.budget,"one population budget in "+str(district.id))
		game._update_audio(0.5)
		check(game.music.playing and game._ambient_song==int(district.music.song),"local loop resumes correct demo track: "+str(district.id))
		if district.id=="saldanha":
			for id in game._editor.targets:
				if str(id).begins_with("base/osm/saldanha/way_"):
					old_id = id
					old_sector = str(game._editor.targets[id].node.get_meta("map_sector"))
					var state: Dictionary = game._editor.get_target_state(id)
					changed_position = state.position.duplicate()
					changed_position[1] += 1.0
					break
			check(not old_id.is_empty(),"OSM buildings registered as stable whole-object editor targets")
			check(game._editor.edit_target(old_id,{"position":changed_position}),"can edit imported building with collision")
			check(game._editor.save_world(),"imported edit saved locally")
		else:
			check(not city.loaded.has(old_sector) and not game._editor.targets.has(old_id),"distant geometry and live editor target unloaded")
			check(game._editor.get_target_state(old_id).position==changed_position,"unloaded edit remains available to history")
		var forward := (Vector3(district.look_at[0],0,district.look_at[1])-Vector3(at.x,0,at.z)).normalized()
		await _capture(str(district.id),at-forward*5+Vector3.UP*2.5,at+forward*15+Vector3.UP*1.8)
	check(game._editor.load_world(),"world save loads while edited sector is absent")
	var saldanha: Dictionary = city.manifest.districts[0]
	game.world.ensure_position(Vector3(saldanha.spawn[0],0,saldanha.spawn[1]))
	check(game._editor.targets.has(old_id) and game._editor.get_target_state(old_id).position==changed_position,"edited building restored after sector reload")
	game._editor.edit_target(old_id,{"position":[changed_position[0],2.0,changed_position[2]]})
	game.world.ensure_position(Vector3(240,0,870))
	check(game._editor.undo(),"undo still works while edited object is unloaded")
	game.world.ensure_position(Vector3(saldanha.spawn[0],0,saldanha.spawn[1]))
	check(game._editor.get_target_state(old_id).position==changed_position,"unloaded undo applied on reload")
	var moved := [changed_position[0],1.0,870.0]
	game._editor.edit_target(old_id,{"position":moved})
	game.world.ensure_position(Vector3(moved[0],0,moved[2]))
	check(city.loaded.has(old_sector) and game._editor.get_target_state(old_id).position==moved,"building moved to a different district streams at edited position")
	game._editor.undo()
	# Manual load uses the real main save path, beyond the old +/-100 metre limits.
	var pink: Dictionary = city.manifest.districts[2]
	var saved_at := Vector3(pink.spawn[0],0.12,pink.spawn[1])
	game.player.global_position = saved_at
	game.store.money = 724
	game._manual_save()
	game.player.global_position = Vector3.ZERO
	game._manual_load()
	check(game.player.global_position.distance_to(saved_at+Vector3.UP*0.1)<0.01 and game.store.money==724,"manual load restores new district and progress")
	# A bookmarked district can be tested on foot, with dirty-world protection.
	game._editor_unlocked = true
	game._request_editor()
	var plaza_view: Dictionary = game.world.get_editor_bookmarks()[3]
	game._editor.camera.global_position = plaza_view.position
	game.world.ensure_position(game._editor.camera.global_position)
	game._editor.camera.look_at(plaza_view.target)
	if screenshots and DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/album-maps-editor.png")==OK,"native editor screenshot")
	game._editor.request_test_district()
	check(game._editor._exit_dialog.visible and game._editor.active,"testing another district preserves unsaved-world confirmation")
	game._editor._save_and_exit()
	check(game.state=="explore" and game.player.global_position.distance_to(Vector3(saldanha.spawn[0],0.15,saldanha.spawn[1]))<0.01,"creator test button starts play safely in selected district")
	check(game._safe_transform.origin.is_equal_approx(game.player.global_position),"testing sets a nearby safe respawn")
	game._set_world_paused(true)
	check(not game.world.is_valid_save_position(Vector3(800,0,700)) and not game.world.is_valid_save_position(Vector3(NAN,0,0)),"save validator rejects gaps and non-finite positions")
	var inactive := 0
	var animations_suspended := true
	for ped in game.world._population.peds:
		if not ped.simulation_enabled:
			inactive += 1
			animations_suspended = animations_suspended and ped.visual.process_mode==Node.PROCESS_MODE_DISABLED
	check(animations_suspended,"every distant NPC animation is suspended")
	check(inactive>20,"remote NPCs do not all animate or simulate")
	# Paused CollisionObject3D nodes are removed from the physics space by Godot.
	# Restore the world for actual traversal, but keep NPCs and controls stopped.
	game.world.process_mode = Node.PROCESS_MODE_INHERIT
	game.world.set_npcs_enabled(false)
	await physics_frame
	# Physically traverse connectors, bends and crop joins with a capsule.
	body = CharacterBody3D.new()
	body.floor_snap_length = 0.4
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.28; capsule.height = 1.8
	collision.shape = capsule; collision.position.y = 0.9
	body.add_child(collision); root.add_child(body)
	for link in city.manifest.links:
		var first: Array = link.points[0]
		body.global_position = Vector3(first[0],0.1,first[1])
		for point in link.points:
			var at := Vector3(point[0],0,point[1])
			game.world.ensure_position(at)
			await _walk_to(at)
	# Both ramps and the full bridge deck support the avatar.
	body.global_position = Vector3(240,0.2,979)
	for at in [Vector3(240,8,1027),Vector3(240,8,1167),Vector3(240,0,1211)]:
		await _walk_to(at)
	if not "--captures-only" in OS.get_cmdline_user_args():
		body.global_position.x += 12.0
		var car: CharacterBody3D = load("res://scripts/vehicle.gd").new()
		root.add_child(car)
		car.set_physics_process(false)
		car.global_position = Vector3(240,0.15,979)
		car.rotation.y = PI
		car.controlled = true
		car.controls_enabled = true
		Input.action_press("move_forward")
		for target in [Vector2(1028,8),Vector2(1160,8),Vector2(1206,0.7)]:
			var reached := false
			for frame in 1600:
				await physics_frame
				car._physics_process(1.0/60.0)
				if car.global_position.z>=target.x: reached = true; break
			check(reached,"actual car traverses bridge checkpoint "+str(target.x)+" at "+str(car.global_position))
			check(absf(car.global_position.y-target.y)<1.0,"actual car is supported by ramp/deck "+str(target.x))
		Input.action_release("move_forward")
		car.queue_free()
		await process_frame
	await _capture("tejo",Vector3(263,21,1010),Vector3(240,18,1080))
	game._game_menu.set_context(game._menu_context())
	game._game_menu.open_menu("map")
	await _capture("map",Vector3(263,21,1010),Vector3(240,18,1080))
	game.music.stop(); game.ambience.stop(); game.player._footsteps.stop(); game._vehicles._horn.stop()
	# Fixed-fps headless simulation outruns the real audio thread; let a stopped
	# Vorbis decoder finish its pending mix before disposing its resources.
	if DisplayServer.get_name()=="headless": OS.delay_msec(250)
	await create_timer(0.22).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	city.editor = null
	game.queue_free(); body.queue_free()
	await process_frame
	print("MAPS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _walk_to(target: Vector3) -> void:
	if "--captures-only" in OS.get_cmdline_user_args():
		body.global_position = target
		return
	var reached := false
	for frame in 1800:
		await physics_frame
		var offset := target-body.global_position; offset.y = 0
		if offset.length()<0.2: reached = true; break
		body.velocity.x = offset.normalized().x*9.0
		body.velocity.z = offset.normalized().z*9.0
		body.velocity.y = -1 if body.is_on_floor() else body.velocity.y-20.0/60.0
		body.move_and_slide()
	check(reached,"physical connector reached "+str(target)+" from "+str(body.position))
	check(absf(body.position.y-target.y)<1,"correct walking height at "+str(target)+" actual "+str(body.position))
func _capture(label: String, at: Vector3, target: Vector3) -> void:
	if not screenshots or DisplayServer.get_name()=="headless": return
	var camera: Camera3D = game.player.get_camera()
	camera.global_position = at; camera.look_at(target); camera.make_current()
	game.world.ensure_position(target)
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/album-maps-"+label+".png")==OK,"native screenshot "+label)
