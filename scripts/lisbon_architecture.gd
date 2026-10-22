class_name LisbonArchitecture
extends RefCounted
## Original Lisbon architecture: spatial windows, supported balconies, entered venues,
## wooden stairs and rooftops. All dimensions are metres; the frontage faces local +Z.
const BUILDING = preload("res://scripts/map_building.gd")
var _materials: Dictionary = {}
var _groups: Dictionary = {}
var _body: StaticBody3D
var _current: Node3D
var _views: Array = []

func _mat(key: String, tint := Color.WHITE, glow := 0.0) -> StandardMaterial3D:
	var cache := key+"/"+tint.to_html()+"/"+str(glow)
	if _materials.has(cache): return _materials[cache]
	var mat := StandardMaterial3D.new()
	var path := "res://assets/maps/textures/"+key
	if not ResourceLoader.exists(path+".png"): path = "res://assets/textures/"+key
	mat.albedo_texture = load(path+".png")
	mat.albedo_color = tint
	if ResourceLoader.exists(path+"_normal.png"):
		mat.normal_enabled = true
		mat.normal_texture = load(path+"_normal.png")
		mat.normal_scale = 0.18
	if ResourceLoader.exists(path+"_rough.png"): mat.roughness_texture = load(path+"_rough.png")
	mat.roughness = 0.84
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# These meshes range from tiny jambs to23m floors. World-space mapping
	# keeps the timber/stone grain at a physical scale across their instances.
	mat.uv1_triplanar=true
	mat.uv1_world_triplanar=true
	mat.uv1_scale=Vector3(0.6,0.6,0.6)
	# Colour belongs to the instance. Wood/metal details with different tints
	# can share a texture draw instead of creating a batch for every paint colour.
	mat.set_meta("architecture_batch_key",path+"/"+str(glow)+(tint.to_html() if glow>0 else ""))
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_texture = mat.albedo_texture
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = glow
	_materials[cache] = mat
	return mat

func _begin(node: Node3D) -> void:
	_current = node
	_groups = {}
	_body = StaticBody3D.new()
	_body.name = "EstruturaSolida"
	node.add_child(_body)

func _piece(at: Vector3, dimensions: Vector3, material: Material, solid := false, yaw := 0.0, range_end := 125.0, cylinder := false) -> void:
	var basis := Basis(Vector3.UP,yaw)
	var group := _geometry_group(material,cylinder,range_end)
	group.transforms.append(Transform3D(basis.scaled_local(dimensions),at))
	group.colors.append(material.albedo_color if not material.emission_enabled else Color.WHITE)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		collision.position = at
		collision.rotation.y = yaw
		_body.add_child(collision)

func _beam(a: Vector3, b: Vector3, width: float, material: Material, solid := false, range_end := 125.0) -> void:
	var direction := b-a
	if direction.length() < 0.001: return
	var basis := Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().y)>0.99 else Vector3.UP)
	var dimensions := Vector3(width,width,direction.length())
	var group := _geometry_group(material,false,range_end)
	group.transforms.append(Transform3D(basis.scaled_local(dimensions),(a+b)*0.5))
	group.colors.append(material.albedo_color if not material.emission_enabled else Color.WHITE)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = dimensions
		collision.shape = shape
		collision.transform = Transform3D(basis,(a+b)*0.5)
		_body.add_child(collision)

func _geometry_group(material: Material, cylinder: bool, range_end: float) -> Dictionary:
	# Two detail distances avoid splitting the same texture into 35/38/40/45m
	# draws. Facades remain visible to125m; small furnishings fade at60m.
	var distance := 60.0 if range_end<100.0 else range_end
	var key := "%s/%s/%.0f" % [material.get_meta("architecture_batch_key",str(material.get_instance_id())),str(cylinder),distance]
	if not _groups.has(key):
		var shared: StandardMaterial3D = material.duplicate()
		if not shared.emission_enabled:
			shared.albedo_color=Color.WHITE
			shared.vertex_color_use_as_albedo=true
		_groups[key] = {"material":shared,"transforms":[],"colors":[],"cylinder":cylinder,"range":distance}
	return _groups[key]

func _finish() -> void:
	for key in _groups:
		var data: Dictionary = _groups[key]
		var mesh: PrimitiveMesh
		if data.cylinder:
			var cylinder := CylinderMesh.new(); cylinder.top_radius=0.5; cylinder.bottom_radius=0.5; cylinder.height=1; cylinder.radial_segments=10
			mesh = cylinder
		else:
			var cube := BoxMesh.new(); cube.size=Vector3.ONE; mesh=cube
		var multi := MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.use_colors=true; multi.mesh=mesh
		multi.instance_count = data.transforms.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i,data.transforms[i])
			multi.set_instance_color(i,data.colors[i])
		var batch := MultiMeshInstance3D.new(); batch.multimesh=multi; batch.material_override=data.material
		batch.name = "ArquiteturaAgrupada"
		batch.visibility_range_end = data.range
		batch.set_meta("editor_keep_material",true)
		_current.add_child(batch)
	if _body.get_child_count()==0: _body.free()
	_groups.clear()

