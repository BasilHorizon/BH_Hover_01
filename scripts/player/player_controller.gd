extends RigidBody3D

@export var acceleration: float = 70.0
@export var air_control: float = 0.35
@export var max_speed: float = 10.0
@export var jump_impulse: float = 6.5
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -75.0
@export var max_pitch: float = 75.0
@export var wallrun_lift_force: float = 14.0
@export var wallrun_lean_degrees: float = 18.0
@export var wallrun_lean_speed: float = 8.0

@onready var ground_ray: RayCast3D = $GroundRay
@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight
@onready var camera_pivot: Node3D = $CameraPivot
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _pitch: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO
var _is_wallrunning: bool = false
var _wall_side: int = 0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		camera_pivot.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("jump") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_debug_input_state(input_dir)

	var move_dir: Vector3 = _get_move_direction(input_dir)
	var current_velocity: Vector3 = linear_velocity
	var horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var grounded: bool = ground_ray.is_colliding()

	if move_dir != Vector3.ZERO:
		var control: float = 1.0 if grounded else air_control
		if horizontal_velocity.length() < max_speed or horizontal_velocity.dot(move_dir) < max_speed:
			apply_central_force(move_dir * acceleration * control)

	if Input.is_action_just_pressed("jump") and grounded:
		apply_central_impulse(Vector3.UP * jump_impulse)

	_handle_wallrun(grounded, move_dir)
	_apply_wallrun_lean(delta)

func _handle_wallrun(grounded: bool, move_dir: Vector3) -> void:
	var touching_left: bool = wall_ray_left.is_colliding()
	var touching_right: bool = wall_ray_right.is_colliding()
	var can_wallrun: bool = not grounded and move_dir != Vector3.ZERO and (touching_left or touching_right)

	if can_wallrun:
		_wall_side = -1 if touching_left else 1
		apply_central_force(Vector3.UP * wallrun_lift_force)
		if not _is_wallrunning:
			_is_wallrunning = true
			print("[Wallrun] START side=", "left" if _wall_side == -1 else "right")
	elif _is_wallrunning:
		_is_wallrunning = false
		_wall_side = 0
		print("[Wallrun] END")

func _apply_wallrun_lean(delta: float) -> void:
	var target_roll: float = 0.0
	if _is_wallrunning:
		target_roll = -deg_to_rad(wallrun_lean_degrees) if _wall_side == -1 else deg_to_rad(wallrun_lean_degrees)

	mesh_instance.rotation.z = lerp_angle(mesh_instance.rotation.z, target_roll, wallrun_lean_speed * delta)

func _debug_input_state(input_dir: Vector2) -> void:
	if not is_equal_approx(input_dir.x, _last_input_dir.x) or not is_equal_approx(input_dir.y, _last_input_dir.y):
		print("[Input] vector=", input_dir,
			" forward=", Input.is_action_pressed("move_forward"),
			" back=", Input.is_action_pressed("move_back"),
			" left=", Input.is_action_pressed("move_left"),
			" right=", Input.is_action_pressed("move_right"),
			" jump=", Input.is_action_pressed("jump"))
		_last_input_dir = input_dir

func _get_move_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var camera_basis: Basis = camera.global_transform.basis
		var forward: Vector3 = -camera_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right: Vector3 = camera_basis.x
		right.y = 0.0
		right = right.normalized()
		return (right * input_dir.x + forward * -input_dir.y).normalized()

	var player_basis: Basis = global_transform.basis
	var player_forward: Vector3 = -player_basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()
	var player_right: Vector3 = player_basis.x
	player_right.y = 0.0
	player_right = player_right.normalized()
	return (player_right * input_dir.x + player_forward * -input_dir.y).normalized()
