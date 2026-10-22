extends SceneTree
## Native, reproducible visual review. Captures are evidence, never a beauty assertion.
## --views --poses --motion --output=/tmp/album-revision-visual
## Overview deliberately disables fog and extends camera range to inspect geography.
var game: Node3D
var city: Node3D
var camera: Camera3D
var output_dir := "/tmp/album-revision-visual"
var records: Array = []
var capture_count := 0
var failures := 0
var _only_views := false
var _only_poses := false
var _motion := false
var _walkthrough := false
var _view_filter: Array[String] = []
var _performance_review := false
var _overview_ranges: Array[Dictionary] = []

func _initialize() -> void:
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
		if arg.begins_with("--view="): _view_filter.append(arg.trim_prefix("--view="))
	_only_views = "--views" in OS.get_cmdline_user_args()
	_only_poses = "--poses" in OS.get_cmdline_user_args()
	_motion = "--motion" in OS.get_cmdline_user_args()
	_walkthrough = "--walkthrough" in OS.get_cmdline_user_args()
	_performance_review = "--performance" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not _walkthrough:
		print("VISUAL REVIEW: SKIP native images require Compatibility renderer.")
		quit(0)
		return
	create_timer(900 if _walkthrough else 240).timeout.connect(func():
		push_error("Visual capture timed out")
		quit(1))
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.15).timeout
	game.store.save_path = "user://visual_review_progress.json"
	game._editor.save_path = "user://visual_review_world.json"
	game.set_process(false)
	game._begin_exploration(0)
	game._set_world_paused(true)
	game.player.set_physics_process(false)
	game.world.process_mode = Node.PROCESS_MODE_INHERIT
	game.world.set_process(false)
	game.world.set_npcs_enabled(true)
	city = game.world.imported_city
	city.set_process(false)
	camera = Camera3D.new()
	camera.name = "ReviewCamera"
	camera.near = 0.08
	root.add_child(camera)
	camera.make_current()
	game._motion_blur.set_strength(0.0)
	game._notice.hide()
	if _walkthrough:
		await _walkthrough_routes()
	if not _walkthrough and not _only_poses:
		await _world_views()
	if _performance_review:
		await _actual_performance_view()
	if not _walkthrough and not _only_views:
		await _character_views()
	if _motion:
		await _motion_frames()
	var report := FileAccess.open(output_dir+"/captures.json",FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"mode":"native Compatibility, software renderer when llvmpipe","captures":records},"\t"))
	game.music.stop(); game.ambience.stop(); game.player._footsteps.stop(); game._vehicles._horn.stop()
	await create_timer(0.22).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	city.editor = null
	game.queue_free()
	camera.queue_free()
	await process_frame
	print("VISUAL REVIEW: %d captures, %d failures, output %s" % [capture_count,failures,output_dir])
	quit(0 if failures==0 else 1)

