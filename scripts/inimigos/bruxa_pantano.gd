extends Chefe
## Chefe da fase 2: Bruxa do Pântano. Ataques:
##  0 TELEPORTE - some e reaparece em outro ponto da arena;
##  1 ESPÍRITOS - solta espíritos que perseguem o jogador;
##  2 INVOCAR   - chama morcegos;
##  3 ESPIRAL   - gira soltando orbes em espiral.

const CENA_ESPIRITO := preload("res://cenas/objetos/espirito.tscn")
const CENA_GOSMA := preload("res://cenas/objetos/projetil_inimigo.tscn")
const CENA_MORCEGO := preload("res://cenas/inimigos/morcego.tscn")

var _morcegos: Array[Node2D] = []
var _tempo := 0.0


func _movimento(delta: float) -> Vector2:
	_tempo += delta
	if _ocupado:
		return Vector2.ZERO
	# flutua em volta do centro da arena
	var alvo := _origem + Vector2(cos(_tempo * 0.8) * 30.0, sin(_tempo * 1.1) * 16.0)
	return global_position.direction_to(alvo) * velocidade_andar if global_position.distance_to(alvo) > 2.0 else Vector2.ZERO


func _atacar() -> void:
	match sortear_ataque(4):
		0:
			var t := create_tween()
			t.tween_property(animacao, "modulate:a", 0.0, 0.3)
			if not await esperar(0.35):
				return
			var fase := get_tree().get_first_node_in_group("fase")
			for tentativa in 20:
				var ponto := _origem + Vector2(randf_range(-56, 56), randf_range(-36, 36))
				# só aparece em chão livre (nunca dentro da água ou de uma parede)
				var livre: bool = fase == null or fase.ponto_livre(ponto)
				if livre and ponto.distance_to(_jogador.global_position) > 60.0:
					global_position = ponto
					break
			var t2 := create_tween()
			t2.tween_property(animacao, "modulate:a", 1.0, 0.3)
			Sons.tocar("portal", -6.0)
			if not await esperar(0.3):
				return
		1:
			avisar(0.5)
			if not await esperar(0.5):
				return
			var qtd := 5 if em_furia else 3
			for i in qtd:
				var dir := global_position.direction_to(_jogador.global_position).rotated((i - (qtd - 1) / 2.0) * 0.6)
				atirar(CENA_ESPIRITO, dir)
			Sons.tocar("chefe_tiro")
		2:
			_morcegos = _morcegos.filter(func(m): return is_instance_valid(m))
			if _morcegos.size() >= 4:
				return
			Sons.tocar("chefe_rugido", -6.0, 0.3)
			for i in (3 if em_furia else 2):
				var m := CENA_MORCEGO.instantiate()
				m.global_position = global_position + Vector2.from_angle(TAU * i / 3.0) * 24.0
				m.raio_ataque = 400.0
				m.raio_ninho = 400.0
				_morcegos.append(m)
				invocou.emit(m)
		3:
			var giros := 24 if em_furia else 16
			for i in giros:
				atirar(CENA_GOSMA, Vector2.from_angle(i * 0.55), 70.0)
				if em_furia:
					atirar(CENA_GOSMA, Vector2.from_angle(i * 0.55 + PI), 70.0)
				if not await esperar(0.08):
					return
