extends RigidBody3D

@export var acceleration: float = 70.0
@export var air_control: float = 0.35
@export var max_speed: float = 10.0
@export var jump_impulse: float = 6.5

@onready var ground_ray: RayCast3D = $GroundRay
@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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

	if Input.is_action_pressed("wallrun") and not grounded:
		if wall_ray_left.is_colliding() or wall_ray_right.is_colliding():
			apply_central_force(Vector3.UP * acceleration * 0.2)

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
		return (right * input_dir.x + forward * input_dir.y).normalized()

	var player_basis: Basis = global_transform.basis
	var player_forward: Vector3 = -player_basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()
	var player_right: Vector3 = player_basis.x
	player_right.y = 0.0
	player_right = player_right.normalized()
	return (player_right * input_dir.x + player_forward * input_dir.y).normalized()
