extends Chefe
## Chefe da fase 1: Golem de Pedra. Ataques:
##  0 ARREMESSO - joga pedras na direção do jogador;
##  1 PANCADA   - ergue os braços (aviso) e bate no chão: onda de choque;
##  2 INVESTIDA - pisca em vermelho e avança; se bater na parede, fica tonto.

const CENA_PEDRA := preload("res://cenas/objetos/pedra.tscn")

var _investindo := false
var _direcao := Vector2.ZERO


func _movimento(_delta: float) -> Vector2:
	if _investindo:
		return _direcao * (210.0 if em_furia else 170.0)
	if _ocupado:
		return Vector2.ZERO
	return global_position.direction_to(_jogador.global_position) * velocidade_andar


func _atacar() -> void:
	match sortear_ataque(3):
		0:
			var qtd := 5 if em_furia else 3
			for i in qtd:
				var mira := global_position.direction_to(_jogador.global_position).rotated(randf_range(-0.25, 0.25))
				atirar(CENA_PEDRA, mira, 120.0)
				Sons.tocar("chefe_tiro")
				if not await esperar(0.3):
					return
		1:
			animacao.play("golpe")
			avisar(0.7)
			if not await esperar(0.75):
				return
			animacao.play("andar")
			onda_de_choque(110.0)
			if em_furia:
				if not await esperar(0.45):
					return
				onda_de_choque(110.0)
		2:
			avisar(0.6)
			if not await esperar(0.6):
				return
			_direcao = global_position.direction_to(_jogador.global_position)
			_investindo = true
			for i in 40:
				await get_tree().physics_frame
				if morrendo or not is_inside_tree():
					return
				if get_slide_collision_count() > 0:
					onda_de_choque(50.0)
					break
			_investindo = false
			if not await esperar(0.8):  # fica tonto
				return
