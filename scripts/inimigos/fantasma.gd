extends Inimigo
## Fantasma: atravessa paredes e água. Fica quase invisível de longe e aparece
## quando chega perto do jogador.


func _calcular_velocidade(_delta: float) -> Vector2:
	if not jogador_valido():
		return Vector2.ZERO
	var distancia := distancia_jogador()
	# transparência: 0.2 de longe, quase opaco de perto
	animacao.modulate.a = clampf(1.2 - distancia / 100.0, 0.2, 0.9)
	if distancia > 200.0:
		return Vector2.ZERO
	var ondulacao := Vector2(0, sin(Time.get_ticks_msec() / 250.0) * 12.0)
	return global_position.direction_to(_jogador.global_position) * velocidade + ondulacao
