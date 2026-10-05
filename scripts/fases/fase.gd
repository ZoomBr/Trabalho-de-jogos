extends Node2D
## Script comum às 3 fases. Cuida de: chaves, pontuação, experiência e níveis,
## tempo, dificuldade progressiva (inimigos e elites surgindo cada vez mais rápido),
## itens que caem dos inimigos, mapa de navegação (A*) usado pela IA dos inimigos,
## o chefão da fase e o fim da fase (vitória ou derrota).
## As diferenças entre as fases ficam nas variáveis exportadas (Inspetor).

const CENA_MOEDA := preload("res://cenas/objetos/moeda.tscn")
const CENA_CORACAO := preload("res://cenas/objetos/coracao.tscn")
const CENA_BANDEIRA := preload("res://cenas/objetos/bandeira.tscn")
const CENA_TEXTO := preload("res://cenas/efeitos/texto_flutuante.tscn")
const CENA_BRILHO := preload("res://cenas/efeitos/efeito_brilho.tscn")

@export var tempo_limite := 180.0
@export var chaves_necessarias := 3
@export var musica := "fase1"
## Inimigos que podem surgir dinamicamente durante a fase.
@export var cenas_spawn: Array[PackedScene] = []
@export var intervalo_spawn_inicial := 12.0
@export var intervalo_spawn_minimo := 5.0
@export var max_inimigos := 12
## Chance (0 a 1) de um inimigo novo nascer como elite.
@export_range(0.0, 1.0) var chance_elite := 0.12
## Última fase: a vitória vem da bandeira que aparece quando o chefe cai.
## Nas outras fases, derrotar o chefe abre o portal de saída.
@export var tem_bandeira := false
## Liga a luz em volta do jogador (usada no castelo escuro).
@export var luz_jogador := false

var chaves := 0
var tempo := 0.0
var moedas_coletadas := 0
var inimigos_derrotados := 0
var terminou := false
var _avisou_tempo := false
var _niveis_pendentes := 0
var _grade := AStarGrid2D.new()

@onready var jogador: CharacterBody2D = $Entidades/Jogador
@onready var hud: CanvasLayer = $HUD
@onready var camada_chao: TileMapLayer = $Mundo/Chao
@onready var camada_agua: TileMapLayer = $Mundo/Agua
@onready var camada_decoracao: TileMapLayer = $Mundo/Decoracao
@onready var itens: Node2D = $Entidades/Itens
@onready var inimigos: Node2D = $Entidades/Inimigos
@onready var projeteis: Node2D = $Entidades/Projeteis
@onready var pontos_spawn: Node2D = $PontosSpawn
@onready var timer_spawn: Timer = $TimerSpawn
@onready var subir_nivel: CanvasLayer = $SubirNivel


func _ready() -> void:
	add_to_group("fase")
	tempo = tempo_limite
	jogador.get_node("Luz").enabled = luz_jogador
	_configurar_camera()
	_montar_grade()

	for item in itens.get_children():
		_conectar_item(item)
	for inimigo in inimigos.get_children():
		_conectar_inimigo(inimigo)

	jogador.vidas_mudaram.connect(hud.atualizar_vidas)
	jogador.morreu.connect(_on_jogador_morreu)
	jogador.disparou.connect(func(p: Node2D): projeteis.add_child.call_deferred(p))
	jogador.poder_mudou.connect(hud.atualizar_poder)
	jogador.esquiva_mudou.connect(hud.atualizar_esquiva)
	subir_nivel.escolhido.connect(_on_melhoria_escolhida)

	var saida := get_node_or_null("Entidades/Saida")
	if saida:
		saida.alcancado.connect(_on_objetivo_alcancado)
	var chefe := get_node_or_null("Entidades/Chefe")
	if chefe:
		chefe.ativado.connect(hud.mostrar_chefe)
		chefe.vida_mudou.connect(hud.atualizar_chefe)
		chefe.enfureceu.connect(func(): hud.mostrar_mensagem("%s ficou furioso!" % chefe.nome_chefe, 2.0))
		chefe.invocou.connect(_on_chefe_invocou)
		chefe.derrotado.connect(_on_chefe_derrotado)
		# o portal só funciona depois que o chefe cai
		if saida:
			saida.desativar()

	timer_spawn.wait_time = intervalo_spawn_inicial
	timer_spawn.timeout.connect(_gerar_inimigo)
	if not cenas_spawn.is_empty():
		timer_spawn.start()

	hud.configurar_classe(Global.classe)
	hud.atualizar_vidas(Global.vidas, Global.vida_maxima)
	hud.atualizar_xp(Global.nivel, Global.xp, Global.xp_para_proximo_nivel())
	hud.atualizar_chaves(chaves, chaves_necessarias)
	hud.atualizar_pontos(Global.pontuacao)
	hud.atualizar_tempo(tempo)
	hud.mostrar_titulo("Fase %d" % (Global.fase_atual + 1), Global.NOMES_FASES[Global.fase_atual])
	Sons.tocar_musica(musica)


