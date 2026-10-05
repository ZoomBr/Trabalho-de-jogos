extends CanvasLayer
## Tela de "Subiu de nível!": pausa o jogo e oferece 3 melhorias sorteadas.
## A melhoria escolhida fica guardada no Global e vale até o fim da campanha.

signal escolhido

const MELHORIAS := [
	{"id": "dano", "nome": "Força +1", "desc": "Todo ataque causa +1 de dano."},
	{"id": "coracao", "nome": "Coração extra", "desc": "+1 coração máximo (e cura 1)."},
	{"id": "cura", "nome": "Cura total", "desc": "Recupera todos os corações."},
	{"id": "recarga", "nome": "Poder mais rápido", "desc": "Recarga do poder -20%."},
	{"id": "velocidade", "nome": "Botas leves", "desc": "Anda 10% mais rápido."},
	{"id": "cadencia", "nome": "Ataque veloz", "desc": "Ataca 15% mais rápido."},
	{"id": "projetil", "nome": "Projétil extra", "desc": "+1 projétil por ataque.", "classes": ["mago", "arqueira"]},
	{"id": "alcance", "nome": "Lâmina longa", "desc": "Golpes 25% maiores.", "classes": ["guerreiro"]},
]

var aberto := false
var _opcoes: Array = []

@onready var titulo: Label = $Fundo/Caixa/Titulo
@onready var botoes: Array[Node] = [$Fundo/Caixa/Opcao1, $Fundo/Caixa/Opcao2, $Fundo/Caixa/Opcao3]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Fundo.hide()
	for i in botoes.size():
		botoes[i].pressed.connect(_escolher.bind(i))


func mostrar(nivel: int) -> void:
	aberto = true
	titulo.text = "Nível %d! Escolha uma melhoria:" % nivel
	var validas := MELHORIAS.filter(func(m):
		if m.has("classes") and not Global.classe.id in m.classes:
			return false
		if m.id == "coracao" and Global.vida_maxima >= Global.LIMITE_CORACOES:
			return false
		return true)
	validas.shuffle()
	_opcoes = validas.slice(0, 3)
	for i in botoes.size():
		botoes[i].text = "%s - %s" % [_opcoes[i].nome, _opcoes[i].desc]
	get_tree().paused = true
	$Fundo.show()
	botoes[0].grab_focus()


func _escolher(i: int) -> void:
	if not aberto:
		return
	match _opcoes[i].id:
		"dano": Global.bonus_dano += 1
		"coracao":
			Global.vida_maxima += 1
			Global.vidas = mini(Global.vidas + 1, Global.vida_maxima)
		"cura": Global.vidas = Global.vida_maxima
		"recarga": Global.mult_recarga *= 0.8
		"velocidade": Global.mult_velocidade *= 1.1
		"cadencia": Global.mult_cadencia *= 0.85
		"projetil": Global.projeteis_extra += 1
		"alcance": Global.mult_alcance += 0.25
	Sons.tocar("cura")
	aberto = false
	$Fundo.hide()
	get_tree().paused = false
	escolhido.emit()
