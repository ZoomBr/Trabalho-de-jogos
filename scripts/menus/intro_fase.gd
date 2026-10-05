extends Control
## Tela entre fases: mostra o resumo da fase anterior (se houver) e a
## história da próxima. ENTER, ESPAÇO ou clique para começar.

var _pronto := false


func _ready() -> void:
	Sons.parar_musica()
	var i := Global.fase_atual
	$Centro/Caixa/Numero.text = "Fase %d de %d" % [i + 1, Global.FASES.size()]
	$Centro/Caixa/Nome.text = Global.NOMES_FASES[i]
	$Centro/Caixa/Historia.text = Global.HISTORIAS[i]
	var resumo := Global.resumo_fase
	if resumo.is_empty():
		$Centro/Caixa/Resumo.hide()
	else:
		$Centro/Caixa/Resumo.text = "Fase %d concluída!  Moedas: %d   Inimigos: %d   Bônus: +%d" % [
			resumo.fase + 1, resumo.moedas, resumo.inimigos, resumo.bonus]
	$Centro/Caixa/Pontos.text = "%s nível %d     Pontos: %d     Vidas: %d\nPoder: Q / K / botão direito     Esquiva: Shift / L" % [
		Global.classe.nome, Global.nivel, Global.pontuacao, Global.vidas]
	$Centro/Caixa/BotaoComecar.pressed.connect(_comecar)
	# pequena espera para o jogador não pular a tela sem querer
	await get_tree().create_timer(0.6).timeout
	_pronto = true
	$Centro/Caixa/BotaoComecar.grab_focus()
	var piscar := create_tween().set_loops()
	piscar.tween_property($Centro/Caixa/BotaoComecar, "modulate:a", 0.5, 0.5)
	piscar.tween_property($Centro/Caixa/BotaoComecar, "modulate:a", 1.0, 0.5)


func _comecar() -> void:
	if not _pronto:
		return
	_pronto = false
	Sons.tocar("clique")
	Global.iniciar_fase_atual()