func decorate_building(_city: Node3D, node: Node3D, data: Dictionary) -> void:
	_begin(node)
	var stone := _mat("city_stone",Color("a39c8d"))
	var iron := _mat("metal",Color("5e6662"))
	var frame := _mat("wood",Color("656653"))
	var dark := _mat("glass",Color("3c4b49"))
	var warm := _mat("glass",Color("d5b578"),0.20)
	var roof := _mat("roof_terracotta",Color("ae8572")) if ResourceLoader.exists("res://assets/maps/textures/roof_terracotta.png") else _mat("city_roof",Color("ae8572"))
	var height: float = data.height
	var seed_value := absi(str(data.id).hash())
	var floor_count := mini(6,maxi(1,floori(height/3.1)))
	for ring_index in data.rings.size():
		var ring: Array = data.rings[ring_index]
		for edge in ring.size():
			var a := Vector3(ring[edge][0],0,ring[edge][1])
			var b := Vector3(ring[(edge+1)%ring.size()][0],0,ring[(edge+1)%ring.size()][1])
			var tangent := (b-a).normalized()
			var normal := Vector3(tangent.z,0,-tangent.x)
			var yaw := atan2(normal.x,normal.z)
			var length := a.distance_to(b)
			if length < 1.0: continue
			_piece((a+b)*0.5+Vector3.UP*0.3,Vector3(length,0.6,0.15),stone,false,yaw)
			_piece((a+b)*0.5+Vector3.UP*(height-0.12),Vector3(length+0.15,0.24,0.32),stone,false,yaw)
			_piece((a+b)*0.5+Vector3.UP*3.1,Vector3(length,0.13,0.2),stone,false,yaw)
			var roof_strip := (a+b)*0.5+Vector3.UP*(height+0.25)-normal*0.22
			_piece(roof_strip,Vector3(length,0.16,0.85),roof,false,yaw)
			var columns := mini(16,floori(length/2.8))
			for column in columns:
				var distance := (column+0.5)*length/maxi(1,columns)
				for floor_index in floor_count:
					var center := a+tangent*distance+Vector3.UP*(1.65+floor_index*3.1)+normal*0.075
					if center.y+1.0 > height: continue
					var lit := (seed_value+column*13+floor_index*7+edge)%7==0
					_window(center,yaw,stone,frame,warm if lit else dark,1.12,1.78)
					if floor_index > 0 and ring_index==0 and (seed_value+column+edge)%4==0 and length>5:
						_balcony(center-Vector3.UP*0.92,yaw,stone,iron)
					elif floor_index>0 and (seed_value+column)%3==0:
						for side in [-1.0,1.0]:
							_piece(center+tangent*side*0.77+normal*0.06,Vector3(0.3,1.82,0.09),frame,false,yaw+side*0.25)
	_finish()

func _window(center: Vector3, yaw: float, stone: Material, frame: Material, glass: Material, width: float, height: float) -> void:
	var side := Vector3(cos(yaw),0,-sin(yaw))
	var normal := Vector3(sin(yaw),0,cos(yaw))
	_piece(center,Vector3(width,height,0.055),glass,false,yaw,105)
	for sign_value in [-1.0,1.0]:
		_piece(center+side*sign_value*(width*0.5+0.06),Vector3(0.12,height+0.2,0.2),stone,false,yaw)
		_piece(center+Vector3.UP*sign_value*(height*0.5+0.06),Vector3(width+0.35,0.12,0.23),stone,false,yaw)
	_piece(center+normal*0.04,Vector3(0.06,height,0.09),frame,false,yaw,95)
	_piece(center+normal*0.04+Vector3.UP*0.12,Vector3(width,0.065,0.09),frame,false,yaw,95)
	_piece(center-Vector3.UP*(height*0.5+0.13)+normal*0.09,Vector3(width+0.45,0.14,0.42),stone,false,yaw)

func _balcony(at: Vector3, yaw: float, stone: Material, iron: Material) -> void:
	var side := Vector3(cos(yaw),0,-sin(yaw)); var normal := Vector3(sin(yaw),0,cos(yaw))
	_piece(at+normal*0.36,Vector3(1.75,0.14,0.85),stone,false,yaw)
	for side_value in [-1.0,1.0]:
		_beam(at+side*side_value*0.65-Vector3.UP*0.55,at+side*side_value*0.65+normal*0.7-Vector3.UP*0.06,0.07,iron)
		_beam(at+side*side_value*0.82+Vector3.UP*0.95,at+side*side_value*0.82+normal*0.78+Vector3.UP*0.95,0.045,iron)
	for i in 9:
		_piece(at+normal*0.78+side*(-0.78+float(i)*0.195)+Vector3.UP*0.48,Vector3(0.025,0.91,0.025),iron)
	_piece(at+normal*0.78+Vector3.UP*0.95,Vector3(1.72,0.045,0.045),iron,false,yaw)

