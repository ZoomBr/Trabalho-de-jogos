extends Node2D
## Onda de choque: um anel que cresce a partir do centro. Fere o jogador se
## o anel passar por ele (pular o anel com a esquiva funciona!).

@export var raio_maximo := 100.0
@export var velocidade := 150.0
@export var espessura := 7.0

var raio := 6.0
var _acertou := false
var _jogador: Node2D


func _ready() -> void:
	_jogador = get_tree().get_first_node_in_group("jogador")
	z_index = 2


func _physics_process(delta: float) -> void:
	raio += velocidade * delta
	queue_redraw()
	if not _acertou and is_instance_valid(_jogador):
		var d := global_position.distance_to(_jogador.global_position)
		if absf(d - raio) < espessura and not _jogador.esta_invencivel():
			_acertou = true
			_jogador.levar_dano(global_position)
	if raio >= raio_maximo:
		queue_free()


func _draw() -> void:
	var alfa := clampf(1.0 - raio / raio_maximo, 0.2, 1.0)
	draw_arc(Vector2.ZERO, raio, 0, TAU, 48, Color(0.75, 0.8, 0.86, alfa), 3.0)
	draw_arc(Vector2.ZERO, raio - 3, 0, TAU, 48, Color(0.35, 0.4, 0.53, alfa * 0.7), 2.0)
