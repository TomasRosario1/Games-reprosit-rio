extends Node3D
## A whole footprint is one editor target, including its walls and collisions.
var editor_bounds := AABB()
func get_editor_bounds() -> AABB:
	return editor_bounds
