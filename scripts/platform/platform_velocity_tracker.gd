extends Node
class_name PlatformVelocityTracker

var _previous_transform: Transform3D
var _velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	if get_parent() is Node3D:
		_previous_transform = (get_parent() as Node3D).global_transform

func _physics_process(delta: float) -> void:
	if not (get_parent() is Node3D):
		return

	var platform: Node3D = get_parent() as Node3D
	var current_transform: Transform3D = platform.global_transform
	if _previous_transform == Transform3D():
		_previous_transform = current_transform
		_velocity = Vector3.ZERO
		return

	_velocity = (current_transform.origin - _previous_transform.origin) / max(delta, 0.0001)
	_previous_transform = current_transform

func get_velocity() -> Vector3:
	return _velocity

func get_platform_velocity() -> Vector3:
	return _velocity
