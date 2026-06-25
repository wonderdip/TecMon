extends StaticBody2D

func interact() -> void:
	MessageBus.send(["You Have Opened a Common Chest", "You Have found a potion of healing"])
