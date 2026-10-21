class_name AlbumImportedCity
extends Node3D
## Offline OSM crops. Geometry is unloaded; persistent actors and edits live elsewhere.
signal sector_loaded(sector: Node3D)
signal sector_unloading(sector: Node3D)
const MANIFEST := "res://assets/maps/generated/manifest.json"
const BUILDING = preload("res://scripts/map_building.gd")
var manifest: Dictionary = {}
var loaded: Dictionary = {}
var viewer: Node3D
var world: Node3D
var editor: Control
var load_radius := 140.0
var unload_radius := 180.0
var _timer := 0.0
var _feature_sectors: Dictionary = {}
var _facades: Array[StandardMaterial3D] = []
var _music_lights: Array[OmniLight3D] = []

func _ready() -> void:
	name = "LisboaImportada"
	world = get_parent()
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for spec in manifest.sectors:
		for id in spec.get("features",[]): _feature_sectors[id] = spec.id
	_prepare_materials()
	var foundation := Node3D.new()
	foundation.name = "FundacaoProtegida"
	foundation.set_meta("editor_locked",true)
	add_child(foundation)
	for sector in manifest.sectors:
		var b: Array = sector.bounds
		_box(foundation,Vector3((b[0]+b[2])*0.5,-0.2,(b[1]+b[3])*0.5),Vector3(b[2]-b[0],0.4,b[3]-b[1]),world._material("calcada"),true)
	for link in manifest.links:
		_build_link(foundation,link.points)
	_build_river(foundation)
	# Preserve OSM attribution in the data and the menu; no web service at runtime.

func _prepare_materials() -> void:
	for index in 4:
		var mat := StandardMaterial3D.new()
		var path := "res://assets/maps/textures/facade_%d" % index
		mat.albedo_texture = load(path+".png")
		mat.normal_enabled = true
		mat.normal_texture = load(path+"_normal.png")
		mat.normal_scale = 0.18
		mat.roughness_texture = load(path+"_rough.png")
		mat.roughness = 0.85
		mat.emission_enabled = true
		mat.emission_texture = load(path+"_emission.png")
		mat.emission = Color("ffe7bc")
		mat.emission_energy_multiplier = 0.45
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_facades.append(mat)

func _process(delta: float) -> void:
	if is_instance_valid(viewer):
		_timer -= delta
		if _timer <= 0.0:
			_timer = 0.12
			update_streaming(viewer.global_position)

func _distance(at: Vector3, bounds: Array) -> float:
	var nearest := Vector2(clampf(at.x,bounds[0],bounds[2]),clampf(at.z,bounds[1],bounds[3]))
	return Vector2(at.x,at.z).distance_to(nearest)

func ensure_position(at: Vector3) -> void:
	# Used before teleport/restore and on returning from the flying editor.
	update_streaming(at,true)

func update_streaming(at: Vector3, immediate := false, pinned := "") -> void:
	var edited_positions := {}
	if is_instance_valid(editor):
		for id in editor._base_edits:
			if not _feature_sectors.has(id): continue
			var state: Dictionary = editor._base_edits[id]
			var sector_id: String = _feature_sectors[id]
			if not edited_positions.has(sector_id): edited_positions[sector_id] = []
			edited_positions[sector_id].append(_point([state.position[0],state.position[2]]))
	var needed: Array = []
	for sector in manifest.sectors:
		var distance := _distance(at,sector.stream_bounds)
		for position in edited_positions.get(sector.id,[]): distance = minf(distance,Vector2(at.x,at.z).distance_to(Vector2(position.x,position.z)))
		if loaded.has(sector.id):
			if distance > unload_radius and sector.id != pinned:
				var node: Node3D = loaded[sector.id]
				sector_unloading.emit(node)
				remove_child(node)
				node.queue_free()
				loaded.erase(sector.id)
		elif distance < load_radius:
			needed.append({"spec":sector,"distance":distance})
	needed.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance < b.distance)
	var limit := needed.size() if immediate else mini(2,needed.size())
	for index in limit:
		_load_sector(needed[index].spec)

