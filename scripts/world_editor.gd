class_name AlbumWorldEditor
extends Control
## Runtime creator tools. World edits and player progress are separate files.
## AI outputs are data proposals with a closed schema, never executable scripts.

signal closed
const SAVE_VERSION := 1
const MAX_HISTORY := 80
const CATALOG := ["Parede", "Porta", "Luz", "NPC", "Missão", "Carro", "Mota", "Bicicleta", "Trotinete", "Peça"]
const MATERIALS := ["existing", "stucco", "wood", "metal", "tiles", "city_stone"]
const PERSONALITIES := ["calm", "intoxicated", "dreamy", "timid", "security"]
const RESERVED_ROOT := "EditorObjects"
var world: Node3D
var player: Node3D
var vehicle_manager: Node3D
var save_path := "user://world_edits.json"
var active := false
var selected_id := ""
var camera: Camera3D
var targets: Dictionary = {}
var last_error := ""
var _original: Dictionary = {}
var _added: Dictionary = {}
var _overrides: Dictionary = {}
var _base_edits: Dictionary = {}
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _spawn_root: Node3D
var _override_root: Node3D
var _selection_box: MeshInstance3D
var _list: ItemList
var _filter: LineEdit
var _list_ids: Array[String] = []
var _status: Label
var _selection_name: Label
var _spins: Dictionary = {}
var _color: ColorPickerButton
var _material: OptionButton
var _appearance: SpinBox
var _personality: OptionButton
var _mission_title: LineEdit
var _mission_kind: OptionButton
var _mission_reward: SpinBox
var _mission_box: VBoxContainer
var _npc_box: VBoxContainer
var _light_box: VBoxContainer
var _energy: SpinBox
var _light_range: SpinBox
var _refreshing := false
var _yaw := 0.0
var _pitch := -0.25
var _looking := false
var _previous_camera: Camera3D
var _previous_world_process_mode: int = Node.PROCESS_MODE_INHERIT
var _counter := 0
var _model: LineEdit
var _command: TextEdit
var _ai_response: TextEdit
var _request: HTTPRequest
var _preview_before: Dictionary = {}
var _preview_after: Dictionary = {}
var _apply_ai: Button
var _cancel_ai: Button
var _ai_send: Button
var _glb_path: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()
	set_process(false)
	set_process_unhandled_input(false)

func configure(map: Node3D, actor: Node3D, vehicles: Node3D = null) -> void:
	world = map
	player = actor
	vehicle_manager = vehicles
	if not is_node_ready():
		await ready
	_spawn_root = world.get_node_or_null(RESERVED_ROOT)
	if _spawn_root == null:
		_spawn_root = Node3D.new()
		_spawn_root.name = RESERVED_ROOT
		world.add_child(_spawn_root)
	_override_root = Node3D.new()
	_override_root.name = "EditorVisualOverrides"
	world.add_child(_override_root)
	camera = Camera3D.new()
	camera.name = "CreatorCamera"
	camera.fov = 65.0
	camera.near = 0.08
	camera.far = 130.0
	world.add_child(camera)
	_build_selection_box()
	_index_base(world)
	_refresh_list()
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		load_world()

func enter_editor() -> void:
	if not is_instance_valid(world) or not is_instance_valid(camera): return
	_previous_camera = get_viewport().get_camera_3d()
	if _previous_camera != camera and is_instance_valid(_previous_camera):
		camera.global_transform = _previous_camera.global_transform
	elif is_instance_valid(player):
		camera.global_position = player.global_position + Vector3(0,4,7)
		camera.look_at(player.global_position+Vector3.UP)
	var angles := camera.global_basis.get_euler()
	_yaw = angles.y
	_pitch = angles.x
	camera.make_current()
	_previous_world_process_mode = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	active = true
	show()
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_status("Editor local • rato direito: olhar • WASD: voar • Q/E: altura • Shift: acelerar")

func exit_editor() -> void:
	cancel_ai_preview()
	active = false
	if is_instance_valid(world): world.process_mode = _previous_world_process_mode
	_looking = false
	hide()
	set_process(false)
	set_process_unhandled_input(false)
	_selection_box.hide()
	if is_instance_valid(_previous_camera): _previous_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()

