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
	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	animation_player = _find_type(model, "AnimationPlayer") as AnimationPlayer
	_clips.clear()
	if animation_player:
		for full_name in animation_player.get_animation_list():
			var short_name := String(full_name).get_slice("/", String(full_name).get_slice_count("/") - 1).to_lower()
			if "|" in short_name:
				short_name = short_name.get_slice("|", short_name.get_slice_count("|") - 1)
			_clips[short_name] = String(full_name)
			var clip: Animation = animation_player.get_animation(full_name)
			clip.loop_mode = Animation.LOOP_NONE if short_name == "flinch" else Animation.LOOP_LINEAR
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
		animation_player.play(_clips[clip], 0.16)
		_current = clip


func animate(delta: float, speed: float, running: bool = false, crouched: bool = false, performing: bool = false, bpm: float = 100.0) -> void:
	if not animation_player:
		return
	if not _vehicle_pose.is_empty():
		_animate_vehicle(delta, speed)
		return
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	if _microphone:
		_microphone.visible = performing and _performance_style == "sing"
	if _reaction_timer > 0.0 and not performing:
		_play("flinch" if _reaction_kind in ["hit", "bump", "flinch"] else "talk", 1.0)
		return
	if performing:
		_play("dance", clampf(bpm / 100.0, 0.65, 1.6))
	elif crouched and speed > 0.12:
		_play("crouch", clampf(speed / 0.90, 0.55, 1.8))
	elif crouched:
		# Hold a properly bent two-joint pose, retaining idle breath in the upper body.
		_play("crouch", 0.0)
		animation_player.seek(0.15, true)
	elif speed > 0.12:
		_play("run" if running else "walk", clampf(speed / (3.7 if running else 1.6), 0.45, 1.9))
	else:
		_play("idle", 1.0)


func react(kind: String) -> void:
	_reaction_kind = kind
	_reaction_timer = 0.56 if kind in ["hit", "bump", "flinch"] else 1.25
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
	if animation_player:
		animation_player.active = kind.is_empty()
	if kind.is_empty():
		if skeleton:
			skeleton.reset_bone_poses()
		_current = ""


func _animate_vehicle(delta: float, speed: float) -> void:
	if not skeleton:
		return
	if _microphone:
		_microphone.hide()
	_vehicle_phase += delta * speed * 0.9
	skeleton.reset_bone_poses()
	var scooter: bool = _vehicle_pose == "scooter"
	var bicycle: bool = _vehicle_pose == "bicycle"
	var car: bool = _vehicle_pose == "car"
	_pose_bone("spine", Vector3(-0.08 if car else (-0.04 if scooter else -0.28), 0, 0))
	_pose_bone("chest", Vector3(-0.04 if car else (-0.02 if scooter else -0.13), 0, 0))
	for side in ["L", "R"]:
		var phase: float = _vehicle_phase + (PI if side == "R" else 0.0)
		var pedal: float = sin(phase) * minf(speed * 0.12, 0.32) if bicycle else 0.0
		_pose_bone("thigh." + side, Vector3((0.04 if scooter else (1.30 if car else 0.90)) + pedal, 0, 0))
		_pose_bone("shin." + side, Vector3((0.06 if scooter else (-1.48 if car else -1.25)) - pedal * 0.8, 0, 0))
		_pose_bone("foot." + side, Vector3(0.03 if scooter else 0.14, 0, 0))
		_pose_bone("upper_arm." + side, Vector3(1.12 if car else (0.88 if scooter else 1.05), 0, 0.10 if side == "L" else -0.10))
		_pose_bone("forearm." + side, Vector3(0.35 if car else 0.24, 0, 0))
		_pose_bone("hand." + side, Vector3(0.0, 0.0, 0.0))


func _pose_bone(bone: String, euler: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(euler))