func _process(delta: float) -> void:
	if terminou:
		return
	tempo = maxf(tempo - delta, 0.0)
	hud.atualizar_tempo(tempo)
	if tempo <= 30.0 and not _avisou_tempo:
		_avisou_tempo = true
		Sons.tocar("alerta")
		hud.mostrar_mensagem("Faltam 30 segundos!", 2.0)
	if tempo <= 0.0:
		hud.mostrar_mensagem("O tempo acabou!", 2.0)
		_terminar_derrota()


## A câmera é filha do jogador; aqui só limitamos ela ao tamanho do mapa.
func _configurar_camera() -> void:
	var area := camada_chao.get_used_rect()
	var t := camada_chao.tile_set.tile_size
	jogador.camera.limitar(Rect2i(area.position * t, area.size * t))


# ---------- navegação (A*) ----------

## Monta uma grade com as células bloqueadas (água, árvores, muros, portões).
## Os inimigos pedem caminhos para ela quando não enxergam o jogador.
func _montar_grade() -> void:
	var area := camada_chao.get_used_rect()
	_grade.region = area
	_grade.cell_size = Vector2(16, 16)
	_grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grade.update()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			if camada_agua.get_cell_source_id(c) != -1 or _decoracao_solida(c):
				_grade.set_point_solid(c, true)
	for portao in get_tree().get_nodes_in_group("portoes"):
		_grade.set_point_solid(camada_chao.local_to_map(camada_chao.to_local(portao.global_position)), true)


func _decoracao_solida(c: Vector2i) -> bool:
	var dados := camada_decoracao.get_cell_tile_data(c)
	return dados != null and dados.get_collision_polygons_count(0) > 0


## Verdadeiro se o ponto do mundo cai numa célula andável (sem água, parede ou portão).
func ponto_livre(ponto: Vector2) -> bool:
	var c := camada_chao.local_to_map(camada_chao.to_local(ponto))
	return _grade.region.has_point(c) and not _grade.is_point_solid(c)


## Caminho (lista de pontos no mundo) de "de" até "para", desviando dos obstáculos.
func caminho(de: Vector2, para: Vector2) -> PackedVector2Array:
	var a := camada_chao.local_to_map(camada_chao.to_local(de))
	var b := camada_chao.local_to_map(camada_chao.to_local(para))
	if not _grade.region.has_point(a) or not _grade.region.has_point(b) or _grade.is_point_solid(b):
		return PackedVector2Array()
	var celulas := _grade.get_id_path(a, b, true)
	var pontos := PackedVector2Array()
	for i in range(1, celulas.size()):
		pontos.append(camada_chao.to_global(camada_chao.map_to_local(celulas[i])))
	return pontos


# ---------- itens ----------

func _conectar_item(item: Node) -> void:
	if item.has_signal("coletado"):
		item.coletado.connect(_on_item_coletado)


func _on_item_coletado(item: Area2D) -> void:
	var posicao := item.global_position
	match item.tipo:
		0:  # MOEDA
			moedas_coletadas += 1
			Global.moedas_total += 1
			_somar_pontos(10, posicao)
			Sons.tocar("moeda", -3.0)
		1:  # CHAVE
			chaves += 1
			_somar_pontos(50, posicao)
			hud.atualizar_chaves(chaves, chaves_necessarias)
			Sons.tocar("chave")
			_brilho(posicao, Color("feae34"))
			if chaves >= chaves_necessarias:
				_abrir_portoes()
			else:
				hud.mostrar_mensagem("Chave encontrada! (%d/%d)" % [chaves, chaves_necessarias], 2.0)
		2:  # CORACAO
			if jogador.curar():
				_texto(posicao, "+1 vida", Color("f6757a"))
			else:
				_somar_pontos(25, posicao)
			Sons.tocar("cura")
			_brilho(posicao, Color("e43b44"))


