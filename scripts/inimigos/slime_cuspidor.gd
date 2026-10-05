extends Inimigo
## Slime azul: mantém distância e, quando enxerga o jogador, incha (aviso) e
## cospe uma gosma na direção dele.

const CENA_GOSMA := preload("res://cenas/objetos/projetil_inimigo.tscn")

@export var alcance := 130.0
@export var distancia_preferida := 70.0
@export var intervalo_tiro := 2.2

var _recarga := 1.0
var _mirando := false


func _calcular_velocidade(delta: float) -> Vector2:
	if not jogador_valido() or _mirando:
		return Vector2.ZERO
	var distancia := distancia_jogador()
	if distancia > alcance:
		return Vector2.ZERO
	var enxerga := tem_visao(_jogador.global_position)
	_recarga -= delta
	if _recarga <= 0.0 and enxerga:
		_recarga = intervalo_tiro
		_cuspir()
	if distancia < distancia_preferida:
		return _jogador.global_position.direction_to(global_position) * velocidade
	if not enxerga:
		return mover_para(_jogador.global_position, velocidade, delta)
	return Vector2.ZERO


func _cuspir() -> void:
	_mirando = true
	# aviso: incha antes de cuspir
	var t := create_tween()
	t.tween_property(animacao, "scale", Vector2(1.35, 0.75), 0.4)
	await t.finished
	if morto or not is_inside_tree() or not jogador_valido():
		_mirando = false
		return
	animacao.scale = Vector2.ONE
	var gosma := CENA_GOSMA.instantiate()
	gosma.global_position = global_position
	gosma.direcao = global_position.direction_to(_jogador.global_position)
	adicionar_ao_mundo(gosma)
	Sons.tocar("chefe_tiro", -10.0, 0.2)
	_mirando = false