func _load_sector(spec: Dictionary) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec.path))
	var root := Node3D.new()
	root.name = spec.id
	root.set_meta("map_sector",spec.id)
	add_child(root)
	loaded[spec.id] = root
	for feature in data.buildings:
		_build_building(root,feature)
	_build_surfaces(root,data.surfaces)
	for point in data.lamps:
		_build_lamp(root,point)
	for point in data.monuments:
		# Original stylised monument, positioned using the supplied footprint.
		var monument := Node3D.new()
		monument.name = "MonumentoSaldanha"
		monument.position = _point(point)
		monument.set_meta("map_feature",true)
		monument.set_meta("editor_stable_id","base/osm/saldanha/monumento")
		root.add_child(monument)
		_box(monument,Vector3(0,0.4,0),Vector3(8,0.8,8),world._material("city_stone"),true)
		_box(monument,Vector3(0,3.7,0),Vector3(3.4,6,3.4),world._material("city_stone"),true)
		var previous_children: Array = world.get_children()
		world._monument_figure(monument.position+Vector3(0,6.7,0))
		for child in world.get_children():
			if not previous_children.has(child): child.reparent(monument,true)
	for point in data.signs:
		_build_sign(root,point)
	for venue in data.get("venues",[]):
		_build_venue(root,venue)
	for district in manifest.districts:
		if district.id == spec.district and _distance(_point(district.music.position),spec.bounds) < 0.01:
			var light := OmniLight3D.new()
			light.position = _point(district.music.position)+Vector3(0,3,0)
			light.light_color = Color("d073a4") if district.id == "pink_street" else Color("d6a261")
			light.omni_range = 15.0
			light.shadow_enabled = false
			root.add_child(light)
			_music_lights.append(light)
	sector_loaded.emit(root)

func _point(point: Array, height := 0.0) -> Vector3:
	return Vector3(float(point[0]),height,float(point[1]))

func _mesh(parent: Node3D, verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, mat: Material, solid := false) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	if solid:
		node.create_trimesh_collision()
	return node

func _build_building(parent: Node3D, data: Dictionary) -> void:
	var node: Node3D = BUILDING.new()
	node.name = "Predio_"+str(data.id).get_slice("/",2)
	node.position = _point(data.position)
	node.set_meta("map_feature",true)
	node.set_meta("editor_stable_id","base/"+str(data.id))
	node.set_meta("map_sector",parent.name)
	node.set_meta("height_inferred",data.inferred_height)
	parent.add_child(node)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var height: float = data.height
	var bounds := AABB(Vector3.ZERO,Vector3(0,height,0))
	for ring in data.rings:
		for i in ring.size():
			var a := _point(ring[i])
			var b := _point(ring[(i+1)%ring.size()])
			bounds = bounds.expand(a).expand(b)
			var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
			var length := a.distance_to(b)/5.6
			var points := [a,b,a+Vector3.UP*height,b,b+Vector3.UP*height,a+Vector3.UP*height]
			var tex := [Vector2(0,1),Vector2(length,1),Vector2(0,1-height/3.1),Vector2(length,1),Vector2(length,1-height/3.1),Vector2(0,1-height/3.1)]
			for j in 6:
				verts.append(points[j]); normals.append(normal); uvs.append(tex[j])
	node.editor_bounds = bounds
	_mesh(node,verts,normals,uvs,_facades[int(data.style)],true)
	verts = PackedVector3Array(); normals = PackedVector3Array(); uvs = PackedVector2Array()
	for point in data.roof:
		verts.append(_point(point,height)); normals.append(Vector3.UP); uvs.append(Vector2(point[0],point[1])*0.4)
	var roof := _mesh(node,verts,normals,uvs,world._material("roof"),true)
	roof.set_meta("editor_keep_material",true)