func _abrir_portoes() -> void:
	for portao in get_tree().get_nodes_in_group("portoes"):
		_grade.set_point_solid(camada_chao.local_to_map(camada_chao.to_local(portao.global_position)), false)
		portao.abrir()
	Sons.tocar("portao")
	jogador.camera.tremer(3.0, 0.4)
	var chefe := get_node_or_null("Entidades/Chefe")
	var texto := "O portão se abriu! Cuidado: o guardião está lá dentro!"
	if tem_bandeira:
		texto = "A porta do trono se abriu!"
	elif chefe == null:
		texto = "O portão se abriu! Vá até o portal!"
	hud.mostrar_mensagem(texto, 3.0)


# ---------- inimigos ----------

func _conectar_inimigo(inimigo: Node) -> void:
	if inimigo.has_signal("derrotado") and not inimigo.derrotado.is_connected(_on_inimigo_derrotado):
		inimigo.derrotado.connect(_on_inimigo_derrotado)
	if inimigo.has_signal("gerou") and not inimigo.gerou.is_connected(_on_inimigo_gerou):
		inimigo.gerou.connect(_on_inimigo_gerou)


func _on_inimigo_derrotado(inimigo: Node2D) -> void:
	inimigos_derrotados += 1
	Global.inimigos_total += 1
	var posicao := inimigo.global_position
	_somar_pontos(inimigo.pontos, posicao)
	_ganhar_xp(inimigo.xp, posicao)
	# drop: o inimigo pode deixar uma moeda ou um coração (instância dinâmica)
	var sorteio := randf()
	if sorteio < inimigo.chance_coracao:
		_soltar_item.call_deferred(CENA_CORACAO, posicao)
	elif sorteio < inimigo.chance_coracao + inimigo.chance_moeda:
		_soltar_item.call_deferred(CENA_MOEDA, posicao)


## Inimigos criados por outros inimigos (ex.: filhotes do Slime Gigante).
func _on_inimigo_gerou(novo: Node2D) -> void:
	inimigos.add_child.call_deferred(novo)
	_conectar_inimigo(novo)


func _soltar_item(cena: PackedScene, posicao: Vector2) -> void:
	var item := cena.instantiate()
	item.global_position = posicao
	item.surgir_pulando = true
	itens.add_child(item)
	_conectar_item(item)


## Instância dinâmica: novos inimigos surgem nos pontos de spawn longe do
## jogador; o intervalo diminui com o tempo e alguns nascem como elite.
func _gerar_inimigo() -> void:
	if terminou or inimigos.get_child_count() >= max_inimigos:
		return
	var candidatos := pontos_spawn.get_children().filter(func(p: Node2D):
		return p.global_position.distance_to(jogador.global_position) > 150.0)
	if candidatos.is_empty():
		return
	var ponto: Node2D = candidatos.pick_random()
	var inimigo: Node2D = cenas_spawn.pick_random().instantiate()
	inimigo.global_position = ponto.global_position
	var progresso := 1.0 - tempo / tempo_limite
	inimigo.velocidade *= 1.0 + 0.4 * progresso
	inimigos.add_child(inimigo)
	if randf() < chance_elite + 0.1 * progresso:
		inimigo.tornar_elite()
	_conectar_inimigo(inimigo)
	_brilho(ponto.global_position, Color("b55088"))
	timer_spawn.wait_time = maxf(intervalo_spawn_minimo, timer_spawn.wait_time - 0.5)


func _on_chefe_invocou(lacaio: Node2D) -> void:
	inimigos.add_child.call_deferred(lacaio)
	_conectar_inimigo(lacaio)
	_brilho(lacaio.global_position, Color("63c74d"))


