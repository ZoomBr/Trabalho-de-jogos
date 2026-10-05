extends CharacterBody2D
## Jogador. A aparência, os atributos, o ataque e o poder vêm da classe escolhida
## (Global.classe, um Resource ClasseHeroi). Comandos:
##   setas/WASD = andar | Espaço/J/clique = atacar | Q/K/botão direito = poder
##   Shift/L = esquiva (impulso rápido e invencível)

signal vidas_mudaram(vidas: int, maximo: int)
signal morreu
signal disparou(projetil: Node2D)
signal poder_mudou(restante: float, total: float)
signal esquiva_mudou(restante: float, total: float)

const ACELERACAO := 900.0
const FORCA_EMPURRAO := 200.0
const VELOCIDADE_ESQUIVA := 260.0
const DURACAO_ESQUIVA := 0.18
const RECARGA_ESQUIVA := 1.0
const CENA_GOLPE := preload("res://cenas/objetos/golpe_espada.tscn")
const CENA_BOLA_FOGO := preload("res://cenas/objetos/bola_de_fogo.tscn")
const CENA_FLECHA := preload("res://cenas/objetos/flecha.tscn")
const CENA_GIRO := preload("res://cenas/objetos/giro_espada.tscn")

var classe: ClasseHeroi
var direcao_olhar := Vector2.DOWN
var controlavel := true
var _invencivel := false
var _tempo_ataque := 0.0
var _recarga_poder := 0.0
var _recarga_esquiva := 0.0
var _tempo_esquiva := 0.0
var _direcao_esquiva := Vector2.ZERO
var _empurrao := Vector2.ZERO
var _velocidade_base := Vector2.ZERO
var _tempo_invencivel := 0.0

@onready var animacao: AnimatedSprite2D = $Animacao
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("jogador")
	classe = Global.classe
	animacao.sprite_frames = _criar_animacoes(classe.textura)
	animacao.play("parado_baixo")


## Monta as animações a partir da folha de sprites da classe (4 colunas x 3 linhas).
func _criar_animacoes(textura: Texture2D) -> SpriteFrames:
	var quadros := SpriteFrames.new()
	quadros.remove_animation("default")
	for linha in 3:
		var direcao: String = ["baixo", "cima", "lado"][linha]
		quadros.add_animation("parado_" + direcao)
		quadros.add_animation("andar_" + direcao)
		quadros.set_animation_speed("andar_" + direcao, 8.0)
		for coluna in 4:
			var recorte := AtlasTexture.new()
			recorte.atlas = textura
			recorte.region = Rect2(coluna * 16, linha * 16, 16, 16)
			quadros.add_frame("andar_" + direcao, recorte)
			if coluna == 0:
				quadros.add_frame("parado_" + direcao, recorte)
	return quadros


func velocidade_atual() -> float:
	return classe.velocidade * Global.mult_velocidade


func dano_atual() -> int:
	return classe.dano + Global.bonus_dano


func _physics_process(delta: float) -> void:
	_atualizar_recargas(delta)
	var entrada := Vector2.ZERO
	if controlavel:
		entrada = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")

	if _tempo_esquiva > 0.0:
		_tempo_esquiva -= delta
		velocity = _direcao_esquiva * VELOCIDADE_ESQUIVA
		_rastro()
	else:
		_velocidade_base = _velocidade_base.move_toward(entrada * velocidade_atual(), ACELERACAO * delta)
		velocity = _velocidade_base + _empurrao
	_empurrao = _empurrao.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	if entrada != Vector2.ZERO:
		direcao_olhar = entrada.normalized()
	_atualizar_animacao(entrada != Vector2.ZERO or _tempo_esquiva > 0.0)

	if not controlavel:
		return
	if Input.is_action_pressed("atirar") and _tempo_ataque <= 0.0:
		_atacar(_mira(MOUSE_BUTTON_LEFT))
	if Input.is_action_just_pressed("poder") and _recarga_poder <= 0.0:
		_usar_poder(_mira(MOUSE_BUTTON_RIGHT))
	if Input.is_action_just_pressed("esquiva") and _recarga_esquiva <= 0.0:
		_esquivar(entrada if entrada != Vector2.ZERO else direcao_olhar)


func _atualizar_recargas(delta: float) -> void:
	_tempo_ataque -= delta
	if _recarga_poder > 0.0:
		_recarga_poder = maxf(_recarga_poder - delta, 0.0)
		poder_mudou.emit(_recarga_poder, classe.recarga_poder * Global.mult_recarga)
	if _recarga_esquiva > 0.0:
		_recarga_esquiva = maxf(_recarga_esquiva - delta, 0.0)
		esquiva_mudou.emit(_recarga_esquiva, RECARGA_ESQUIVA)
	if _tempo_invencivel > 0.0:
		_tempo_invencivel -= delta
		if _tempo_invencivel <= 0.0 and _tempo_esquiva <= 0.0:
			_invencivel = false
			animacao.modulate.a = 1.0


## Direção da mira: o cursor do mouse (se o botão estiver apertado) ou para onde o jogador olha.
func _mira(botao: MouseButton) -> Vector2:
	if Input.is_mouse_button_pressed(botao):
		var d := global_position.direction_to(get_global_mouse_position())
		if d != Vector2.ZERO:
			direcao_olhar = d
			return d
	return direcao_olhar


