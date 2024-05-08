extends Node3D

@onready var grid_map = $GridMap
@onready var players = $Players


var height_map: FastNoiseLite
var temperature_map: FastNoiseLite
var chunk_size = Vector2i(8, 8)
var spawn_chunk_size = Vector2i(10, 10)

@onready var mesh_library = grid_map.mesh_library
@onready var DIRT = mesh_library.find_item_by_name("Dirt")
@onready var GRASS = mesh_library.find_item_by_name("Grass")
@onready var DIRT_MOUNTAINS = mesh_library.find_item_by_name("DirtMountains")
@onready var GRASS_MOUNTAINS = mesh_library.find_item_by_name("GrassMountains")
@onready var DIRT_MOUNTAIN_TRANSITIONS = mesh_library.find_item_by_name("DirtMountainTransitions")
@onready var GRASS_MOUNTAIN_TRANSITIONS = mesh_library.find_item_by_name("GrassMountainTransitions")

@onready var biomes = {
	"Mountains": {"weight": 0.7, "height": 0.1, "height_remap": 30,
		"dirt": DIRT_MOUNTAINS, "grass": GRASS_MOUNTAINS},
	
	"MountainTransitions": {"weight": 0.7, "height": 0.0, "height_remap": 15,
		"dirt": DIRT_MOUNTAIN_TRANSITIONS, "grass": GRASS_MOUNTAIN_TRANSITIONS},
	
	"Plains": {"weight": 1, "height": -1, "height_remap": 5,
		"dirt": DIRT, "grass": GRASS},
}

@export var rng_seed = randi_range(1, 100)

var noise_height_multiplier = 15
var height_limit = 60

var last_chunk = Vector2i.ZERO

var rng = RandomNumberGenerator.new()

var map_loaded = false

#var load_chunks = false

func _ready():
	Globals.grid_map = grid_map
	Globals.block_cell_item = grid_map.mesh_library.find_item_by_name("Block")
	
	if multiplayer.is_server():
		rng.seed = rng_seed
	
		height_map = FastNoiseLite.new()
		height_map.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		height_map.frequency = 0.1
		height_map.seed = rng_seed
		
		temperature_map = FastNoiseLite.new()
		temperature_map.noise_type = FastNoiseLite.TYPE_VALUE
		temperature_map.frequency = 0.3
		temperature_map.seed = rng_seed
		
		load_world(rng_seed)

func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
	#if load_chunks:
		#var player_chunk = Vector2i(player.global_position.x, player.global_position.z).snapped(chunk_size) / chunk_size
		#if last_chunk != player_chunk:
			#var chunk_diff: Vector2 = player_chunk - last_chunk
			#var chunk_diff_abs = abs(chunk_diff)
			#for x in range(-(spawn_chunk_size.x + chunk_diff_abs.x), spawn_chunk_size.x + chunk_diff_abs.x):
				#for y in range(-(spawn_chunk_size.y + chunk_diff_abs.y), spawn_chunk_size.y + chunk_diff_abs.y):
					#if -spawn_chunk_size.x <= x and x < spawn_chunk_size.x and -spawn_chunk_size.y <= y and y < spawn_chunk_size.y:
						#if not check_chunk(Vector2i(player_chunk.x + x, player_chunk.y + y)):
							##print(Vector2i(player_chunk.x + x, player_chunk.y + y))
							##var start = Time.get_ticks_msec()
							#load_chunk(rng_seed, Vector2i(player_chunk.x + x, player_chunk.y + y))
							##print(Time.get_ticks_msec() - start)
					#else:
						#if check_chunk(Vector2i(player_chunk.x + x, player_chunk.y + y)):
							#unload_chunk(Vector2i(player_chunk.x + x, player_chunk.y + y))
			#last_chunk = player_chunk


func load_world(rng_seed: int):
	for x in range(-spawn_chunk_size.x, spawn_chunk_size.x):
		for y in range(-spawn_chunk_size.y, spawn_chunk_size.y):
			load_chunk(rng_seed, Vector2i(x, y))