func _on_chefe_derrotado(chefe: Node2D) -> void:
	_somar_pontos(chefe.pontos, chefe.global_position)
	_ganhar_xp(chefe.xp, chefe.global_position)
	Global.inimigos_total += 1
	inimigos_derrotados += 1
	hud.esconder_chefe()
	Sons.tocar_musica(musica)
	for inimigo in inimigos.get_children():
		if inimigo.has_method("morrer"):
			inimigo.morrer()
	if tem_bandeira:
		hud.mostrar_mensagem("%s foi derrotado! Erga a bandeira!" % chefe.nome_chefe, 3.0)
		timer_spawn.stop()
		var bandeira := CENA_BANDEIRA.instantiate()
		bandeira.global_position = $PontoBandeira.global_position
		$Entidades.add_child.call_deferred(bandeira)
		bandeira.alcancado.connect(_on_objetivo_alcancado)
		_brilho($PontoBandeira.global_position, Color("0099db"))
	else:
		hud.mostrar_mensagem("%s caiu! O portal se abriu!" % chefe.nome_chefe, 3.0)
		var saida := get_node_or_null("Entidades/Saida")
		if saida:
			saida.ativar()
			_brilho(saida.global_position, Color("b55088"))


# ---------- experiência e níveis ----------

func _ganhar_xp(quantidade: int, posicao: Vector2) -> void:
	var subiu := Global.ganhar_xp(quantidade)
	hud.atualizar_xp(Global.nivel, Global.xp, Global.xp_para_proximo_nivel())
	if subiu > 0 and not terminou:
		_niveis_pendentes += subiu
		_texto(posicao, "NÍVEL %d!" % Global.nivel, Color("2ce8f5"))
		Sons.tocar("chave")
		_abrir_escolha.call_deferred()


func _abrir_escolha() -> void:
	if _niveis_pendentes > 0 and not subir_nivel.aberto:
		_niveis_pendentes -= 1
		subir_nivel.mostrar(Global.nivel - _niveis_pendentes)


func _on_melhoria_escolhida() -> void:
	hud.atualizar_vidas(Global.vidas, Global.vida_maxima)
	if _niveis_pendentes > 0:
		_abrir_escolha.call_deferred()


# ---------- fim da fase ----------

func _on_objetivo_alcancado() -> void:
	if terminou:
		return
	terminou = true
	jogador.controlavel = false
	timer_spawn.stop()
	var bonus := int(tempo) * 5
	Global.pontuacao += bonus
	Global.tempo_total += tempo_limite - tempo
	hud.atualizar_pontos(Global.pontuacao)
	Sons.tocar_vinheta("vitoria" if tem_bandeira else "portal")
	hud.mostrar_mensagem("Fase concluída! Bônus de tempo: +%d" % bonus, 3.0)
	await get_tree().create_timer(2.2).timeout
	Global.concluir_fase({
		"fase": Global.fase_atual,
		"moedas": moedas_coletadas,
		"inimigos": inimigos_derrotados,
		"bonus": bonus,
	})


func _on_jogador_morreu() -> void:
	hud.mostrar_mensagem("Você foi derrotado...", 2.0)
	_terminar_derrota()


func _terminar_derrota() -> void:
	if terminou:
		return
	terminou = true
	jogador.controlavel = false
	timer_spawn.stop()
	Global.tempo_total += tempo_limite - tempo
	Sons.tocar_vinheta("derrota")
	await get_tree().create_timer(2.0).timeout
	Global.perder()


# ---------- utilidades ----------

func _somar_pontos(valor: int, posicao: Vector2) -> void:
	Global.pontuacao += valor
	hud.atualizar_pontos(Global.pontuacao)
	_texto(posicao, "+%d" % valor, Color("fee761"))


func _texto(posicao: Vector2, texto: String, cor: Color) -> void:
	var rotulo: Label = CENA_TEXTO.instantiate()
	rotulo.text = texto
	rotulo.modulate = cor
	rotulo.position = posicao + Vector2(0, -10)
	$Entidades.add_child.call_deferred(rotulo)


func _brilho(posicao: Vector2, cor: Color) -> void:
	var efeito: CPUParticles2D = CENA_BRILHO.instantiate()
	efeito.global_position = posicao
	efeito.color = cor
	$Entidades.add_child.call_deferred(efeito)