func _process(delta: float) -> void:
	if not active: return
	if _looking:
		var input_axis := Input.get_vector("move_left","move_right","move_forward","move_back")
		var vertical := float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
		var direction := camera.global_basis*Vector3(input_axis.x,vertical,input_axis.y)
		var speed := 16.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 6.0
		camera.global_position += direction.limit_length(1.0)*delta*speed
	_update_selection_box()

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x*0.003
		_pitch = clampf(_pitch-event.relative.y*0.003,-1.5,1.5)
		camera.global_rotation = Vector3(_pitch,_yaw,0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_ray(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z: undo()
		elif event.keycode == KEY_Y: redo()
		elif event.keycode == KEY_S: save_world()

func _index_base(parent: Node) -> void:
	for child in parent.get_children():
		if child == camera or child == _spawn_root or child == _override_root or child == _selection_box: continue
		if child is CharacterBody3D:
			_register_base(child,"actor")
			continue
		if child is MultiMeshInstance3D and child.multimesh != null:
			for index in child.multimesh.instance_count:
				_register_base(child,"batch",index)
			continue
		if child is MeshInstance3D and child.mesh != null:
			# Exclude the very large ground slab. Its absence would break the entire map.
			if child.mesh.get_aabb().size.length() < 85.0:
				_register_base(child,"mesh")
			continue
		if child is OmniLight3D or child is SpotLight3D:
			_register_base(child,"light")
			continue
		_index_base(child)

func _register_base(node: Node3D, kind: String, instance: int = -1) -> void:
	var at := node.global_transform
	var mesh: Mesh
	if kind == "batch":
		at *= node.multimesh.get_instance_transform(instance)
		mesh = node.multimesh.mesh
	elif node is MeshInstance3D:
		mesh = node.mesh
	var dimensions := mesh.get_aabb().size if mesh else Vector3.ZERO
	var texture := ""
	var material := _vehicle_paint_material(node) if node.has_method("get_seat_position") else _base_material(node,kind)
	if material is StandardMaterial3D and material.albedo_texture:
		texture = material.albedo_texture.resource_path
	var signature := "%s|%s|%s|%s|%s" % [kind,_rounded(at.origin),_rounded(dimensions),_rounded(at.basis.get_scale()),texture]
	var id := "base/"+signature.sha256_text().substr(0,22)
	var suffix := 0
	while targets.has(id):
		suffix += 1
		id = "base/"+signature.sha256_text().substr(0,22)+"_"+str(suffix)
	targets[id] = {"node":node,"kind":kind,"instance":instance,"material":material,"original_transform":at,"name":_target_name(node,kind,at.origin)}
	_original[id] = get_target_state(id)

func _rounded(value: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [value.x,value.y,value.z]

func _target_name(node: Node3D, kind: String, at: Vector3) -> String:
	var label := "Peça de fachada" if kind == "batch" else str(node.name).get_slice("@",0)
	if label.is_empty(): label = "Objeto"
	if kind == "actor": label = ("Veículo / " if node.has_method("get_seat_position") else "Personagem / ")+str(node.name)
	if kind == "light": label = "Luz"
	return "%s  [%.0f, %.0f]" % [label,at.x,at.z]

func _base_material(node: Node3D, kind: String) -> Material:
	if node is GeometryInstance3D:
		if node.material_override: return node.material_override
		var mesh: Mesh = node.multimesh.mesh if kind == "batch" else node.mesh
		if mesh and mesh.get_surface_count() > 0: return mesh.surface_get_material(0)
	return null

func get_target_state(id: String) -> Dictionary:
	if not targets.has(id): return {}
	var item: Dictionary = targets[id]
	var node: Node3D = item.node
	if not is_instance_valid(node): return {}
	var at := node.global_transform
	if item.kind == "batch":
		at = node.global_transform*node.multimesh.get_instance_transform(item.instance)
		if _overrides.has(id) and is_instance_valid(_overrides[id]): at = _overrides[id].global_transform
	var existing: Dictionary = _base_edits.get(id,{}) if id.begins_with("base/") else _added.get(id,{}).get("state",{})
	if item.kind == "batch" and not existing.get("visible",true) and existing.has_all(["position","rotation","scale"]):
		at = Transform3D(Basis.from_euler(_array_vec(existing.rotation)*PI/180.0).scaled(_array_vec(existing.scale)),_array_vec(existing.position))
	var color := Color.WHITE
	if item.material is StandardMaterial3D: color = item.material.albedo_color
	if node is Light3D: color = node.light_color
	var state := {"position":_vec_array(at.origin),"rotation":_vec_array(at.basis.get_euler()*180.0/PI),"scale":_vec_array(at.basis.get_scale()),"color":existing.get("color",color.to_html()),"preset":existing.get("preset","existing"),"visible":existing.get("visible",node.visible)}
	if node is Light3D:
		state["energy"] = node.light_energy
		state["range"] = node.omni_range if node is OmniLight3D else node.spot_range
	if node is CharacterBody3D and node.get("appearance_id") != null:
		state["appearance_id"] = node.appearance_id
		state["personality"] = node.personality
	if node.has_meta("editor_mission"):
		state["mission"] = node.get_meta("editor_mission").duplicate(true)
	return state

func edit_target(id: String, changes: Dictionary) -> bool:
	if not targets.has(id) or not _valid_changes(changes): return false
	cancel_ai_preview()
	var before := get_target_state(id)
	var after := before.duplicate(true)
	for key in changes: after[key] = changes[key]
	_apply_state(id,after)
	_record({id:before},{id:after})
	_refresh_inspector()
	_update_selection_box()
	return true

func _apply_state(id: String, state: Dictionary) -> void:
	if not targets.has(id): return
	var item: Dictionary = targets[id]
	var node: Node3D = item.node
	if not is_instance_valid(node): return
	var position := _array_vec(state.position)
	var rotation := _array_vec(state.rotation)*PI/180.0
	var scale_value := _array_vec(state.scale)
	var at := Transform3D(Basis.from_euler(rotation).scaled(scale_value),position)
	var tinted: bool = state.get("preset","existing") != "existing" or str(state.get("color","ffffffff")) != str(_original.get(id,{}).get("color",state.get("color","ffffffff")))
	if item.kind == "batch":
		if tinted:
			if not _overrides.has(id) or not is_instance_valid(_overrides[id]):
				var replacement := MeshInstance3D.new()
				replacement.mesh = node.multimesh.mesh
				_override_root.add_child(replacement)
				_overrides[id] = replacement
			_overrides[id].global_transform = at
			_overrides[id].material_override = _material_for(state,item.material)
			_overrides[id].visible = state.get("visible",true)
			node.multimesh.set_instance_transform(item.instance,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO))
		else:
			if _overrides.has(id) and is_instance_valid(_overrides[id]): _overrides[id].queue_free()
			_overrides.erase(id)
			var local_at := node.global_transform.affine_inverse()*at
			if not state.get("visible",true): local_at.basis = Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
			node.multimesh.set_instance_transform(item.instance,local_at)
	else:
		var offset := position-node.global_position
		if node is CharacterBody3D and node.get("route") != null and offset.length_squared() > 0.000001:
			var points: PackedVector3Array = node.route
			for i in points.size(): points[i] += offset
			node.route = points
		node.global_transform = at
		node.visible = state.get("visible",true)
		_set_collision_visibility(node,node.visible)
		if node is CollisionObject3D:
			if not node.has_meta("editor_collision_layer"): node.set_meta("editor_collision_layer",node.collision_layer)
			node.collision_layer = node.get_meta("editor_collision_layer") if node.visible else 0
			if node is CharacterBody3D: node.velocity = Vector3.ZERO
		elif node is MeshInstance3D:
			node.material_override = _material_for(state,item.material)
			for child in node.get_children():
				if child is CollisionObject3D:
					if not child.has_meta("editor_collision_layer"): child.set_meta("editor_collision_layer",child.collision_layer)
					child.collision_layer = child.get_meta("editor_collision_layer") if node.visible else 0
		if item.kind == "object": _set_object_material(node,_material_for(state,item.material))
		elif node.has_method("get_seat_position"):
			_set_vehicle_paint(node,item.material,_material_for(state,item.material))
		if node is Light3D:
			node.light_color = Color.from_string(state.color,Color.WHITE)
			node.light_energy = float(state.get("energy",node.light_energy))
			if node is OmniLight3D: node.omni_range = float(state.get("range",node.omni_range))
			else: node.spot_range = float(state.get("range",node.spot_range))
		if node is CharacterBody3D and state.has("appearance_id") and node.has_method("configure"):
			node.configure(int(state.appearance_id),str(state.get("personality","calm")),node.route)
		if state.has("mission"):
			node.set_meta("editor_mission",state.mission.duplicate(true))
	if id.begins_with("base/"): _base_edits[id] = state.duplicate(true)
	elif _added.has(id): _added[id]["state"] = state.duplicate(true)

func _material_for(state: Dictionary, original: Material) -> StandardMaterial3D:
	var preset: String = state.get("preset","existing")
	var mat: StandardMaterial3D = original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
	if preset != "existing":
		var path := "res://assets/textures/"+preset+".png"
		if ResourceLoader.exists(path): mat.albedo_texture = load(path)
		var rough := "res://assets/textures/"+preset+"_rough.png"
		if ResourceLoader.exists(rough): mat.roughness_texture = load(rough)
		mat.roughness = 0.85
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE*0.5
	mat.albedo_color = Color.from_string(state.get("color","ffffffff"),Color.WHITE)
	return mat

func _record(before: Dictionary, after: Dictionary) -> void:
	_history.append({"before":before.duplicate(true),"after":after.duplicate(true)})
	if _history.size() > MAX_HISTORY: _history.pop_front()
	_redo.clear()

func undo() -> bool:
	cancel_ai_preview()
	if _history.is_empty(): return false
	var change: Dictionary = _history.pop_back()
	for id in change.before: _apply_state(id,change.before[id])
	_redo.append(change)
	_refresh_inspector()
	_update_selection_box()
	_set_status("Alteração desfeita.")
	return true

func redo() -> bool:
	cancel_ai_preview()
	if _redo.is_empty(): return false
	var change: Dictionary = _redo.pop_back()
	for id in change.after: _apply_state(id,change.after[id])
	_history.append(change)
	_refresh_inspector()
	_update_selection_box()
	_set_status("Alteração refeita.")
	return true

func delete_selected() -> void:
	if selected_id.is_empty(): return
	edit_target(selected_id,{"visible":false})
	_set_status("Objeto ocultado e colisão desativada. Desfazer recupera-o.")

func duplicate_selected() -> void:
	if not targets.has(selected_id): return
	var source: Dictionary = targets[selected_id]
	var state := get_target_state(selected_id)
	state.position[0] += 1.0
	if source.has("catalog"):
		var entry: Dictionary = _added[selected_id]
		spawn_catalog(source.catalog,_array_vec(state.position),state,entry.get("resource",""),entry.get("geometry",{}))
		return
	var mesh: Mesh
	if source.kind == "batch": mesh = source.node.multimesh.mesh
	elif source.node is MeshInstance3D: mesh = source.node.mesh
	if mesh is BoxMesh:
		var solid := false
		for child in source.node.get_children():
			if child is StaticBody3D: solid = true
		spawn_catalog("Peça",_array_vec(state.position),state,"",{"size":_vec_array(mesh.size),"collision":solid,"centered":true})
	else:
		_set_status("Este recurso complexo deve ser colocado a partir do respetivo GLB.")

func spawn_catalog(kind: String, position: Vector3, state_override: Dictionary = {}, resource_path: String = "", geometry: Dictionary = {}) -> String:
	if not CATALOG.has(kind) and kind != "GLB": return ""
	if not _valid_changes(state_override) or not _valid_geometry(geometry) or not position.is_finite(): return ""
	if kind == "GLB" and (not resource_path.begins_with("res://") or not resource_path.to_lower().ends_with(".glb") and not resource_path.to_lower().ends_with(".gltf")):
		_set_status("Importa primeiro um GLB/GLTF para assets no projeto.")
		return ""
	_counter += 1
	var id := "added/%08d" % _counter
	var node := _make_catalog_node(kind,position,resource_path,geometry)
	if node == null: return ""
	node.name = "Criado_%08d" % _counter
	_spawn_root.add_child(node)
	if kind in ["Carro","Mota","Bicicleta","Trotinete"] and is_instance_valid(vehicle_manager) and vehicle_manager.has_method("register_vehicle"):
		vehicle_manager.register_vehicle(node)
	targets[id] = {"node":node,"kind":"light" if node is Light3D else "actor" if node is CharacterBody3D else "object","instance":-1,"material":_editable_material(node),"name":kind+" / "+str(_counter),"catalog":kind}
	var state := get_target_state(id)
	for key in state_override: state[key] = state_override[key]
	_added[id] = {"catalog":kind,"resource":resource_path,"geometry":geometry.duplicate(true),"state":state.duplicate(true)}
	_apply_state(id,state)
	var hidden := state.duplicate(true)
	hidden.visible = false
	_record({id:hidden},{id:state})
	_refresh_list()
	select_target(id)
	_set_status(kind+" criado. Ajusta a posição e guarda o mundo.")
	return id

func _make_catalog_node(kind: String, at: Vector3, resource_path: String = "", geometry: Dictionary = {}) -> Node3D:
	var node: Node3D
	if kind == "Luz":
		var light := OmniLight3D.new()
		light.light_color = Color("ffd09a")
		light.light_energy = 1.8
		light.omni_range = 8.0
		node = light
	elif kind == "NPC" and ResourceLoader.exists("res://scripts/npc.gd"):
		node = load("res://scripts/npc.gd").new()
		var route := PackedVector3Array([at,at+Vector3(3,0,0),at+Vector3(3,0,3),at+Vector3(0,0,3)])
		node.configure(0,"calm",route)
		if is_instance_valid(player): node.set_player(player)
	elif kind == "Missão":
		node = Node3D.new()
		node.set_meta("editor_mission",{"title":"Novo encontro","kind":"visitar","reward":50,"completed":false})
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.35
		ring.outer_radius = 0.45
		marker.mesh = ring
		marker.position.y = 0.15
		var material := _material_for({"preset":"metal","color":"82c9baff"},null)
		material.emission_enabled = true
		material.emission = Color("82c9ba")
		material.emission_energy_multiplier = 1.3
		marker.material_override = material
		node.add_child(marker)
	elif kind in ["Carro","Mota","Bicicleta","Trotinete"]:
		var script_path := "res://scripts/vehicle.gd"
		if not ResourceLoader.exists(script_path):
			_set_status("O sistema de veículos ainda não está disponível nesta versão.")
			return null
		node = load(script_path).new()
		var names := {"Carro":"car","Mota":"motorcycle","Bicicleta":"bicycle","Trotinete":"scooter"}
		if node.has_method("configure"): node.configure(names[kind])
		elif node.get("vehicle_type") != null: node.set("vehicle_type",names[kind])
	elif kind == "GLB":
		if not ResourceLoader.exists(resource_path): return null
		var resource = load(resource_path)
		if not resource is PackedScene: return null
		node = resource.instantiate()
		_add_mesh_collision(node)
	else:
		node = Node3D.new()
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = _array_vec(geometry.get("size",[1,1,1])) if kind == "Peça" else Vector3(2.4,2.8,0.28) if kind == "Parede" else Vector3(1.0,2.2,0.12)
		collider.shape = shape
		collider.position.y = 0.0 if geometry.get("centered",false) else shape.size.y*0.5
		body.add_child(collider)
		if geometry.get("collision",true): node.add_child(body)
		else: body.free()
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		mesh.mesh = box
		mesh.position.y = 0.0 if geometry.get("centered",false) else shape.size.y*0.5
		mesh.material_override = _material_for({"preset":"stucco" if kind == "Parede" else "wood","color":"ffffffff"},null)
		node.add_child(mesh)
	node.position = at
	return node

func _add_mesh_collision(node: Node) -> void:
	if node is MeshInstance3D: node.create_trimesh_collision()
	for child in node.get_children():
		if child is Node3D and not child is CollisionObject3D: _add_mesh_collision(child)

func _set_collision_visibility(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		if not node.has_meta("editor_collision_layer"): node.set_meta("editor_collision_layer",node.collision_layer)
		node.collision_layer = node.get_meta("editor_collision_layer") if enabled else 0
	for child in node.get_children(): _set_collision_visibility(child,enabled)

func _set_object_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
		return
	for child in node.get_children(): _set_object_material(child,mat)

func _valid_geometry(geometry) -> bool:
	if not geometry is Dictionary: return false
	if geometry.is_empty(): return true
	if not geometry.has_all(["size","collision"]) or not geometry.collision is bool or not geometry.size is Array or geometry.size.size() != 3: return false
	if geometry.has("centered") and not geometry.centered is bool: return false
	for value in geometry.size:
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<=0 or float(value)>100: return false
	return true

func _editable_material(node: Node3D) -> Material:
	return _vehicle_paint_material(node) if node.has_method("get_seat_position") else _first_material(node)

func _vehicle_paint_material(node: Node) -> Material:
	if node is MeshInstance3D:
		var mat: Material = node.material_override
		if mat is StandardMaterial3D and mat.albedo_texture and mat.albedo_texture.resource_path.ends_with("/metal.png") and mat.albedo_color != Color.WHITE and not mat.emission_enabled:
			return mat
	for child in node.get_children():
		var found := _vehicle_paint_material(child)
		if found: return found
	return null

func _set_vehicle_paint(node: Node, original: Material, replacement: Material) -> void:
	if node is MeshInstance3D and (node.get_meta("editor_paint",false) or node.material_override == original):
		node.material_override = replacement
		node.set_meta("editor_paint",true)
	for child in node.get_children(): _set_vehicle_paint(child,original,replacement)

func _first_material(node: Node) -> Material:
	if node is MeshInstance3D: return _base_material(node,"mesh")
	for child in node.get_children():
		var found := _first_material(child)
		if found: return found
	return null

func get_nearest_mission(at: Vector3) -> Dictionary:
	var nearest := 2.7
	var result := {}
	for id in _added:
		if not targets.has(id): continue
		var node: Node3D = targets[id].node
		if not node.visible or not node.has_meta("editor_mission"): continue
		var data: Dictionary = node.get_meta("editor_mission")
		if data.get("completed",false): continue
		var distance := node.global_position.distance_to(at)
		if distance < nearest:
			nearest = distance
			result = data.duplicate(true)
			result["id"] = id
			result["available"] = true
	return result

func interact_mission(id: String) -> Dictionary:
	if not targets.has(id): return {}
	var node: Node3D = targets[id].node
	if not node.has_meta("editor_mission"): return {}
	var mission: Dictionary = node.get_meta("editor_mission").duplicate(true)
	if mission.get("completed",false): return {}
	mission.completed = true
	node.set_meta("editor_mission",mission)
	if _added.has(id): _added[id].state.mission = mission
	save_world()
	return {"text":mission.title+" — concluída.","reward":int(mission.reward),"completed":true}

func _valid_changes(changes: Dictionary) -> bool:
	var keys := ["position","rotation","scale","color","preset","visible","energy","range","appearance_id","personality","mission"]
	for key in changes:
		if not keys.has(key): return false
		var value = changes[key]
		if key in ["position","rotation","scale"]:
			if not value is Array or value.size() != 3: return false
			for number in value:
				if not (number is float or number is int) or not is_finite(float(number)): return false
				if absf(float(number)) > 1000.0: return false
				if key == "scale" and (float(number) < 0.05 or float(number) > 15.0): return false
		elif key == "color":
			if not value is String or not Color.html_is_valid(value): return false
		elif key == "preset":
			if not value is String or not MATERIALS.has(value): return false
		elif key == "visible":
			if not value is bool: return false
		elif key in ["energy","range"]:
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100.0: return false
		elif key == "appearance_id":
			if not (value is float or value is int) or int(value) < 0 or int(value)>19: return false
		elif key == "personality":
			if not value is String or not PERSONALITIES.has(value): return false
		elif key == "mission":
			if not value is Dictionary or not value.has_all(["title","kind","reward","completed"]): return false
			if not value.title is String or value.title.length()>100 or not ["visitar","encontro","recolher"].has(value.kind): return false
			if not (value.reward is int or value.reward is float) or int(value.reward)<0 or int(value.reward)>10000 or not value.completed is bool: return false
	return true

func _vec_array(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _array_vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func save_world() -> bool:
	if not _valid_save_path(): return false
	if not _preview_before.is_empty():
		_set_status("Aplica ou cancela a pré-visualização antes de guardar.")
		return false
	var data := {"version":SAVE_VERSION,"base":_base_edits,"added":_added,"counter":_counter}
	var temporary := save_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		_set_status("Falha ao guardar: pasta de dados sem acesso.")
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_file(temporary).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		_set_status("Escrita incompleta. A gravação anterior foi preservada.")
		return false
	if FileAccess.file_exists(save_path):
		var current := _read_file(save_path)
		if not current.is_empty():
			var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),ProjectSettings.globalize_path(save_path+".bak.tmp"))
			if error != OK:
				_set_status("Não foi possível preservar o backup. Gravação cancelada.")
				return false
			if _read_file(save_path+".bak.tmp").is_empty() or DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".bak.tmp"),ProjectSettings.globalize_path(save_path+".bak")) != OK:
				_set_status("Falha ao confirmar o backup. O mundo anterior foi preservado.")
				return false
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path))
	_set_status("Mundo guardado localmente em world_edits.json." if result == OK else "Falha ao substituir o ficheiro de dados.")
	return result == OK

