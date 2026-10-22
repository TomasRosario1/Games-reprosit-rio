class_name AlbumCharacterVisual
extends Node3D
## Original textured/skinned low-poly humans. Does not control physics or NPC decisions.
## Public API is shared by the player, pedestrians, guards and club patrons.

@export var appearance_id: int = 0
var model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _clips: Dictionary = {}
var _current: String = ""
var _reaction_timer: float = 0.0
var _reaction_kind: String = ""
var _performance_style: String = "dance"
var _microphone: Node3D
var _vehicle_pose: String = ""
var _vehicle_phase: float = 0.0
var _vehicle_contacts: Dictionary = {}
var _loaded_appearance := -1
var _smoothed_speed := 0.0
var _bone_ids: Dictionary = {}
var _rest_global: Dictionary = {}
var _posed_global: Dictionary = {}
static var _catalog: Array = []
static var _scenes: Dictionary = {}


func _ready() -> void:
	setup(appearance_id)


static func catalog() -> Array:
	if _catalog.is_empty():
		var file := FileAccess.open("res://assets/characters/catalog.json", FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				_catalog = parsed
	return _catalog


func setup(index: int) -> void:
	appearance_id = clampi(index, 0, 19)
	if is_instance_valid(model) and _loaded_appearance == appearance_id: return
	if not is_inside_tree():
		return
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	var entries := catalog()
	if entries.size() <= appearance_id:
		push_error("O catálogo de personagens está incompleto.")
		return
	var path: String = entries[appearance_id]["scene"]
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var packed: PackedScene = _scenes[path]
	if packed == null:
		push_error("Não foi possível carregar " + path)
		return
	model = packed.instantiate()
	add_child(model)
	_loaded_appearance = appearance_id
	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	animation_player = _find_type(model, "AnimationPlayer") as AnimationPlayer
	_bone_ids.clear(); _rest_global.clear()
	if skeleton:
		for index_bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(index_bone)
			_bone_ids[bone_name] = index_bone
			_rest_global[bone_name] = skeleton.get_bone_global_rest(index_bone)
	_clips.clear()
	if animation_player:
		for full_name in animation_player.get_animation_list():
			var short_name := String(full_name).get_slice("/", String(full_name).get_slice_count("/") - 1).to_lower()
			if "|" in short_name:
				short_name = short_name.get_slice("|", short_name.get_slice_count("|") - 1)
			_clips[short_name] = String(full_name)
			var clip: Animation = animation_player.get_animation(full_name)
			clip.loop_mode = Animation.LOOP_NONE if short_name in ["flinch","land"] else Animation.LOOP_LINEAR
	_current = ""
	_play("idle", 1.0)
	_setup_microphone()


func _find_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_type(child, type_name)
		if found:
			return found
	return null


func _play(clip: String, speed: float) -> void:
	if not animation_player or not _clips.has(clip):
		return
	animation_player.speed_scale = speed
	if clip != _current:
		var gait := ["walk","run","crouch"]
		var phase := -1.0
		if clip in gait and _current in gait and animation_player.current_animation_length>0:
			phase = fposmod(animation_player.current_animation_position/animation_player.current_animation_length,1.0)
		animation_player.play(_clips[clip],0.12 if clip in ["jump","fall","land"] else 0.18)
		if phase>=0.0: animation_player.seek(phase*animation_player.get_animation(_clips[clip]).length,false)
		_current = clip


func animate(delta: float, speed: float, running: bool = false, crouched: bool = false, performing: bool = false, bpm: float = 100.0, grounded: bool = true, vertical_speed: float = 0.0) -> void:
	if not animation_player:
		return
	if not _vehicle_pose.is_empty():
		_animate_vehicle(delta, speed)
		return
	_smoothed_speed = lerpf(_smoothed_speed,maxf(0.0,speed),1.0-exp(-14.0*delta))
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	if _microphone:
		_microphone.visible = performing and _performance_style == "sing"
	if _reaction_timer > 0.0 and not performing:
		_play("land" if _reaction_kind=="land" and _clips.has("land") else "flinch" if _reaction_kind in ["hit", "bump", "flinch"] else "talk", 1.0)
		return
	if performing:
		_play("dance",clampf(bpm/100.0,0.65,1.6))
	elif not grounded and _clips.has("jump"):
		_play("jump" if vertical_speed>0.8 else "fall",1.0)
	elif crouched:
		if _smoothed_speed>0.12:
			_play("crouch",clampf(_smoothed_speed/0.53,0.6,2.0))
		else:
			_play("crouch_idle" if _clips.has("crouch_idle") else "crouch",1.0)
	elif _smoothed_speed>(0.08 if _current in ["walk","run"] else 0.16):
		# The baked stance travels .82m in 60% of a .9s cycle.
		_play("run" if running else "walk",clampf(_smoothed_speed/(3.81 if running else 1.52),0.45,1.9))
	else:
		_play("idle",1.0)

func react(kind: String) -> void:
	_reaction_kind = kind
	_reaction_timer = 0.22 if kind=="land" else 0.56 if kind in ["hit", "bump", "flinch"] else 1.25
	if animation_player and _clips.has("flinch") and kind in ["hit", "bump", "flinch"]:
		_current = ""
		_play("flinch", 1.0)


func set_performance_style(style: String) -> void:
	_performance_style = "sing" if style == "sing" else "dance"


func _setup_microphone() -> void:
	if is_instance_valid(_microphone):
		_microphone.queue_free()
	if not skeleton:
		return
	var hand_index := skeleton.find_bone("hand.R")
	if hand_index < 0:
		return
	var socket := BoneAttachment3D.new()
	socket.bone_name = "hand.R"
	skeleton.add_child(socket)
	_microphone = Node3D.new()
	_microphone.rotation_degrees.z = 90.0
	socket.add_child(_microphone)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/metal.png")
	material.roughness = 0.65
	var handle := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.020
	cylinder.height = 0.13
	cylinder.radial_segments = 8
	handle.mesh = cylinder
	handle.material_override = material
	handle.position.y = 0.02
	_microphone.add_child(handle)
	var head := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.030
	cap.height = 0.060
	cap.radial_segments = 8
	cap.rings = 4
	head.mesh = cap
	head.material_override = material
	head.position.y = 0.10
	_microphone.add_child(head)
	_microphone.visible = false


func set_vehicle_pose(kind: String) -> void:
	if kind == _vehicle_pose:
		return
	_vehicle_pose = kind
	_vehicle_contacts.clear()
	if animation_player:
		animation_player.active = kind.is_empty()
	if kind.is_empty():
		if skeleton:
			skeleton.reset_bone_poses()
		_current = ""


func set_vehicle_contacts(contacts: Dictionary) -> void:
	_vehicle_contacts = contacts

func get_body_height() -> float:
	var entries := catalog()
	return float(entries[appearance_id].get("height",1.83)) if appearance_id<entries.size() else 1.83


func _animate_vehicle(delta: float, speed: float) -> void:
	if not skeleton:
		return
	if _microphone:
		_microphone.hide()
	_vehicle_phase += delta * speed * 0.9
	skeleton.reset_bone_poses()
	_posed_global = _rest_global.duplicate()
	# Imported people have different adult heights. Anchor their pelvis on the
	# same physical seat and convert contacts into skeleton coordinates; using
	# unscaled bone coordinates leaves smaller riders buried inside the saddle.
	var seat_anchor := skeleton.to_local(to_global(Vector3(0,0.96,0))) if _vehicle_pose!="scooter" else (_rest_global["pelvis"] as Transform3D).origin
	var root_pose: Transform3D = _rest_global["root"]
	root_pose.origin += seat_anchor-(_rest_global["pelvis"] as Transform3D).origin
	_set_vehicle_global("root",root_pose)
	var scooter: bool = _vehicle_pose == "scooter"
	var bicycle: bool = _vehicle_pose == "bicycle"
	var car: bool = _vehicle_pose == "car"
	# Use the same anatomical axes as the baked gait. Local Euler angles on
	# differently rolled thigh/shin bones make knees and shoes fold backwards.
	_rotate_vehicle_bone("pelvis",0.0)
	_rotate_vehicle_bone("spine",0.23 if car else (-0.12 if scooter else -0.60 if bicycle else -0.72))
	_rotate_vehicle_bone("chest",0.12 if car else (-0.05 if scooter else -0.20 if bicycle else -0.22))
	_rotate_vehicle_bone("neck",-0.10 if car else 0.06 if scooter else 0.25)
	_rotate_vehicle_bone("head",-0.10 if car else 0.08 if scooter else 0.25)
	for side in ["L","R"]:
		var sign_side := -1.0 if side=="L" else 1.0
		var phase: float = _vehicle_phase+(PI if side=="R" else 0.0)
		var ankle := Vector3(sign_side*0.16,0.71,-0.52) if car else Vector3(sign_side*0.26,0.40,-0.10)
		if bicycle: ankle = Vector3(sign_side*0.22,0.34+0.14*cos(phase),-0.10+0.14*sin(phase))
		if scooter: ankle = Vector3(sign_side*0.055,0.135,0.14 if side=="L" else -0.16)
		ankle = _vehicle_contacts.get("foot."+side,ankle)
		ankle = skeleton.to_local(to_global(ankle))
		_solve_vehicle_chain("thigh."+side,"shin."+side,ankle,Vector3.FORWARD)
		var foot: Transform3D = _rest_global["foot."+side]
		foot.origin = _posed_global["shin."+side].origin + _posed_global["shin."+side].basis.y * _bone_length("shin."+side,"foot."+side)
		_set_vehicle_global("foot."+side,foot)
		var hand := Vector3(sign_side*0.16,1.28,-0.38) if car else Vector3(sign_side*0.30,1.07,-0.73)
		if scooter: hand = Vector3(sign_side*0.28,1.21,-0.50)
		if bicycle: hand = Vector3(sign_side*0.29,1.01,-0.61)
		hand = _vehicle_contacts.get("hand."+side,hand)
		hand = skeleton.to_local(to_global(hand))
		# The contact is at the palm, not the wrist. Placing the wrist directly
		# on a handlebar makes the entire hand project past it.
		var wrist := hand
		for correction in 3:
			_solve_vehicle_chain("upper_arm."+side,"forearm."+side,wrist,Vector3(sign_side*0.5,-1.0,0.6))
			var palm := _vehicle_parent_rest("hand."+side)
			wrist += hand-(palm.origin+palm.basis.y*0.055)
		_set_vehicle_global("hand."+side,_vehicle_parent_rest("hand."+side))
	skeleton.force_update_all_bone_transforms()


func _vehicle_parent_rest(bone: String) -> Transform3D:
	var parent := skeleton.get_bone_parent(_bone_ids[bone])
	if parent<0: return _rest_global[bone]
	var parent_name := skeleton.get_bone_name(parent)
	return _posed_global[parent_name]*_rest_global[parent_name].affine_inverse()*_rest_global[bone]


func _set_vehicle_global(bone: String, target: Transform3D) -> void:
	var index: int = _bone_ids[bone]
	var parent := skeleton.get_bone_parent(index)
	var local := target
	if parent>=0: local = _posed_global[skeleton.get_bone_name(parent)].affine_inverse()*target
	# Godot bone poses are absolute parent-local transforms, including the
	# rest translation. Removing rest here collapses every joint onto the root.
	skeleton.set_bone_pose_position(index,local.origin)
	skeleton.set_bone_pose_rotation(index,local.basis.get_rotation_quaternion())
	_posed_global[bone] = target


func _rotate_vehicle_bone(bone: String, angle: float) -> void:
	var target := _vehicle_parent_rest(bone)
	target.basis = Basis(Vector3.RIGHT,angle)*target.basis
	_set_vehicle_global(bone,target)


func _bone_length(first: String, next: String) -> float:
	return _rest_global[first].origin.distance_to(_rest_global[next].origin)


func _solve_vehicle_chain(first: String, second: String, target: Vector3, pole: Vector3) -> void:
	var end := "foot."+first.get_slice(".",1) if first.begins_with("thigh") else "hand."+first.get_slice(".",1)
	var start := _vehicle_parent_rest(first).origin
	var length_first := _bone_length(first,second)
	var length_second := _bone_length(second,end)
	var distance := clampf(start.distance_to(target),0.03,length_first+length_second-0.002)
	var direction := start.direction_to(target)
	var along := (length_first*length_first-length_second*length_second+distance*distance)/(2.0*distance)
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var middle := start+direction*along+bend*sqrt(maxf(0.0,length_first*length_first-along*along))
	for values in [[first,start,middle],[second,middle,start+direction*distance]]:
		var rest: Transform3D = _rest_global[values[0]]
		var rotation := Quaternion(rest.basis.y.normalized(),values[1].direction_to(values[2]))
		_set_vehicle_global(values[0],Transform3D(Basis(rotation)*rest.basis,values[1]))
