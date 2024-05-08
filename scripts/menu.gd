extends Control

@onready var username = $CenterContainer/Start/Name
@onready var start = $CenterContainer/Start
@onready var waiting_room = $CenterContainer/WaitingRoom
@onready var port_or_adress = $CenterContainer/Start/PortOrAdress
@onready var error_label = $CenterContainer/Start/ErrorLabel
@onready var game_over = $GameOver
@onready var start_again_button = $GameOver/VBoxContainer/StartAgainButton

const LEVEL = preload("res://scenes/level.tscn")

var player_ids = []

func _ready():
	get_tree().paused = true
	error_label.hide()
	game_over.hide()
	start_again_button.hide()

func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func game_finished():
	get_tree().paused = true
	player_ids = []
	for node in get_node("../World/Level/Players").get_children():
		player_ids.append(str(node.name))
	get_node("..").del_level()
	game_over.show()
	if multiplayer.is_server():
		start_again_button.show()

func _on_host_pressed():
	if username.text == "":
		error_label.show()
		error_label.text = "Need username!"
		return
	Lobby.player_info["name"] = username.text
	var error = Lobby.create_game()
	if error:
		error_label.show()
		if error == ERR_ALREADY_IN_USE:
			error_label.text = "ENetMultiplayerPeer instance already has an open connection."
		elif error == ERR_CANT_CREATE:
			error_label.text = "Could not create server."
		else:
			error_label.text = "Unidentified error occured."
		return
	#Lobby._register_player(username.text)
	start.hide()
	get_node("/root/Game").change_level(LEVEL)
	multiplayer.peer_connected.connect(get_node("..").add_player)
	multiplayer.peer_disconnected.connect(get_node("..").del_player)
	get_node("..").add_player(multiplayer.get_unique_id())
	get_tree().paused = false

func _on_join_pressed():
	if username.text == "":
		error_label.show()
		error_label.text = "Need username!"
		return
	Lobby.player_info["name"] = username.text
	#Lobby._register_player(username.text)
	var error = Lobby.join_game(port_or_adress.text)
	if error:
		error_label.show()
		if error == ERR_ALREADY_IN_USE:
			error_label.text = "ENetMultiplayerPeer instance already has an open connection."
		elif error == ERR_CANT_CREATE:
			error_label.text = "Coudn't create client."
		else:
			error_label.text = "Unidentified error occured."
		return
	start.hide()
	get_node("/root/Game").change_level(LEVEL)
	get_tree().paused = false


func _on_quit_button_pressed():
	get_tree().quit()


func _on_start_again_button_pressed():
	#get_node("/root/Game").change_level(LEVEL)
	#get_tree().paused = false
	game_over.hide()
	#await get_tree().create_timer(2).timeout
	#for player_id in player_ids:
		#get_node("..").add_player(player_id.to_int())
