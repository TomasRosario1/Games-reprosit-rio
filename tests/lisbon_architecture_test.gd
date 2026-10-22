extends SceneTree
## Real passage through tall entrances and wooden stairs to each occupied rooftop.
const ARCHITECTURE = preload("res://scripts/lisbon_architecture.gd")
const PLAYER = preload("res://scripts/player.gd")
var checks := 0
var failures := 0
var clusters: Array = []
var walker: CharacterBody3D
func _initialize() -> void:
	Engine.max_fps = 0
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("LISBON ARCHITECTURE: "+message)
func _run() -> void:
	create_timer(300).timeout.connect(func(): push_error("Architecture test timed out"); quit(1))
	for action in ["move_right","move_left","move_forward","move_back","jump","sprint","crouch"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	var world := Node3D.new(); root.add_child(world)
	var ground := StaticBody3D.new(); var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
	# Match the real exterior paving height, so timber cannot pass this test
	# while being buried under the calçada in the game.
	shape.size=Vector3(350,0.4,90); collision.shape=shape; ground.add_child(collision); ground.position=Vector3(100,-0.155,0); world.add_child(ground)
	var architecture: RefCounted = ARCHITECTURE.new()
	for data in [["saldanha",Vector3.ZERO,0.0],["bairro_alto",Vector3(110,0,0),0.0],["pink_street",Vector3(220,0,0),PI]]:
		var cluster: Dictionary = architecture.build_nightlife(world,world,data[0],data[1],data[2]); clusters.append(cluster)
		check(cluster.venues.size()==6,"six distinct entered venues in "+str(data[0]))
		check(cluster.roofs.size()==1 and cluster.stairs.size()==1,"one full stair-house and roof per district")
		check(cluster.spawn.origin.is_equal_approx(cluster.roofs[0]),"spawn is on the authored roof")
		print("ARCHITECTURE BATCHES ",data[0]," ",_count_batches(cluster.root))
		for venue in cluster.venues:
			check(venue.node.get_meta("editor_stable_id","").begins_with("base/lisboa/"),"venue has stable editor ID")
			check(venue.node.get_editor_bounds().size.y>=8.0,"venue retains full-height architecture")
		check(_count_batches(cluster.root)<=128,"six venue frontages stay within128 texture/primitive batches")
		check(_count_instances(cluster.root)>=_count_batches(cluster.root)*8,"repeated architecture is instanced instead of one draw per object")
		if data[0]=="pink_street":
			check(cluster.has("performance") and cluster.performance.dance_homes.size()>=8,"actual disco floor metadata has persistent audience positions")
	await physics_frame
	# Exercise the controller shipped in the game, including step clearance,
	# grounded motion and fall damage. A second hand-written walker can hide
	# passage failures that the actual player encounters.
	walker=PLAYER.new(); root.add_child(walker)
	walker.set_physics_process(false)
	walker.walk_speed=2.8
	# Geometry is accelerated with fixed-fps; do not queue thousands of real-time
	# audio playbacks while the sound mixer runs on wall-clock time.
	walker._footsteps.stream=null
	for cluster in clusters:
		for venue in cluster.venues:
			walker.respawn_at(Transform3D(Basis.IDENTITY,venue.entrance))
			await _walk_to(venue.interior)
			check(walker.global_position.y>=venue.node.global_position.y-0.015,"interior rests on its timber floor above street paving")
		var stairs: PackedVector3Array=cluster.stairs[0]
		walker.respawn_at(Transform3D(Basis.IDENTITY,stairs[0]))
		for point in stairs: await _walk_to(point)
		check(absf(walker.global_position.y-cluster.spawn.origin.y)<0.4,"roof reached by wooden stairs at correct height")
		for index in range(stairs.size()-1,-1,-1): await _walk_to(stairs[index])
		check(absf(walker.global_position.y)<0.5,"roof-to-street return remains walkable")
		if cluster.has("performance"):
			var route: PackedVector3Array=cluster.performance.route
			walker.respawn_at(Transform3D(Basis.IDENTITY,route[0]))
			for point in route: await _walk_to(point)
			check(walker.global_position.distance_to(cluster.performance.stage_position)<0.4,"DJ console can be reached around the physical desk at "+str(walker.global_position)+" target "+str(cluster.performance.stage_position))
	walker._footsteps.stop()
	walker.queue_free(); world.queue_free(); clusters.clear(); architecture=null; await process_frame
	print("LISBON ARCHITECTURE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _walk_to(target: Vector3) -> void:
	var reached := false
	for frame in 900:
		await physics_frame
		var offset := target-walker.global_position; offset.y=0
		if offset.length()<0.16: reached=true; break
		var direction := Vector2(offset.x,offset.z).normalized()
		Input.action_press("move_right",maxf(0.0,direction.x))
		Input.action_press("move_left",maxf(0.0,-direction.x))
		Input.action_press("move_back",maxf(0.0,direction.y))
		Input.action_press("move_forward",maxf(0.0,-direction.y))
		walker._yaw=0.0
		walker._physics_process(1.0/60.0)
		if walker._dead: break
	for action in ["move_right","move_left","move_forward","move_back"]: Input.action_release(action)
	check(reached,"walk to "+str(target)+" actual "+str(walker.position))
	check(absf(walker.position.y-target.y)<0.65,"height at "+str(target)+" actual "+str(walker.position))
	check(not walker._dead,"no fall death reaching "+str(target))
func _count_batches(node: Node) -> int:
	var count := 1 if node is MultiMeshInstance3D else 0
	for child in node.get_children(): count += _count_batches(child)
	return count
func _count_instances(node: Node) -> int:
	var count: int = node.multimesh.instance_count if node is MultiMeshInstance3D else 0
	for child in node.get_children(): count+=_count_instances(child)
	return count
