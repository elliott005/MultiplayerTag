extends MultiplayerSpawner

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
#
#func _exit_tree():
	#if not multiplayer.is_server():
		#return
	#multiplayer.peer_connected.disconnect(add_player)
	#multiplayer.peer_disconnected.disconnect(del_player)
