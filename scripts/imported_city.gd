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
var _geography: RefCounted
var _architecture: RefCounted
var _nightlife: Dictionary = {}
var exploration_points: Array[Dictionary] = []
var _skyline: Array[GeometryInstance3D] = []

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
	_geography = load("res://scripts/city_geography.gd").new()
	_geography.build(self,foundation)
	_build_river(foundation)
	_build_skyline(foundation)
	if ResourceLoader.exists("res://scripts/lisbon_architecture.gd"):
		_architecture = load("res://scripts/lisbon_architecture.gd").new()
		for entry in [{"id":"saldanha","at":Vector3(270,0,306),"yaw":0.0},{"id":"bairro_alto","at":Vector3(184,8,696),"yaw":0.0},{"id":"pink_street","at":Vector3(305,0,985),"yaw":PI}]:
			_nightlife[entry.id] = _architecture.build_nightlife(self,foundation,entry.id,entry.at,entry.yaw)
	exploration_points.assign(get_bookmarks())
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
		mat.emission_energy_multiplier = 0.12
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
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
		monument.position = _point(point,ground_height(point[0],point[1]))
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
			light.position = _point(district.music.position,ground_height(district.music.position[0],district.music.position[1]))+Vector3(0,3,0)
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
	node.position = _point(data.position,ground_height(data.position[0],data.position[1]))
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
			var upper_a := a+Vector3.UP*height
			var upper_b := b+Vector3.UP*height
			# Foundations on authored slopes reach the real terrain at each corner.
			# The roof stays level; no downhill facade is suspended above the street.
			a.y = minf(0.0,ground_height(node.position.x+a.x,node.position.z+a.z)-node.position.y)-0.08
			b.y = minf(0.0,ground_height(node.position.x+b.x,node.position.z+b.z)-node.position.y)-0.08
			bounds = bounds.expand(a).expand(b)
			var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
			var length := a.distance_to(b)/5.6
			var points := [a,b,upper_a,b,upper_b,upper_a]
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
	if _architecture != null: _architecture.decorate_building(self,node,data)

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
			verts.append(_point(point,ground_height(point[0],point[1])+(0.026 if key == "pink" else 0.018))); normals.append(Vector3.UP); uvs.append(Vector2(point[0],point[1]))
		_mesh(node,verts,normals,uvs,_geography.ground_material(key))

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var node: MeshInstance3D = world._box(at,dimensions,mat,solid,parent)
	node.visibility_range_end = 175.0
	return node

func _build_lamp(parent: Node3D, point: Array) -> void:
	var at := _point(point,ground_height(point[0],point[1]))
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
	light.light_energy = 2.6
	light.omni_range = 18.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 25.0
	lamp.add_child(light)

func _build_sign(parent: Node3D, data: Dictionary) -> void:
	var sign := Node3D.new()
	sign.set_meta("editor_locked",true)
	parent.add_child(sign)
	var label := Label3D.new()
	label.text = str(data.get("name",""))
	label.position = _point(data.position,ground_height(data.position[0],data.position[1])+2.4)
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
	# The quay now belongs to the continuous terrain rather than a suspended strip.
	_box(parent,Vector3(240,-0.3,1195),Vector3(310,0.6,50),world._material("city_stone"),true)
	# Stylised Tejo, separate from the original OSM crops (which contain no river mesh).
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
		at.y = ground_height(at.x,at.z)
		var target := _point(district.look_at,2)
		target.y = ground_height(target.x,target.z)+2
		var position := at+Vector3(10,12,18)
		if district.id == "saldanha":
			for spec in manifest.sectors:
				if spec.get("features",[]).has("base/osm/saldanha/monumento"):
					var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec.path))
					target = _point(data.monuments[0],6)
					position = target+Vector3(34,14,35)
		result.append({"label":district.label+" · mapa recebido","position":position,"target":target})
	result.append({"label":"Tejo / Ponte 25 de Abril","position":Vector3(263,20,1015),"target":Vector3(240,17,1085)})
	for id in _nightlife:
		var entry: Dictionary = _nightlife[id]
		for view in entry.get("views",[]):
			if view is Dictionary:
				var point: Dictionary = view.duplicate()
				point["label"] = point.get("label",String(point.get("id",id)).replace("_"," "))
				result.append(point)
	return result

func is_valid_position(at: Vector3) -> bool:
	if not at.is_finite() or at.y < -0.2 or at.y > 90: return false
	var polygon := PackedVector2Array()
	for point in manifest.peninsula.polygon: polygon.append(Vector2(point[0],point[1]))
	if Geometry2D.is_point_in_polygon(Vector2(at.x,at.z),polygon): return at.y >= ground_height(at.x,at.z)-0.5
	return (at.x>85 and at.x<395 and at.z>1170 and at.z<1220) or (absf(at.x-240)<5.5 and at.z>=1020 and at.z<=1170 and at.y>7.5)

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
	node.position = _point(data.position,ground_height(data.position[0],data.position[1]))
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

func ground_height(_x: float, z: float) -> float:
	var profile: Array = manifest.get("peninsula",{}).get("profile",[[0,0],[1300,0]])
	for index in profile.size()-1:
		var a: Array = profile[index]; var b: Array = profile[index+1]
		if z>=a[0] and z<=b[0]: return lerpf(a[1],b[1],(z-a[0])/(b[0]-a[0]))
	return 0.0

func set_quality_level(index: int) -> void:
	load_radius = [165.0,215.0,275.0][clampi(index,0,2)]
	unload_radius = load_radius+45

