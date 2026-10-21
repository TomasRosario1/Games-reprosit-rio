extends SceneTree
## Real main-scene verification of camera blur and direct creator manipulation.
var checks := 0
var failures := 0
var game: Node3D
var screenshots := false

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PRESENTATION: "+message)

func _run() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	create_timer(90).timeout.connect(func():
		push_error("Presentation test timed out")
		quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.15).timeout
	game.set_process(false)
	game._begin_exploration(0)
	game._set_world_paused(true)
	game.store.save_path = "user://presentation_player.json"
	game._editor.save_path = "user://presentation_world.json"
	game._game_menu._change_motion_blur(0.7)
	check(is_equal_approx(game._motion_blur.strength,0.7),"quality control changes actual motion-blur strength")
	var preferences := ConfigFile.new()
	check(preferences.load("user://menu_settings.cfg") == OK and is_equal_approx(preferences.get_value("menu","motion_blur"),0.7),"motion blur preference survives local save")
	var camera: Camera3D = game.player.get_camera()
	camera.global_position = Vector3(7,2.8,12)
	camera.look_at(Vector3(24,4,-9))
	var effect: Node = game._motion_blur
	effect.reset_history()
	effect.update_camera(camera,1.0/60.0,true)
	check(not effect.active,"first frame suppresses stale camera history")
	effect.update_camera(camera,1.0/60.0,true)
	check(effect.active,"blur activates after valid camera history")
	effect.update_camera(camera,1.0/60.0,false)
	check(not effect.active,"menus/editor disable blur")
	effect.update_camera(camera,1.0/60.0,true)
	effect.update_camera(camera,1.0/60.0,true)
	camera.global_position += Vector3(20,0,0)
	effect.update_camera(camera,1.0/60.0,true)
	check(not effect.active,"teleport rejects previous pose instead of streaking the scene")
	camera.global_position -= Vector3(20,0,0)
	effect.update_camera(camera,1.0/60.0,true)
	effect.set_strength(0.0)
	effect.update_camera(camera,1.0/60.0,true)
	check(not effect.active,"zero strength bypasses blur sampling")
	if DisplayServer.get_name() != "headless":
		await _render_blur(camera,effect)
	else:
		print("SKIP: GPU image comparisons require native Compatibility rendering.")
	effect.reset_history()

	game._editor_unlocked = true
	game._request_editor()
	game._notice.hide()
	var editor: Control = game._editor
	check(game.state == "editor" and editor.active,"creator opens in the real game")
	check(editor._inspection_light.visible,"creator has local inspection light for night editing")
	editor._bookmarks.get_popup().about_to_popup.emit()
	check(editor._bookmarks.item_count>=4,"camera bookmarks are populated from the actual world")
	editor._bookmarks.item_selected.emit(1)
	check(editor.camera.global_position.is_equal_approx(Vector3(10,7,19)),"bookmark menu actually moves editor camera to Saldanha")
	var id: String = editor.spawn_catalog("Parede",Vector3(10,0.12,10))
	var wall: Node3D = editor.targets[id].node
	var body: StaticBody3D = wall.get_child(0)
	check(editor.dirty,"placing an object marks world as unsaved")
	var count: int = editor._history.size()
	check(editor.begin_transform("move",0),"axis manipulation starts on selected object")
	check(editor.preview_transform(0.61) and editor.preview_transform(0.93),"successive drag updates are accepted")
	check(is_equal_approx(wall.global_position.x,11.0) and is_equal_approx(body.global_position.x,11.0),"grid snaps real mesh and collider together")
	check(not editor.save_world(),"unfinished drag cannot leak into a saved world")
	editor.end_transform(true)
	check(editor._history.size() == count+1,"one complete drag creates one undo entry")
	check(editor.undo() and is_equal_approx(wall.global_position.x,10.0),"undo restores original geometry and collision")
	check(editor.redo() and is_equal_approx(wall.global_position.x,11.0),"redo restores committed drag")
	var before: Transform3D = wall.global_transform
	editor.begin_transform("move",2)
	editor.preview_transform(2.1)
	editor.end_transform(false)
	check(wall.global_transform.is_equal_approx(before),"cancel restores exact pre-drag transform")
	editor.begin_transform("rotate",1)
	editor.preview_transform(21)
	editor.end_transform(true)
	check(absf(rad_to_deg(wall.global_rotation.y)-15.0)<0.01,"rotation snaps in fifteen-degree steps")
	editor.begin_transform("scale",0)
	editor.preview_transform(-100.0)
	editor.end_transform(true)
	check(wall.scale.x >= 0.0499,"scale drag cannot collapse or invert geometry")
	editor.undo()
	editor.snap_enabled = false
	editor.begin_transform("move",0)
	editor.preview_transform(0.123)
	editor.end_transform(true)
	check(is_equal_approx(wall.global_position.x,11.123),"precision mode supports movement without grid snapping")
	editor.snap_enabled = true
	check(editor.focus_selected(),"focus tool finds the current object")
	check(not editor.camera.is_position_behind(wall.global_position+Vector3.UP),"focus places selected geometry in front of camera")
	editor.set_transform_mode("move")
	editor.camera.global_position = wall.global_position+Vector3(6,5,10)
	editor.camera.look_at(wall.global_position+Vector3.UP)
	editor._update_gizmo()
	var origin: Vector3 = wall.global_position
	var endpoint: Vector2 = editor.camera.unproject_position(origin+Vector3.RIGHT*editor._gizmo.length_world)
	check(editor._gizmo.pick_axis(editor.camera,endpoint)==0,"visible red handle is selectable in screen coordinates")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = endpoint
	editor._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = endpoint+editor._drag_screen_axis*editor._drag_pixels_per_unit*0.51
	editor._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	editor._input(release)
	check(is_equal_approx(wall.global_position.x,origin.x+0.5),"mouse handle drag changes real world position and confirms on release")

	var building_id: String = editor.spawn_catalog("Prédio",Vector3(18,0.12,12))
	var building: Node3D = editor.targets[building_id].node
	var detail_count := 0
	for child in building.get_children():
		if child is MultiMeshInstance3D: detail_count += child.multimesh.instance_count
	check(detail_count>30,"building preset creates façade, windows, cornices and roof")
	check(building.get_child_count()<10,"building details share batches instead of one node/draw per window")
	var kept: GeometryInstance3D
	var building_body: StaticBody3D
	for child in building.get_children():
		if child is GeometryInstance3D and child.get_meta("editor_keep_material",false): kept = child
		if child is StaticBody3D: building_body = child
	var original_material: Material = kept.material_override if kept else null
	var textured := true
	for child in building.get_children():
		if child is GeometryInstance3D:
			textured = textured and child.material_override is StandardMaterial3D and child.material_override.albedo_texture != null
	check(textured,"all building surfaces have real albedo textures")
	check(editor.edit_target(building_id,{"color":"c6a69aff","scale":[1.2,1.1,1.0]}),"new building accepts façade tint and proportions")
	check(kept.material_override == original_material,"façade recolouring preserves roofs/window materials")
	check(building_body and building_body.global_basis.get_scale().is_equal_approx(Vector3(1.2,1.1,1.0)),"building collider follows scaled architecture")
	editor.focus_selected()
	await _capture("editor-building")
	check(editor.save_world() and not editor.dirty,"saving clears the unsaved indicator")
	check(editor.edit_target(building_id,{"position":[30,0.12,12]}) and editor.load_world(),"building supports save-edit-reload lifecycle")
	check(editor.targets.has(building_id) and is_equal_approx(editor.targets[building_id].node.global_position.x,18.0),"reload reconstructs placed building from saved data")
	editor.select_target(building_id)
	editor.edit_target(building_id,{"position":[19,0.12,12]})
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(editor._exit_dialog.visible and editor._exit_application and game.state=="editor","window close protects unsaved creator world before quitting")
	editor._exit_dialog.get_cancel_button().pressed.emit()
	var f10 := InputEventAction.new()
	f10.action = "editor_toggle"
	f10.pressed = true
	game._unhandled_input(f10)
	check(editor._exit_dialog.visible and editor.active and game.state=="editor","F10 warns before leaving unsaved world")
	editor._exit_dialog.get_cancel_button().pressed.emit()
	check(editor.active and game.state=="editor","cancel keeps creator session and edits")
	editor.request_exit()
	editor._exit_dialog.get_ok_button().pressed.emit()
	check(not editor.active and game.state=="explore" and not editor.dirty,"save-and-return closes creator and resumes game")
	check(not editor._inspection_light.visible,"inspection light cannot change game lighting after editing")
	game._set_world_paused(true)
	game.music.stop()
	game.ambience.stop()
	game.player._footsteps.stop()
	game._vehicles._horn.stop()
	await create_timer(0.22).timeout
	game.rhythm.finished.disconnect(game._performance_finished)
	game.rhythm.note_judged.disconnect(game._note_judged)
	game._rhythm_view.rhythm = null
	game.rhythm = null
	game.queue_free()
	await process_frame
	print("PRESENTATION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func _render_blur(camera: Camera3D, effect: Node) -> void:
	var target := camera.global_transform.rotated_local(Vector3.UP,0.08)
	var start := camera.global_transform
	camera.global_transform = target
	effect.set_strength(0.0)
	effect.update_camera(camera,1.0/60.0,true)
	await _draw()
	var sharp := root.get_texture().get_image()
	if screenshots: sharp.save_png("/tmp/album-v3-blur-off.png")
	effect.set_strength(1.0)
	effect.reset_history()
	camera.global_transform = start
	effect.update_camera(camera,1.0/60.0,true)
	camera.global_transform = target
	effect.update_camera(camera,1.0/60.0,true)
	await _draw()
	var moving := root.get_texture().get_image()
	if screenshots: moving.save_png("/tmp/album-v3-blur-on.png")
	var changed := _changed_pixels(sharp,moving,Rect2i(0,0,sharp.get_width(),sharp.get_height()))
	check(changed>100,"native shader changes pixels after real camera rotation")
	var hud_pixels := 0
	var hud_changed := 0
	for y in range(26,75):
		for x in range(sharp.get_width()-300,sharp.get_width()-28):
			var a := sharp.get_pixel(x,y)
			if absf(a.r-208.0/255.0)<0.003 and absf(a.g-212.0/255.0)<0.003 and absf(a.b-207.0/255.0)<0.003:
				hud_pixels += 1
				var b := moving.get_pixel(x,y)
				if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.016: hud_changed += 1
	check(hud_pixels>50 and hud_changed==0,"opaque money/icon pixels remain sharp while world background blurs")
	effect.update_camera(camera,1.0/60.0,true)
	await _draw()
	var stationary := root.get_texture().get_image()
	if screenshots: stationary.save_png("/tmp/album-v3-blur-stationary.png")
	var stationary_changes := _changed_pixels(sharp,stationary,Rect2i(0,0,sharp.get_width(),sharp.get_height()))
	check(stationary_changes<50,"stationary camera preserves scene colour and sharpness")
	print("NATIVE BLUR: changed=",changed," stationary_difference=",stationary_changes)
	effect.update_camera(camera,1.0/60.0,false)

func _changed_pixels(a: Image,b: Image,rect: Rect2i) -> int:
	var changed := 0
	for y in range(rect.position.y,mini(rect.end.y,a.get_height())):
		for x in range(rect.position.x,mini(rect.end.x,a.get_width())):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			if maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))>0.016: changed += 1
	return changed

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(label: String) -> void:
	if not screenshots or DisplayServer.get_name()=="headless": return
	await _draw()
	check(root.get_texture().get_image().save_png("/tmp/album-v3-"+label+".png")==OK,"native screenshot "+label)
