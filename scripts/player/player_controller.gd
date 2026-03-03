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
@export var wallrun_grace_time: float = 0.2
@export_range(0.0, 1.0) var wallrun_gravity_factor: float = 0.35
@export_range(0.0, 1.0) var floor_threshold: float = 0.65
@export_range(0.0, 89.0) var floor_max_angle_degrees: float = 50.0

@onready var ground_ray: RayCast3D = $GroundRay
@onready var wall_ray_left: RayCast3D = $WallRayLeft
@onready var wall_ray_right: RayCast3D = $WallRayRight
@onready var camera_pivot: Node3D = $CameraPivot
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _pitch: float = 0.0
var _is_wallrunning: bool = false
var _wall_side: int = 0
var _wall_contact_timer: float = 0.0
var _platform_velocity: Vector3 = Vector3.ZERO
var _platform_prev_transform: Dictionary = {}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	contact_monitor = true
	max_contacts_reported = 8

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
	var move_dir: Vector3 = _get_move_direction(input_dir)
	var current_velocity: Vector3 = linear_velocity
	var horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	_platform_velocity = _get_ground_platform_velocity(delta)
	var grounded: bool = ground_ray.is_colliding() or _platform_velocity != Vector3.ZERO
	if not grounded:
		_platform_velocity = Vector3.ZERO

	var platform_horizontal_velocity: Vector3 = Vector3(_platform_velocity.x, 0.0, _platform_velocity.z)
	var target_horizontal_velocity: Vector3 = move_dir * max_speed + platform_horizontal_velocity
	var horizontal_velocity_error: Vector3 = target_horizontal_velocity - horizontal_velocity
	var control: float = 1.0 if grounded else air_control
	apply_central_force(horizontal_velocity_error * acceleration * control)

	if move_dir == Vector3.ZERO and grounded and platform_horizontal_velocity == Vector3.ZERO:
		apply_central_force(-horizontal_velocity * acceleration * 0.15)

	if Input.is_action_just_pressed("jump") and grounded:
		apply_central_impulse(Vector3.UP * jump_impulse)

	_handle_wallrun(delta, grounded, move_dir)
	_apply_wallrun_lean(delta)

func _get_ground_platform_velocity(delta: float) -> Vector3:
	var gravity_vector: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var up_dir: Vector3 = -gravity_vector.normalized()
	var min_floor_dot: float = max(floor_threshold, cos(deg_to_rad(floor_max_angle_degrees)))
	var best_floor_dot: float = -1.0
	var floor_velocity: Vector3 = Vector3.ZERO

	for i in get_contact_count():
		var collider: Object = get_contact_collider_object(i)
		if collider == null:
			continue

		var local_normal: Vector3 = get_contact_local_normal(i)
		if local_normal == Vector3.ZERO:
			continue

		var world_normal: Vector3 = (global_transform.basis * local_normal).normalized()
		var floor_dot: float = world_normal.dot(up_dir)
		if floor_dot <= min_floor_dot:
			continue

		if floor_dot > best_floor_dot:
			best_floor_dot = floor_dot
			floor_velocity = _get_collider_velocity(collider, delta)

	return floor_velocity

func _get_collider_velocity(collider: Object, delta: float) -> Vector3:
	if collider is RigidBody3D:
		return (collider as RigidBody3D).linear_velocity

	if collider is AnimatableBody3D or collider is CharacterBody3D:
		if collider.has_method("get_platform_velocity"):
			return collider.call("get_platform_velocity")

		if collider is Node:
			var collider_node: Node = collider as Node
			var tracker: Node = collider_node.get_node_or_null("PlatformVelocityTracker")
			if tracker and tracker.has_method("get_velocity"):
				return tracker.call("get_velocity")

		if collider is Node3D:
			var body: Node3D = collider as Node3D
			var id: int = body.get_instance_id()
			if _platform_prev_transform.has(id):
				var prev_transform: Transform3D = _platform_prev_transform[id]
				var velocity: Vector3 = (body.global_transform.origin - prev_transform.origin) / max(delta, 0.0001)
				_platform_prev_transform[id] = body.global_transform
				return velocity
			_platform_prev_transform[id] = body.global_transform

	return Vector3.ZERO

func _handle_wallrun(delta: float, grounded: bool, move_dir: Vector3) -> void:
	var touching_left: bool = wall_ray_left.is_colliding()
	var touching_right: bool = wall_ray_right.is_colliding()
	var touching_wall: bool = touching_left or touching_right
	var can_attempt_wallrun: bool = not grounded and move_dir != Vector3.ZERO

	if touching_wall:
		_wall_contact_timer = wallrun_grace_time
		_wall_side = -1 if touching_left else 1
	elif _wall_contact_timer > 0.0:
		_wall_contact_timer = max(_wall_contact_timer - delta, 0.0)

	var can_wallrun: bool = can_attempt_wallrun and _wall_contact_timer > 0.0

	if can_wallrun:
		var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		var anti_gravity_force: float = mass * gravity * (1.0 - wallrun_gravity_factor)
		apply_central_force(Vector3.UP * (wallrun_lift_force + anti_gravity_force))
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
