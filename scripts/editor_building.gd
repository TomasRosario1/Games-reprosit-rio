class_name AlbumEditorBuilding
extends Node3D
## Original closed building preset; textured façade, cornices and tiled roof.
var dimensions := Vector3(8,10,8)

func _ready() -> void:
	var plaster := _material("city_plaster",Color("d9d0bc"))
	var stone := _material("city_stone",Color("b6ae9d"))
	var roof := _material("city_roof",Color("b99b88"))
	var frame := _material("wood",Color("8f8d80"))
	var window := _material("glass",Color("959f90"))
	window.emission_enabled = true
	window.emission = Color("d4c48c")
	window.emission_texture = window.albedo_texture
	window.emission_energy_multiplier = 0.32
	_piece(Vector3(0,dimensions.y*0.5,0),dimensions,plaster,false)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position.y = dimensions.y*0.5
	body.add_child(collider)
	add_child(body)
	var floors := maxi(1,floori(dimensions.y/3.0))
	for floor_index in floors:
		var y := 1.65+floor_index*(dimensions.y/float(floors))
		for side in [-1.0,1.0]:
			for column in maxi(1,floori(dimensions.x/2.3)):
				var count := maxi(1,floori(dimensions.x/2.3))
				var x := -dimensions.x*0.5+(column+0.5)*dimensions.x/count
				var at := Vector3(x,y,side*(dimensions.z*0.5+0.025))
				_piece(at,Vector3(1.32,1.65,0.10),frame,true)
				_piece(at+Vector3(0,0,side*0.06),Vector3(1.12,1.4,0.035),window,true)
				_piece(at+Vector3(0,-0.88,0),Vector3(1.58,0.15,0.3),stone,true)
			for column in maxi(1,floori(dimensions.z/2.5)):
				var count := maxi(1,floori(dimensions.z/2.5))
				var z := -dimensions.z*0.5+(column+0.5)*dimensions.z/count
				_piece(Vector3(side*(dimensions.x*0.5+0.03),y,z),Vector3(0.10,1.65,1.32),frame,true)
				_piece(Vector3(side*(dimensions.x*0.5+0.10),y,z),Vector3(0.035,1.4,1.12),window,true)
		_piece(Vector3(0,(floor_index+1)*dimensions.y/floors,0),Vector3(dimensions.x+0.25,0.16,dimensions.z+0.25),stone,true)
	for side in [-1.0,1.0]:
		var half := _piece(Vector3(side*dimensions.x*0.25,dimensions.y+0.7,0),Vector3(dimensions.x*0.53,0.16,dimensions.z+0.5),roof,true)
		half.rotation.z = side*-atan2(1.4,dimensions.x*0.5)
	_piece(Vector3(0,1.18,dimensions.z*0.5+0.09),Vector3(1.15,2.36,0.16),frame,true)
	_batch_details()

func get_editor_bounds() -> AABB:
	return AABB(Vector3(-dimensions.x*0.5-0.3,0,-dimensions.z*0.5-0.3),Vector3(dimensions.x+0.6,dimensions.y+1.5,dimensions.z+0.6))

func _batch_details() -> void:
	var groups := {}
	for child in get_children():
		if not child is MeshInstance3D or not child.get_meta("editor_keep_material",false): continue
		var mat: Material = child.material_override
		var key := mat.get_instance_id()
		if not groups.has(key): groups[key] = {"material":mat,"transforms":[]}
		var transform: Transform3D = child.transform
		transform.basis = transform.basis.scaled_local(child.mesh.size)
		groups[key].transforms.append(transform)
		remove_child(child)
		child.free()
	for key in groups:
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = BoxMesh.new()
		batch.multimesh.mesh.size = Vector3.ONE
		batch.multimesh.instance_count = groups[key].transforms.size()
		for i in batch.multimesh.instance_count:
			batch.multimesh.set_instance_transform(i,groups[key].transforms[i])
		batch.material_override = groups[key].material
		batch.visibility_range_end = 100.0
		batch.set_meta("editor_keep_material",true)
		add_child(batch)

func _material(key: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/"+key+".png")
	mat.albedo_color = tint
	mat.roughness = 0.85
	mat.roughness_texture = load("res://assets/textures/"+key+"_rough.png")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/"+key+"_normal.png")
	mat.normal_scale = 0.25
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*0.5
	return mat

func _piece(at: Vector3, size_value: Vector3, mat: Material, preserve: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_value
	node.mesh = box
	node.position = at
	node.material_override = mat
	node.visibility_range_end = 100.0
	node.set_meta("editor_keep_material",preserve)
	add_child(node)
	return node