func _catalog(district: String) -> Array:
	match district:
		"saldanha": return [
			{"id":"tasca_largo","name":"TASCA DO LARGO","kind":"portuguese","width":12.0,"color":"d2b58d"},
			{"id":"cafe_paris","name":"CAFÉ DE PARIS","kind":"french","width":10.0,"color":"b8c5b3"},
			{"id":"casa_avenidas","name":"CASA DAS AVENIDAS","kind":"rooftop","width":18.0,"color":"d5c9ab"},
			{"id":"trattoria","name":"TRATTORIA DA AVENIDA","kind":"italian","width":12.0,"color":"c6a18f"},
			{"id":"mercearia","name":"MERCEARIA AVENIDAS","kind":"convenience","width":10.0,"color":"b2c2ba"},
			{"id":"mare_jazz","name":"MARÉ · JAZZ & BAR","kind":"bar","width":12.0,"color":"c7bca0"}]
		"bairro_alto": return [
			{"id":"madragoa","name":"CASA DA MADRAGOA · FADO","kind":"fado","width":12.0,"color":"beae98"},
			{"id":"kebab_bairro","name":"KEBAB DO BAIRRO","kind":"kebab","width":10.0,"color":"b2bfb6"},
			{"id":"casa_bairro","name":"CASA DO BAIRRO","kind":"floorbar","width":18.0,"color":"c8bb9f"},
			{"id":"esquina","name":"BAR DA ESQUINA","kind":"bar","width":10.0,"color":"c8a6a0"},
			{"id":"taberna","name":"TABERNA DO PÁTIO","kind":"portuguese","width":12.0,"color":"d1bc92"},
			{"id":"noite_aberta","name":"NOITE ABERTA · MERCEARIA","kind":"convenience","width":10.0,"color":"bdc4ac"}]
		_: return [
			{"id":"discoteca_rosa","name":"DISCOTECA ROSA","kind":"disco","width":16.0,"color":"c7b3a0"},
			{"id":"bar_odio","name":"ÓDIO PURO · BAR","kind":"bar","width":12.0,"color":"b5b6b0"},
			{"id":"casa_cais","name":"CASA DO CAIS · TERRAÇO","kind":"rooftop","width":18.0,"color":"c8bca6"},
			{"id":"kebab_cais","name":"KEBAB DO CAIS","kind":"kebab","width":10.0,"color":"d0b489"},
			{"id":"loja24","name":"LOJA 24 · CONVENIÊNCIA","kind":"convenience","width":10.0,"color":"b2c6b8"},
			{"id":"patio_rosa","name":"PÁTIO ROSA · BAR","kind":"bar","width":12.0,"color":"bea6ad"}]

func build_nightlife(city: Node3D, _parent: Node3D, district_id: String, anchor: Vector3, yaw: float) -> Dictionary:
	var cluster := Node3D.new(); cluster.name = "VidaNoturna_"+district_id
	cluster.position=anchor; cluster.rotation.y=yaw; city.add_child(cluster)
	var result := {"root":cluster,"venues":[],"entrances":[],"stairs":[],"roofs":[],"paths":[],"views":[],"spawn":Transform3D.IDENTITY,"facing":Vector3.FORWARD,"bounds":AABB()}
	var catalog := _catalog(district_id)
	var total_width := 0.0
	for entry in catalog: total_width += float(entry.width)
	total_width += (catalog.size()-1)*0.65
	var cursor := -total_width*0.5
	for index in catalog.size():
		var entry: Dictionary = catalog[index]
		var width: float = entry.width
		var node: Node3D = BUILDING.new()
		node.name = entry.name.validate_node_name()
		# Finished timber sits above the exterior paving, which reaches0.045m.
		# Lift the complete interior so tables, steps and doors share its floor.
		node.position=Vector3(cursor+width*0.5,0.075,0)
		node.set_meta("map_feature",true)
		node.set_meta("editor_stable_id","base/lisboa/"+district_id+"/"+str(entry.id))
		node.set_meta("venue_kind",entry.kind)
		node.set_meta("venue_name",entry.name)
		node.add_to_group("lisbon_venues")
		cluster.add_child(node)
		var stairs: bool = entry.kind in ["rooftop","floorbar"]
		var floors := 3 if stairs else 2+index%2
		var depth := 23.0 if stairs else 18.0+float(index%2)*2.0
		node.editor_bounds=AABB(Vector3(-width*0.5-0.4,0,-depth-0.4),Vector3(width+0.8,floors*3.6+1.7,depth+3.5))
		_begin(node)
		_build_venue_shell(node,entry,width,depth,floors,index)
		if stairs: _wooden_stair_house(node,entry,width,depth,floors)
		else: _furnish_venue(node,entry,width,depth)
		_terrace(node,entry,width,index)
		_finish()
		var entrance := node.to_global(Vector3(0,0.1,1.8))
		var inside := node.to_global(Vector3(0,0.1,-3.5))
		result.entrances.append(entrance)
		result.venues.append({"id":entry.id,"name":entry.name,"kind":entry.kind,"entrance":entrance,"interior":inside,"node":node})
		result.paths.append(PackedVector3Array([entrance,inside]))
		result.views.append({"id":district_id+"_"+str(entry.id),"position":node.to_global(Vector3(3.5,2.0,-1.8)),"target":node.to_global(Vector3(-1.0,1.7,-11.0)),"player":inside})
		if entry.kind=="disco":
			var homes := PackedVector3Array()
			for z in [-4.5,-7.2,-9.7]:
				for x in [-2.1,0.5,3.0]: homes.append(node.to_global(Vector3(x,0.1,z)))
			result["performance"] = {"id":str(entry.id),"node":node,"stage_position":node.to_global(Vector3(width*0.15,0.36,-16.5)),"camera_position":node.to_global(Vector3(-3.8,3.2,-9.5)),"camera_target":node.to_global(Vector3(width*0.15,1.6,-16.5)),"facing":node.global_basis*Vector3(0,0,1),"entry_outside":node.to_global(Vector3(0,0.1,2)),"entry_door":node.to_global(Vector3(0,0.1,0)),"entry_inside":node.to_global(Vector3(0,0.1,-2)),"dance_origin":node.to_global(Vector3(0.5,0.1,-7.2)),"dance_homes":homes,"bar_position":node.to_global(Vector3(-width*0.5+1.25,0,-depth*0.52)),"street_corner":node.to_global(Vector3(width*0.4,0.1,5.3))}
			var dj_route := PackedVector3Array([node.to_global(Vector3(0,0.1,2)),node.to_global(Vector3(0,0.1,-2)),node.to_global(Vector3(width*0.15,0.1,-11.8)),node.to_global(Vector3(width*0.15,0.46,-13.2)),node.to_global(Vector3(width*0.15+2.4,0.46,-14.5)),node.to_global(Vector3(width*0.15,0.46,-16.5))])
			result.performance["route"]=dj_route
			result.paths.append(dj_route)
		if stairs:
			var route := _stair_path(node,floors)
			result.paths.append(route); result.stairs.append(route)
			var rooftop := node.to_global(Vector3(0,floors*3.6+0.12,-3.0))
			result.roofs.append(rooftop)
			result.spawn = Transform3D(Basis(Vector3.UP,yaw),rooftop)
			result.facing = cluster.global_basis*Vector3(0,0,1)
			result.views.append({"id":district_id+"_wooden_stairs","position":node.to_global(Vector3(-3.5,1.8,-4.5)),"target":node.to_global(Vector3(0,3.3,-8.4)),"player":node.to_global(Vector3(0,0.1,-4.4))})
			result.views.append({"id":district_id+"_rooftop","position":node.to_global(Vector3(-5,floors*3.6+3,-3)),"target":node.to_global(Vector3(2,floors*3.6+1,7)),"player":rooftop})
		cursor += width+0.65
	result.bounds=AABB(anchor-Vector3(total_width*0.5,0,24),Vector3(total_width,14,30))
	result.views.append({"id":district_id+"_nightlife_street","position":cluster.to_global(Vector3(-30,2.3,13)),"target":cluster.to_global(Vector3(10,3,-2)),"player":cluster.to_global(Vector3(-28,0.1,10))})
	return result

