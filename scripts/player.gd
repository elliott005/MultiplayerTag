extends CharacterBody3D

@export var player := 1 :
	set(id):
		player = id

@onready var camera_3d = $Camera3D
@onready var jump_timer = $JumpTimer
@onready var block_ray_cast = $Camera3D/BlockRayCast
@onready var jump_boost_timer = $JumpBoostTimer
@onready var name_label = $NameLabel
@onready var role_label = %RoleLabel
@onready var hurt_box = $HurtBox
@onready var wall_run_timer = $WallRunTimer
@onready var wall_ray_cast_left = $WallRayCastLeft
@onready var wall_ray_cast_right = $WallRayCastRight
@onready var wall_sep_left = $WallSepLeft
@onready var wall_sep_right = $WallSepRight
@onready var block_place_cooldown = $BlockPlaceCooldown


const FORWARD_SPEED = 7.0
const SIDE_SPEED = FORWARD_SPEED
const SPRINT_SPEED = 9.0
const ACCELERATION = 10.0
const FRICTION = 50.0
const JUMP_STR = 4.5
const GRAVITY_MAX = -10.0
const GRAVITY_ACCELERATION = 1.0
const CAMERA_SPEED = 15.0
const JUMP_BOOST_SPEED = 1.0

var twist_input = 0.0
var pitch_input = 0.0
var camera_pitch_limit = deg_to_rad(90)

var in_free_cam = false
var camera_start_position: Vector3
var free_cam_pitch_limit = deg_to_rad(90)

var last_wall_normal = Vector3.ZERO

var role

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	#print(get_node("../../../../RolesSynchronizer"))
	if not multiplayer.is_server():
		get_node("../../../../MenuRolesSynchronizer").synchronized.connect(update_role)
	camera_start_position = camera_3d.position
	camera_3d.current = true
	name_label.text = Lobby.player_info["name"]
	#Lobby.player_loaded()


func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	if role:
		role_label.text = "role: " + role
	
	if Input.is_action_just_pressed("free_cam"):
		in_free_cam = not in_free_cam
	
	var input_axis = Input.get_vector("move_forward", "move_backward", "move_left", "move_right")
	
	if not in_free_cam:
		var place_block_input = Input.is_action_just_pressed("place_block")
		var break_block_input = Input.is_action_just_pressed("break_block")
		var jump_input = Input.is_action_just_pressed("jump")
	
		handle_place_block(place_block_input)
		handle_break_block(break_block_input)
		
		handle_wall_run()
		
		apply_gravity(delta)
		velocity = velocity.rotated(Vector3.UP, -global_rotation.y)
		handle_acceleration(delta, input_axis)
		apply_friction(delta, input_axis)
		handle_jump(jump_input)
		velocity = velocity.rotated(Vector3.UP, global_rotation.y)
		move_and_slide()
	else:
		handle_free_cam_movement(delta, input_axis)
	
	handle_camera_movement()

func handle_place_block(input):
	if input and block_place_cooldown.time_left <= 0.0:
		if block_ray_cast.is_colliding():
			var pos = block_ray_cast.get_collision_point().floor()
			if position.distance_to(pos) > 1.7 	and pos.y < 40:
				block_place_cooldown.start()
				pos += block_ray_cast.get_collision_normal() / 2
				Globals.grid_map.set_cell_item(pos.floor(), Globals.block_cell_item)

func handle_break_block(input):
	if input:
		if block_ray_cast.is_colliding():
			var pos = block_ray_cast.get_collision_point().floor()
			pos -= block_ray_cast.get_collision_normal() / 2
			if Globals.grid_map.get_cell_item(pos.floor()) == Globals.block_cell_item:
				Globals.grid_map.set_cell_item(pos.floor(), -1)

func handle_wall_run():
	if is_on_floor():
		last_wall_normal = Vector3.ZERO
		wall_run_timer.stop()
	if wall_run_timer.time_left <= 0.0 and not is_on_floor():
		if wall_ray_cast_right.is_colliding():
			if wall_ray_cast_right.get_collision_normal() != last_wall_normal:
				wall_run_timer.start()
				last_wall_normal = wall_ray_cast_right.get_collision_normal()
		elif wall_ray_cast_left.is_colliding():
			if wall_ray_cast_left.get_collision_normal() != last_wall_normal:
				wall_run_timer.start()
				last_wall_normal = wall_ray_cast_left.get_collision_normal()
	
	if not (wall_ray_cast_left.is_colliding() or wall_ray_cast_right.is_colliding()):
		wall_run_timer.stop()
	
	if not is_on_floor() and wall_ray_cast_left.is_colliding():
		wall_sep_left.disabled = false
	else:
		wall_sep_left.disabled = true
	if not is_on_floor() and wall_ray_cast_right.is_colliding():
		wall_sep_right.disabled = false
	else:
		wall_sep_right.disabled = true

