extends RefCounted
## Authored continuous terrain, coast, roads and plaza surrounding the source crops.
var city: Node3D
var materials: Dictionary = {}

func build(owner: Node3D, parent: Node3D) -> void:
	city = owner
	_build_land(parent)
	_build_water(parent)
	_build_shore(parent)
	_build_roads(parent)
	_build_saldanha_garden(parent)
	_build_hills(parent)

func ground_material(key: String) -> Material:
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	var basename: String = {"calcada":"calcada_lisbon","asphalt":"street_asphalt","pink":"pink_paving"}.get(key,"calcada_lisbon")
	var path := "res://assets/maps/textures/"+basename
	mat.albedo_texture = load(path+".png")
	mat.normal_enabled = true
	mat.normal_texture = load(path+"_normal.png")
	mat.normal_scale = 0.15
	mat.roughness_texture = load(path+"_rough.png")
	mat.roughness = 0.88
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*0.45
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = mat
	return mat

func _build_land(parent: Node3D) -> void:
	var groups := {}
	var points: Array = city.manifest.landscape.ground
	for index in range(0,points.size(),3):
		var p: Array = points[index]
		var key := Vector2i(floori(p[0]/64),floori(p[2]/64))
		if not groups.has(key): groups[key] = []
		groups[key].append_array(points.slice(index,index+3))
	for key in groups:
		var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
		var data: Array = groups[key]
		for index in range(0,data.size(),3):
			var a := Vector3(data[index][0],data[index][1],data[index][2])
			var b := Vector3(data[index+1][0],data[index+1][1],data[index+1][2])
			var c := Vector3(data[index+2][0],data[index+2][1],data[index+2][2])
			var normal := (c-a).cross(b-a).normalized()
			for at in [a,b,c]: verts.append(at); normals.append(normal); uvs.append(Vector2(at.x,at.z))
		city._mesh(parent,verts,normals,uvs,ground_material("calcada"),true)

func _build_water(parent: Node3D) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2500,2300)
	mesh.subdivide_width = 40
	mesh.subdivide_depth = 40
	var node := MeshInstance3D.new()
	node.name = "TejoEOceano"
	node.mesh = mesh
	node.position = Vector3(220,-2,640)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/tejo_water.gdshader")
	mat.set_shader_parameter("water_texture",load("res://assets/textures/glass.png"))
	node.material_override = mat
	parent.add_child(node)

func _build_shore(parent: Node3D) -> void:
	var shore: Array = city.manifest.peninsula.polygon
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for index in shore.size():
		var a2: Array = shore[index]; var b2: Array = shore[(index+1)%shore.size()]
		var a := Vector3(a2[0],city.ground_height(a2[0],a2[1]),a2[1])
		var b := Vector3(b2[0],city.ground_height(b2[0],b2[1]),b2[1])
		var bottom_a := Vector3(a.x,-7,a.z); var bottom_b := Vector3(b.x,-7,b.z)
		var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
		for at in [a,bottom_a,b,b,bottom_a,bottom_b]:
			vertices.append(at); normals.append(normal); uvs.append(Vector2(at.x+at.z,at.y))
		# A visible quay/stone edge defines land; no invisible perimeter walls.
		if index>1:
			var length := a.distance_to(b)
			var edge: MeshInstance3D = city._box(parent,(a+b)*0.5+Vector3.UP*0.12,Vector3(0.45,0.24,length),city.world._material("city_stone"))
			edge.rotation.y = atan2(b.x-a.x,b.z-a.z)
	city._mesh(parent,vertices,normals,uvs,city.world._material("city_stone",Color("88847b")),true)

func _road_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for at in [a,b,c,a,c,d]: vertices.append(at); normals.append(normal); uvs.append(Vector2(at.x,at.z))

