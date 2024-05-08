extends CharacterBody3D

const MAX_SPEED = -7.0
const ACCELERATION = 5.0
const FRICTION = 1.0
const ROLL_SPEED = -deg_to_rad(22)
const ROLL_RESET_SPEED = deg_to_rad(10.0)
const PITCH_SPEED = deg_to_rad(22)
const ROLL_PITCH_SPEED = -deg_to_rad(10)
const YAW_SPEED = -deg_to_rad(20)

var plane_velocity = Vector3.ZERO

func _physics_process(delta):
	var throttle_input = Input.get_axis("brake", "accelerate")
	handle_acceleration(delta, throttle_input)
	apply_friction(delta)
	var roll_input = Input.get_axis("roll_left", "roll_right")
	handle_roll(delta, roll_input)
	var pitch_input = Input.get_axis("pitch_down", "pitch_up")
	handle_pitch(delta, pitch_input)
	var yaw_input = Input.get_axis("yaw_left", "yaw_right")
	handle_yaw(delta, yaw_input)
	apply_velocity()
	move_and_slide()

func handle_acceleration(delta, throttle_input):
	if throttle_input:
		plane_velocity.z = min(0, move_toward(plane_velocity.z, MAX_SPEED * throttle_input, ACCELERATION * delta))

func apply_friction(delta):
	plane_velocity.z = move_toward(plane_velocity.z, 0, FRICTION * delta)

func handle_roll(delta, roll_input):
	rotate(basis.z, roll_input * ROLL_SPEED * delta)
	var ref_rotation = global_transform.basis
	var current_rotation = Quaternion(ref_rotation)
	var target_rotation = Quaternion(Vector3.FORWARD, 0)
	transform.basis = Basis(current_rotation.slerp(target_rotation, min(ROLL_RESET_SPEED * delta, 1)))

func handle_pitch(delta, pitch_input):
	rotate(basis.x, pitch_input * PITCH_SPEED * delta)
	rotate(Vector3.DOWN, rotation.z * ROLL_PITCH_SPEED * delta)

func handle_yaw(delta, yaw_input):
	rotate(basis.y, yaw_input * YAW_SPEED * delta)

func apply_velocity():
	var ref_rotation = global_transform.basis.z
	var cross = Vector3.BACK.cross(ref_rotation).normalized()
	var angle = Vector3.BACK.angle_to(ref_rotation)
	if cross:
		velocity = plane_velocity.rotated(cross, angle)
	else:
		velocity = plane_velocity
