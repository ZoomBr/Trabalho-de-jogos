extends Inimigo
## Slime roxo: vagueia até ver o jogador e então persegue, desviando dos
## obstáculos (A*). Vários slimes "cercam" o jogador, cada um mirando um lado.
## Com pouca vida, foge por um tempo.

@export var raio_visao := 110.0
@export var raio_desistir := 180.0

var _perseguindo := false
var _direcao_vagar := Vector2.ZERO
var _tempo_vagar := 0.0
var _angulo_cerco := 0.0
var _tempo_fuga := 0.0


func _iniciar() -> void:
	_angulo_cerco = randf() * TAU


func _calcular_velocidade(delta: float) -> Vector2:
	if not jogador_valido():
		return Vector2.ZERO
	var distancia := distancia_jogador()
	if distancia < raio_visao:
		_perseguindo = true
	elif distancia > raio_desistir:
		_perseguindo = false
	# foge quando está quase morrendo (só uma vez)
	if vida == 1 and vida_maxima >= 3 and _tempo_fuga == 0.0:
		_tempo_fuga = 1.5
	if _tempo_fuga > 0.0:
		_tempo_fuga = maxf(_tempo_fuga - delta, -1.0)
		return _jogador.global_position.direction_to(global_position) * velocidade * 1.1
	if _perseguindo:
		# cerco: de longe, mira um ponto ao redor do jogador; de perto, vai direto
		var alvo := _jogador.global_position
		if distancia > 40.0:
			alvo += Vector2.from_angle(_angulo_cerco) * 24.0
		return mover_para(alvo, velocidade, delta)
	_tempo_vagar -= delta
	if _tempo_vagar <= 0.0:
		_tempo_vagar = randf_range(1.0, 2.5)
		_direcao_vagar = Vector2.from_angle(randf() * TAU) if randf() > 0.35 else Vector2.ZERO
	return _direcao_vagar * velocidade * 0.35
