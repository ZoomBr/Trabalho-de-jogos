extends CanvasLayer
## Interface durante o jogo: vidas, nível e experiência, chaves, pontos, tempo,
## recarga do poder e da esquiva, mensagens, título da fase e vida do chefão.

const TEX_CORACAO_CHEIO := preload("res://recursos/ui/coracao_cheio.tres")
const TEX_CORACAO_VAZIO := preload("res://recursos/ui/coracao_vazio.tres")

var _tween_mensagem: Tween

@onready var caixa_vidas: HBoxContainer = $Topo/Esquerda/Vidas
@onready var barra_xp: ProgressBar = $Topo/Esquerda/Nivel/BarraXP
@onready var label_nivel: Label = $Topo/Esquerda/Nivel/Valor
@onready var label_chaves: Label = $Topo/Chaves/Valor
@onready var label_pontos: Label = $Topo/Pontos/Valor
@onready var label_tempo: Label = $Topo/Tempo
@onready var label_mensagem: Label = $Mensagem
@onready var titulo: Control = $Titulo
@onready var painel_chefe: Control = $Chefe
@onready var barra_chefe: ProgressBar = $Chefe/Barra
@onready var nome_chefe: Label = $Chefe/Nome
@onready var icone_poder: TextureRect = $Habilidades/Poder/Icone
@onready var barra_poder: ProgressBar = $Habilidades/Poder/Recarga
@onready var barra_esquiva: ProgressBar = $Habilidades/Esquiva/Recarga


func _ready() -> void:
	label_mensagem.modulate.a = 0.0
	titulo.modulate.a = 0.0
	painel_chefe.hide()


func configurar_classe(classe: ClasseHeroi) -> void:
	icone_poder.texture = classe.icone_poder
	$Habilidades/Poder/Nome.text = classe.nome_poder
	atualizar_poder(0.0, 1.0)
	atualizar_esquiva(0.0, 1.0)


func atualizar_vidas(vidas: int, maximo: int) -> void:
	for i in caixa_vidas.get_child_count():
		var coracao: TextureRect = caixa_vidas.get_child(i)
		coracao.visible = i < maximo
		coracao.texture = TEX_CORACAO_CHEIO if i < vidas else TEX_CORACAO_VAZIO


func atualizar_xp(nivel: int, xp: int, proximo: int) -> void:
	label_nivel.text = "NV %d" % nivel
	barra_xp.max_value = proximo
	barra_xp.value = xp


func atualizar_poder(restante: float, total: float) -> void:
	barra_poder.value = 1.0 - restante / maxf(total, 0.01)
	icone_poder.modulate = Color.WHITE if restante <= 0.0 else Color(0.45, 0.45, 0.55)


func atualizar_esquiva(restante: float, total: float) -> void:
	barra_esquiva.value = 1.0 - restante / maxf(total, 0.01)


func atualizar_chaves(atual: int, total: int) -> void:
	label_chaves.text = "%d/%d" % [atual, total]
	if atual > 0:
		_pulsar(label_chaves)


func atualizar_pontos(pontos: int) -> void:
	label_pontos.text = str(pontos)


func atualizar_tempo(segundos: float) -> void:
	var s := int(ceil(segundos))
	label_tempo.text = "%d:%02d" % [s / 60, s % 60]
	label_tempo.modulate = Color("ff0044") if s <= 30 and s % 2 == 0 else Color.WHITE


func mostrar_mensagem(texto: String, duracao: float) -> void:
	label_mensagem.text = texto
	label_mensagem.modulate.a = 1.0
	if _tween_mensagem:
		_tween_mensagem.kill()
	_tween_mensagem = create_tween()
	_tween_mensagem.tween_interval(duracao)
	_tween_mensagem.tween_property(label_mensagem, "modulate:a", 0.0, 0.5)


func mostrar_titulo(linha1: String, linha2: String) -> void:
	$Titulo/Linha1.text = linha1
	$Titulo/Linha2.text = linha2
	var tween := create_tween()
	tween.tween_property(titulo, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(titulo, "modulate:a", 0.0, 0.6)


func mostrar_chefe(nome: String, vida_maxima: int) -> void:
	nome_chefe.text = nome
	barra_chefe.max_value = vida_maxima
	barra_chefe.value = vida_maxima
	painel_chefe.show()
	painel_chefe.modulate.a = 0.0
	create_tween().tween_property(painel_chefe, "modulate:a", 1.0, 0.5)


func atualizar_chefe(vida: int, _vida_maxima: int) -> void:
	create_tween().tween_property(barra_chefe, "value", float(vida), 0.15)


func esconder_chefe() -> void:
	create_tween().tween_property(painel_chefe, "modulate:a", 0.0, 0.5)


func _pulsar(controle: Control) -> void:
	controle.pivot_offset = controle.size / 2.0
	controle.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(controle, "scale", Vector2.ONE, 0.25)