func _plaster(tint: Color) -> StandardMaterial3D:
	return _mat("plaster_plain",tint) if ResourceLoader.exists("res://assets/maps/textures/plaster_plain.png") else _mat("city_plaster",tint)
func _wood_floor() -> StandardMaterial3D:
	return _mat("wood_floor",Color("b5a18a")) if ResourceLoader.exists("res://assets/maps/textures/wood_floor.png") else _mat("wood",Color("aa9477"))
func _door_material() -> StandardMaterial3D:
	return _mat("wood_door",Color("bba284")) if ResourceLoader.exists("res://assets/maps/textures/wood_door.png") else _mat("wood",Color("a98d69"))
func _tiles() -> StandardMaterial3D:
	return _mat("azulejo_blue",Color("c2c8b5")) if ResourceLoader.exists("res://assets/maps/textures/azulejo_blue.png") else _mat("tiles",Color("aab9b3"))

func _build_venue_shell(node: Node3D, data: Dictionary, width: float, depth: float, floors: int, index: int) -> void:
	var plaster := _plaster(Color(data.color))
	var stone := _mat("city_stone",Color("b6ad98"))
	var iron := _mat("metal",Color("4d5952"))
	var floor_mat := _wood_floor()
	var height := floors*3.6
	_piece(Vector3(0,-0.13,-depth*0.5),Vector3(width,0.26,depth),floor_mat,true)
	# The front is an actual 2m by 2.95m opening, not a door over a sealed collider.
	var wing := (width-2.0)*0.5
	for side in [-1.0,1.0]:
		_piece(Vector3(side*(1.0+wing*0.5),1.6,-0.05),Vector3(wing,3.2,0.3),plaster,true)
		_piece(Vector3(side*(width*0.5-0.16),height*0.5,-depth*0.5),Vector3(0.32,height,depth),plaster,true)
		_piece(Vector3(side*1.1,1.58,0.12),Vector3(0.22,3.16,0.45),stone,true)
		# Open hinged timber leaves remain visibly attached to their jambs.
		_piece(Vector3(side*1.28,1.45,0.45),Vector3(0.82,2.9,0.1),_door_material(),false,side*-1.05,70)
	_piece(Vector3(0,3.35,-0.02),Vector3(width,0.5,0.35),stone,true)
	_piece(Vector3(0,1.58,-depth+0.15),Vector3(width,3.16,0.3),plaster,true)
	_piece(Vector3(0,3.08,0.18),Vector3(2.45,0.25,0.56),stone)
	for floor_index in range(1,floors):
		var y := floor_index*3.6+1.8
		_piece(Vector3(0,y,-0.03),Vector3(width,3.6,0.3),plaster,true)
		_piece(Vector3(0,y,-depth+0.15),Vector3(width,3.6,0.3),plaster,true)
		_piece(Vector3(0,floor_index*3.6,0.1),Vector3(width+0.28,0.18,0.45),stone)
		for column in maxi(2,floori(width/2.8)):
			var count := maxi(2,floori(width/2.8))
			var x: float = -width*0.5+(column+0.5)*width/count
			var glass := _mat("glass",Color("c5a878"),0.24) if (floor_index+column+index)%5==0 else _mat("glass",Color("334747"))
			_window(Vector3(x,y,0.18),0.0,stone,_mat("wood",Color("647263")),glass,1.15,1.95)
			if floor_index==1 and column%2==0: _balcony(Vector3(x,y-1.02,0.25),0,stone,iron)
	for side in [-1.0,1.0]:
		var x: float = side*(width*0.5-0.3)
		_piece(Vector3(x,height*0.5,0.16),Vector3(0.45,height,0.25),stone)
	_piece(Vector3(0,height-0.1,-depth*0.5),Vector3(width+0.5,0.26,depth+0.4),stone)
	# Interior wainscot and plaster remain readable at street light levels.
	for side in [-1.0,1.0]:
		_piece(Vector3(side*(width*0.5-0.35),0.65,-depth*0.5),Vector3(0.055,1.25,depth-0.4),_tiles())
	# Roof of stair houses is a terrace with parapets; other roofs have pitched tile slopes.
	if not data.kind in ["rooftop","floorbar"]:
		_piece(Vector3(0,height,-depth*0.5),Vector3(width,0.24,depth),floor_mat,true)
		var roof := _mat("roof_terracotta",Color("b78b71")) if ResourceLoader.exists("res://assets/maps/textures/roof_terracotta.png") else _mat("city_roof",Color("b78b71"))
		for side in [-1.0,1.0]:
			# Low pitched roof with visible eaves; beams support ridge and tile surfaces.
			_beam(Vector3(side*width*0.5,height+0.15,-depth*0.5),Vector3(0,height+1.25,-depth*0.5),0.2,roof)
			var slope := BoxMesh.new()
			var mesh := MeshInstance3D.new(); slope.size=Vector3(sqrt(pow(width*0.5,2)+1.21),0.12,depth+0.55); mesh.mesh=slope
			mesh.position=Vector3(side*width*0.25,height+0.7,-depth*0.5); mesh.rotation.z=side*-atan2(1.1,width*0.5); mesh.material_override=roof
			mesh.visibility_range_end=160; mesh.set_meta("editor_keep_material",true); node.add_child(mesh)
		_piece(Vector3(width*0.3,height+0.9,-depth*0.7),Vector3(0.7,1.6,0.8),stone)
		_piece(Vector3(width*0.3,height+1.76,-depth*0.7),Vector3(0.9,0.14,1.0),_mat("metal",Color("62655b")))
	_storefront(node,data,width)

