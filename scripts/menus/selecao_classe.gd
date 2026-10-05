extends Control
## Tela de escolha de classe: mostra as 3 classes com atributos, ataque e poder.

const ORDEM := ["guerreiro", "mago", "arqueira"]


func _ready() -> void:
	for i in ORDEM.size():
		var classe: ClasseHeroi = Global.CLASSES[ORDEM[i]]
		var carta := $Centro/Caixa/Cartas.get_child(i).get_node("V")
		var recorte := AtlasTexture.new()
		recorte.atlas = classe.textura
		recorte.region = Rect2(0, 0, 16, 16)
		carta.get_node("Retrato").texture = recorte
		carta.get_node("Nome").text = classe.nome
		carta.get_node("Info").text = "Vida %d  Dano %d\nVelocidade %d\n%s" % [
			classe.vida_inicial, classe.dano, int(classe.velocidade), classe.nome_poder]
		carta.get_node("Botao").pressed.connect(_escolher.bind(ORDEM[i]))
		carta.get_node("Botao").focus_entered.connect(_mostrar_descricao.bind(classe))
		carta.get_node("Botao").mouse_entered.connect(_mostrar_descricao.bind(classe))
	$Centro/Caixa/BotaoVoltar.pressed.connect(Global.voltar_ao_menu)
	$Centro/Caixa/Cartas.get_child(0).get_node("V/Botao").grab_focus()


func _mostrar_descricao(classe: ClasseHeroi) -> void:
	$Centro/Caixa/Descricao.text = "%s Poder: %s" % [classe.descricao, classe.descricao_poder]


func _escolher(id: String) -> void:
	Sons.tocar("clique")
	Global.novo_jogo(Global.fase_escolhida, id)
