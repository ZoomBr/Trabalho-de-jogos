class_name Inimigo
extends CharacterBody2D
## Base de todos os inimigos comuns. Cuida de:
##  - vida, barra de vida em cima da cabeça e números de dano;
##  - versão "elite" (dourada, com o dobro de vida e mais recompensa);
##  - empurrão, piscar branco ao ser atingido e aviso vermelho antes de atacar;
##  - movimento inteligente: vai direto se enxerga o alvo; senão pede um
##    caminho (A*) para a fase e desvia dos obstáculos;
##  - morte com efeito, pontos, experiência e chance de deixar itens.
## Cada tipo de inimigo herda deste script e só implementa o próprio comportamento.

signal derrotado(inimigo: Inimigo)
## Para inimigos que criam outros (ex.: o Slime Gigante se divide).
signal gerou(novo: Node2D)

const CENA_EFEITO_MORTE := preload("res://cenas/efeitos/efeito_morte.tscn")
const CENA_TEXTO := preload("res://cenas/efeitos/texto_flutuante.tscn")
const MASCARA_VISAO := 1 | 32  # mundo + água

@export var vida_maxima := 2
@export var pontos := 20
@export var xp := 2
@export var velocidade := 40.0
@export_range(0.0, 1.0) var chance_moeda := 0.5
@export_range(0.0, 1.0) var chance_coracao := 0.08
@export var cor_efeito := Color("63c74d")
@export var pode_ser_elite := true

var vida := 1
var morto := false
var elite := false
var _empurrao := Vector2.ZERO
var _jogador: Node2D
var _fase: Node
var _caminho := PackedVector2Array()
var _tempo_caminho := 0.0
var _tempo_barra := 0.0

@onready var animacao: AnimatedSprite2D = $Animacao
@onready var area_dano: Area2D = $AreaDano


func _ready() -> void:
	add_to_group("inimigos")
	vida = vida_maxima
	_jogador = get_tree().get_first_node_in_group("jogador")
	_fase = get_tree().get_first_node_in_group("fase")
	animacao.play("andar")
	animacao.frame = randi() % 2
	_iniciar()


## Transforma em versão elite: dourada, maior, com o dobro de vida e mais recompensa.
func tornar_elite() -> void:
	if not pode_ser_elite or elite:
		return
	elite = true
	vida_maxima *= 2
	vida = vida_maxima
	pontos *= 2
	xp *= 3
	chance_moeda = 1.0
	velocidade *= 1.15
	animacao.scale *= 1.2
	# brilho dourado pulsando + coroa desenhada em _draw(), para ninguém
	# confundir o elite com outro tipo de inimigo
	var brilho := create_tween().set_loops()
	brilho.tween_property(animacao, "self_modulate", Color(1.5, 1.3, 0.7), 0.4)
	brilho.tween_property(animacao, "self_modulate", Color.WHITE, 0.4)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if morto:
		return
	velocity = _calcular_velocidade(delta) + _empurrao
	_empurrao = _empurrao.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	_depois_de_mover()
	if absf(velocity.x) > 1.0:
		animacao.flip_h = velocity.x < 0.0
	_causar_dano_por_contato()
	if _tempo_barra > 0.0:
		_tempo_barra -= delta
		queue_redraw()


# ---------- pontos para os filhos sobrescreverem ----------

func _iniciar() -> void:
	pass


func _calcular_velocidade(_delta: float) -> Vector2:
	return Vector2.ZERO


func _depois_de_mover() -> void:
	pass


## Chamado quando o inimigo morre (antes de sumir).
func _ao_morrer() -> void:
	pass


# ---------- utilidades de IA ----------

func jogador_valido() -> bool:
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador")
	return is_instance_valid(_jogador) and _jogador.controlavel


func distancia_jogador() -> float:
	return global_position.distance_to(_jogador.global_position) if jogador_valido() else INF


## Verdadeiro se não há parede nem água entre o inimigo e o ponto.
func tem_visao(alvo: Vector2) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, alvo, MASCARA_VISAO, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()