func _valid_save_path() -> bool:
	var filename := save_path.trim_prefix("user://")
	return save_path.begins_with("user://") and filename == filename.get_file() and filename.ends_with(".json") and filename.length()<100

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 4000000: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	var parsed = json.data
	if not parsed is Dictionary or parsed.get("version",0) != SAVE_VERSION or not parsed.get("base",null) is Dictionary or not parsed.get("added",null) is Dictionary: return {}
	for id in parsed.base:
		if not id is String or not id.begins_with("base/") or not parsed.base[id] is Dictionary or not parsed.base[id].has_all(["position","rotation","scale","color","preset","visible"]) or not _valid_changes(parsed.base[id]): return {}
	for id in parsed.added:
		var entry = parsed.added[id]
		if not id is String or not id.begins_with("added/") or not entry is Dictionary or not entry.has_all(["catalog","resource","state"]): return {}
		if not entry.catalog is String or not CATALOG.has(entry.catalog) and entry.catalog != "GLB": return {}
		if not entry.resource is String or not entry.state is Dictionary or not entry.state.has_all(["position","rotation","scale","color","preset","visible"]) or not _valid_changes(entry.state): return {}
		if entry.has("geometry") and not _valid_geometry(entry.geometry): return {}
		if entry.catalog == "GLB" and (not entry.resource.begins_with("res://") or not entry.resource.to_lower().ends_with(".glb") and not entry.resource.to_lower().ends_with(".gltf")): return {}
	return parsed