func _clip_z(points: Array[Vector3], boundary: float, above: bool) -> Array[Vector3]:
	var clipped: Array[Vector3] = []
	if points.is_empty(): return clipped
	var previous: Vector3 = points[-1]
	var previous_inside := previous.z>=boundary if above else previous.z<=boundary
	for current in points:
		var inside := current.z>=boundary if above else current.z<=boundary
		if inside!=previous_inside:
			clipped.append(previous.lerp(current,(boundary-previous.z)/(current.z-previous.z)))
		if inside: clipped.append(current)
		previous=current; previous_inside=inside
	return clipped

func _ground_road_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, a: Vector3,b: Vector3,c: Vector3,d: Vector3, offset: float) -> void:
	# Split across every slope transition, including across the road's width.
	# Interpolating one wide quad across z710 previously put the middle of the
	# Bairro Alto road 37 cm below the plateau, exposing paving in its centre.
	var profile: Array = city.manifest.peninsula.profile
	for index in profile.size()-1:
		var face: Array[Vector3] = [a,b,c,d]
		face = _clip_z(face,float(profile[index][0]),true)
		face = _clip_z(face,float(profile[index+1][0]),false)
		if face.size()<3: continue
		for point in face.size():
			face[point].y=city.ground_height(face[point].x,face[point].z)+offset
		for triangle in range(1,face.size()-1):
			var normal := (face[triangle+1]-face[0]).cross(face[triangle]-face[0])
			if normal.length_squared()<0.000001: continue
			normal=normal.normalized()
			for at in [face[0],face[triangle],face[triangle+1]]:
				vertices.append(at); normals.append(normal); uvs.append(Vector2(at.x,at.z))

func _build_roads(parent: Node3D) -> void:
	var road_vertices := PackedVector3Array(); var road_normals := PackedVector3Array(); var road_uvs := PackedVector2Array()
	var marking_vertices := PackedVector3Array(); var marking_normals := PackedVector3Array(); var marking_uvs := PackedVector2Array()
	var posts := PackedVector3Array()
	for spec in city.manifest.peninsula.roads:
		var points: Array = spec.points
		for index in points.size()-1:
			var a := Vector2(points[index][0],points[index][1]); var b := Vector2(points[index+1][0],points[index+1][1])
			var direction := (b-a).normalized(); var side := Vector2(direction.y,-direction.x)
			var length := a.distance_to(b); var steps := maxi(1,ceili(length/6))
			for part in steps:
				var p := a.lerp(b,float(part)/steps); var q := a.lerp(b,float(part+1)/steps)
				var w: float = spec.width*0.5
				var left_a := p-side*w; var right_a := p+side*w; var right_b := q+side*w; var left_b := q-side*w
				_ground_road_quad(road_vertices,road_normals,road_uvs,_at(left_a,0.022),_at(right_a,0.022),_at(right_b,0.022),_at(left_b,0.022),0.022)
				if part%2==0:
					var dash_start := p+direction*0.5; var dash_end := q-direction*1.0
					_ground_road_quad(marking_vertices,marking_normals,marking_uvs,_at(dash_start-side*0.065,0.036),_at(dash_start+side*0.065,0.036),_at(dash_end+side*0.065,0.036),_at(dash_end-side*0.065,0.036),0.036)
			for distance in range(15,int(length),34):
				var p := a+direction*distance+side*(float(spec.width)*0.5+2.1)
				posts.append(_at(p,0))
	_chunk_mesh(parent,road_vertices,road_normals,road_uvs,ground_material("asphalt"))
	var paint: Material = city.world._material("marking",Color("9c9885"))
	_chunk_mesh(parent,marking_vertices,marking_normals,marking_uvs,paint)
	_build_lamps(parent,posts)
	for at in [Vector3(65,city.ground_height(65,320),320),Vector3(435,8,710),Vector3(65,0,900)]:
		city._box(parent,at+Vector3(0,1.6,0),Vector3(0.08,3.2,0.08),city.world._material("metal"))
		city._box(parent,at+Vector3(0,3.0,0),Vector3(3.5,0.95,0.15),city.world._material("metal",Color("55666b")))
		var label := Label3D.new()
		label.text = "SALDANHA ↑\nBAIRRO ALTO ↓\nCAIS DO SODRÉ ↓"
		label.position = at+Vector3(0,3.0,0.09)
		label.font = load("res://assets/fonts/Interface.ttf")
		label.font_size = 26; label.pixel_size = 0.004
		label.visibility_range_end = 28
		parent.add_child(label)

