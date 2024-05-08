extends Node

@export var player_roles = {}

@onready var game_over: CenterContainer = $Menu/GameOver
@onready var start_again_button = $Menu/GameOver/VBoxContainer/StartAgainButton
@onready var menu = $Menu
@onready var start = $Menu/CenterContainer/Start

func _process(delta):
	if game_over.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			start_again_button.show()
		if not get_tree().paused:
			del_level()
			get_tree().paused = true
	else:
		if not start.visible and get_tree().paused and multiplayer.is_server():
			get_tree().paused = false
			player_roles = {}
			load_game.rpc()
			load_game()
			#await get_tree().create_timer(2.0).timeout
			#load_game()

@rpc("authority", "reliable", "call_remote")
func load_game(pressed_play_again=false):
	change_level(menu.LEVEL)
	get_tree().paused = false
	if multiplayer.is_server():
		for player_id in menu.player_ids:
			add_player(player_id.to_int(), pressed_play_again)
	game_over.hide()

# Call this function deferred and only on the main authority (server).
func change_level(scene: PackedScene):
	# Remove old level if any.
	var level = $World
	for c in level.get_children():
		level.remove_child(c)
		c.queue_free()
	# Add new level.
	level.add_child(scene.instantiate())
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func del_level():
	var level = $World
	for c in level.get_children():
		level.call_deferred("remove_child", c)
		c.call_deferred("queue_free")

func add_player(id: int, pressed_play_again=false):
	var character = preload("res://scenes/actors/player.tscn").instantiate()
	# Set player id.
	character.player = id
	#print(character.get_multiplayer_authority(), ", ", id)
	# Randomize character position.
	var pos = Vector3(randi_range(-20, 20), 60, randi_range(-20, 20))
	character.position = pos
	character.name = str(id)
	
	if pressed_play_again:
		Lobby.player_loaded.rpc()
	
	var players_node = get_node("World/Level/Players")
	if multiplayer.is_server():
		var has_cat = false
		for role in player_roles:
			if player_roles[role] == "cat":
				has_cat = true
		if has_cat:
			player_roles[str(id)] = "mouse"
		else:
			if players_node.get_child_count() >= 1:
				player_roles[str(id)] = "cat"
			else:
				player_roles[str(id)] = ["cat", "mouse"].pick_random()
		character.role = player_roles[str(id)]
	players_node.add_child(character, true)
	if id != 1:
		get_node("World/Level/Players/" + str(id)).SetPosition.rpc_id(id, pos)


func del_player(id: int):
	var players_node = get_node_or_null("World/Level/Players")
	if players_node:
		if not players_node.has_node(str(id)):
			return
		players_node.get_node(str(id)).queue_free()
	if str(id) in menu.player_ids:
		menu.player_ids.erase(str(id))

#func _enter_tree():
	## We only need to spawn players on the server.
	#if multiplayer.is_server():
#
		#multiplayer.peer_connected.connect(add_player)
		#multiplayer.peer_disconnected.connect(del_player)
#
		## Spawn already connected players.
		#for id in multiplayer.get_peers():
			#add_player(id)
#
		## Spawn the local player unless this is a dedicated server export.
		#if not OS.has_feature("dedicated_server"):
			#add_player(1)

func _exit_tree():
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.disconnect(add_player)
	multiplayer.peer_disconnected.disconnect(del_player)
