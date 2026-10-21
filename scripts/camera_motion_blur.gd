class_name AlbumCameraMotionBlur
extends Node
## Stylised screen-space camera blur, sharing the existing brightness pass.
## No frame history texture, CPU image readback or per-object velocity pass.
const EFFECT := preload("res://assets/shaders/camera_motion_blur.gdshader")
var strength := 0.35
var material: ShaderMaterial
var active := false
var _camera: Camera3D
var _previous_transform := Transform3D.IDENTITY
var _previous_projection := Projection.IDENTITY
var _history_valid := false

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = EFFECT

func attach_surface(surface: ColorRect) -> void:
	surface.material = material

func set_strength(value: float) -> void:
	strength = clampf(value,0.0,1.0) if is_finite(value) else 0.35
	if strength <= 0.0: _clear_motion()

func _clear_motion() -> void:
	active = false
	if material:
		material.set_shader_parameter("motion",Vector2.ZERO)
		material.set_shader_parameter("radial_motion",0.0)

func reset_history() -> void:
	_history_valid = false
	_clear_motion()

func update_camera(current: Camera3D, delta: float, enabled: bool) -> void:
	if not is_instance_valid(current):
		reset_history()
		return
	var at := current.get_camera_transform()
	var projection := current.get_camera_projection()
	var cut := not _history_valid or current != _camera or delta <= 0.0 or delta > 0.15
	cut = cut or at.origin.distance_to(_previous_transform.origin) > 8.0
	cut = cut or at.basis.get_rotation_quaternion().angle_to(_previous_transform.basis.get_rotation_quaternion()) > 0.8
	cut = cut or projection != _previous_projection
	active = enabled and strength > 0.0 and not cut
	if active:
		var previous_forward := at.basis.inverse()*_previous_transform.basis.z
		var local_travel := at.basis.inverse()*(at.origin-_previous_transform.origin)
		var extent := tan(deg_to_rad(current.fov*0.5))
		var viewport_size := current.get_viewport().get_visible_rect().size
		var aspect := viewport_size.x/maxf(viewport_size.y,1.0)
		var angular := Vector2(atan2(previous_forward.x,previous_forward.z)/(2.0*extent*aspect),-asin(clampf(previous_forward.y,-1.0,1.0))/(2.0*extent))
		var shutter := strength*minf(1.0,(1.0/60.0)/maxf(delta,0.001))
		material.set_shader_parameter("motion",(angular+Vector2(local_travel.x,-local_travel.y)*0.04)*shutter)
		material.set_shader_parameter("radial_motion",-local_travel.z*0.04*shutter)
	else:
		_clear_motion()
	_camera = current
	_previous_transform = at
	_previous_projection = projection
	_history_valid = enabled
