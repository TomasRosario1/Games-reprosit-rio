class_name AlbumPopulation
extends Node3D
## Stable catalogue of twenty pedestrians; quality controls the local active pool.

signal message(text: String)
const NPC_SCRIPT = preload("res://scripts/npc.gd")
const CATALOGUE_SIZE := 20
const PERSONALITY_ORDER := ["calm", "dreamy", "timid", "intoxicated", "calm", "security", "timid", "calm", "dreamy", "intoxicated", "timid", "security", "dreamy", "calm", "intoxicated", "security", "calm", "timid", "intoxicated", "dreamy"]

var budget: int = 10
var activation_radius: float = 52.0
var enabled: bool = true
var visuals_enabled: bool = true
var peds: Array[CharacterBody3D] = []
var routes: Array[PackedVector3Array] = []
var player: Node3D
var _refresh_timer: float = 0.0
var _message_timer: float = 0.0
var _seed: int = 73


func configure(points: Array, seed_value: int = 73) -> void:
	_seed = seed_value
	routes.clear()
	for route_points in points:
		if route_points is PackedVector3Array and route_points.size() > 0:
			routes.append(route_points.duplicate())
		elif route_points is Array and not route_points.is_empty():
			var converted := PackedVector3Array()
			for point in route_points:
				if point is Vector3:
					converted.append(point)
			if not converted.is_empty():
				routes.append(converted)
	if is_inside_tree():
		_create_pool()


func _ready() -> void:
	if not routes.is_empty():
		_create_pool()


func _create_pool() -> void:
	for ped in peds:
		ped.set_simulation_enabled(false)
		remove_child(ped)
		ped.queue_free()
	peds.clear()
	if routes.is_empty():
		return
	for index in CATALOGUE_SIZE:
		var ped: CharacterBody3D = NPC_SCRIPT.new()
		ped.visual_enabled = visuals_enabled
		var route_index := index % routes.size()
		var selected: PackedVector3Array = routes[route_index]
		var personality_index := posmod(index + _seed, PERSONALITY_ORDER.size())
		ped.configure(index, PERSONALITY_ORDER[personality_index], selected)
		ped.simulation_enabled = false
		add_child(ped)
		var local_slot := floori(float(index) / routes.size())
		var per_route := ceili(float(CATALOGUE_SIZE) / routes.size())
		ped.place_on_route((float(local_slot) + 0.23) / float(per_route))
		ped.set_player(player)
		ped.message.connect(_relay_message)
		peds.append(ped)
	_refresh_membership()


func set_player(body: Node3D) -> void:
	player = body
	for ped in peds:
		ped.set_player(body)
	_refresh_membership()


func set_budget(count: int) -> void:
	budget = clampi(count, 0, CATALOGUE_SIZE)
	_refresh_membership()


func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_membership()


func get_active_count() -> int:
	var count := 0
	for ped in peds:
		if ped.simulation_enabled:
			count += 1
	return count


func _process(delta: float) -> void:
	_refresh_timer -= delta
	_message_timer = maxf(0.0, _message_timer - delta)
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.40
		_refresh_membership()


func _refresh_membership() -> void:
	if not enabled or not is_instance_valid(player):
		for ped in peds:
			ped.set_simulation_enabled(false)
		return
	var eligible: Array[CharacterBody3D] = []
	var retained: Array[CharacterBody3D] = []
	for ped in peds:
		var distance_squared := ped.global_position.distance_squared_to(player.global_position)
		var limit := activation_radius + 5.0 if ped.simulation_enabled else activation_radius
		if distance_squared <= limit * limit:
			eligible.append(ped)
			if ped.simulation_enabled:
				retained.append(ped)
	# Keep active identities until they leave range or budget decreases. We never
	# teleport an existing pedestrian to make it reappear ahead of the camera.
	retained.sort_custom(_closer)
	while retained.size() > budget:
		retained.pop_back()
	eligible.sort_custom(_closer)
	for ped in eligible:
		if retained.size() >= budget:
			break
		if not retained.has(ped):
			retained.append(ped)
	for ped in peds:
		var should_enable := retained.has(ped)
		if ped.simulation_enabled != should_enable:
			ped.set_simulation_enabled(should_enable)


func _closer(a: CharacterBody3D, b: CharacterBody3D) -> bool:
	return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)


func _relay_message(text: String) -> void:
	if _message_timer <= 0.0:
		_message_timer = 2.5
		message.emit(text)

func append_region_routes(region: String, source_routes: Array) -> void:
	# Inactive bodies keep identity; one global budget applies to every district.
	if source_routes.is_empty(): return
	var local_routes: Array[PackedVector3Array] = []
	for points in source_routes:
		var route := PackedVector3Array()
		for point in points: route.append(Vector3(point[0],0.05,point[1]))
		if route.size() > 1: local_routes.append(route)
	if local_routes.is_empty(): return
	for index in CATALOGUE_SIZE:
		var ped: CharacterBody3D = NPC_SCRIPT.new()
		ped.visual_enabled = visuals_enabled
		ped.configure(index,PERSONALITY_ORDER[posmod(index+_seed,PERSONALITY_ORDER.size())],local_routes[index%local_routes.size()])
		ped.simulation_enabled = false
		ped.set_meta("region",region)
		ped.set_meta("editor_stable_id","base/ped/"+region+"/"+str(index))
		add_child(ped)
		ped.place_on_route(0.12+0.035*index)
		ped.set_player(player)
		ped.message.connect(_relay_message)
		peds.append(ped)
	_refresh_membership()
