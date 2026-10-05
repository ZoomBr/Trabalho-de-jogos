extends Node2D
## Marca vermelha no chão: depois de "atraso" segundos, fere o jogador se ele
## ainda estiver dentro do círculo (usado no salto e na chuva do Rei Slime).

const CENA_EXPLOSAO := preload("res://cenas/efeitos/efeito_morte.tscn")

@export var raio := 20.0
@export var atraso := 0.9
@export var cor := Color("e43b44")

var _tempo := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()
	if _tempo >= atraso:
		var jogador := get_tree().get_first_node_in_group("jogador")
		if jogador and jogador.global_position.distance_to(global_position) <= raio:
			jogador.levar_dano(global_position)
		var efeito := CENA_EXPLOSAO.instantiate()
		efeito.global_position = global_position
		efeito.color = Color("63c74d")
		get_parent().add_child(efeito)
		queue_free()


func _draw() -> void:
	var progresso := clampf(_tempo / atraso, 0.0, 1.0)
	draw_circle(Vector2.ZERO, raio, Color(cor, 0.18 + 0.2 * sin(_tempo * 18.0) * 0.5))
	draw_circle(Vector2.ZERO, raio * progresso, Color(cor, 0.35))
	draw_arc(Vector2.ZERO, raio, 0, TAU, 32, Color(cor, 0.9), 1.0)