func load_world() -> bool:
	if not _valid_save_path(): return false
	cancel_ai_preview()
	var data := _read_file(save_path)
	if data.is_empty(): data = _read_file(save_path+".bak")
	if data.is_empty():
		_set_status("A gravação está ausente ou inválida. O cenário atual foi preservado.")
		return false
	for id in _original: _apply_state(id,_original[id])
	for id in _added:
		if targets.has(id) and is_instance_valid(targets[id].node): targets[id].node.queue_free()
		targets.erase(id)
	_added.clear()
	_base_edits.clear()
	for id in data.base:
		if targets.has(id): _apply_state(id,data.base[id])
	_counter = 0
	for saved_id in data.added:
		var entry: Dictionary = data.added[saved_id]
		var node := _make_catalog_node(entry.catalog,_array_vec(entry.state.position),entry.resource,entry.get("geometry",{}))
		if node == null: continue
		node.name = "Criado_"+saved_id.get_slice("/",1)
		_spawn_root.add_child(node)
		if entry.catalog in ["Carro","Mota","Bicicleta","Trotinete"] and is_instance_valid(vehicle_manager) and vehicle_manager.has_method("register_vehicle"):
			vehicle_manager.register_vehicle(node)
		targets[saved_id] = {"node":node,"kind":"light" if node is Light3D else "actor" if node is CharacterBody3D else "object","instance":-1,"material":_editable_material(node),"name":entry.catalog+" / "+saved_id.get_slice("/",1),"catalog":entry.catalog}
		_added[saved_id] = entry.duplicate(true)
		_apply_state(saved_id,entry.state)
		_counter = maxi(_counter,int(saved_id.get_slice("/",1)))
	_history.clear()
	_redo.clear()
	_refresh_list()
	select_target("")
	_set_status("Mundo carregado. As alterações do jogador permanecem separadas.")
	return true

