class_name Chefe
extends CharacterBody2D
## Base dos chefões (Golem de Pedra, Bruxa do Pântano e Rei Slime).
## Cuida de: acordar quando o jogador chega perto, vida e fúria (metade da vida),
## escolha de ataques sem repetir, dano por contato e a morte com explosões.
## Cada chefão só implementa os ataques em _atacar() e o movimento em _movimento().

signal ativado(nome: String, vida_maxima: int)
signal vida_mudou(vida: int, vida_maxima: int)
signal enfureceu
signal invocou(inimigo: Node2D)
signal derrotado(chefe: Node2D)

const CENA_EFEITO_MORTE := preload("res://cenas/efeitos/efeito_morte.tscn")
const CENA_ONDA := preload("res://cenas/objetos/onda_choque.tscn")
const CENA_AVISO := preload("res://cenas/objetos/aviso_area.tscn")
const CENA_TEXTO := preload("res://cenas/efeitos/texto_flutuante.tscn")

@export var nome_chefe := "Chefe"
@export var vida_maxima := 50
@export var raio_despertar := 100.0
@export var velocidade_andar := 22.0
@export var pausa_entre_ataques := 1.3
@export var pontos := 500
@export var xp := 25
@export var cor_morte := Color("e43b44")

var vida := 50
var acordado := false
var em_furia := false
var morrendo := false
var _jogador: Node2D
var _ocupado := false
var _proximo_ataque := 1.0
var _ultimo := -1
var _origem := Vector2.ZERO

@onready var animacao: AnimatedSprite2D = $Animacao
@onready var area_dano: Area2D = $AreaDano


func _ready() -> void:
	add_to_group("chefe")
	vida = vida_maxima
	_origem = global_position
	animacao.play("parado")


func _physics_process(delta: float) -> void:
	if morrendo:
		return
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador")
		if not is_instance_valid(_jogador):
			return
	if not acordado:
		if global_position.distance_to(_jogador.global_position) < raio_despertar:
			despertar()
		return
	velocity = _movimento(delta)
	move_and_slide()
	if absf(velocity.x) > 1.0:
		animacao.flip_h = velocity.x < 0.0
	_causar_dano_por_contato()
	if not _ocupado:
		_proximo_ataque -= delta
		if _proximo_ataque <= 0.0:
			_executar_ataque()


func _executar_ataque() -> void:
	_ocupado = true
	await _atacar()
	_ocupado = false
	_proximo_ataque = pausa_entre_ataques * (0.6 if em_furia else 1.0)


## Sobrescreva: movimento entre os ataques.
func _movimento(_delta: float) -> Vector2:
	return global_position.direction_to(_jogador.global_position) * velocidade_andar


## Sobrescreva: escolhe e executa um ataque (pode usar await).
func _atacar() -> void:
	pass


## Sobrescreva: o que muda quando o chefe fica furioso.
func _ao_enfurecer() -> void:
	pass


## Sorteia um número de ataque de 0 a quantidade-1, sem repetir o anterior.
func sortear_ataque(quantidade: int) -> int:
	var opcoes := range(quantidade)
	if quantidade > 1:
		opcoes.erase(_ultimo)
	_ultimo = opcoes.pick_random()
	return _ultimo


func despertar() -> void:
	if acordado:
		return
	acordado = true
	Sons.tocar("chefe_rugido")
	Sons.tocar_musica("chefe")
	if _jogador:
		_jogador.camera.tremer(4.0, 0.6)
	ativado.emit(nome_chefe, vida_maxima)
	animacao.play("andar")
	_proximo_ataque = 1.2


## Espera "segundos" respeitando a pausa do jogo. Devolve falso se o chefe morreu nesse meio-tempo.
func esperar(segundos: float) -> bool:
	await get_tree().create_timer(segundos, false).timeout
	return not morrendo and is_inside_tree()


func avisar(duracao: float) -> void:
	var t := create_tween().set_loops(maxi(1, int(duracao / 0.14)))
	t.tween_property(animacao, "modulate", Color(2.2, 0.5, 0.5), 0.07)
	t.tween_property(animacao, "modulate", Color.WHITE, 0.07)


func atirar(cena: PackedScene, direcao: Vector2, velocidade := -1.0) -> Node2D:
	var p := cena.instantiate()
	p.global_position = global_position + Vector2(0, 4)
	p.direcao = direcao
	if velocidade > 0.0:
		p.velocidade = velocidade
	get_parent().add_child(p)
	return p


func onda_de_choque(raio_maximo: float, posicao := Vector2.INF) -> void:
	var onda := CENA_ONDA.instantiate()
	onda.raio_maximo = raio_maximo
	onda.global_position = global_position + Vector2(0, 8) if posicao == Vector2.INF else posicao
	get_parent().add_child(onda)
	if _jogador:
		_jogador.camera.tremer(4.0, 0.3)
	Sons.tocar("portao", -2.0)


func area_de_aviso(posicao: Vector2, raio: float, atraso: float) -> void:
	var aviso := CENA_AVISO.instantiate()
	aviso.global_position = posicao
	aviso.raio = raio
	aviso.atraso = atraso
	get_parent().add_child(aviso)


func _causar_dano_por_contato() -> void:
	if not area_dano.monitoring:  # desligada durante o salto e a morte
		return
	for corpo in area_dano.get_overlapping_bodies():
		if corpo.has_method("levar_dano"):
			corpo.levar_dano(global_position)


func receber_dano(quantidade: int, _origem_golpe: Vector2, _quebra_escudo := false, _forca := 0.0) -> void:
	if morrendo:
		return
	if not acordado:
		despertar()
	vida = maxi(vida - quantidade, 0)
	vida_mudou.emit(vida, vida_maxima)
	animacao.modulate = Color(4, 4, 4)
	create_tween().tween_property(animacao, "modulate", Color.WHITE, 0.12)
	var rotulo: Label = CENA_TEXTO.instantiate()
	rotulo.text = "-%d" % quantidade
	rotulo.position = global_position + Vector2(randf_range(-8, 8), -22)
	get_parent().add_child.call_deferred(rotulo)
	Sons.tocar("acerto", -2.0)
	if not em_furia and vida <= vida_maxima / 2:
		em_furia = true
		Sons.tocar("chefe_rugido")
		if _jogador:
			_jogador.camera.tremer(5.0, 0.5)
		animacao.speed_scale = 1.6
		_ao_enfurecer()
		enfureceu.emit()
	if vida <= 0:
		_morrer()


func _morrer() -> void:
	morrendo = true
	collision_layer = 0
	area_dano.set_deferred("monitoring", false)
	Sons.tocar("chefe_rugido")
	for i in 6:
		var efeito := CENA_EFEITO_MORTE.instantiate()
		efeito.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-10, 10))
		efeito.color = cor_morte if i % 2 == 0 else Color("feae34")
		get_parent().add_child(efeito)
		Sons.tocar("explosao", -4.0, 0.2)
		if _jogador:
			_jogador.camera.tremer(3.0, 0.2)
		await get_tree().create_timer(0.18, false).timeout
	# espera um ataque em andamento terminar antes de sumir
	while _ocupado:
		await get_tree().process_frame
	derrotado.emit(self)
	queue_free()
