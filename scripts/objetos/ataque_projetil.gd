extends Area2D
## Projétil do jogador (flecha ou bola de fogo).
## - "perfura": quantos inimigos ele atravessa antes de sumir (flecha = 1).
## - "raio_explosao": se for maior que zero, explode e acerta quem estiver perto (bola de fogo).

const CENA_FAISCA := preload("res://cenas/efeitos/efeito_faisca.tscn")
const CENA_EXPLOSAO := preload("res://cenas/efeitos/efeito_morte.tscn")

@export var velocidade := 200.0
@export var perfura := 0
@export var raio_explosao := 0.0
@export var cor_explosao := Color("f77622")

var direcao := Vector2.RIGHT
var dano := 1
var _acertados: Array[Node] = []
var _acabou := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$TimerVida.timeout.connect(_terminar)
	rotation = direcao.angle()


func _physics_process(delta: float) -> void:
	position += direcao * velocidade * delta


func _on_body_entered(corpo: Node2D) -> void:
	if _acabou or corpo in _acertados:
		return
	if corpo.has_method("receber_dano"):
		_acertados.append(corpo)
		corpo.receber_dano(dano, global_position - direcao * 10.0)
		if perfura > 0:
			perfura -= 1
			return
	_terminar()


func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	if raio_explosao > 0.0:
		_explodir()
	else:
		var faisca := CENA_FAISCA.instantiate()
		faisca.global_position = global_position
		get_parent().add_child.call_deferred(faisca)
	queue_free()


## Explosão: acerta todos os inimigos dentro do raio (menos quem já levou o golpe direto).
func _explodir() -> void:
	var efeito := CENA_EXPLOSAO.instantiate()
	efeito.global_position = global_position
	efeito.color = cor_explosao
	get_parent().add_child.call_deferred(efeito)
	for alvo in get_tree().get_nodes_in_group("inimigos") + get_tree().get_nodes_in_group("chefe"):
		if alvo in _acertados or not is_instance_valid(alvo):
			continue
		if alvo.global_position.distance_to(global_position) <= raio_explosao:
			alvo.receber_dano(maxi(1, dano / 2), global_position)