func apply_gravity(delta):
	if not is_on_floor():
		if jump_timer.time_left <= 0.0:
			if wall_run_timer.time_left > 0.0:
				velocity.y = move_toward(velocity.y, 0, GRAVITY_ACCELERATION)
			else:
				velocity.y = move_toward(velocity.y, GRAVITY_MAX, GRAVITY_ACCELERATION)
	else:
		velocity.y = 0.0

func handle_jump(jump_input):
	if jump_input:
		if is_on_floor() or wall_run_timer.time_left > 0.0:
			wall_run_timer.stop()
			jump_boost_timer.start()
			jump_timer.start()
			velocity.y = JUMP_STR

func handle_acceleration(delta, input_axis):
	var speed_boost = 0
	var speed = FORWARD_SPEED
	var side_speed = SIDE_SPEED
	var sprint_input = Input.is_action_pressed("sprint")
	if jump_boost_timer.time_left > 0.0:
		speed_boost = JUMP_BOOST_SPEED
	if sprint_input:
		speed = SPRINT_SPEED
		side_speed = SPRINT_SPEED
	if input_axis.x:
		if sign(input_axis.x) == sign(velocity.z) or velocity.z == 0.0:
			velocity.z = move_toward(velocity.z, (speed + speed_boost) * input_axis.x, (ACCELERATION + speed_boost) * delta)
		else:
			velocity.z = move_toward(velocity.z, (speed + speed_boost) * input_axis.x, (FRICTION + ACCELERATION + speed_boost) * delta)
	if input_axis.y:
		if sign(input_axis.y) == sign(velocity.x) or velocity.x == 0.0:
			velocity.x = move_toward(velocity.x, (side_speed + speed_boost) * input_axis.y, (ACCELERATION + speed_boost) * delta)
		else:
			velocity.x = move_toward(velocity.x, (side_speed + speed_boost) * input_axis.y, (FRICTION + ACCELERATION + speed_boost) * delta)
	

func apply_friction(delta, input_axis):
	if not input_axis.x:
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
	if not input_axis.y:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func handle_free_cam_movement(delta, input_axis):
	if input_axis.x:
		var camera_velocity = Vector3.ZERO
		camera_velocity.z = CAMERA_SPEED * -input_axis.x * delta
		var ref_rotation = camera_3d.global_transform.basis.z
		var cross = Vector3.FORWARD.cross(ref_rotation).normalized()
		var angle = Vector3.FORWARD.angle_to(ref_rotation)
		if cross:
			var rotated = camera_velocity.rotated(cross, angle)
			camera_3d.global_position += rotated
		else:
			camera_3d.global_position += camera_velocity
	if input_axis.y:
		camera_3d.global_position += Vector3(input_axis.y, 0, 0).rotated(Vector3.UP, camera_3d.global_rotation.y) * CAMERA_SPEED * delta

func handle_camera_movement():
	if not in_free_cam:
		rotate_y(twist_input)
		camera_3d.rotation.y = 0.0
		camera_3d.position = camera_start_position
		camera_3d.rotate_x(pitch_input)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, -camera_pitch_limit, camera_pitch_limit)
	else:
		camera_3d.rotate_y(twist_input)
		camera_3d.rotate_object_local(Vector3.RIGHT, pitch_input)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, -free_cam_pitch_limit, free_cam_pitch_limit)
	twist_input = 0.0
	pitch_input = 0.0

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		twist_input = -event.relative.x * Globals.settings["mouse_sensitivity"]
		pitch_input = -event.relative.y *  Globals.settings["mouse_sensitivity"]

@rpc("any_peer", "call_remote", "reliable")
func SetPosition(pos):
	position = pos
	hurt_box.position = pos


func update_role():
	role = get_node("../../../..").player_roles[str(name)]
	role_label.text = "role: " + role

func _on_hurt_box_area_entered(area):
	var opponent_role = get_node("../../../..").player_roles[str(area.get_parent().name)]
	#print(opponent_role, ", ", role)
	if role == "mouse" and opponent_role == "cat":
		get_node("../../../../Menu").game_finished()
