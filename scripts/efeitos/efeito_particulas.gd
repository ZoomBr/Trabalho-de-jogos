extends CPUParticles2D
## Efeito de partículas de uso único: dispara e se apaga sozinho ao terminar.


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