func _world_views() -> void:
	var views: Array = []
	if city.has_method("get_visual_views"):
		views = city.get_visual_views()
	if views.is_empty():
		for district in city.manifest.districts:
			var origin := Vector3(district.spawn[0],_ground(district.spawn[0],district.spawn[1]),district.spawn[1])
			var forward := (Vector3(district.look_at[0],origin.y,district.look_at[1])-origin).normalized()
			views.append({"id":str(district.id)+"_street","position":origin-forward*7+Vector3.UP*2.4,"target":origin+forward*17+Vector3.UP*2.0,"player":origin+Vector3.UP*0.05})
		for bookmark in city.get_bookmarks():
			views.append({"id":"bookmark_"+str(bookmark.label).validate_filename(),"position":bookmark.position,"target":bookmark.target})
		views.append({"id":"peninsula_overview","position":Vector3(850,850,1500),"target":Vector3(220,0,450),"overview":true})
	var environment: Environment = game.world.get_environment()
	var original_fog := environment.fog_enabled
	var original_load_radius: float = city.load_radius
	var original_unload_radius: float = city.unload_radius
	for view in views:
		if not _view_filter.is_empty() and not _view_filter.has(str(view.get("id",""))): continue
		_restore_geometry_ranges()
		var at: Vector3 = _as_vector(view.position)
		var target: Vector3 = _as_vector(view.target)
		var player_at: Vector3 = _as_vector(view.get("player",Vector3(target.x,_ground(target.x,target.z)+0.05,target.z)))
		var overview: bool = bool(view.get("overview",str(view.get("id","")).contains("overview") or at.y-target.y>120.0))
		game.player.global_position = player_at
		game.player._visuals.rotation = Vector3.ZERO
		game.player.movement_locked = true
		_set_pose("idle",0.2)
		if overview:
			# A geography diagnostic must not depict unloaded districts as empty land.
			# This full-resident mode is only for the aerial review, never gameplay.
			city.load_radius = 2400.0
			city.unload_radius = 2450.0
			camera.far = 2400.0
			camera.fov = 57.0
			environment.fog_enabled = false
		else:
			city.load_radius = original_load_radius
			city.unload_radius = original_unload_radius
			camera.far = 180.0
			camera.fov = float(view.get("fov",65.0))
			environment.fog_enabled = original_fog
		game.world.ensure_position(target)
		if overview: _unlimit_overview_geometry()
		# The production visibility refresh must follow review teleports too.
		# Otherwise a club correctly suspended at the previous district remains hidden.
		if not overview: game.world._process(0.51)
		camera.global_position = at
		if at.distance_to(target)>0.01: camera.look_at(target)
		camera.make_current()
		game.world._population._refresh_membership()
		if view.has("ui"):
			game._ui.visible = bool(view.ui)
		else:
			game._ui.visible = not overview
		await _capture(str(view.get("id","view_%02d"%capture_count)))
	_restore_geometry_ranges()
	city.load_radius = original_load_radius
	city.unload_radius = original_unload_radius
	city.ensure_position(game.player.global_position)
	environment.fog_enabled = original_fog
	game._ui.show()

func _unlimit_overview_geometry() -> void:
	# Far aerial review also needs the roads normally culled at gameplay distance.
	# Keep coarse skyline proxies excluded: the detailed sectors are all resident.
	for node in city.find_children("*","GeometryInstance3D",true,false):
		var geometry := node as GeometryInstance3D
		if city._skyline.has(geometry): continue
		if geometry.visibility_range_begin<=0.0 and geometry.visibility_range_end<=0.0: continue
		_overview_ranges.append({"node":geometry,"begin":geometry.visibility_range_begin,"end":geometry.visibility_range_end})
		geometry.visibility_range_begin = 0.0
		geometry.visibility_range_end = 0.0

func _restore_geometry_ranges() -> void:
	for record in _overview_ranges:
		if not is_instance_valid(record.node): continue
		record.node.visibility_range_begin = record.begin
		record.node.visibility_range_end = record.end
	_overview_ranges.clear()

func _actual_performance_view() -> void:
	var venues: Array = city.get_performance_venues()
	if venues.is_empty():
		failures += 1
		push_error("No playable music venue supplied for the native DJ review")
		return
	var venue: Dictionary = venues[0]
	var stage: Vector3 = venue.stage_position
	game.world.ensure_position(stage)
	game.player.global_position = stage+Vector3.UP*0.04
	game.player.velocity = Vector3.ZERO
	game.world._process(0.51)
	game._update_interaction()
	game._interact()
	if game.state != "songs":
		failures += 1
		push_error("DJ interaction did not open the actual song sheet")
		return
	await _capture("pink_street_song_selection")
	game._start_performance()
	if game.state != "performance" or game._performance_context.get("id","") != venue.id:
		failures += 1
		push_error("DJ flow did not retain its actual venue context")
		return
	var review_camera := camera
	camera = game._performance_camera
	for frame in 20:
		await physics_frame
		game._process(1.0/60.0)
		game.player._animate(1.0/60.0,0.0,false)
	await _capture("pink_street_actual_dj_performance")
	records.append({"id":"actual_performance_flow","venue_id":venue.id,"state":game.state,"player_position":[stage.x,stage.y,stage.z],"camera_is_actual_performance_camera":camera.current})
	game._abandon_performance()
	camera = review_camera
	camera.make_current()

