extends SceneTree
## Main-scene QA for pause settings, save/load, real skinned riding and creator flow.
var game: Node3D
var checks := 0
var failures := 0
var screenshots := false
var _original_actor_id := 0
var _original_visual_id := 0

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FEATURES FAIL: " + description)

func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	# Run with isolated XDG data: manual slots and creator access are real main paths.
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.16).timeout
	game.set_process(false)
	game.player.set_physics_process(false)
	game.store.save_path = "user://features_progress.json"
	game.store.reset_progress()
	game._editor.save_path = "user://features_world.json"
	game._begin_exploration(0)
	game.player.set_physics_process(false)
	game.world.set_process(false)
	game._vehicles.set_physics_process(false)
	for vehicle in game._vehicles.vehicles:
		vehicle.set_physics_process(false)
	_original_actor_id = game.player.get_instance_id()
	_original_visual_id = game.player._visuals.get_instance_id()
	check(game.player._visuals.skeleton != null and game.player._visuals.skeleton.find_bone("thigh.L") >= 0 and game.player._visuals.skeleton.find_bone("forearm.R") >= 0 and _has_skinned_mesh(game.player._visuals.model), "main player is a real skinned rig, not a vehicle test stub")

	game.player.global_position = Vector3(-3.5,0.15,4)
	game.store.money = 241
	game.player.health = 63.0
	game._update_interaction()
	game._show_pause()
	check(game.state == "paused" and game._game_menu.visible and not game._pause.visible, "pause opens integrated dark menu instead of legacy panel")
	check(game.world.process_mode == Node.PROCESS_MODE_DISABLED and not game._vehicles.controls_enabled, "pause freezes world and vehicle controls")
	check(game._game_menu._context.money == 241 and game._game_menu._context.health == 63.0, "pause context comes from live player state")
	game._game_menu._select_tab("map")
	check(game._game_menu._map.get("context").player_position.is_equal_approx(game.player.global_position), "integrated map marks live player position")
	await _capture("map")
	game._game_menu._change_quality(2)
	game._game_menu._change_population(0)
	check(game._quality_index == 2 and game.player.get_camera().far == 270.0, "quality signal changes real camera draw distance")
	check(game._npc_budget == 6 and game.world._population.budget == 6, "population slider changes actual local pool budget")
	game._game_menu._change_audio(0.73,"master")
	game._game_menu._change_audio(0.34,"music")
	game._game_menu._change_audio(0.45,"ambient")
	game._game_menu._change_audio(0.61,"effects")
	game._update_audio(1.0)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.73), "master audio slider controls actual master bus")
	check(is_equal_approx(db_to_linear(game.music.volume_db),0.34), "music slider controls actual music player")
	check(absf(game.ambience.volume_db - (-4.0 + linear_to_db(0.45))) < 0.02, "ambient slider reaches actual ambience output")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("AlbumEffects"))),0.61), "effects slider controls actual effects bus")
	check(game.player._footsteps.bus == "AlbumEffects" and game._vehicles._horn.bus == "AlbumEffects", "footsteps and vehicle horn are routed through effects slider")
	game._game_menu._change_brightness(1.24)
	check(is_equal_approx(float(game._brightness_rect.material.get_shader_parameter("brightness")),1.24), "brightness slider reaches world shader")
	game._game_menu._change_subtitles(false)
	check(not game._subtitles, "subtitle preference reaches main scene")
	game._notify("SEGURANÇA / Teste de legenda", 7.0, true)
	check(not game._notice.visible, "disabled subtitles hide dialogue rather than only storing a preference")
	game._game_menu._change_subtitles(true)
	game._notify("SEGURANÇA / Teste de legenda", 7.0, true)
	check(game._notice.visible, "enabled subtitles display dialogue")
	game._game_menu._change_subtitles(false)
	game._notify("Objeto guardado.")
	check(game._notice.visible, "essential interaction feedback stays available without subtitles")
	var preferences := ConfigFile.new()
	check(preferences.load("user://menu_settings.cfg") == OK and preferences.get_value("menu","audio_music") == 0.34 and preferences.get_value("menu","brightness") == 1.24, "menu preferences persist separately from progress")
	game._game_menu._select_tab("audio")
	await _capture("audio")

	game.player.global_position = Vector3(-3.5,0.15,4)
	game.player.health = 63.0
	game.store.money = 241
	game.store.bar_unlocked = true
	game._game_menu._request_save()
	check(FileAccess.file_exists("user://manual_save.json") and FileAccess.file_exists("user://manual_position.json"), "manual save button writes progress and location slots")
	game.store.money = 999
	game.player.health = 19
	game.player.global_position = Vector3(20,0.2,20)
	game._game_menu._request_load()
	check(game.store.money == 241 and game.player.health == 63.0 and game.store.bar_unlocked, "manual load restores money, health and access state")
	check(game.player.global_position.distance_to(Vector3(-3.5,0.25,4)) < 0.02, "manual load restores saved location with safe offset")
	check(game.state == "explore" and not game._game_menu.visible and game.player.get_camera().current, "manual load resumes play with player camera")
	game.world.set_process(false)
	game.player.set_physics_process(false)
	game._vehicles.set_physics_process(false)

	# E interaction completes a mission created by the real editor catalog.
	var mission_position := Vector3(4,0.1,3)
	var mission_id: String = game._editor.spawn_catalog("Missão",mission_position,{"mission":{"title":"Encontro de teste","kind":"visitar","reward":80,"completed":false}})
	check(not mission_id.is_empty(), "creator catalog can add an actual mission to this world")
	game.player.global_position = mission_position + Vector3(0.2,0.1,0)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	game._unhandled_input(event)
	check(game.store.money == 321 and game._editor.get_target_state(mission_id).mission.completed, "normal E interaction completes mission and pays once")
	game._unhandled_input(event)
	check(game.store.money == 321, "repeating E cannot farm completed creator mission")
	game._wanted.record_event("police_assault",true)
	game._process(0.0)
	check(game._game_hud.get_money_text() == "€000000321" and game._game_hud.wanted == 25.0, "integrated HUD receives live cash and continuous police heat")
	game._wanted.clear()

	# Use the actual player's retained model and skeleton in all four vehicle types.
	check(game._vehicles.vehicles.size() >= 4, "main scene exposes all four drivable vehicle types")
	for vehicle in game._vehicles.vehicles.slice(0,4):
		await _exercise_vehicle(vehicle)
	check(game.player.get_instance_id() == _original_actor_id and game.player._visuals.get_instance_id() == _original_visual_id, "all rides preserve player and human model identity")

	# F10 is routed through the root and requires the unlocked creator session.
	game._editor_unlocked = true
	var editor_event := InputEventAction.new()
	editor_event.action = "editor_toggle"
	editor_event.pressed = true
	game._unhandled_input(editor_event)
	check(game.state == "editor" and game._editor.active and game._editor.camera.current, "F10 enters actual creator mode with fly camera after unlocking")
	check(not game._game_menu.visible and game.player.process_mode == Node.PROCESS_MODE_DISABLED, "editor hides pause and stops gameplay input")
	check(game._editor.vehicle_manager == game._vehicles, "creator is wired to actual drivable vehicle manager")
	await _capture("editor")
	game._editor.exit_editor()
	check(game.state == "explore" and not game._editor.active and game.player.get_camera().current, "closing creator mode resumes player camera and exploration")
	check(game.player.process_mode == Node.PROCESS_MODE_INHERIT and game._vehicles.controls_enabled, "closing creator restores player and vehicle controls")
	game.set_process(false)
	game.player.set_physics_process(false)
	game.world.set_process(false)
	game._vehicles.set_physics_process(false)
	game.music.stop()
	game.ambience.stop()
	game.player._footsteps.stop()
	game._vehicles._horn.stop()
	await create_timer(0.22).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	game.queue_free()
	await process_frame
	print("FEATURES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _exercise_vehicle(vehicle: Node3D) -> void:
	# A clear stretch of the actual south street, away from scenery and other rides.
	for other in game._vehicles.vehicles:
		other.set_physics_process(false)
		other.global_position = Vector3(25 + game._vehicles.vehicles.find(other) * 2.0,0.2,28)
	vehicle.global_position = Vector3(0,0.12,28)
	vehicle.rotation = Vector3.ZERO
	vehicle.forward_speed = 0.0
	game.player.global_position = vehicle.get_entry_position() + Vector3(-0.25,0.1,0)
	game.player.velocity = Vector3.ZERO
	await physics_frame
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	game._unhandled_input(event)
	check(game._vehicles.state == "entering" and game._vehicles.active_vehicle == vehicle, "E begins real entry transition: " + vehicle.type)
	if game._vehicles.active_vehicle != vehicle:
		return
	for i in 28:
		game._vehicles._physics_process(0.05)
	check(game._vehicles.state == "driving" and vehicle.controlled, "entry reaches real driving state: " + vehicle.type)
	check(game.player.global_position.is_equal_approx(vehicle.get_seat_position()), "human rider is attached to actual seat: " + vehicle.type)
	check(game.player.collision_layer == 0 and game.player._visuals._vehicle_pose == vehicle.type, "human skin uses mounted pose and avoids self collision: " + vehicle.type)
	var skeleton: Skeleton3D = game.player._visuals.skeleton
	var thigh := skeleton.find_bone("thigh.L")
	var hand := skeleton.find_bone("upper_arm.R")
	check(thigh >= 0 and hand >= 0 and not skeleton.get_bone_pose_rotation(thigh).is_equal_approx(Quaternion.IDENTITY) and not skeleton.get_bone_pose_rotation(hand).is_equal_approx(Quaternion.IDENTITY), "actual skinned hip and arm articulate while mounted: " + vehicle.type)
	if vehicle.type == "bicycle":
		vehicle.forward_speed = 4.0
		game._vehicles._physics_process(0.1)
		var before := skeleton.get_bone_pose_rotation(thigh)
		# Manager-only ticks must not invent pedalling while the actual pedals
		# are stationary. Advance the vehicle and then mount the same physical phase.
		vehicle._physics_process(0.3)
		game._vehicles._physics_process(0.3)
		check(not skeleton.get_bone_pose_rotation(thigh).is_equal_approx(before), "real bicycle rider follows the physically rotating pedals")
	vehicle.forward_speed = 0.0
	await physics_frame
	await physics_frame
	if vehicle.type == "car":
		await _capture("car-rider")
	game._unhandled_input(event)
	if game._vehicles.state != "exiting":
		print("EXIT DIAGNOSTIC ", vehicle.type, " rootstate=",game.state," managerstate=",game._vehicles.state," clear=",game._vehicles._find_clear_exit()," hint=",game._notice.text)
		_exit_diagnostic(vehicle)
	check(game._vehicles.state == "exiting", "E requests a collision-checked exit: " + vehicle.type)
	for i in 20:
		game._vehicles._physics_process(0.05)
	check(game._vehicles.state == "on_foot" and game.player.collision_layer != 0 and game.player._visuals._vehicle_pose.is_empty(), "exit restores same on-foot human and animation: " + vehicle.type)
	game.player.set_physics_process(false)

func _capture(label: String) -> void:
	if not screenshots or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/album-v2-features-"+label+".png") == OK, "native screenshot "+label)

func _has_skinned_mesh(node: Node) -> bool:
	if node is MeshInstance3D and node.skin != null:
		return true
	for child in node.get_children():
		if _has_skinned_mesh(child):
			return true
	return false

func _exit_diagnostic(vehicle: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	for offset: Vector3 in vehicle.exit_offsets:
		var candidate: Vector3 = vehicle.to_global(offset)
		var ray := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*2,candidate-Vector3.UP*3,1,[game.player.get_rid(),vehicle.get_rid()])
		var floor_hit := space.intersect_ray(ray)
		print("EXIT FLOOR ", candidate," => ",floor_hit)
		if floor_hit.is_empty():continue
		candidate.y = floor_hit.position.y + 0.04
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.29
		capsule.height = 1.82
		query.shape = capsule
		query.transform = Transform3D(Basis(),candidate+Vector3.UP*0.91)
		query.collision_mask = 3
		query.exclude = [game.player.get_rid(),vehicle.get_rid()]
		print("EXIT BLOCKED ",space.intersect_shape(query,4))