func _label(parent: Node3D, text: String, at: Vector3, pixel_size := 0.0045, font_size := 40, tint := Color("e4d8b7")) -> Label3D:
	var label := Label3D.new(); label.text=text; label.position=at
	label.font=load("res://assets/fonts/Interface.ttf"); label.font_size=font_size; label.pixel_size=pixel_size
	label.modulate=tint; label.outline_size=2; label.outline_modulate=Color("171a18")
	label.visibility_range_end=45.0
	parent.add_child(label)
	return label

func _storefront(node: Node3D, data: Dictionary, width: float) -> void:
	var frame := _mat("wood",Color("554b3f"))
	var metal := _mat("metal",Color("525e57"))
	var is_club: bool = data.kind in ["disco","bar","rooftop","floorbar"]
	var sign_y := 3.45
	var sign_width := minf(width-0.8,8.0)
	_piece(Vector3(0,sign_y,0.45),Vector3(sign_width,0.58,0.18),metal)
	for x in [-sign_width*0.38,sign_width*0.38]:
		_beam(Vector3(x,sign_y+0.5,0),Vector3(x,sign_y+0.32,0.52),0.045,metal)
	_label(node,str(data.name),Vector3(0,sign_y,0.56),minf(0.012,sign_width*0.82/(str(data.name).length()*23.0)),44,Color("d6a5df") if is_club else Color("e2cd9b"))
	if is_club:
		var neon := _mat("marking",Color("c272b7") if data.kind!="disco" else Color("6683c8"),1.7)
		_piece(Vector3(0,sign_y-0.36,0.48),Vector3(sign_width,0.035,0.035),neon)
		for side in [-1.0,1.0]: _piece(Vector3(side*1.17,1.6,0.21),Vector3(0.035,2.95,0.035),neon)
	# Two shop windows have thickness, stone framing and a sill.
	for side in [-1.0,1.0]:
		var x: float = side*(width*0.28)
		_window(Vector3(x,1.65,0.2),0,_mat("city_stone",Color("b5a78f")),frame,_mat("glass",Color("44544d"),0.03),minf(2.8,width*0.26),1.6)
	_light(node,Vector3(0,2.75,1.5),Color("d986bf") if is_club else Color("e3b47f"),0.75,8.0)
	for side in [-1.0,1.0]:
		var x: float = side*(width*0.5-0.65)
		_piece(Vector3(x,2.45,0.38),Vector3(0.19,0.4,0.28),metal)
		_piece(Vector3(x,2.45,0.54),Vector3(0.13,0.27,0.06),_mat("glass",Color("e6c388"),1.0))

