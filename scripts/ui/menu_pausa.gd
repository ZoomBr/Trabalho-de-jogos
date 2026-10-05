extends CanvasLayer
## Menu de pausa (CanvasLayer). Continua funcionando com o jogo pausado
## porque o process_mode dele é "Sempre".

@onready var painel: Control = $Fundo
@onready var botao_continuar: Button = $Fundo/Caixa/BotaoContinuar
@onready var botao_musica: Button = $Fundo/Caixa/BotaoMusica
@onready var botao_sons: Button = $Fundo/Caixa/BotaoSons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	painel.hide()
	botao_continuar.pressed.connect(_alternar_pausa)
	$Fundo/Caixa/BotaoReiniciar.pressed.connect(_reiniciar)
	botao_musica.pressed.connect(func(): Global.alternar_musica(); _atualizar_textos())
	botao_sons.pressed.connect(func(): Global.alternar_sons(); _atualizar_textos())
	$Fundo/Caixa/BotaoMenu.pressed.connect(_voltar_menu)
	$Fundo/Caixa/BotaoSair.pressed.connect(get_tree().quit)
	for botao in $Fundo/Caixa.get_children():
		if botao is Button:
			botao.pressed.connect(Sons.tocar.bind("clique", -6.0, 0.0))
	_atualizar_textos()


func _unhandled_input(event: InputEvent) -> void:
	# não abre a pausa por cima de outra tela que já pausou o jogo (ex.: subir de nível)
	if get_tree().paused and not painel.visible:
		return
	if event.is_action_pressed("pausar") and not Transicao.esta_ocupado():
		_alternar_pausa()
		get_viewport().set_input_as_handled()


func _alternar_pausa() -> void:
	var pausado := not get_tree().paused
	get_tree().paused = pausado
	painel.visible = pausado
	if pausado:
		botao_continuar.grab_focus()


func _atualizar_textos() -> void:
	botao_musica.text = "Música: " + ("ligada" if Global.musica_ligada else "desligada")
	botao_sons.text = "Efeitos: " + ("ligados" if Global.sons_ligados else "desligados")


func _reiniciar() -> void:
	Global.tentar_novamente()


func _voltar_menu() -> void:
	Global.voltar_ao_menu()
