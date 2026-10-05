extends Inimigo
## Slime Bomba: corre até o jogador, pisca e explode, ferindo quem estiver perto
## (inclusive outros inimigos!). Se for derrotado antes, explode sem ferir o jogador.

const CENA_EXPLOSAO := preload("res://cenas/efeitos/efeito_morte.tscn")
const RAIO := 34.0

var _armando := false


func _calcular_velocidade(delta: float) -> Vector2:
	if not jogador_valido() or _armando:
		return Vector2.ZERO
	var distancia := distancia_jogador()
	if distancia < 24.0:
		_armar()
		return Vector2.ZERO
	if distancia > 170.0:
		return Vector2.ZERO
	return mover_para(_jogador.global_position, velocidade, delta)


func _armar() -> void:
	_armando = true
	animacao.play("piscar")
	Sons.tocar("alerta", -8.0, 0.0)
	await get_tree().create_timer(0.9, false).timeout
	if morto or not is_inside_tree():
		return
	_explodir(true)
	morrer()


func _ao_morrer() -> void:
	if not _armando:
		_explodir(false)


func _explodir(fere_jogador: bool) -> void:
	for i in 3:
		var efeito := CENA_EXPLOSAO.instantiate()
		efeito.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		efeito.color = Color("f77622") if i % 2 == 0 else Color("feae34")
		adicionar_ao_mundo(efeito)
	Sons.tocar("explosao", -4.0)
	if fere_jogador and jogador_valido() and distancia_jogador() <= RAIO:
		_jogador.levar_dano(global_position)
		_jogador.camera.tremer(4.0, 0.3)
	for outro in get_tree().get_nodes_in_group("inimigos"):
		if outro != self and is_instance_valid(outro) and not outro.morto \
				and outro.global_position.distance_to(global_position) <= RAIO:
			outro.receber_dano.call_deferred(3, global_position, true)