func _ground(x: float,z: float) -> float:
	return float(city.ground_height(x,z)) if city.has_method("ground_height") else 0.0

func _as_vector(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size()==3: return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO

func _character_views() -> void:
	var district: Dictionary = city.manifest.districts[2]
	var at := Vector3(district.spawn[0],_ground(district.spawn[0],district.spawn[1])+0.06,district.spawn[1])
	game.world.ensure_position(at)
	game.world.set_npcs_enabled(false)
	game.player.global_position = at
	game.player._visuals.rotation = Vector3.ZERO
	game.player._visuals.position = Vector3.ZERO
	game._ui.hide()
	camera.fov = 43.0
	camera.far = 120.0
	for pose in ["idle","walk","run","crouch_idle","crouch"]:
		for orientation in ["front","side","back"]:
			var offset: Vector3 = {"front":Vector3(0,1.15,-3.0),"side":Vector3(3.0,1.15,0),"back":Vector3(0,1.15,3.0)}[orientation]
			var aim_height := 0.85 if pose.begins_with("crouch") else 0.95
			camera.global_position = at+offset
			camera.look_at(at+Vector3.UP*aim_height)
			camera.make_current()
			_set_pose(pose,0.22)
			await _capture("character_"+pose+"_"+orientation)
	# Exact gait phases expose knee/toe orientation without cherry-picking one pose.
	for phase in 8:
		camera.global_position = at+Vector3(3.0,1.15,0)
		camera.look_at(at+Vector3.UP*0.95)
		_set_pose("walk",float(phase)/8.0)
		await _capture("gait_side_%02d" % phase)
	await _actual_crouch_views(at)
	game._ui.show()

func _set_pose(clip: String,phase: float) -> void:
	var visual: Node3D = game.player._visuals
	var crouched := clip.begins_with("crouch")
	var speed := 0.0 if clip in ["idle","crouch_idle"] else 4.6 if clip=="run" else 1.2 if crouched else 1.85
	visual.animate(1.0/60.0,speed,clip=="run",crouched,false,100.0)
	var animator: AnimationPlayer = visual.animation_player
	if animator == null: return
	var selected: String = str(visual._clips.get(clip,visual._clips.get("crouch" if crouched else "walk","")))
	if selected.is_empty(): return
	animator.play(selected,0.0)
	animator.advance(0.25)
	animator.pause()
	animator.seek(phase*animator.get_animation(selected).length,true)
	animator.advance(0.0)
	if visual.skeleton: visual.skeleton.force_update_all_bone_transforms()

func _motion_frames() -> void:
	# Reproducible clip frames use actual exported animation, not a mock skeleton.
	var district: Dictionary = city.manifest.districts[2]
	var at := Vector3(district.spawn[0],_ground(district.spawn[0],district.spawn[1])+0.06,district.spawn[1])
	game.player.global_position = at
	game._ui.hide()
	camera.fov = 43.0
	camera.global_position = at+Vector3(3.2,1.2,-1.2)
	camera.look_at(at+Vector3.UP*0.9)
	for index in 90:
		var clip := "walk" if index<30 else "run" if index<60 else "crouch"
		_set_pose(clip,float(index%30)/30.0)
		await _capture("motion_%03d"%index,false)
	game._ui.show()

func _capture(id: String,add_to_report := true) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var path := output_dir+"/"+id.validate_filename()+".png"
	if frame.save_png(path)!=OK:
		failures+=1
		push_error("Cannot save visual evidence "+path)
		return
	capture_count+=1
	if add_to_report:
		var mean := 0.0
		var light := 0
		var samples := 0
		for y in range(0,frame.get_height(),12):
			for x in range(0,frame.get_width(),12):
				var color := frame.get_pixel(x,y)
				var luma := color.r*0.2126+color.g*0.7152+color.b*0.0722
				mean+=luma
				light+=int(luma>0.8)
				samples+=1
		records.append({"id":id,"image":path,"position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"mean_luma":mean/maxi(1,samples),"bright_fraction":float(light)/maxi(1,samples),"fog_enabled":game.world.get_environment().fog_enabled,"loaded_sectors":city.loaded.size(),"review_load_radius":city.load_radius})
		print("VISUAL CAPTURE ",id," ",path)

func _walkthrough_routes() -> void:
	if not city.has_method("get_exploration_routes"):
		failures+=1
		push_error("No public exploration routes supplied by world")
		return
	var routes: Array = city.get_exploration_routes()
	if routes.is_empty():
		failures+=1
		push_error("No exploration routes")
		return
	game.world.set_npcs_enabled(false)
	game.world.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.set_physics_process(false)
	game.player.walk_speed = 3.1
	game.player.movement_locked = false
	for route in routes:
		var points: Array = []
		for point in route.get("points",[]): points.append(point)
		if points.size()<2: continue
		var first := _as_vector(points[0])
		game.world.ensure_position(first)
		game.player.respawn_at(Transform3D(Basis.IDENTITY,first+Vector3.UP*0.08))
		game.player.set_physics_process(false)
		game.player.movement_locked = false
		game.player._yaw = 0.0
		var completed := true
		var start_ms := Time.get_ticks_msec()
		for index in range(1,points.size()):
			var target := _as_vector(points[index])
			var reached := false
			var distance: float = game.player.global_position.distance_to(target)
			var frame_limit := maxi(180,ceili(distance/2.0*60.0)+180)
			for frame in frame_limit:
				await physics_frame
				var offset: Vector3 = target-game.player.global_position
				if Vector2(offset.x,offset.z).length()<0.35 and absf(offset.y)<0.65:
					reached = true
					break
				var direction := Vector2(offset.x,offset.z).normalized()
				Input.action_press("move_right",maxf(0.0,direction.x))
				Input.action_press("move_left",maxf(0.0,-direction.x))
				Input.action_press("move_back",maxf(0.0,direction.y))
				Input.action_press("move_forward",maxf(0.0,-direction.y))
				game.player._yaw = 0.0
				if frame%30==0: game.world.ensure_position(game.player.global_position)
				game.player._physics_process(1.0/60.0)
				if game.player._dead: break
			_release_movement()
			if not reached:
				completed = false
				failures+=1
				push_error("EXPLORATION route %s blocked at waypoint%d target%s actual%s dead%s" % [route.get("id","route"),index,target,game.player.global_position,game.player._dead])
				break
		records.append({"id":"route_"+str(route.get("id","route")),"completed":completed,"waypoints":points.size(),"wall_ms":Time.get_ticks_msec()-start_ms})
		print("EXPLORATION ROUTE ",route.get("id","route")," complete=",completed," waypoints=",points.size())
	_release_movement()
	game.player.set_physics_process(false)

func _release_movement() -> void:
	for action in ["move_right","move_left","move_back","move_forward"]: Input.action_release(action)

func _actual_crouch_views(at: Vector3) -> void:
	var player: CharacterBody3D = game.player
	player.global_position = at
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_physics_process(false)
	player.movement_locked = false
	player._visuals._current = ""
	Input.action_release("crouch")
	for frame in 8:
		await physics_frame
		player._physics_process(1.0/60.0)
	var standing_height: float = player._capsule.height
	Input.action_press("crouch")
	for frame in 24:
		await physics_frame
		player._physics_process(1.0/60.0)
	var lowered_height: float = player._capsule.height
	_set_pose("crouch_idle",0.2)
	for direction in ["front","side"]:
		camera.global_position = player.global_position+({"front":Vector3(0,1.1,-3),"side":Vector3(3,1.1,0)}[direction] as Vector3)
		camera.look_at(player.global_position+Vector3.UP*0.7)
		await _capture("character_actual_ctrl_"+direction)
	records.append({"id":"actual_ctrl_crouch","controller_crouched":player._crouched,"standing_collider_height":standing_height,"crouched_collider_height":lowered_height})
	Input.action_release("crouch")
	for frame in 12:
		await physics_frame
		player._physics_process(1.0/60.0)
	player.set_physics_process(false)
	player.movement_locked = true