## Devolve a velocidade para ir até o alvo: em linha reta se enxerga,
## senão seguindo o caminho calculado pelo A* da fase (recalculado a cada 0,5 s).
func mover_para(alvo: Vector2, vel: float, delta: float) -> Vector2:
	if tem_visao(alvo) or _fase == null:
		_caminho.clear()
		return global_position.direction_to(alvo) * vel
	_tempo_caminho -= delta
	if _tempo_caminho <= 0.0 or _caminho.is_empty():
		_tempo_caminho = 0.5
		_caminho = _fase.caminho(global_position, alvo)
	while not _caminho.is_empty() and global_position.distance_to(_caminho[0]) < 5.0:
		_caminho.remove_at(0)
	if _caminho.is_empty():
		return global_position.direction_to(alvo) * vel
	return global_position.direction_to(_caminho[0]) * vel


## Coloca projéteis e efeitos no nó "Projeteis" da fase (e não junto dos
## inimigos, para não contarem como inimigo no limite de spawn).
func adicionar_ao_mundo(no: Node) -> void:
	if is_instance_valid(_fase) and _fase.get("projeteis") != null:
		_fase.projeteis.add_child.call_deferred(no)
	else:
		get_parent().add_child.call_deferred(no)


## Pisca em vermelho para avisar o jogador que um ataque vem aí.
func avisar(duracao: float) -> void:
	var t := create_tween().set_loops(maxi(1, int(duracao / 0.14)))
	t.tween_property(animacao, "modulate", Color(2.2, 0.5, 0.5), 0.07)
	t.tween_property(animacao, "modulate", Color.WHITE, 0.07)


func _causar_dano_por_contato() -> void:
	for corpo in area_dano.get_overlapping_bodies():
		if corpo.has_method("levar_dano"):
			corpo.levar_dano(global_position)


# ---------- vida ----------

## "forca" é o empurrão: projéteis empurram mais; a espada empurra pouco para
## o inimigo continuar ao alcance do próximo golpe.
func receber_dano(quantidade: int, origem: Vector2, _quebra_escudo := false, forca := 140.0) -> void:
	if morto:
		return
	vida -= quantidade
	_tempo_barra = 2.5
	queue_redraw()
	_empurrao = origem.direction_to(global_position) * forca
	animacao.modulate = Color(4, 4, 4)
	create_tween().tween_property(animacao, "modulate", Color.WHITE, 0.15)
	mostrar_texto("-%d" % quantidade, Color.WHITE)
	if vida <= 0:
		morrer()
	else:
		Sons.tocar("acerto")


func mostrar_texto(texto: String, cor: Color) -> void:
	var rotulo: Label = CENA_TEXTO.instantiate()
	rotulo.text = texto
	rotulo.modulate = cor
	rotulo.position = global_position + Vector2(randf_range(-4, 4), -14)
	adicionar_ao_mundo(rotulo)


## Barra de vida em cima da cabeça (aparece por alguns segundos depois de levar dano).
func _draw() -> void:
	if morto:
		return
	var topo := -13.0 * animacao.scale.y
	if elite:
		# coroa dourada em cima da cabeça
		var y := topo - (8.0 if _tempo_barra > 0.0 else 4.0)
		var coroa := PackedVector2Array([Vector2(-5, y + 5), Vector2(-5, y), Vector2(-2.5, y + 2.5),
			Vector2(0, y - 1), Vector2(2.5, y + 2.5), Vector2(5, y), Vector2(5, y + 5)])
		draw_colored_polygon(coroa, Color("feae34"))
		draw_polyline(coroa + PackedVector2Array([coroa[0]]), Color("3e2731"), 1.0)
	if _tempo_barra <= 0.0:
		return
	var largura := 14.0
	draw_rect(Rect2(-largura / 2 - 1, topo - 1, largura + 2, 4), Color("181425"))
	var cor := Color("feae34") if elite else Color("e43b44")
	draw_rect(Rect2(-largura / 2, topo, largura * clampf(float(vida) / vida_maxima, 0, 1), 2), cor)


func morrer() -> void:
	if morto:
		return
	morto = true
	queue_redraw()
	Sons.tocar("inimigo_morre", -2.0)
	var efeito := CENA_EFEITO_MORTE.instantiate()
	efeito.global_position = global_position
	efeito.color = cor_efeito
	adicionar_ao_mundo(efeito)
	_ao_morrer()
	derrotado.emit(self)
	queue_free()