func _at(point: Vector2, offset: float) -> Vector3:
	return Vector3(point.x,city.ground_height(point.x,point.y)+offset,point.y)

func _chunk_mesh(parent: Node3D, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, material: Material) -> void:
	# Compatibility chooses a bounded set of lights per mesh. A single road
	# spanning the whole city would lose local lamp lighting at the other end.
	var groups := {}
	for index in range(0,vertices.size(),3):
		var center := (vertices[index]+vertices[index+1]+vertices[index+2])/3.0
		var key := Vector2i(floori(center.x/64),floori(center.z/64))
		if not groups.has(key): groups[key] = {"verts":PackedVector3Array(),"normals":PackedVector3Array(),"uvs":PackedVector2Array()}
		var group: Dictionary = groups[key]
		for vertex in range(index,index+3):
			group.verts.append(vertices[vertex]); group.normals.append(normals[vertex]); group.uvs.append(uvs[vertex])
	for group in groups.values():
		var mesh: MeshInstance3D = city._mesh(parent,group.verts,group.normals,group.uvs,material)
		mesh.visibility_range_end = 310.0

func _build_lamps(parent: Node3D, posts: PackedVector3Array) -> void:
	var metal: Material = city.world._material("metal",Color("73716a"))
	var glow: Material = city.world._material("glass",Color("d6b570"),Color("ffc16b"),0.7)
	var pole_transforms: Array[Transform3D] = []; var bulb_transforms: Array[Transform3D] = []
	for index in posts.size():
		var at := posts[index]
		pole_transforms.append(Transform3D(Basis().scaled(Vector3(0.1,6.2,0.1)),at+Vector3(0,3.1,0)))
		pole_transforms.append(Transform3D(Basis().scaled(Vector3(1.1,0.1,0.12)),at+Vector3(0.5,6.2,0)))
		bulb_transforms.append(Transform3D(Basis().scaled(Vector3(0.7,0.12,0.35)),at+Vector3(0.7,6.14,0)))
		var light := OmniLight3D.new()
		light.position = at+Vector3(0.7,5.6,0)
		light.light_color = Color("ffc27c")
		light.light_energy = 2.4
		light.omni_range = 20
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 70
		light.distance_fade_length = 25
		parent.add_child(light)
	_multimesh(parent,pole_transforms,metal)
	_multimesh(parent,bulb_transforms,glow)

