extends "res://scripts/inimigos/slime_perseguidor.gd"
## Slime Gigante: lento e resistente. Quando morre, se divide em dois slimes roxos.

const CENA_FILHOTE := preload("res://cenas/inimigos/slime_perseguidor.tscn")


func _ao_morrer() -> void:
	for i in 2:
		var filhote := CENA_FILHOTE.instantiate()
		filhote.global_position = global_position + Vector2(-8 + 16 * i, 0)
		filhote.raio_visao = 300.0
		gerou.emit(filhote)
