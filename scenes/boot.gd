extends Node
## Minimal bootstrap scene. App owns the real startup flow.

func _ready() -> void:
	App.boot()
