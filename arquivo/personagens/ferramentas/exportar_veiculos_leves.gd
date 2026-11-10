extends SceneTree
## Isolated source snapshots for the two remaining vehicle-entry reviews.
func _initialize() -> void:
	call_deferred("_run")
func _array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _run() -> void:
	var output := "res://arquivo/personagens/emmet/revisao_04/veiculos/"
	DirAccess.make_dir_recursive_absolute(output)
	var metadata := {}
	for kind in ["bicycle", "scooter"]:
		var vehicle: Node3D = load("res://scripts/vehicle.gd").new()
		vehicle.type = kind
		root.add_child(vehicle)
		vehicle.set_physics_process(false)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(vehicle.visual, state) == OK)
		assert(document.write_to_filesystem(state, output + kind + "_original.glb") == OK)
		var contacts := {}
		for key in vehicle.get_rider_contacts():
			contacts[key] = _array(vehicle.get_rider_contacts()[key] + vehicle.seat_offset)
		metadata[kind] = {"source": "scripts/vehicle.gd", "source_commit": "c7d85815ada35a4b28e678fea6786be33ba32fb5", "seat_root": _array(vehicle.seat_offset), "contacts": contacts}
		vehicle.queue_free()
		await process_frame
	var file := FileAccess.open(output + "metadados.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("REVIEW04 VEHICLE SNAPSHOTS: bicycle and scooter")
	quit()
