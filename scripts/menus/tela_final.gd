extends Control
## Tela de final: vitória (depois do chefão) ou derrota. Mostra as estatísticas
## e permite tentar de novo ou voltar ao menu.


func _ready() -> void:
	var caixa := $Centro/Caixa
	var tempo := int(Global.tempo_total)
	var estatisticas := "%s nível %d    Pontuação: %d\nMoedas: %d    Inimigos derrotados: %d\nTempo de jogo: %d:%02d    Recorde: %d" % [
		Global.classe.nome, Global.nivel, Global.pontuacao, Global.moedas_total, Global.inimigos_total, tempo / 60, tempo % 60, Global.recorde]
	if Global.novo_recorde:
		estatisticas += "   NOVO RECORDE!"
	caixa.get_node("Estatisticas").text = estatisticas
	var botao_novamente: Button = caixa.get_node("BotaoNovamente")
	if Global.venceu:
		caixa.get_node("Titulo").text = "Vitória!"
		caixa.get_node("Titulo").modulate = Color("feae34")
		caixa.get_node("Subtitulo").text = "O Rei Slime caiu e a bandeira do reino voltou a tremular!"
		botao_novamente.text = "Jogar de novo"
		botao_novamente.pressed.connect(func(): Global.escolher_classe(0))
		# o herói da vitória é a classe que o jogador escolheu
		var retrato := AtlasTexture.new()
		retrato.atlas = Global.classe.textura
		retrato.region = Rect2(0, 0, 16, 16)
		$Heroi.texture = retrato
		$Heroi.show()
		$Coroa.show()
		Sons.tocar_musica("menu")
	else:
		caixa.get_node("Titulo").text = "Derrota..."
		caixa.get_node("Titulo").modulate = Color("e43b44")
		caixa.get_node("Subtitulo").text = "Você caiu na fase %d: %s." % [Global.fase_atual + 1, Global.NOMES_FASES[Global.fase_atual]]
		botao_novamente.text = "Tentar a fase de novo"
		botao_novamente.pressed.connect(Global.tentar_novamente)
		$Heroi.hide()
		$Coroa.hide()
	caixa.get_node("BotaoMenu").pressed.connect(Global.voltar_ao_menu)
	for botao in caixa.find_children("*", "Button"):
		botao.pressed.connect(Sons.tocar.bind("clique", -6.0, 0.0))
	botao_novamente.grab_focus()
