extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _array(v: Vector3) -> Array:
	return [v.x,v.y,v.z]
func _run() -> void:
	var metadata := {}
	for kind in ["car","motorbike"]:
		var vehicle: Node3D = load("res://scripts/vehicle.gd").new()
		vehicle.type = kind
		root.add_child(vehicle)
		vehicle.set_physics_process(false)
		if vehicle.door_pivot: vehicle.door_pivot.name="PivotPorta"
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(vehicle.visual,state)==OK)
		assert(document.write_to_filesystem(state,"res://arquivo/personagens/emmet/revisao_03/veiculos/"+kind+"_original.glb")==OK)
		var contacts := {}
		for key in vehicle.get_rider_contacts(): contacts[key]=_array(vehicle.get_rider_contacts()[key]+vehicle.seat_offset)
		metadata[kind]={"seat_root":_array(vehicle.seat_offset),"entry":_array(vehicle.entry_offset),"contacts":contacts,"source":"scripts/vehicle.gd","source_commit":"fd80a6786ca3546c3330f8768e3ab4f5ca65ba65"}
		vehicle.queue_free()
		await process_frame
	var file := FileAccess.open("res://arquivo/personagens/emmet/revisao_03/veiculos/metadados.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"));file.close()
	print("VEHICLE REVIEW EXPORT: car and motorbike ready")
	quit()