func _build_skyline(parent: Node3D) -> void:
	# Coarse building envelopes stay resident behind the streamed detailed shells.
	for sector in manifest.get("skyline",[]):
		var groups := {}
		for feature in sector.buildings:
			var style: int = feature.style
			if not groups.has(style): groups[style] = []
			groups[style].append(feature)
		for style in groups:
			var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
			for data in groups[style]:
				var origin := _point(data.position,ground_height(data.position[0],data.position[1]))
				var height: float = data.height
				for ring in data.rings:
					for index in ring.size():
						var a := _point(ring[index])+origin; var b := _point(ring[(index+1)%ring.size()])+origin
						var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
						for at in [a,b,a+Vector3.UP*height,b,b+Vector3.UP*height,a+Vector3.UP*height]:
							verts.append(at); normals.append(normal); uvs.append(Vector2(at.x/5.6,-at.y/3.1))
				for point in data.roof:
					var at := _point(point,height)+origin
					verts.append(at); normals.append(Vector3.UP); uvs.append(Vector2(at.x/5.6,-at.z/5.6))
			var node := _mesh(parent,verts,normals,uvs,_facades[int(style)])
			node.visibility_range_begin = 128.0
			node.visibility_range_end = 1100.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_skyline.append(node)

func get_start_transform() -> Transform3D:
	if _nightlife.has("saldanha"):
		var data: Dictionary = _nightlife.saldanha
		var point: Variant = data.get("spawn")
		if point is Transform3D: return point
		if point is Vector3:
			return Transform3D(Basis(Vector3.UP,PI),point)
	var district: Dictionary = manifest.districts[0]
	return Transform3D(Basis.IDENTITY,_point(district.spawn,0.2))

func get_start_street() -> Transform3D:
	if _nightlife.has("saldanha"):
		var data: Dictionary = _nightlife.saldanha
		var entries: Array = data.get("entrances",[])
		if not entries.is_empty():
			var point: Variant = entries[0]
			if point is Vector3: return Transform3D(Basis.IDENTITY,point+Vector3.UP*0.1)
			if point is Dictionary and point.get("position") is Vector3: return Transform3D(Basis.IDENTITY,point.position+Vector3.UP*0.1)
	return Transform3D(Basis.IDENTITY,_point(manifest.districts[0].spawn,0.15))

func get_venue_routes() -> Array:
	var routes: Array = []
	for id in _nightlife:
		var data: Dictionary = _nightlife[id]
		for path in data.get("paths",[]):
			if path is PackedVector3Array or path is Array: routes.append(path)
	return routes

func get_performance_venues() -> Array:
	var venues: Array = []
	for id in _nightlife:
		var performance: Dictionary = _nightlife[id].get("performance",{})
		if not performance.is_empty():
			var data: Dictionary = performance.duplicate()
			data["district"] = id
			data["id"] = id+"/"+str(data.id)
			venues.append(data)
	return venues

func get_exploration_routes() -> Array:
	var routes: Array = []
	for link in manifest.links:
		var points: Array[Vector3] = []
		for index in link.points.size()-1:
			var a := Vector2(link.points[index][0],link.points[index][1]); var b := Vector2(link.points[index+1][0],link.points[index+1][1])
			var count := maxi(1,ceili(a.distance_to(b)/8.0))
			for part in count:
				var p := a.lerp(b,float(part)/count)
				points.append(Vector3(p.x,ground_height(p.x,p.y),p.y))
		var last: Array = link.points[-1]
		points.append(Vector3(last[0],ground_height(last[0],last[1]),last[1]))
		routes.append({"id":link.id,"points":points})
	for id in _nightlife:
		var data: Dictionary = _nightlife[id]
		for index in data.get("stairs",[]).size():
			var path: Variant = data.stairs[index]
			if path is PackedVector3Array or path is Array:
				routes.append({"id":id+"_wooden_stairs_"+str(index),"points":Array(path)})
	return routes

func get_traffic_routes() -> Array:
	var routes: Array = []
	for corners in [[[65,320],[435,320],[435,710],[65,710]],[[65,710],[435,710],[435,972],[65,972]],[[-35,200],[65,200],[65,450],[-35,450]]]:
		var points := PackedVector3Array()
		for index in corners.size():
			var a := Vector2(corners[index][0],corners[index][1]); var b := Vector2(corners[(index+1)%corners.size()][0],corners[(index+1)%corners.size()][1])
			var count := maxi(1,ceili(a.distance_to(b)/12.0))
			for part in count:
				var p := a.lerp(b,float(part)/count)
				points.append(Vector3(p.x,ground_height(p.x,p.y)+0.05,p.y))
		routes.append(points)
	return routes

func get_visual_views() -> Array:
	var result: Array = [
		{"id":"peninsula_overview","position":Vector3(850,850,1500),"target":Vector3(220,0,450),"player":Vector3(270,0.2,320)},
		{"id":"saldanha_praca","position":Vector3(290,6,242),"target":Vector3(258,5,183),"player":Vector3(285,0.15,236)},
		{"id":"saldanha_avenida","position":Vector3(233,2.4,152),"target":Vector3(224,5,88),"player":Vector3(232,0.15,147)},
		{"id":"bairro_alto_rua","position":Vector3(224,10.4,552),"target":Vector3(226,11,526),"player":Vector3(225,8.15,548)},
		{"id":"pink_street_rua","position":Vector3(218,2.5,868),"target":Vector3(246,3,869),"player":Vector3(224,0.15,868)},
		{"id":"peninsula_cais","position":Vector3(300,24,1026),"target":Vector3(240,18,1084),"player":Vector3(300,0.15,1026)}]
	for id in _nightlife:
		for view in _nightlife[id].get("views",[]):
			if view is Dictionary: result.append(view)
	return result
