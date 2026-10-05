extends Label
## Texto que sobe e desaparece (ex.: "+10" ao pegar uma moeda).


func _ready() -> void:
	position -= size / 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(queue_free)