func select_target(id: String) -> void:
	selected_id = id if targets.has(id) else ""
	_refresh_inspector()
	_update_selection_box()

func _select_ray(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best := INF
	var selected := ""
	for id in targets:
		var item: Dictionary = targets[id]
		var state := get_target_state(id)
		if not state.get("visible",true): continue
		var bounds := _world_bounds(id)
		var hit = bounds.intersects_ray(origin,direction)
		if hit is Vector3:
			var distance := origin.distance_to(hit)
			if distance < best:
				best = distance
				selected = id
	select_target(selected)

func _world_bounds(id: String) -> AABB:
	if not targets.has(id): return AABB()
	var item: Dictionary = targets[id]
	var node: Node3D = item.node
	var state := get_target_state(id)
	var at := Transform3D(Basis.from_euler(_array_vec(state.rotation)*PI/180.0).scaled(_array_vec(state.scale)),_array_vec(state.position))
	if item.kind == "batch": return at*node.multimesh.mesh.get_aabb()
	if node is MeshInstance3D: return at*node.mesh.get_aabb()
	if node is Light3D: return AABB(at.origin-Vector3.ONE*0.25,Vector3.ONE*0.5)
	if node is CharacterBody3D: return at*AABB(Vector3(-0.45,0,-0.45),Vector3(0.9,1.9,0.9))
	var result := AABB(at.origin-Vector3(0.5,0,0.5),Vector3(1,2,1))
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh: result = result.merge(child.global_transform*child.mesh.get_aabb())
	return result

func _build_selection_box() -> void:
	_selection_box = MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("95e5c8")
	lines.surface_begin(Mesh.PRIMITIVE_LINES,material)
	var corners := [Vector3(0,0,0),Vector3(1,0,0),Vector3(1,1,0),Vector3(0,1,0),Vector3(0,0,1),Vector3(1,0,1),Vector3(1,1,1),Vector3(0,1,1)]
	for pair in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,0),Vector2i(4,5),Vector2i(5,6),Vector2i(6,7),Vector2i(7,4),Vector2i(0,4),Vector2i(1,5),Vector2i(2,6),Vector2i(3,7)]:
		lines.surface_add_vertex(corners[pair.x])
		lines.surface_add_vertex(corners[pair.y])
	lines.surface_end()
	_selection_box.mesh = lines
	_selection_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_selection_box)
	_selection_box.hide()

