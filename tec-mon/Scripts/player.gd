extends CharacterBody2D
class_name Player

@export var tile_collision_layers: Array[int] = []

@export_category("Nodes")
@export var animation_tree: AnimationTree

@export_category("Movement")
@export var walk_speed: float = 64.0
@export var run_speed: float = 128.0
@export var is_walking: bool = false
var is_running: bool = false

@export_category("Jumping")
@export var jump_height: float = 10.0
@export var jump_height_multiplier: float = 4.0
@export var jump_tile_y: float = 1.0
@export var jump_speed: float = 2.0
@export var jump_running_speed: float = 4.0
@export var progress: float = 0.0
@export var is_jumping: bool = false

@onready var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

enum CharacterMovement { WALKING, JUMPING }

const TILE_SIZE: float = 16.0

var character_action: CharacterMovement = CharacterMovement.WALKING
var start_position: Vector2
var target_position: Vector2
var move_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var direction_keys: Array = []
var movement_blocked: bool = false
var current_move_speed: float = walk_speed

var tecmon_party: Array[TecmonInstance]
var inventory: Inventory = Inventory.new()

func _ready() -> void:
	target_position = global_position.snapped(Vector2.ONE * TILE_SIZE)
	global_position = target_position
	Global.register_player(self)
	Global.block_movement.connect(_on_movement_blocked)

func _unhandled_input(_event: InputEvent) -> void:
	if MessageBus.is_reading():
		return
	if Input.is_action_just_pressed("interact"):
		_check_interaction()

func _physics_process(delta: float) -> void:
	process_input_stack()
	
	if is_moving():
		walk(delta)
		jump(delta)
	else:
		read_input()
		
	update_animation()

func _on_movement_blocked(blocked: bool) -> void:
	movement_blocked = blocked
	print(movement_blocked)

## Getter for checking player motion
func is_moving() -> bool:
	return is_walking or is_jumping

## Stacks multiple inputs for smoother movement
func process_input_stack() -> void:
	if Input.is_action_just_pressed("right"): direction_keys.push_back("right")
	elif Input.is_action_just_released("right"): direction_keys.erase("right")
	if Input.is_action_just_pressed("left"): direction_keys.push_back("left")
	elif Input.is_action_just_released("left"): direction_keys.erase("left")
	if Input.is_action_just_pressed("down"): direction_keys.push_back("down")
	elif Input.is_action_just_released("down"): direction_keys.erase("down")
	if Input.is_action_just_pressed("up"): direction_keys.push_back("up")
	elif Input.is_action_just_released("up"): direction_keys.erase("up")

	if (not Input.is_action_pressed("right") and not Input.is_action_pressed("left")
			and not Input.is_action_pressed("down") and not Input.is_action_pressed("up")):
		direction_keys.clear()

## Reads the input from the stack and applies motion
func read_input() -> void:
	if direction_keys.is_empty() or MessageBus.is_reading() or movement_blocked:
		return
	
	var key: String = direction_keys.back()
	if not Input.is_action_pressed(key):
		return

	var input_direction := Vector2.ZERO
	match key:
		"right": input_direction = Vector2.RIGHT
		"left": input_direction = Vector2.LEFT
		"down": input_direction = Vector2.DOWN
		"up": input_direction = Vector2.UP

	if input_direction == Vector2.ZERO:
		return

	move_direction = input_direction
	last_direction = move_direction
	start_moving()

func start_moving() -> void:
	var desired_target: Vector2 = global_position + move_direction * TILE_SIZE
	if is_target_occupied(desired_target):
		return
	target_position = desired_target
	current_move_speed = run_speed if Input.is_action_pressed("run") else walk_speed
	is_running = current_move_speed == run_speed
	
	if character_action == CharacterMovement.JUMPING:
		progress = 0.0
		start_position = global_position
		target_position = global_position + move_direction * (TILE_SIZE * 2.0)
		is_jumping = true
		AudioManager.play_sfx("jump")
	else:
		is_walking = true

func walk(delta: float) -> void:
	if not is_walking:
		return
	var dir_to_target := target_position - global_position
	var dist_this_frame := current_move_speed * delta

	if dir_to_target.length() <= dist_this_frame:
		global_position = target_position
		velocity = Vector2.ZERO
		stop_moving()
	else:
		velocity = dir_to_target.normalized() * current_move_speed
		move_and_slide()

