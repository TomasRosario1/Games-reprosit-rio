class_name AlbumEditorGizmo
extends Node3D
## Screen-sized world-space axes with screen-space picking. No physics helpers.
const AXES := [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
var length_world := 2.0
var _handles: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _grid: MeshInstance3D

func _ready() -> void:
	set_meta("editor_helper",true)
	for axis in 3:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 120
		mat.albedo_color = [Color("ee746c"),Color("91d88b"),Color("7eb7f3")][axis]
		_materials.append(mat)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.018,0.018,0.018)+AXES[axis]*0.98
		line.mesh = box
		line.position = AXES[axis]*0.5
		line.material_override = mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		var handle := MeshInstance3D.new()
		var tip := SphereMesh.new()
		tip.radius = 0.055
		tip.height = 0.11
		tip.radial_segments = 8
		tip.rings = 4
		handle.mesh = tip
		handle.position = AXES[axis]
		handle.material_override = mat
		handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(handle)
		_handles.append(handle)
	_build_grid()
	hide()

func _build_grid() -> void:
	_grid = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.47,0.64,0.62,0.32)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for i in range(-8,9):
		lines.surface_add_vertex(Vector3(i,0,-8))
		lines.surface_add_vertex(Vector3(i,0,8))
		lines.surface_add_vertex(Vector3(-8,0,i))
		lines.surface_add_vertex(Vector3(8,0,i))
	lines.surface_end()
	_grid.mesh = lines
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)

func place(camera: Camera3D, at: Vector3, highlighted_axis: int, grid_enabled: bool) -> void:
	global_position = at
	var distance := camera.global_position.distance_to(at)
	length_world = clampf(distance*0.13,0.65,12.0)
	scale = Vector3.ONE*length_world
	for axis in 3:
		_materials[axis].emission_enabled = highlighted_axis == axis
		_materials[axis].emission = Color.WHITE
		_materials[axis].emission_energy_multiplier = 0.25
	_grid.visible = grid_enabled
	_grid.scale = Vector3.ONE/length_world
	_grid.position = Vector3(0,0.018,0)/length_world
	show()

func pick_axis(camera: Camera3D, screen: Vector2) -> int:
	if not visible or camera.is_position_behind(global_position): return -1
	var origin := camera.unproject_position(global_position)
	var best := 12.0
	var selected := -1
	for axis in 3:
		var endpoint := camera.unproject_position(global_position+AXES[axis]*length_world)
		var start := origin.lerp(endpoint,0.18)
		var closest := Geometry2D.get_closest_point_to_segment(screen,start,endpoint)
		var distance := screen.distance_to(closest)
		if distance < best:
			best = distance
			selected = axis
	return selected
