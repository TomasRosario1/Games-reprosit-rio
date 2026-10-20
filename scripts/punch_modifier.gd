class_name AlbumPunchModifier
extends SkeletonModifier3D
## Additive punch after the imported locomotion animation. No source clip is modified.
var strength: float = 0.0

func _process_modification() -> void:
	if strength <= 0.001:
		return
	var rig := get_skeleton()
	if not rig:
		return
	for entry in [["upper_arm.R", Vector3.RIGHT, -1.35], ["forearm.R", Vector3.RIGHT, 0.65], ["chest", Vector3.UP, -0.20]]:
		var index: int = rig.find_bone(entry[0])
		if index >= 0:
			var rotation: Quaternion = rig.get_bone_pose_rotation(index)
			rig.set_bone_pose_rotation(index, rotation * Quaternion(entry[1], float(entry[2]) * strength))