func jump(delta: float) -> void:
	if not is_jumping:
		return
	
	var move_speed: float = jump_speed
	if Input.is_action_pressed("run"):
		move_speed = jump_running_speed
		
	progress += move_speed * delta
		
	var pos: Vector2 = start_position.lerp(target_position, progress)
	var arc_offset: float = jump_height * (jump_tile_y - jump_height_multiplier * (progress - 0.5) * (progress - 0.5))
	pos.y -= arc_offset
	global_position = pos

	if progress >= 1.0:
		stop_moving()

func stop_moving() -> void:
	is_walking = false
	is_jumping = false
	character_action = CharacterMovement.WALKING
	snap_position_to_grid()

	## If the player is still holding a direction, immediately queue the next
	## tile instead of dropping to Idle for a frame.
	if not direction_keys.is_empty() and not movement_blocked and not MessageBus.is_reading():
		read_input()

func snap_position_to_grid() -> void:
	global_position = Vector2(
		roundf(global_position.x / TILE_SIZE) * TILE_SIZE,
		roundf(global_position.y / TILE_SIZE) * TILE_SIZE
	)

## Checks if the tile next to the Player has an interactable object
func _check_interaction() -> void:
	# raycast one tile ahead in last_direction
	var query: PhysicsPointQueryParameters2D = create_query(global_position + move_direction * TILE_SIZE, [2])
	var results := get_world_2d().direct_space_state.intersect_point(query)
	
	for result in results:
		var collider := result["collider"] as Node
		if collider and collider.has_method("interact"):
			collider.interact()
			break

## Returns true when the tile at the target_position blocks movement. (Has a collision layer)
func is_target_occupied(target_pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = create_query(target_pos, tile_collision_layers)
	var results: Array = space_state.intersect_point(query)

	if results.is_empty():
		return false

	if results.size() == 1:
		var collider: Node = results[0]["collider"]
		if collider == null:
			return true
			
		match collider.get_class():
			"TileMapLayer":
					return _get_tile_map_collision(collider as TileMapLayer, query.position)
			_:
				return true

	# More than one collider means always blocked.
	return true

## Creates a PhysicsQuery for tile checking
func create_query(target_pos: Vector2, collision_layers: Array[int]) -> PhysicsPointQueryParameters2D:
	# Offset (+8, +8 for centre-of-tile checks).
	var query_pos := target_pos + Vector2(8.0, 8.0)
	var query := PhysicsPointQueryParameters2D.new()
	query.position = query_pos
	query.collision_mask = layers(collision_layers)
	query.collide_with_areas = true
	
	return query
	
## Gets the bit value for a layer or multiple because physics layers are coded with binary
func layers(layer_numbers: Array[int]) -> int:
	var mask := 0
	for n in layer_numbers:
		mask |= (1 << (n - 1))
	return mask
	
## Checks if the ledge custom data is on a TileMapLayer.
## Returns false (passable) when a matching ledge jump is initiated.
func _get_tile_map_collision(tile_map: TileMapLayer, query_pos: Vector2) -> bool:
	var tile_coords: Vector2i = tile_map.local_to_map(query_pos)
	var tile_data: TileData = tile_map.get_cell_tile_data(tile_coords)

	#checks for the custome data
	if tile_data == null or !tile_data.has_custom_data("LEDGE"):
		return true
	
	var ledge_dir: String = str(tile_data.get_custom_data("LEDGE"))

	# Trigger a jump when the player walks into the ledge in its facing direction.
	var facing_matches := false
	match ledge_dir:
		"DOWN": facing_matches = (move_direction == Vector2.DOWN)
		"LEFT": facing_matches = (move_direction == Vector2.LEFT)
		"RIGHT": facing_matches = (move_direction == Vector2.RIGHT)

	if facing_matches:
		character_action = CharacterMovement.JUMPING
		return false # passable – jump will handle movement
		
	return true # blocked from other directions

func update_animation() -> void:
	animation_tree.set("parameters/Idle/blend_position", last_direction)
	animation_tree.set("parameters/Walking/blend_position", last_direction)
	animation_tree.set("parameters/Running/blend_position", last_direction)

	var moving := is_moving()
	animation_tree.set("parameters/conditions/Idle", not moving)
	animation_tree.set("parameters/conditions/Walking", moving and not is_running)
	animation_tree.set("parameters/conditions/Running", moving and is_running)
