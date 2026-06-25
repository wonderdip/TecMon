extends Node

signal message_requested(messages: Array[String])

var _message_box: Node

func register(box: Node) -> void:
	_message_box = box

func send(messages: Array[String]) -> void:
	message_requested.emit(messages)

func is_reading() -> bool:
	if _message_box == null:
		return false
	return _message_box.is_reading()