func _atualizar_animacao(andando: bool) -> void:
	var sufixo := "lado"
	if absf(direcao_olhar.y) > absf(direcao_olhar.x):
		sufixo = "baixo" if direcao_olhar.y > 0.0 else "cima"
	animacao.flip_h = sufixo == "lado" and direcao_olhar.x < 0.0
	animacao.play(("andar_" if andando else "parado_") + sufixo)


# ---------- ataque básico ----------

func _atacar(mira: Vector2) -> void:
	_tempo_ataque = classe.cadencia * Global.mult_cadencia
	match classe.ataque:
		ClasseHeroi.Ataque.ESPADA:
			var golpe := CENA_GOLPE.instantiate()
			golpe.dano = dano_atual()
			golpe.direcao = mira
			golpe.escala = Global.mult_alcance
			add_child(golpe)
			Sons.tocar("tiro", -8.0, 0.25)
		ClasseHeroi.Ataque.BOLA_DE_FOGO:
			_disparar_leque(CENA_BOLA_FOGO, mira, 1 + Global.projeteis_extra, 12.0)
			Sons.tocar("chefe_tiro", -8.0)
		ClasseHeroi.Ataque.FLECHA:
			_disparar_leque(CENA_FLECHA, mira, 1 + Global.projeteis_extra, 8.0)
			Sons.tocar("tiro", -6.0)


## Dispara "quantidade" projéteis abertos em leque (graus entre eles) na direção da mira.
func _disparar_leque(cena: PackedScene, mira: Vector2, quantidade: int, abertura: float) -> void:
	for i in quantidade:
		var angulo := deg_to_rad((i - (quantidade - 1) / 2.0) * abertura)
		_disparar(cena, mira.rotated(angulo))


func _disparar(cena: PackedScene, direcao: Vector2) -> void:
	var projetil := cena.instantiate()
	projetil.global_position = global_position + direcao * 8.0 + Vector2(0, 2)
	projetil.direcao = direcao
	projetil.dano = dano_atual()
	disparou.emit(projetil)


# ---------- poder especial ----------

func _usar_poder(mira: Vector2) -> void:
	_recarga_poder = classe.recarga_poder * Global.mult_recarga
	camera.tremer(2.0, 0.2)
	match classe.poder:
		ClasseHeroi.Poder.GIRO_DA_ESPADA:
			var giro := CENA_GIRO.instantiate()
			giro.dano = dano_atual() * 2
			giro.escala = Global.mult_alcance
			add_child(giro)
			_ficar_invencivel(giro.DURACAO + 0.1, false)
			Sons.tocar("portal", -4.0, 0.0)
		ClasseHeroi.Poder.EXPLOSAO_ARCANA:
			var quantidade := 14 + Global.projeteis_extra * 4
			for i in quantidade:
				_disparar(CENA_BOLA_FOGO, Vector2.from_angle(TAU * i / quantidade))
			Sons.tocar("explosao", -6.0)
		ClasseHeroi.Poder.CHUVA_DE_FLECHAS:
			for onda in 3:
				if not is_inside_tree():
					return
				_disparar_leque(CENA_FLECHA, mira, 7 + Global.projeteis_extra * 2, 9.0)
				Sons.tocar("tiro", -4.0)
				await get_tree().create_timer(0.12, false).timeout


# ---------- esquiva ----------

func _esquivar(direcao: Vector2) -> void:
	_recarga_esquiva = RECARGA_ESQUIVA
	_tempo_esquiva = DURACAO_ESQUIVA
	_direcao_esquiva = direcao.normalized()
	_ficar_invencivel(DURACAO_ESQUIVA + 0.05, false)
	Sons.tocar("tiro", -10.0, 0.3)


## Deixa uma "sombra" do personagem para trás durante a esquiva.
func _rastro() -> void:
	var fantasma := Sprite2D.new()
	fantasma.texture = animacao.sprite_frames.get_frame_texture(animacao.animation, animacao.frame)
	fantasma.flip_h = animacao.flip_h
	fantasma.global_position = global_position
	fantasma.modulate = Color(0.5, 0.9, 1.0, 0.6)
	fantasma.z_index = -1
	get_parent().add_child(fantasma)
	var t := fantasma.create_tween()
	t.tween_property(fantasma, "modulate:a", 0.0, 0.25)
	t.tween_callback(fantasma.queue_free)


# ---------- vida ----------

func _ficar_invencivel(segundos: float, piscar: bool) -> void:
	_invencivel = true
	_tempo_invencivel = maxf(_tempo_invencivel, segundos)
	if piscar:
		var t := create_tween().set_loops(int(segundos / 0.16))
		t.tween_property(animacao, "modulate:a", 0.25, 0.08)
		t.tween_property(animacao, "modulate:a", 1.0, 0.08)


func esta_invencivel() -> bool:
	return _invencivel


func levar_dano(origem: Vector2) -> void:
	if _invencivel or Global.vidas <= 0 or not controlavel:
		return
	Global.vidas -= 1
	vidas_mudaram.emit(Global.vidas, Global.vida_maxima)
	Sons.tocar("dano")
	camera.tremer(4.0, 0.25)
	_empurrao = origem.direction_to(global_position) * FORCA_EMPURRAO
	if Global.vidas <= 0:
		controlavel = false
		animacao.modulate = Color(1, 0.4, 0.4)
		morreu.emit()
		return
	_ficar_invencivel(1.2, true)


func curar() -> bool:
	if Global.vidas >= Global.vida_maxima:
		return false
	Global.vidas += 1
	vidas_mudaram.emit(Global.vidas, Global.vida_maxima)
	return true