func _update_selection_box() -> void:
	if not active or not targets.has(selected_id):
		_selection_box.hide()
		return
	var bounds := _world_bounds(selected_id).grow(0.025)
	_selection_box.global_position = bounds.position
	_selection_box.scale = bounds.size.max(Vector3.ONE*0.01)
	_selection_box.show()

func _spawn_from_camera(kind: String) -> void:
	var at := camera.global_position-camera.global_basis.z*5.0
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*40.0,1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): at = hit.position
	at.y = maxf(0.12,at.y)
	spawn_catalog(kind,at)

func _refresh_list() -> void:
	if _list == null: return
	_list.clear()
	_list_ids.clear()
	var filter_text := _filter.text.to_lower()
	for id in targets:
		var label: String = targets[id].name
		if not get_target_state(id).get("visible",true): label += " [oculto]"
		if not filter_text.is_empty() and not label.to_lower().contains(filter_text): continue
		_list.add_item(label)
		_list_ids.append(id)

func _refresh_inspector() -> void:
	if _selection_name == null: return
	_refreshing = true
	var available := targets.has(selected_id)
	_selection_name.text = targets[selected_id].name if available else "Seleciona um objeto"
	var data := get_target_state(selected_id) if available else {"position":[0,0,0],"rotation":[0,0,0],"scale":[1,1,1],"color":"ffffffff","preset":"existing"}
	for key in ["position","rotation","scale"]:
		for axis in 3:
			_spins[key][axis].editable = available
			_spins[key][axis].value = float(data[key][axis])
	_color.color = Color.from_string(data.get("color","ffffffff"),Color.WHITE)
	_material.select(maxi(0,MATERIALS.find(data.get("preset","existing"))))
	_light_box.visible = data.has("energy")
	if _light_box.visible:
		_energy.value = data.energy
		_light_range.value = data.range
	_npc_box.visible = data.has("appearance_id")
	if _npc_box.visible:
		_appearance.value = data.appearance_id
		_personality.select(maxi(0,PERSONALITIES.find(data.personality)))
	_mission_box.visible = data.has("mission")
	if _mission_box.visible:
		_mission_title.text = data.mission.title
		_mission_kind.select(maxi(0,["visitar","encontro","recolher"].find(data.mission.kind)))
		_mission_reward.value = data.mission.reward
	_refreshing = false

func _inspector_vector(_value: float, key: String) -> void:
	if _refreshing or selected_id.is_empty(): return
	var vector := []
	for spin in _spins[key]: vector.append(spin.value)
	edit_target(selected_id,{key:vector})

func _inspector_color(color: Color) -> void:
	if not _refreshing and not selected_id.is_empty(): edit_target(selected_id,{"color":color.to_html()})

func _inspector_material(index: int) -> void:
	if not _refreshing and not selected_id.is_empty(): edit_target(selected_id,{"preset":MATERIALS[index]})

func _inspector_light(_value: float) -> void:
	if not _refreshing and not selected_id.is_empty(): edit_target(selected_id,{"energy":_energy.value,"range":_light_range.value})

func _inspector_npc(_value = null) -> void:
	if not _refreshing and not selected_id.is_empty(): edit_target(selected_id,{"appearance_id":int(_appearance.value),"personality":PERSONALITIES[_personality.selected]})

