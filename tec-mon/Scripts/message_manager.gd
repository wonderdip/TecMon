extends CanvasLayer

@export_category("Components")
@export var box: NinePatchRect
@export var label: RichTextLabel
@export_category("Variables")
@export var is_scrolling: bool = false
@export var speed: int = 15
@export_multiline() var Messages: Array[String] = []

signal advanced

var _waiting_for_input: bool = false
var _closing: bool = false

func _ready() -> void:
	box.visible = false
	MessageBus.register(self)
	MessageBus.message_requested.connect(_on_message_requested)

func _unhandled_input(event: InputEvent) -> void:
	if not is_reading() or _closing:
		return
	if Input.is_action_just_pressed("interact"):
		get_viewport().set_input_as_handled()
		if is_scrolling:
			label.visible_characters = -1
		elif _waiting_for_input:
			_waiting_for_input = false
			advanced.emit()

func _on_message_requested(messages: Array[String]) -> void:
	play_text(messages)

func play_text(payload: Array[String]) -> void:
	if is_reading() or payload.is_empty():
		return
	Messages = payload
	scroll_text()

func scroll_text() -> void:
	box.visible = true

	while not Messages.is_empty():
		is_scrolling = true
		label.visible_characters = 0
		label.text = Messages[0]

		for i in Messages[0].length():
			if label.visible_characters == -1:
				break
			label.visible_characters = i + 1
			await get_tree().create_timer(1.0 / speed).timeout

		label.visible_characters = -1
		is_scrolling = false
		Messages.remove_at(0)

		# Wait for interact before next message or closing
		_waiting_for_input = true
		await advanced

	# Close with a brief cooldown
	_closing = true
	box.visible = false
	await get_tree().create_timer(0.1).timeout
	_closing = false

func is_reading() -> bool:
	return box.visible

func scrolling() -> bool:
	return is_scrolling

func get_messages() -> Array[String]:
	return Messages