func _build_surfaces(parent: Node3D, surfaces: Array) -> void:
	var groups := {}
	for surface in surfaces:
		if not groups.has(surface.material): groups[surface.material] = []
		groups[surface.material].append_array(surface.triangles)
	var node := Node3D.new()
	node.set_meta("editor_locked",true)
	parent.add_child(node)
	for key in groups:
		var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
		for point in groups[key]:
			verts.append(_point(point,0.026 if key == "pink" else 0.018)); normals.append(Vector3.UP); uvs.append(Vector2(point[0],point[1]))
		_mesh(node,verts,normals,uvs,world._material("city_pink",Color("d47b9e")) if key == "pink" else world._material(key))

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var node: MeshInstance3D = world._box(at,dimensions,mat,solid,parent)
	node.visibility_range_end = 175.0
	return node

func _build_lamp(parent: Node3D, point: Array) -> void:
	var at := _point(point)
	var lamp := Node3D.new()
	lamp.position = at
	lamp.name = "Candeeiro"
	lamp.set_meta("map_feature",true)
	lamp.set_meta("editor_stable_id","base/osm/lamp/%d/%d" % [roundi(at.x*1000),roundi(at.z*1000)])
	lamp.set_meta("map_sector",parent.name)
	parent.add_child(lamp)
	_box(lamp,Vector3(0,3.2,0),Vector3(0.1,6.4,0.1),world._material("metal"))
	_box(lamp,Vector3(0,6.4,0),Vector3(0.7,0.15,0.4),world._material("glass",Color("dfc499"),Color("ffb45a"),1.5))
	var light := OmniLight3D.new()
	light.position = Vector3(0,5.8,0)
	light.light_color = Color("ffc178")
	light.light_energy = 1.6
	light.omni_range = 14.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 15.0
	lamp.add_child(light)

func _build_sign(parent: Node3D, data: Dictionary) -> void:
	var sign := Node3D.new()
	sign.set_meta("editor_locked",true)
	parent.add_child(sign)
	var label := Label3D.new()
	label.text = str(data.get("name",""))
	label.position = _point(data.position,2.4)
	label.font = load("res://assets/fonts/Interface.ttf")
	label.font_size = 30
	label.pixel_size = 0.0027
	label.modulate = Color("cfbf9d")
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position.z += 0.055
	label.visibility_range_end = 18.0
	sign.add_child(label)
	var back: Label3D = label.duplicate()
	back.rotation.y = PI
	back.position.z -= 0.11
	sign.add_child(back)
	_box(sign,label.position-Vector3(0,0.1,0.055),Vector3(2.5,0.65,0.08),world._material("metal"))
	_box(sign,label.position-Vector3(0,1.25,0),Vector3(0.06,2.4,0.06),world._material("metal"))

func _build_link(parent: Node3D, points: Array) -> void:
	for index in points.size()-1:
		var a := _point(points[index]); var b := _point(points[index+1])
		var direction := (b-a).normalized()
		var length := a.distance_to(b)
		var middle := (a+b)*0.5
		var road := _box(parent,middle-Vector3.UP*0.17,Vector3(13,0.34,length+0.1),world._material("asphalt"),true)
		road.rotation.y = atan2(direction.x,direction.z)
		for side in [-1.0,1.0]:
			var offset: Vector3 = Vector3(direction.z,0,-direction.x)*5.5*side
			var walk := _box(parent,middle+offset+Vector3.UP*0.02,Vector3(1.8,0.04,length+1.5),world._material("calcada"),true)
			walk.rotation.y = road.rotation.y
			var rail := _box(parent,middle+offset*1.18+Vector3.UP*0.55,Vector3(0.1,1.1,maxf(0.1,length-16.0)),world._material("metal"),true)
			rail.rotation.y = road.rotation.y