func _inspector_mission(_value = null) -> void:
	if _refreshing or selected_id.is_empty(): return
	var current: Dictionary = get_target_state(selected_id).get("mission",{})
	current["title"] = _mission_title.text
	current["kind"] = ["visitar","encontro","recolher"][_mission_kind.selected]
	current["reward"] = int(_mission_reward.value)
	current["completed"] = false
	edit_target(selected_id,{"mission":current})

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14
	if ResourceLoader.exists("res://assets/fonts/Interface.ttf"): theme.default_font = load("res://assets/fonts/Interface.ttf")
	self.theme = theme
	var left := _panel(Vector2(12,12),Vector2(255,-24),false)
	_text(left,"CRIADOR • LISBOA",19)
	_text(left,"Rato direito + WASD: voar\nQ/E: subir/descer • Shift: rápido",12)
	var save_row := HBoxContainer.new()
	left.add_child(save_row)
	_button(save_row,"Guardar",save_world)
	_button(save_row,"Carregar",load_world)
	var undo_row := HBoxContainer.new()
	left.add_child(undo_row)
	_button(undo_row,"Desfazer",undo)
	_button(undo_row,"Refazer",redo)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filtrar objetos…"
	_filter.text_changed.connect(func(_text_value: String): _refresh_list())
	left.add_child(_filter)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 210
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int): select_target(_list_ids[index]))
	left.add_child(_list)
	_text(left,"COLOCAR NO CENÁRIO",12)
	var catalog_grid := GridContainer.new()
	catalog_grid.columns = 2
	left.add_child(catalog_grid)
	for kind in CATALOG: _button(catalog_grid,kind,_spawn_from_camera.bind(kind))
	_glb_path = LineEdit.new()
	_glb_path.placeholder_text = "res://assets/modelo.glb"
	left.add_child(_glb_path)
	_button(left,"Colocar GLB/GLTF",func(): spawn_catalog("GLB",camera.global_position-camera.global_basis.z*5.0,{},_glb_path.text.strip_edges()))
	_button(left,"VOLTAR AO JOGO • F10",exit_editor)
	var right := _panel(Vector2(-318,12),Vector2(306,-24),true)
	_selection_name = _text(right,"Seleciona um objeto",16)
	for key in ["position","rotation","scale"]:
		_text(right,{"position":"POSIÇÃO XYZ","rotation":"ROTAÇÃO XYZ • GRAUS","scale":"ESCALA XYZ"}[key],11)
		var row := HBoxContainer.new()
		right.add_child(row)
		_spins[key] = []
		for axis in 3:
			var spin := SpinBox.new()
			spin.min_value = 0.05 if key == "scale" else -1000.0
			spin.max_value = 15.0 if key == "scale" else 1000.0
			spin.step = 0.05 if key == "scale" else 0.25 if key == "position" else 5.0
			spin.custom_minimum_size.x = 85
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(_inspector_vector.bind(key))
			row.add_child(spin)
			_spins[key].append(spin)
	_color = ColorPickerButton.new()
	_color.custom_minimum_size.y = 30
	_color.color_changed.connect(_inspector_color)
	right.add_child(_color)
	_material = OptionButton.new()
	for preset in MATERIALS: _material.add_item("Material: "+preset)
	_material.item_selected.connect(_inspector_material)
	right.add_child(_material)
	_light_box = VBoxContainer.new()
	right.add_child(_light_box)
	_text(_light_box,"ENERGIA / ALCANCE DA LUZ",11)
	var light_row := HBoxContainer.new()
	_light_box.add_child(light_row)
	_energy = SpinBox.new()
	_energy.min_value = 0
	_energy.max_value = 20
	_energy.step = 0.1
	_energy.value_changed.connect(_inspector_light)
	_energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	light_row.add_child(_energy)
	_light_range = SpinBox.new()
	_light_range.min_value = 0.1
	_light_range.max_value = 100
	_light_range.step = 0.5
	_light_range.value_changed.connect(_inspector_light)
	_light_range.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	light_row.add_child(_light_range)
	_light_box.hide()
	_npc_box = VBoxContainer.new()
	right.add_child(_npc_box)
	_text(_npc_box,"PERSONAGEM / PERSONALIDADE",11)
	_appearance = SpinBox.new()
	_appearance.min_value = 0
	_appearance.max_value = 19
	_appearance.step = 1
	_appearance.value_changed.connect(_inspector_npc)
	_npc_box.add_child(_appearance)
	_personality = OptionButton.new()
	for personality in PERSONALITIES: _personality.add_item(personality)
	_personality.item_selected.connect(_inspector_npc)
	_npc_box.add_child(_personality)
	_npc_box.hide()
	_mission_box = VBoxContainer.new()
	right.add_child(_mission_box)
	_text(_mission_box,"MISSÃO LOCAL",11)
	_mission_title = LineEdit.new()
	_mission_title.placeholder_text = "Nome do encontro"
	_mission_title.text_submitted.connect(_inspector_mission)
	_mission_title.focus_exited.connect(_inspector_mission)
	_mission_box.add_child(_mission_title)
	_mission_kind = OptionButton.new()
	for mission_kind in ["visitar","encontro","recolher"]: _mission_kind.add_item(mission_kind)
	_mission_kind.item_selected.connect(_inspector_mission)
	_mission_box.add_child(_mission_kind)
	_mission_reward = SpinBox.new()
	_mission_reward.max_value = 10000
	_mission_reward.step = 10
	_mission_reward.value_changed.connect(_inspector_mission)
	_mission_box.add_child(_mission_reward)
	_mission_box.hide()
	var object_row := HBoxContainer.new()
	right.add_child(object_row)
	_button(object_row,"Duplicar",duplicate_selected)
	_button(object_row,"Retirar",delete_selected)
	_text(right,"ASSISTENTE LOCAL • OLLAMA",12)
	_model = LineEdit.new()
	_model.text = "qwen2.5:3b"
	_model.placeholder_text = "Modelo instalado no teu PC"
	right.add_child(_model)
	_command = TextEdit.new()
	_command.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_command.placeholder_text = "Ex.: move a luz selecionada 2m para cima"
	_command.custom_minimum_size.y = 72
	right.add_child(_command)
	_ai_send = _button(right,"Pedir proposta à IA local",request_ai)
	_ai_response = TextEdit.new()
	_ai_response.editable = false
	_ai_response.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_ai_response.custom_minimum_size.y = 80
	_ai_response.placeholder_text = "A proposta aparece aqui. Requer Ollama e um modelo já instalados."
	right.add_child(_ai_response)
	var ai_row := HBoxContainer.new()
	right.add_child(ai_row)
	_apply_ai = _button(ai_row,"Aplicar",apply_ai_preview)
	_cancel_ai = _button(ai_row,"Cancelar",cancel_ai_preview)
	_apply_ai.disabled = true
	_cancel_ai.disabled = true
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 65
	right.add_child(_status)
	_request = HTTPRequest.new()
	_request.timeout = 90
	_request.body_size_limit = 262144
	_request.request_completed.connect(_ai_completed)
	add_child(_request)

