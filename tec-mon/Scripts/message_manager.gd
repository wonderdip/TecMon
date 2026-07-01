extends CanvasLayer

@export_category("Components")
@export var box: NinePatchRect
@export var label: RichTextLabel

@export_category("Variables")
@export var cursor_frames: Array[Texture2D] = []
@export var cursor_fps: float = 6.0
@export var battle_timer: float = 0.5
@export var normal_timer: float = 2

@export var is_scrolling: bool = false
@export_multiline() var Messages: Array[String] = []

@onready var container: Control = $Container
@onready var message_timer: Timer = $MessageTimer

signal advanced

var _waiting_for_input: bool = false
var _closing: bool = false
var normal_position: Vector2
var normal_size: Vector2
var battle_mode: bool = false
var _passive: bool = false  ## True when showing text that doesn't wait for input.
var timer_done
var _cursor_frame_index: int = 0
var _cursor_anim_timer: Timer

func _ready() -> void:
	visible = false
	normal_position = box.position
	normal_size = box.size
	process_mode = Node.PROCESS_MODE_DISABLED
	box.visible = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	MessageBus.register(self)
	MessageBus.message_requested.connect(_on_message_requested)
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	message_timer.timeout.connect(_on_timer_timeout)
	
	_cursor_anim_timer = Timer.new()
	_cursor_anim_timer.wait_time = 1.0 / cursor_fps
	_cursor_anim_timer.timeout.connect(_advance_cursor_frame)
	add_child(_cursor_anim_timer)
	
func _on_timer_timeout(): 
	if _waiting_for_input:
		_waiting_for_input = false
		AudioManager.play_sfx("select")
		advanced.emit()
			
func _on_battle_started() -> void:
	battle_mode = true
	switch_mode()

func _on_battle_ended(outcome: BattleSystem.BattleOutcome) -> void:
	## Clear any passive prompt before showing the result message.
	if _passive:
		_clear_passive()
	
func switch_mode() -> void:
	if battle_mode:
		box.position = Vector2(0, 112)
		box.size = Vector2(208, 48)
	else:
		box.position = normal_position
		box.size = normal_size

func show_passive(text: String, speed: int = 30) -> void:
	## If a real message is mid-play, don't interrupt it.
	if is_reading() and not _passive:
		return
	_passive = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	box.visible = true
	label.text = text
	label.visible_characters = -1

func _clear_passive() -> void:
	_passive = false
	box.visible = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	## Passive mode: box is visible but we deliberately ignore input here.
	if _passive or _closing:
		return
	if not is_reading():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("select")
		if is_scrolling:
			label.visible_characters = -1
		elif _waiting_for_input:
			_waiting_for_input = false
			advanced.emit()

func _on_message_requested(messages: Array[String], speed: int) -> void:
	play_text(messages, speed)

func play_text(payload: Array[String], speed: int) -> void:
	## If passive text is showing, clear it first so we can take over the box.
	if _passive:
		_clear_passive()
	if is_reading() or payload.is_empty():
		return
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	Messages = payload
	box.visible = true

	while not Messages.is_empty():
		is_scrolling = true
		label.visible_characters = 0
		label.text = Messages[0]
		for i in Messages[0].length():
			if label.visible_characters == -1:
				break
			label.visible_characters = i + 1
			AudioManager.play_sfx("dialog", -15, 1)
			await get_tree().create_timer(1.0 / speed).timeout
		
		show_cursor()
		label.visible_characters = -1
		is_scrolling = false
		Messages.remove_at(0)
		_waiting_for_input = true
		if battle_mode:
			message_timer.start(battle_timer)
		else:
			message_timer.start(normal_timer)
		await advanced

	_closing = true
	box.visible = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.1).timeout
	_closing = false
	MessageBus.notify_closed()
	
func show_cursor() -> void:
	label.visible_characters = -1
	_cursor_frame_index = 0
	_append_cursor_frame()
	_cursor_anim_timer.start()

func _advance_cursor_frame() -> void:
	if not _waiting_for_input:
		_cursor_anim_timer.stop()
		return
	_cursor_frame_index = (_cursor_frame_index + 1) % cursor_frames.size()
	_strip_last_cursor_tag()
	_append_cursor_frame()

func _append_cursor_frame() -> void:
	var tex := cursor_frames[_cursor_frame_index]
	label.text += "[img=" + str(tex.get_width()) + "x" + str(tex.get_height()) + "]" + tex.resource_path + "[/img]"

func _strip_last_cursor_tag() -> void:
	var idx := label.text.rfind("[img=")
	if idx != -1:
		label.text = label.text.substr(0, idx)
	
func is_reading() -> bool:
	## Passive counts as "showing" but not as "reading" for input purposes.
	## BattleSystem's _say() checks MessageBus.message_box_closed, not is_reading.
	return visible and box.visible and not _passive

func scrolling() -> bool:
	return is_scrolling

func get_messages() -> Array[String]:
	return Messages