func _build_river(parent: Node3D) -> void:
	var pink: Dictionary = manifest.districts[2]
	var start: Array = pink.portals.south
	_build_link(parent,[start,[float(start[0]),990],[240,990],[240,1010]])
	_box(parent,Vector3(240,-0.3,990),Vector3(310,0.6,60),world._material("city_stone"),true)
	_box(parent,Vector3(240,-0.3,1195),Vector3(310,0.6,50),world._material("city_stone"),true)
	# Stylised Tejo, separate from the original OSM crops (which contain no river mesh).
	_box(parent,Vector3(240,-1.0,1100),Vector3(650,0.15,160),world._material("glass",Color("354f56")))
	var bridge: Node3D = BUILDING.new()
	bridge.editor_bounds = AABB(Vector3(233,0,1020),Vector3(14,36,150))
	bridge.name = "Ponte25AbrilEstilizada"
	bridge.set_meta("map_feature",true)
	bridge.set_meta("editor_stable_id","base/landmark/ponte25abril")
	add_child(bridge)
	var metal: Material = world._material("metal",Color("c7674e"),Color("a8462d"),0.06)
	_box(bridge,Vector3(240,7.8,1095),Vector3(11,0.5,150),world._material("asphalt"),true)
	for z in [1045.0,1135.0]:
		for x in [234.0,246.0]: _box(bridge,Vector3(x,18,z),Vector3(1.1,36,1.5),metal,true)
		for height in [13.0,26.0,34.5]: _box(bridge,Vector3(240,height,z),Vector3(13,0.9,1.3),metal)
	for side in [-1.0,1.0]:
		_box(bridge,Vector3(240+side*5.4,8.7,1095),Vector3(0.15,1.4,150),metal,true)
		for index in 30:
			var z := 1020.0+index*5.0
			var next_z := z+5.0
			var y := _cable_height(z); var next_y := _cable_height(next_z)
			var cable := _box(bridge,Vector3(240+side*6,(y+next_y)*0.5,(z+next_z)*0.5),Vector3(0.18,0.18,Vector2(5,next_y-y).length()),metal)
			cable.rotation.x = -atan2(next_y-y,5.0)
			_box(bridge,Vector3(240+side*6,(8.2+y)*0.5,z),Vector3(0.09,y-8.2,0.09),metal)
	_batch_landmark(bridge)
	_build_ramp(parent,981,1020,0,8.05)
	_build_ramp(parent,1170,1209,8.05,0)
	for z in range(1024,1171,24):
		for x in [235.0,245.0]:
			_box(parent,Vector3(x,8.8,z),Vector3(0.22,0.18,0.22),world._material("glass",Color("e1bb7d"),Color("ed9c4b"),1.8))
			var light := OmniLight3D.new()
			light.position = Vector3(x,9.2,z)
			light.light_color = Color("eeb67c")
			light.light_energy = 1.2
			light.omni_range = 12.0
			light.distance_fade_enabled = true
			light.distance_fade_begin = 35.0
			light.distance_fade_length = 15.0
			parent.add_child(light)
	# No swimming: river surface is visual, falling uses the existing death/respawn.

func _cable_height(z: float) -> float:
	if z < 1045: return lerpf(12,35,(z-1020)/25)
	if z > 1135: return lerpf(35,12,(z-1135)/35)
	return 15.0+20.0*pow((z-1090)/45.0,2.0)

func set_pulse(value: float) -> void:
	for index in range(_music_lights.size()-1,-1,-1):
		if not is_instance_valid(_music_lights[index]): _music_lights.remove_at(index)
		else: _music_lights[index].light_energy = 0.8+value*1.2

func get_bookmarks() -> Array:
	var result: Array = []
	for district in manifest.districts:
		var at := _point(district.spawn)
		var target := _point(district.look_at,2)
		var position := at+Vector3(10,12,18)
		if district.id == "saldanha":
			for spec in manifest.sectors:
				if spec.get("features",[]).has("base/osm/saldanha/monumento"):
					var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec.path))
					target = _point(data.monuments[0],6)
					position = target+Vector3(34,14,35)
		result.append({"label":district.label+" · mapa recebido","position":position,"target":target})
	result.append({"label":"Tejo / Ponte 25 de Abril","position":Vector3(263,20,1015),"target":Vector3(240,17,1085)})
	return result