func _panel(at: Vector2, dimensions: Vector2, from_right: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE if from_right else Control.PRESET_LEFT_WIDE)
	panel.offset_left = at.x
	panel.offset_right = at.x+dimensions.x
	panel.offset_top = at.y
	panel.offset_bottom = dimensions.y+at.y
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.04,0.05,0.97)
	style.border_color = Color("637d76")
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	return box

func _text(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("d8dfcf"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 29
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _set_status(text: String) -> void:
	last_error = text
	if _status: _status.text = text

func get_scene_graph() -> Dictionary:
	var objects := []
	if targets.has(selected_id): objects.append(_graph_entry(selected_id))
	var ids: Array = targets.keys()
	ids.sort_custom(func(a,b): return _array_vec(get_target_state(a).get("position",[0,0,0])).distance_squared_to(camera.global_position)<_array_vec(get_target_state(b).get("position",[0,0,0])).distance_squared_to(camera.global_position))
	for id in ids:
		if id == selected_id: continue
		if objects.size() >= 24: break
		objects.append(_graph_entry(id))
	return {"selected_id":selected_id,"objects":objects}

func _graph_entry(id: String) -> Dictionary:
	return {"id":id,"name":targets[id].name,"state":get_target_state(id)}

func request_ai() -> void:
	if _command.text.strip_edges().is_empty():
		_set_status("Escreve primeiro o que queres alterar.")
		return
	cancel_ai_preview()
	var prompt := "You edit a Godot scene using JSON only. Return {\"actions\":[{\"id\":\"exact object id\",\"position\":[x,y,z]}]}. Allowed fields: position, rotation (degrees), scale, color (HTML hex), preset (existing/stucco/wood/metal/tiles/city_stone), energy, range. Up to12 actions, existing exact IDs only. No code. Coordinates are global. User request: "+_command.text+"\nScene: "+JSON.stringify(get_scene_graph())
	var body := {"model":_model.text.strip_edges(),"prompt":prompt,"stream":false,"format":"json","options":{"temperature":0.1}}
	var error := _request.request("http://127.0.0.1:11434/api/generate",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(body))
	if error != OK:
		_set_status("Não foi possível contactar a IA local. O editor manual continua disponível.")
		return
	_ai_send.disabled = true
	_ai_response.text = "A pedir uma proposta ao modelo local…"

func _ai_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_ai_send.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_ai_response.text = "Sem resposta do Ollama local. Inicia o Ollama e instala o modelo indicado. Nenhum modelo está incluído no jogo."
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_ai_response.text = "Resposta local inválida; nenhuma alteração foi aplicada."
		return
	var envelope = json.data
	if not envelope is Dictionary or not envelope.get("response",null) is String:
		_ai_response.text = "Resposta local inválida; nenhuma alteração foi aplicada."
		return
	_ai_response.text = envelope.response
	var proposal_json := JSON.new()
	if proposal_json.parse(envelope.response) != OK:
		_set_status("A IA não devolveu JSON válido. Nenhuma alteração aplicada.")
		return
	var proposal = proposal_json.data
	if not proposal is Dictionary or not proposal.get("actions",null) is Array or not preview_actions(proposal.actions):
		_set_status("Proposta rejeitada: IDs ou propriedades fora das operações permitidas.")

func preview_actions(actions: Array) -> bool:
	cancel_ai_preview()
	if actions.is_empty() or actions.size()>12: return false
	var before := {}
	var after := {}
	for action in actions:
		if not action is Dictionary or not action.get("id",null) is String or not targets.has(action.id): return false
		var changes: Dictionary = action.duplicate(true)
		var id: String = changes.id
		changes.erase("id")
		if changes.is_empty() or not _valid_changes(changes): return false
		if not before.has(id):
			before[id] = get_target_state(id)
			after[id] = before[id].duplicate(true)
		for key in changes: after[id][key] = changes[key]
	_preview_before = before
	_preview_after = after
	for id in after: _apply_state(id,after[id])
	_apply_ai.disabled = false
	_cancel_ai.disabled = false
	_set_status("PRÉ-VISUALIZAÇÃO. Inspeciona a cena e escolhe Aplicar ou Cancelar.")
	return true

func apply_ai_preview() -> bool:
	if _preview_before.is_empty(): return false
	_record(_preview_before,_preview_after)
	_preview_before.clear()
	_preview_after.clear()
	_apply_ai.disabled = true
	_cancel_ai.disabled = true
	_refresh_inspector()
	_set_status("Proposta aplicada. Desfazer permite voltar atrás.")
	return true

func cancel_ai_preview() -> void:
	for id in _preview_before: _apply_state(id,_preview_before[id])
	_preview_before.clear()
	_preview_after.clear()
	if _apply_ai: _apply_ai.disabled = true
	if _cancel_ai: _cancel_ai.disabled = true
