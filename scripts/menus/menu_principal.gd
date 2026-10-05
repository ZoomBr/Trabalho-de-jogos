extends Control
## Menu inicial: Jogar, Selecionar fase, Como jogar, Créditos e Sair.
## Ao fundo, a câmera passeia devagar pelo mapa da Fase 1.

@onready var principal: Control = $UI/Principal
@onready var painel_como_jogar: Control = $UI/ComoJogar
@onready var painel_creditos: Control = $UI/Creditos
@onready var painel_fases: Control = $UI/Fases
@onready var camera: Camera2D = $Cenario/Camera

var _tempo := 0.0


func _ready() -> void:
	Sons.tocar_musica("menu")
	$UI/Principal/Caixa/Recorde.text = "Recorde: %d" % Global.recorde
	_mostrar(principal)
	$UI/Principal/Caixa/BotaoJogar.pressed.connect(func(): Global.escolher_classe(0))
	$UI/Principal/Caixa/BotaoFases.pressed.connect(_mostrar.bind(painel_fases))
	$UI/Principal/Caixa/BotaoComoJogar.pressed.connect(_mostrar.bind(painel_como_jogar))
	$UI/Principal/Caixa/BotaoCreditos.pressed.connect(_mostrar.bind(painel_creditos))
	$UI/Principal/Caixa/BotaoSair.pressed.connect(get_tree().quit)
	for voltar in [$UI/ComoJogar/Caixa/BotaoVoltar, $UI/Creditos/Caixa/BotaoVoltar, $UI/Fases/Caixa/BotaoVoltar]:
		voltar.pressed.connect(_mostrar.bind(principal))
	# seleção de fase: só as fases já alcançadas ficam liberadas
	for i in 3:
		var botao: Button = $UI/Fases/Caixa.get_child(i + 1)
		botao.text = "Fase %d - %s" % [i + 1, Global.NOMES_FASES[i]]
		botao.disabled = i > Global.fase_maxima_liberada
		botao.pressed.connect(Global.escolher_classe.bind(i))
	for botao in find_children("*", "Button"):
		botao.pressed.connect(Sons.tocar.bind("clique", -6.0, 0.0))


func _process(delta: float) -> void:
	# passeio lento da câmera pelo cenário de fundo
	_tempo += delta * 0.12
	camera.position = Vector2(400, 240) + Vector2(cos(_tempo) * 200.0, sin(_tempo * 1.3) * 110.0)


func _mostrar(painel: Control) -> void:
	for p in [principal, painel_como_jogar, painel_creditos, painel_fases]:
		p.visible = p == painel
	var primeiro := _primeiro_botao(painel)
	if primeiro:
		primeiro.grab_focus()


func _primeiro_botao(no: Node) -> Button:
	for filho in no.find_children("*", "Button"):
		if not filho.disabled:
			return filho
	return null
