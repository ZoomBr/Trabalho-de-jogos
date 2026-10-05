extends Area2D
## Poder do Guerreiro: a espada gira em volta do corpo e acerta todo mundo por perto.
## Quebra o escudo do Golem Escudeiro.

const DURACAO := 0.45

var dano := 4
var escala := 1.0
var _acertados: Array[Node] = []
var _tempo := 0.0


func _ready() -> void:
	scale = Vector2(escala, escala)


func _physics_process(delta: float) -> void:
	_tempo += delta
	$Laminas.rotation += delta * 22.0
	for corpo in get_overlapping_bodies():
		if corpo in _acertados or not corpo.has_method("receber_dano"):
			continue
		_acertados.append(corpo)
		corpo.receber_dano(dano, get_parent().global_position, true)
	for area in get_overlapping_areas():
		if area.is_in_group("projetil_inimigo"):
			area.destruir()
	if _tempo >= DURACAO:
		queue_free()