func load_chunk(rng_seed, chunk_coords: Vector2i):
	var global_coords = Vector2i(4 + chunk_coords.x * chunk_size.x, 4 + chunk_coords.y * chunk_size.y)
	var biome_value = height_map.get_noise_2dv(global_coords)
	var possible_biomes = {}
	for biome_name in biomes:
		if biome_value >= biomes[biome_name]["height"]:
			possible_biomes[biome_name] = biomes[biome_name]["weight"]
	var biome = select_weighted(possible_biomes, temperature_map.get_noise_2dv(global_coords))
	if biome == "":
		biome = "Plains"
	
	for x in range(chunk_size.x):
		for y in range(chunk_size.y):
			global_coords = Vector2i(x + chunk_coords.x * chunk_size.x, y + chunk_coords.y * chunk_size.y)
			var noise_value = height_map.get_noise_2d(global_coords.x, global_coords.y)
			#var temp_value = temperature_map.get_noise_2d(global_coords.x, global_coords.y)
			var height = get_height(noise_value, biome)
			
			for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var noise_value_neighbor = height_map.get_noise_2d(x + dir.x + chunk_coords.x * chunk_size.x, y + dir.y + chunk_coords.y * chunk_size.y)
				var biome_neighbor = "Plains"
				for biome_name in biomes:
					if noise_value_neighbor >= biomes[biome_name]["height"]:
						biome_neighbor = biome_name
						break
				
				var neighbor_height = get_height(noise_value_neighbor, biome_neighbor)
				
				if biomes[biome_neighbor]["height"] > biomes[biome]["height"]:
					height += abs(noise_value * noise_height_multiplier)
					height = min(height, neighbor_height - 1)
				elif biomes[biome_neighbor]["height"] < biomes[biome]["height"]:
					height -= abs(noise_value * noise_height_multiplier)
					height = max(height, neighbor_height + 1)
			
			for z in range(height):
				grid_map.set_cell_item(Vector3i(global_coords.x, z, global_coords.y), biomes[biome]["dirt"], 0)
			grid_map.set_cell_item(Vector3i(global_coords.x, height, global_coords.y), biomes[biome]["grass"], 0)

func unload_chunk(chunk_coords: Vector2i):
	for x in range(chunk_size.x):
		for y in range(chunk_size.y):
			var global_coords = Vector2i(x + chunk_coords.x * chunk_size.x, y + chunk_coords.y * chunk_size.y)
			for z in range(height_limit):
				grid_map.set_cell_item(Vector3i(global_coords.x, z, global_coords.y), -1)

func check_chunk(chunk_coords: Vector2i):
	var result = grid_map.get_cell_item(Vector3i(chunk_coords.x * chunk_size.x + 4, 0, chunk_coords.y * chunk_size.y + 4))
	return result != -1

func get_height(noise_value, biome):
	return remap(noise_value, -1.0, 1.0, 1.0, biomes[biome]["height_remap"]) # + abs(noise_value * noise_height_multiplier)

func select_weighted(d, noise_value):
	var total = 0
	for key in d:
		total += d[key]

	var dice_roll = remap(noise_value * rng.randf(), -1, 1, 0, 1)
	var n_seen = 0
	for key in d:
		var accept_prob = float( 1.0 / ( total - n_seen ) )
		n_seen += d[key]
		if dice_roll <= accept_prob:
			return key
	
	return ""


func _on_synchronizer_synchronized():
	if not map_loaded and not multiplayer.is_server():
		rng.seed = rng_seed
	
		height_map = FastNoiseLite.new()
		height_map.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		height_map.frequency = 0.1
		height_map.seed = rng_seed
		
		temperature_map = FastNoiseLite.new()
		temperature_map.noise_type = FastNoiseLite.TYPE_VALUE
		temperature_map.frequency = 0.3
		temperature_map.seed = rng_seed
		
		load_world(rng_seed)
		
		map_loaded = true