func _multimesh(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new(); cube.size = Vector3.ONE
	mm.mesh = cube; mm.instance_count = transforms.size()
	for index in transforms.size(): mm.set_instance_transform(index,transforms[index])
	var node := MultiMeshInstance3D.new(); node.multimesh = mm; node.material_override = material
	parent.add_child(node)

func _build_saldanha_garden(parent: Node3D) -> void:
	var center := Vector3(258.1,0.045,194.7)
	var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for index in 60:
		var angle := TAU*index/60.0; var next := TAU*(index+1)/60.0
		var a := center+Vector3(cos(angle)*27,0,sin(angle)*31)
		var b := center+Vector3(cos(next)*27,0,sin(next)*31)
		for at in [center,a,b]: verts.append(at); normals.append(Vector3.UP); uvs.append(Vector2(at.x,at.z))
	city._mesh(parent,verts,normals,uvs,city.world._material("city_granite",Color("697650")))
	# A garden has visible paths and a stone boundary, rather than a black oval
	# pasted over the plaza. These low steps remain traversable by the player.
	var stone: Material = city.world._material("city_stone",Color("bfb39a"))
	for direction in [Vector3.RIGHT,Vector3.BACK]:
		var dimensions := Vector3(54,0.11,3.4) if direction==Vector3.RIGHT else Vector3(3.4,0.11,62)
		city._box(parent,center+Vector3.UP*0.03,dimensions,stone)
	var curb_verts := PackedVector3Array(); var curb_normals := PackedVector3Array(); var curb_uvs := PackedVector2Array()
	for index in 72:
		var a := TAU*index/72.0; var b := TAU*(index+1)/72.0
		var ia := center+Vector3(cos(a)*27,0.10,sin(a)*31)
		var ib := center+Vector3(cos(b)*27,0.10,sin(b)*31)
		var oa := center+Vector3(cos(a)*27.5,0.10,sin(a)*31.5)
		var ob := center+Vector3(cos(b)*27.5,0.10,sin(b)*31.5)
		_road_quad(curb_verts,curb_normals,curb_uvs,ia,oa,ob,ib)
	city._mesh(parent,curb_verts,curb_normals,curb_uvs,stone)
	var metal: Material = city.world._material("metal",Color("73736d"))
	var glow: Material = city.world._material("glass",Color("e5b167"),Color("ffaf54"),2.8)
	for index in 4:
		var angle := TAU*(float(index)+0.5)/4.0
		var at := center+Vector3(cos(angle)*25.2,0,sin(angle)*29.0)
		city._box(parent,at+Vector3(0,4.0,0),Vector3(0.14,8,0.14),metal)
		city._box(parent,at+Vector3(0,7.88,0),Vector3(3.8,0.13,0.16),metal)
		for side in [-1.0,1.0]:
			city._box(parent,at+Vector3(side*1.6,7.8,0),Vector3(0.95,0.18,0.55),glow)
		var light := OmniLight3D.new()
		light.position = at+Vector3(0,6.8,0)
		light.light_color = Color("ffb766")
		light.light_energy = 3.4
		light.omni_range = 28.0
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 100.0
		light.distance_fade_length = 35.0
		parent.add_child(light)
	# Warm ground-mounted uplights make the real landmark readable from the
	# avenue. Housings touch the stone paths and do not float in the square.
	for side in [-1.0,1.0]:
		var at := center+Vector3(side*6,0.1,4)
		city._box(parent,at,Vector3(0.55,0.22,0.48),metal)
		var spot := SpotLight3D.new()
		spot.position = at+Vector3.UP*0.2
		spot.light_color = Color("ffc17f")
		spot.light_energy = 4.0
		spot.spot_range = 19.0
		spot.spot_angle = 45.0
		spot.shadow_enabled = false
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 100.0
		spot.distance_fade_length = 35.0
		parent.add_child(spot)
		spot.look_at(center+Vector3(0,5.0,0))
	for index in 14:
		var angle := TAU*index/14.0
		var at := center+Vector3(cos(angle)*36,0,sin(angle)*39)
		var before: Array = city.world.get_children()
		city.world._tree(at)
		if index%2==0: city.world._bench(at+Vector3(2.5,0,0))
		for child in city.world.get_children():
			if not before.has(child): child.reparent(parent,true)

func _build_hills(parent: Node3D) -> void:
	var verts := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	for index in 14:
		var x := -125.0+index*50
		var top := 32.0+sin(index*1.7)*9
		_road_quad(verts,normals,uvs,Vector3(x,0,-180),Vector3(x,top+5,-240),Vector3(x+50,top,-240),Vector3(x+50,0,-180))
		_road_quad(verts,normals,uvs,Vector3(x,top+5,-240),Vector3(x,top+20,-370),Vector3(x+50,top+15,-370),Vector3(x+50,top,-240))
	city._mesh(parent,verts,normals,uvs,city.world._material("city_stone",Color("686b5e")),true)
