extends Inimigo
## Morcego: voa (atravessa água e obstáculos) em zigue-zague até o jogador,
## mas não se afasta demais do ninho.

@export var raio_ataque := 120.0
@export var raio_ninho := 180.0

var _ninho := Vector2.ZERO
var _tempo := 0.0


func _iniciar() -> void:
	_ninho = global_position
	_tempo = randf() * TAU


func _calcular_velocidade(delta: float) -> Vector2:
	_tempo += delta * 6.0
	var alvo := _ninho
	if jogador_valido() and _jogador.global_position.distance_to(_ninho) < raio_ninho \
			and global_position.distance_to(_jogador.global_position) < raio_ataque:
		alvo = _jogador.global_position
	if global_position.distance_to(alvo) < 4.0:
		return Vector2.ZERO
	var frente := global_position.direction_to(alvo)
	var lado := frente.orthogonal() * sin(_tempo) * 0.8  # zigue-zague
	return (frente + lado).normalized() * velocidade
