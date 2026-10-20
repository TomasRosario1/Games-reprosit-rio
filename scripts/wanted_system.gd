class_name AlbumWantedSystem
extends RefCounted
## Continuous heat, separate from combat and from the presentation of five segments.

signal changed(heat: float)
const EVENT_HEAT := {
	"bump": 0.0,
	"civilian_assault": 10.0,
	"civilian_kill": 20.0,
	"vehicle_collision": 20.0,
	"police_assault": 25.0,
	"police_kill": 45.0
}

var heat: float = 0.0
var seconds_since_crime: float = 0.0
var cooldown_seconds: float = 20.0
var decay_per_second: float = 3.0
var crimes_include_civilians: bool = true


func record_event(kind: String, witnessed: bool = true) -> bool:
	if not EVENT_HEAT.has(kind):
		return false
	if kind in ["civilian_assault", "civilian_kill", "vehicle_collision"]:
		if not witnessed or not crimes_include_civilians:
			return false
	var amount: float = EVENT_HEAT[kind]
	if amount <= 0.0:
		return false
	seconds_since_crime = 0.0
	_set_heat(heat + amount)
	return true


func update(delta: float, seen: bool) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var before := seconds_since_crime
	seconds_since_crime += delta
	if seen or heat <= 0.0:
		return
	# Only the portion of a long frame after the grace period may decay heat.
	var eligible_time := maxf(0.0, seconds_since_crime - maxf(before, cooldown_seconds))
	if eligible_time > 0.0:
		_set_heat(heat - eligible_time * decay_per_second)


func clear() -> void:
	seconds_since_crime = 0.0
	_set_heat(0.0)


func stars() -> int:
	return clampi(ceili(heat / 20.0), 0, 5)


func _set_heat(value: float) -> void:
	var next := clampf(value, 0.0, 100.0)
	if not is_equal_approx(next, heat):
		heat = next
		changed.emit(heat)