func _light(parent: Node3D, at: Vector3, tint: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new(); light.position=at; light.light_color=tint; light.light_energy=energy; light.omni_range=radius
	light.shadow_enabled=false; light.distance_fade_enabled=true; light.distance_fade_begin=28; light.distance_fade_length=12
	parent.add_child(light)

func _table(at: Vector3, tint: Color, seats := 4, outside := false) -> void:
	var wood := _wood_floor(); var iron := _mat("metal",Color("596158"))
	_piece(at+Vector3.UP*0.76,Vector3(1.1,0.1,0.85),wood,false,0,55)
	for side in [-1.0,1.0]:
		for z in [-0.3,0.3]: _piece(at+Vector3(side*0.43,0.38,z),Vector3(0.055,0.75,0.055),iron,false,0,55)
	for index in seats:
		var side := -1.0 if index%2==0 else 1.0
		var z := -0.3 if index<2 else 0.3
		var chair := at+Vector3(side*0.85,0,z)
		_piece(chair+Vector3.UP*0.43,Vector3(0.45,0.08,0.43),_mat("wood",tint),false,0,55)
		_piece(chair+Vector3(side*0.2,0.75,0),Vector3(0.055,0.58,0.45),_mat("wood",tint),false,0,55)
		for dx in [-0.16,0.16]:
			for dz in [-0.15,0.15]: _piece(chair+Vector3(dx,0.21,dz),Vector3(0.04,0.42,0.04),iron,false,0,48)
	_piece(at+Vector3(0,0.86,0),Vector3(0.22,0.035,0.22),_mat("paper",Color("e2dcc7")),false,0,45,true)
	if outside: _piece(at+Vector3(0.15,0.91,0),Vector3(0.06,0.11,0.06),_mat("glass",Color("827d66")),false,0,35,true)

func _furnish_venue(node: Node3D, data: Dictionary, width: float, depth: float) -> void:
	var kind: String = data.kind
	var wood := _door_material(); var metal := _mat("metal",Color("65716a")); var tile := _tiles()
	# High plaster ceiling with real beams, sockets and hanging luminaires.
	_piece(Vector3(0,3.36,-depth*0.5),Vector3(width-0.6,0.16,depth-0.5),_plaster(Color("c6c0ad")))
	for z in range(-3,-int(depth)+1,-4):
		_piece(Vector3(0,3.16,z),Vector3(width-0.7,0.2,0.17),wood)
		_piece(Vector3(0,2.9,z),Vector3(0.035,0.48,0.035),metal)
		_piece(Vector3(0,2.67,z),Vector3(0.55,0.12,0.55),_mat("glass",Color("d7be84"),0.6),false,0,65,true)
	_light(node,Vector3(0,2.5,-6),Color("d7b27e"),0.55,7.0)
	_light(node,Vector3(0,2.5,-depth+4),Color("d7b27e"),0.55,7.0)
	if kind=="convenience":
		for side in [-1.0,1.0]:
			for z in [-6.0,-11.0,-16.0]:
				var x: float = side*(width*0.5-1.0)
				_piece(Vector3(x,0.95,z),Vector3(0.7,1.9,2.6),wood,true)
				for shelf in 4:
					_piece(Vector3(x-side*0.05,0.35+shelf*0.43,z),Vector3(0.9,0.06,2.7),metal)
					for item in 5:
						_piece(Vector3(x-side*0.28,0.49+shelf*0.43,z-1.0+item*0.48),Vector3(0.23,0.26,0.2),_mat("paper",Color("a99670") if (shelf+item)%2 else Color("77988a")),false,0,38)
		_piece(Vector3(-width*0.27,0.5,-2.5),Vector3(2.1,1.0,0.8),wood,true)
		_piece(Vector3(-width*0.27,1.12,-2.5),Vector3(0.45,0.24,0.4),metal)
		_label(node,"ÁGUA · COMIDA · CAFÉ\nABERTO ATÉ DE MANHÃ",Vector3(0,2.25,-depth+0.34),0.004,38)
	elif kind in ["bar","disco","fado"]:
		var counter_x := -width*0.5+1.25
		_piece(Vector3(counter_x,0.55,-depth*0.52),Vector3(1.25,1.1,depth*0.48),tile,true)
		_piece(Vector3(counter_x,1.15,-depth*0.52),Vector3(1.55,0.13,depth*0.5),wood)
		for z in range(-5,-int(depth)+3,-2):
			_piece(Vector3(counter_x+1.25,0.65,z),Vector3(0.4,0.1,0.4),wood,false,0,50,true)
			_piece(Vector3(counter_x+1.25,0.3,z),Vector3(0.08,0.6,0.08),metal,false,0,50,true)
			_piece(Vector3(counter_x-0.2,1.42,z),Vector3(0.1,0.45,0.1),_mat("glass",Color("718a64")),false,0,40,true)
		if kind!= "disco":
			for z in [-6.0,-11.0]: _table(Vector3(width*0.28,0,z),Color("7e5547"),2)
		else:
			for z in [-5.0,-9.0]:
				_piece(Vector3(width*0.5-0.7,0.45,z),Vector3(0.75,0.9,2.1),_mat("coat",Color("69495c")),true)
		var stage_at := Vector3(width*0.15,0.18,-depth+3.0)
		_piece(stage_at,Vector3(width*0.58,0.36,4.0),wood,true)
		if kind=="disco":
			for i in 3: _piece(Vector3(width*0.15,0.06+float(i)*0.12,-12.32-float(i)*0.25),Vector3(2.1,0.12,0.28),wood)
			_ramp_collider(node,Vector3(width*0.15,0,-12.2),Vector3(width*0.15,0.36,-13),2.0)
			_piece(stage_at+Vector3(0,0.75,0),Vector3(2.7,1.15,0.8),metal,true)
			for x in [-0.7,0.7]: _piece(stage_at+Vector3(x,1.37,0),Vector3(0.48,0.045,0.48),_mat("glass",Color("8992a0")),false,0,45,true)
			for side in [-1.0,1.0]:
				_piece(stage_at+Vector3(side*width*0.3,0.85,0),Vector3(0.7,1.7,0.65),_mat("coat",Color("4f5555")),true)
				_light(node,stage_at+Vector3(side*2.1,2.3,1.5),Color("a461a0") if side<0 else Color("617eaf"),0.8,6)
			_label(node,"ROSA · A NOITE CONTINUA",Vector3(width*0.15,2.5,-depth+0.4),0.0048,40,Color("b0a0d5"))
		elif kind=="fado":
			for x in [-0.8,0.8]:
				_piece(stage_at+Vector3(x,0.48,0),Vector3(0.45,0.1,0.45),wood)
				_piece(stage_at+Vector3(x,0.9,-0.2),Vector3(0.5,0.8,0.08),wood)
			_label(node,"SILÊNCIO · VAI-SE CANTAR O FADO",Vector3(0,2.55,-depth+0.35),0.004,38)
	else:
		for x in [-width*0.28,width*0.28]:
			for z in [-6.0,-10.5,-15.0]:
				if absf(z)<depth-1.5: _table(Vector3(x,0,z),Color("9b6a50") if kind!="french" else Color("829482"),2)
		_piece(Vector3(0,0.53,-depth+2.0),Vector3(width-1.1,1.05,1.2),tile,true)
		_piece(Vector3(0,1.1,-depth+2.0),Vector3(width-1.0,0.1,1.35),metal)
		if kind=="kebab":
			_piece(Vector3(-1.5,1.65,-depth+1.9),Vector3(0.52,1.1,0.52),_mat("wood",Color("937454")),false,0,55,true)
			_piece(Vector3(-1.5,2.25,-depth+1.9),Vector3(1.0,0.2,0.8),metal)
			_piece(Vector3(1.2,1.3,-depth+2.0),Vector3(1.6,0.3,0.75),_mat("glass",Color("9caa9a")))
		var menu: String = {"kebab":"KEBAB · FALAFEL · SOPA", "portuguese":"BACALHAU · BIFANA · CALDO VERDE", "french":"BISTROT · SOUPE · CROQUE", "italian":"PIZZA · PASTA · RISOTTO"}.get(kind,"COZINHA DA NOITE")
		_label(node,menu,Vector3(0,2.45,-depth+0.35),0.004,38)

func _wooden_stair_house(node: Node3D, data: Dictionary, width: float, depth: float, floors: int) -> void:
	var wood := _wood_floor(); var darkwood := _door_material(); var plaster := _plaster(Color("c5c0aa")); var iron := _mat("metal",Color("647065"))
	var half := width*0.5
	# Floors surround one continuous six-metre stairwell; each opening remains clear.
	for level in range(1,floors+1):
		var y := level*3.6
		_piece(Vector3(0,y-0.12,-2.8),Vector3(width-0.6,0.24,5.6),wood,true)
		_piece(Vector3(0,y-0.12,-(depth+11.6)*0.5),Vector3(width-0.6,0.24,depth-11.6),wood,true)
		for side in [-1.0,1.0]:
			_piece(Vector3(side*(half+2.2)*0.5,y-0.12,-8.6),Vector3(half-2.2,0.24,6.0),wood,true)
		if level < floors:
			for side in [-1.0,1.0]:
				if data.kind=="floorbar" and level==1: continue
				var room_width := half-2.55
				var door_x: float = side*(2.35+room_width*0.5)
				_piece(Vector3(side*2.27,y+1.5,-(depth+12)*0.5),Vector3(0.14,3.0,depth-12),plaster,true)
				for door_side in [-1.0,1.0]:
					_piece(Vector3(door_x+door_side*(0.72+(room_width-1.44)*0.25),y+1.5,-12),Vector3((room_width-1.44)*0.5,3,0.18),plaster,true)
					_piece(Vector3(door_x+door_side*0.76,y+1.4,-11.95),Vector3(0.13,2.8,0.2),darkwood)
				_piece(Vector3(door_x,y+2.9,-12),Vector3(1.6,0.2,0.2),darkwood,true)
				_piece(Vector3(door_x+0.92,y+1.35,-12.32),Vector3(0.65,2.7,0.09),darkwood,false,-0.95)
				_piece(Vector3(side*(half-2),y+0.3,-depth+2.1),Vector3(2.4,0.6,3),darkwood,true)
				_piece(Vector3(side*(half-2),y+0.68,-depth+2.1),Vector3(2.2,0.18,2.85),_mat("coat",Color("8b8c79")))
				_light(node,Vector3(side*(half-2.5),y+2.5,-16),Color("cfb783"),0.4,5)
			_label(node,str(level)+"º ANDAR",Vector3(0,y+2.5,-0.22),0.0038,38)
		_light(node,Vector3(0,y-0.5,-3.1),Color("d8b67d"),0.55,6.5)
	for floor_index in floors:
		var base := floor_index*3.6
		# Ten treads per half-flight: rise 0.18m, run0.32m; ramp collider is continuous.
		for step in 10:
			var t := float(step)
			_piece(Vector3(-1.05,base+(t+1)*0.18-0.04,-5.7-(t+0.5)*0.32),Vector3(1.7,0.08,0.34),wood)
			_piece(Vector3(1.05,base+1.8+(t+1)*0.18-0.04,-8.9+(t+0.5)*0.32),Vector3(1.7,0.08,0.34),wood)
			if step%3==0:
				_piece(Vector3(-1.95,base+(t+1)*0.18+0.48,-5.7-(t+0.5)*0.32),Vector3(0.065,0.95,0.065),darkwood)
				_piece(Vector3(1.95,base+1.8+(t+1)*0.18+0.48,-8.9+(t+0.5)*0.32),Vector3(0.065,0.95,0.065),darkwood)
		_ramp_collider(node,Vector3(-1.05,base,-5.6),Vector3(-1.05,base+1.8,-8.9),1.72)
		_ramp_collider(node,Vector3(1.05,base+1.8,-8.9),Vector3(1.05,base+3.6,-5.6),1.72)
		_piece(Vector3(0,base+1.8-0.1,-10.15),Vector3(4.1,0.2,2.5),wood,true)
		for side in [-1.0,1.0]:
			_beam(Vector3(side*1.96,base+0.97,-5.6),Vector3(side*1.96,base+2.77,-8.9),0.07,darkwood,true)
			_beam(Vector3(side*1.96,base+2.77,-8.9),Vector3(side*1.96,base+4.57,-5.6),0.07,darkwood,true)
			_piece(Vector3(side*1.98,base+2.33,-10.2),Vector3(0.07,1.0,2.6),darkwood,true)
		_piece(Vector3(0,base+2.8,-11.4),Vector3(4.1,0.07,0.07),darkwood,true)
		for column in 9:
			_piece(Vector3(-1.9+column*0.475,base+2.33,-11.4),Vector3(0.055,1.0,0.055),darkwood)
	# A supported entrance canopy; genuine tall jambs are already part of shell.
	_piece(Vector3(-half+0.34,0.55,-2.6),Vector3(0.06,1.1,4.0),_tiles())
	_label(node,"ESCADAS · TERRAÇO ↑",Vector3(-2.8,1.8,-5.25),0.0038,38)
	if data.kind=="floorbar":
		for x in [-half+3,half-3]:
			for z in [-15.0,-19.5]: _table(Vector3(x,3.6,z),Color("8e6157"),2)
		_piece(Vector3(0,4.15,-depth+1.5),Vector3(4.6,1.1,0.8),_tiles(),true)
		_label(node,"BAR DO PRIMEIRO · 1º ANDAR",Vector3(0,5.8,-depth+0.32),0.0045,38)
	var roof_y := floors*3.6
	for side in [-1.0,1.0]: _piece(Vector3(side*(half-0.22),roof_y+0.55,-depth*0.5),Vector3(0.28,1.1,depth),plaster,true)
	_piece(Vector3(0,roof_y+0.55,-depth+0.2),Vector3(width,1.1,0.3),plaster,true)
	_piece(Vector3(0,roof_y+0.55,-0.15),Vector3(width,1.1,0.3),plaster,true)
	for x in [-half+2.5,half-2.5]:
		for z in [-3.0,-15.5,-20.0]: _table(Vector3(x,roof_y,z),Color("8e8770"),2,true)
	_piece(Vector3(0,roof_y+0.55,-depth+2),Vector3(4.0,1.1,0.8),darkwood,true)
	for side in [-1.0,1.0]:
		_piece(Vector3(side*2.4,roof_y+1.5,-depth+2.0),Vector3(0.1,3.0,0.1),iron)
	_piece(Vector3(0,roof_y+2.95,-depth+2),Vector3(5.0,0.1,3),_mat("coat",Color("5d6765")))
	_label(node,"TERRAÇO · LISBOA À NOITE",Vector3(0,roof_y+1.8,-depth+0.4),0.0045,38)
	_light(node,Vector3(0,roof_y+2.6,-depth+3),Color("cead7b"),0.55,8)

func _ramp_collider(parent: Node3D, start: Vector3, end: Vector3, width: float) -> void:
	var a := start+Vector3(-width*0.5,0,0)
	var b := start+Vector3(width*0.5,0,0)
	var c := end+Vector3(width*0.5,0,0)
	var d := end+Vector3(-width*0.5,0,0)
	var faces := PackedVector3Array([a,b,c,a,c,d])
	if end.z < start.z: faces=PackedVector3Array([a,c,b,a,d,c])
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new(); shape.set_faces(faces)
	collision.shape=shape
	_body.add_child(collision)

func _stair_path(node: Node3D, floors: int) -> PackedVector3Array:
	var result := PackedVector3Array([node.to_global(Vector3(0,0.15,2)),node.to_global(Vector3(0,0.15,-4.8))])
	for floor_index in floors:
		var base := floor_index*3.6
		for point in [Vector3(-1.05,base+0.15,-5.3),Vector3(-1.05,base+1.95,-9.8),Vector3(1.05,base+1.95,-9.8),Vector3(1.05,base+3.75,-5.25),Vector3(0,base+3.75,-4.8)]: result.append(node.to_global(point))
	result.append(node.to_global(Vector3(0,floors*3.6+0.15,-3)))
	return result

func _terrace(node: Node3D, data: Dictionary, width: float, index: int) -> void:
	if data.kind=="convenience":
		_piece(Vector3(-width*0.32,0.3,1.0),Vector3(0.8,0.6,0.65),_mat("wood",Color("8c9b75")),false,0,55)
		return
	for side in [-1.0,1.0]:
		var x: float = side*width*0.28
		_table(Vector3(x,0,2.3),Color("8a7a60") if index%2 else Color("83616c"),2,true)
		_piece(Vector3(x,0.36,3.6),Vector3(1.3,0.72,0.35),_mat("city_stone",Color("8e9080")),true)
		for sprig in 5: _piece(Vector3(x-0.45+sprig*0.23,0.96,3.6),Vector3(0.16,0.6,0.17),_mat("city_leaf",Color("6f805f")),false,0,60,true)
	# Awning rests on rods fixed to the wall and four posts, with clear pedestrian centre.
	var awning := _mat("coat",Color("77575f") if data.kind in ["bar","disco","fado"] else Color("667c70"))
	for side in [-1.0,1.0]:
		var x: float = side*width*0.28
		_piece(Vector3(x,2.85,1.9),Vector3(width*0.37,0.12,3.7),awning)
		for post_side in [-1.0,1.0]:
			var px: float = x+post_side*width*0.16
			_piece(Vector3(px,1.43,3.6),Vector3(0.065,2.86,0.065),_mat("metal",Color("56645c")),true)
			_beam(Vector3(px,2.95,0.15),Vector3(px,2.8,3.6),0.055,_mat("metal",Color("56645c")))
