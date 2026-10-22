extends SceneTree
## Real main-scene entry, new district performance and migration of existing edits.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("REVISION INTEGRATION FAIL: "+description)

func _run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.store.save_path = "user://revision_progress.json"
	game._editor.save_path = "user://revision_edits.json"
	check(game.player.global_position.distance_to(game.world.get_initial_spawn().origin)<0.1,"a new session starts on the actual Saldanha rooftop")
	check(game.player.global_position.y>10 and game.player.global_position.z>280,"starting rooftop belongs to the connected peninsula")
	var parking: Dictionary = {}
	for vehicle in game._vehicles.vehicles:
		if str(vehicle.get_meta("vehicle_id","")).begins_with("saldanha_"):
			parking[vehicle.type] = vehicle
	check(parking.size()==4,"all four usable vehicle types are parked near the starting building")
	for kind in ["car","motorbike","bicycle","scooter"]:
		if not parking.has(kind): continue
		var vehicle: Node3D = parking[kind]
		check(vehicle.global_position.distance_to(game.world.get_initial_safe().origin)<80,"parked "+kind+" is reachable near the starting street")
	game._begin_exploration(0)
	game.player.set_physics_process(false)
	var venues: Array = game.world.imported_city.get_performance_venues()
	check(not venues.is_empty(),"the actual Pink Street discotheque exposes a playable DJ desk")
	if not venues.is_empty():
		var venue: Dictionary = venues[0]
		game.player.global_position = venue.stage_position
		game.world.ensure_position(game.player.global_position)
		game.store.bar_unlocked = false
		game._update_interaction()
		check(game._hint.text.contains("FAIXA"),"the new discotheque desk has a nearby interaction prompt")
		game._interact()
		check(game.state=="songs" and game._song_sheet.visible,"E opens real song selection at the Pink Street desk")
		check(game.world._performance_id==venue.id,"song selection selects the new venue crowd")
		game._start_performance()
		check(game.state=="performance" and game.rhythm.active,"DJ performance actually starts in the new venue")
		check(game._performance_camera.global_position.distance_to(venue.camera_position)<0.01,"performance camera stays inside the new discotheque")
		check(game._performance_camera.current and game.player.movement_locked,"performance uses its camera and locks player movement")
		var crowd: Node3D = game.world._venue_clubs[venue.id]
		check(crowd._performance,"the new dance floor reacts to the real rhythm activity")
		var zone: Dictionary = game.world.get_music_zone(venue.stage_position)
		check(zone.id==venue.id and int(zone.song)==2,"the new venue also has a spatial looping music source")
		game._abandon_performance()
		check(game.state=="explore" and not crowd._performance and game.player.get_camera().current,"ending the set restores exploration in the same venue")
	# An actual pre-revision editor save must retain the source feature's position.
	var feature: Dictionary = {}
	for sector in game.world.imported_city.manifest.sectors:
		if not str(sector.id).begins_with("bairro_alto_"): continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/generated/"+str(sector.id)+".json"))
		if not data.buildings.is_empty():
			feature = data.buildings[0]
			break
	check(not feature.is_empty(),"a real source Bairro Alto feature is available for save migration")
	if not feature.is_empty():
		var at := Vector3(feature.position[0],8,feature.position[1])
		game.world.ensure_position(at)
		var id := "base/"+str(feature.id)
		var state: Dictionary = game._editor.get_target_state(id)
		check(not state.is_empty(),"streaming indexes the same stable source feature ID")
		if not state.is_empty():
			var expected: float = state.position[1]
			state.position[1] = expected-8.0
			var file := FileAccess.open(game._editor.save_path,FileAccess.WRITE)
			file.store_string(JSON.stringify({"version":1,"base":{id:state},"added":{},"counter":0}))
			file.close()
			check(game._editor.load_world(),"pre-revision editor save loads through the real loader")
			check(absf(float(game._editor.get_target_state(id).position[1])-expected)<0.01,"old building edit rises with Bairro Alto rather than becoming buried")
			check(game._editor.save_world() and game._editor.load_world(),"migrated edits save and reload normally")
			check(absf(float(game._editor.get_target_state(id).position[1])-expected)<0.01,"a second load does not lift the same edit twice")
	game.player.global_position = Vector3(225.384,8.15,544.502)
	game._manual_save()
	var old_position := FileAccess.open("user://manual_position.json",FileAccess.WRITE)
	old_position.store_string(JSON.stringify({"position":[225.384,0.15,544.502],"health":73}))
	old_position.close()
	game._manual_load()
	game.player.set_physics_process(false)
	check(game.player.global_position.distance_to(Vector3(225.384,8.25,544.502))<0.02 and is_equal_approx(game.player.health,73.0),"manual saves from the old flat Bairro Alto also retain location and health")
	var population: Node3D = game.world._population
	var npc: CharacterBody3D = population.peds[0]
	game.player.global_position = npc.global_position+Vector3(2,0,0)
	population._refresh_membership()
	var npc_id := ""
	for id in game._editor.targets:
		if game._editor.targets[id].node == npc: npc_id = id
	check(not npc_id.is_empty(),"the persistent street NPC can be selected in the real editor")
	if not npc_id.is_empty():
		check(game._editor.edit_target(npc_id,{"visible":false}),"the editor can remove a street NPC from the scene")
		population._refresh_membership()
		game.player.global_position += Vector3(100,0,0)
		population._refresh_membership()
		game.player.global_position = npc.global_position+Vector3(2,0,0)
		population._refresh_membership()
		check(not npc.visible and not npc.simulation_enabled,"a removed NPC stays removed after leaving and returning to its area")
	game.queue_free()
	await process_frame
	print("REVISION INTEGRATION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
