extends Inimigo
## Golem Escudeiro: lento e com escudo na frente. Golpes vindos da frente são
## bloqueados (só o Giro da Espada quebra o escudo). Quando fica alinhado com o
## jogador, avisa e faz uma investida. Dica: use a esquiva para pegá-lo por trás!

@export var velocidade_investida := 170.0

var _frente := Vector2.RIGHT
var _estado := "andar"
var _tempo := 0.0


func _calcular_velocidade(delta: float) -> Vector2:
	if not jogador_valido():
		return Vector2.ZERO
	_tempo -= delta
	match _estado:
		"andar":
			_frente = global_position.direction_to(_jogador.global_position)
			var distancia := distancia_jogador()
			if distancia < 100.0 and distancia > 24.0 and _tempo <= 0.0 and tem_visao(_jogador.global_position):
				_estado = "aviso"
				_tempo = 0.6
				avisar(0.6)
				return Vector2.ZERO
			if distancia > 180.0:
				return Vector2.ZERO
			return mover_para(_jogador.global_position, velocidade, delta)
		"aviso":
			if _tempo <= 0.0:
				_estado = "investida"
				_tempo = 0.55
				_frente = global_position.direction_to(_jogador.global_position)
			return Vector2.ZERO
		"investida":
			if _tempo <= 0.0 or is_on_wall():
				_estado = "andar"
				_tempo = 1.5
			return _frente * velocidade_investida
	return Vector2.ZERO


func _depois_de_mover() -> void:
	animacao.flip_h = _frente.x < 0.0


func receber_dano(quantidade: int, origem: Vector2, quebra_escudo := false, forca := 140.0) -> void:
	var vindo_de := global_position.direction_to(origem)
	if not quebra_escudo and vindo_de.dot(_frente) > 0.35:
		mostrar_texto("BLOQUEOU", Color("c0cbdc"))
		Sons.tocar("acerto", -6.0, 0.0)
		_empurrao = -vindo_de * 40.0
		return
	super.receber_dano(quantidade, origem, quebra_escudo, forca)
