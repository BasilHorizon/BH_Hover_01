extends AnimatableBody3D

@export var movement_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var cycle_duration: float = 3.0

var _start_position: Vector3 = Vector3.ZERO
var _last_position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0

func _ready() -> void:
	_start_position = global_position
	_last_position = _start_position

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var cycle: float = max(cycle_duration, 0.001)
	var phase: float = (_elapsed / cycle) * TAU
	global_position = _start_position + movement_offset * sin(phase)
	_velocity = (global_position - _last_position) / max(delta, 0.0001)
	_last_position = global_position

func get_platform_velocity() -> Vector3:
	return _velocity
