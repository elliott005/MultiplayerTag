extends MultiplayerSynchronizer

@export var input_axis = Vector2.ZERO
@export var place_block_input = false
@export var jump_input = false
@export var sprint_input = false

func _enter_tree():
	# Only process for the local player.
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

func _process(delta):
	input_axis = Input.get_vector("move_forward", "move_backward", "move_left", "move_right")
	place_block_input = Input.is_action_just_pressed("place_block")
	jump_input = Input.is_action_just_pressed("jump")
	sprint_input = Input.is_action_pressed("sprint")