func is_valid_position(at: Vector3) -> bool:
	if not at.is_finite() or at.y < -0.2 or at.y > 70: return false
	for district in manifest.districts:
		if _distance(at,district.bounds) < 0.01: return true
	for link in manifest.links:
		for index in link.points.size()-1:
			var a := _point(link.points[index]); var b := _point(link.points[index+1])
			if at.distance_to(Geometry3D.get_closest_point_to_segment(at,a,b)) < 9: return true
	return at.x > 85 and at.x < 395 and ((at.z > 960 and at.z < 1020) or (at.z > 1170 and at.z < 1220) or (absf(at.x-240)<5.5 and at.z>=1020 and at.z<=1170 and at.y>7.5))

func _batch_landmark(parent: Node3D) -> void:
	var groups := {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			var key: Material = child.material_override
			if not groups.has(key): groups[key] = []
			groups[key].append(child)
	for material in groups:
		var pieces: Array = groups[material]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		multimesh.mesh = cube
		multimesh.instance_count = pieces.size()
		for index in pieces.size():
			var piece: MeshInstance3D = pieces[index]
			var at := piece.transform
			at.basis = at.basis.scaled_local(piece.mesh.size)
			multimesh.set_instance_transform(index,at)
			for collision in piece.get_children(): collision.reparent(parent,true)
			piece.free()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = material
		parent.add_child(batch)

func _build_venue(parent: Node3D, data: Dictionary) -> void:
	var node := Node3D.new()
	node.name = str(data.name).validate_node_name()
	node.position = _point(data.position)
	node.rotation.y = float(data.yaw)
	node.set_meta("map_feature",true)
	node.set_meta("editor_stable_id","base/"+str(data.id))
	node.set_meta("map_sector",parent.name)
	parent.add_child(node)
	_box(node,Vector3(0,1.1,0),Vector3(1.15,2.2,0.08),world._material("wood"))
	_box(node,Vector3(0,2.6,0.15),Vector3(2.6,0.48,0.14),world._material("metal"))
	var neon: Material = world._material("city_pink",Color("c497a7"),Color("d87baf"),1.2)
	_box(node,Vector3(0,2.86,0.15),Vector3(2.7,0.035,0.16),neon)
	_box(node,Vector3(0,2.25,0.5),Vector3(2.8,0.12,1.15),world._material("coat",Color("643d4a")))
	var label := Label3D.new()
	label.text = str(data.name).substr(0,26)
	label.font = load("res://assets/fonts/Interface.ttf")
	label.font_size = 36
	label.pixel_size = 0.0032
	label.position = Vector3(0,2.59,0.24)
	label.visibility_range_end = 30.0
	node.add_child(label)
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.5,1.0)
	light.light_color = Color("d286af")
	light.light_energy = 1.0
	light.omni_range = 7.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 12.0
	node.add_child(light)

func _build_ramp(parent: Node3D, start_z: float, end_z: float, start_y: float, end_y: float) -> void:
	# A continuous top surface has no vertical lip for a box-shaped vehicle to hit.
	var a := Vector3(234.5,start_y,start_z)
	var b := Vector3(245.5,start_y,start_z)
	var c := Vector3(245.5,end_y,end_z)
	var d := Vector3(234.5,end_y,end_z)
	var normal := Vector3(0,end_z-start_z,start_y-end_y).normalized()
	var normals := PackedVector3Array()
	normals.resize(6); normals.fill(normal)
	_mesh(parent,PackedVector3Array([a,b,c,a,c,d]),normals,PackedVector2Array([Vector2(0,0),Vector2(11,0),Vector2(11,39),Vector2(0,0),Vector2(11,39),Vector2(0,39)]),world._material("asphalt"),true)
