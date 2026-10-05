extends Inimigo
## Esqueleto arqueiro: procura uma posição com visão do jogador, mira (pisca em
## vermelho) e atira uma flecha. Se o jogador chega perto, recua; com pouca vida, foge.

const CENA_FLECHA := preload("res://cenas/objetos/flecha_inimiga.tscn")

@export var alcance := 140.0
@export var distancia_minima := 55.0
@export var intervalo_tiro := 2.0

var _recarga := 1.2
var _mirando := false


func _calcular_velocidade(delta: float) -> Vector2:
	if not jogador_valido() or _mirando:
		return Vector2.ZERO
	var distancia := distancia_jogador()
	if distancia > alcance + 40.0:
		return Vector2.ZERO
	var fugir := distancia < distancia_minima or vida == 1
	if fugir:
		return _jogador.global_position.direction_to(global_position) * velocidade
	var enxerga := tem_visao(_jogador.global_position)
	if not enxerga or distancia > alcance:
		return mover_para(_jogador.global_position, velocidade, delta)
	_recarga -= delta
	if _recarga <= 0.0:
		_recarga = intervalo_tiro
		_atirar()
	return Vector2.ZERO


func _atirar() -> void:
	_mirando = true
	avisar(0.5)
	await get_tree().create_timer(0.5, false).timeout
	if morto or not is_inside_tree() or not jogador_valido():
		_mirando = false
		return
	var flecha := CENA_FLECHA.instantiate()
	flecha.global_position = global_position
	flecha.direcao = global_position.direction_to(_jogador.global_position)
	adicionar_ao_mundo(flecha)
	Sons.tocar("tiro", -8.0, 0.3)
	_mirando = false
