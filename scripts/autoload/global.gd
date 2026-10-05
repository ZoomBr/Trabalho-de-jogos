extends Node
## Autoload "Global": guarda o estado da campanha (fase atual, classe escolhida,
## pontos, vidas, nível e melhorias), o recorde salvo em disco e as opções de
## áudio. Existe durante o jogo todo, então os dados passam de uma fase para a outra.

const FASES: Array[String] = [
	"res://cenas/fases/fase_1.tscn",
	"res://cenas/fases/fase_2.tscn",
	"res://cenas/fases/fase_3.tscn",
]
const NOMES_FASES: Array[String] = ["Vila das Colinas", "Pântano Sombrio", "Castelo do Rei Slime"]
const HISTORIAS: Array[String] = [
	"Os slimes invadiram a vila e esconderam as 3 chaves.\nAbra o portão da fortaleza, derrote o Golem de Pedra\nque guarda o portal e siga em frente!",
	"O portal levou você ao Pântano Sombrio. Esqueletos,\nfantasmas e slimes cuspidores rondam a água.\nAche as chaves e vença a Bruxa do Pântano!",
	"Chegou a hora! O Rei Slime se esconde na sala do trono.\nAche as 3 chaves do castelo, abra a porta do trono,\nderrote o Rei e erga a bandeira do reino!",
]
## As classes jogáveis (cada uma é um Resource editável no Inspetor).
const CLASSES := {
	"guerreiro": preload("res://recursos/classes/guerreiro.tres"),
	"mago": preload("res://recursos/classes/mago.tres"),
	"arqueira": preload("res://recursos/classes/arqueira.tres"),
}
const CENA_SELECAO := "res://cenas/menus/selecao_classe.tscn"
const CENA_INTRO := "res://cenas/menus/intro_fase.tscn"
const CENA_FINAL := "res://cenas/menus/tela_final.tscn"
const CENA_MENU := "res://cenas/menus/menu_principal.tscn"
const CAMINHO_SAVE := "user://chaves_do_reino.cfg"
const LIMITE_CORACOES := 9

var fase_atual := 0
## Fase escolhida no menu (o jogo começa nela depois da seleção de classe).
var fase_escolhida := 0
var classe: ClasseHeroi = CLASSES["guerreiro"]
var pontuacao := 0
var vidas := 4
var vida_maxima := 6
var venceu := false
var recorde := 0
var novo_recorde := false
var fase_maxima_liberada := 0
var resumo_fase: Dictionary = {}
var moedas_total := 0
var inimigos_total := 0
var tempo_total := 0.0

# ---------- nível e melhorias ----------
var nivel := 1
var xp := 0
var bonus_dano := 0
var mult_cadencia := 1.0
var mult_recarga := 1.0
var mult_velocidade := 1.0
var mult_alcance := 1.0
var projeteis_extra := 0

var musica_ligada := true
var sons_ligados := true

## Cópia do estado no início da fase, para o "Tentar novamente".
var _inicio_fase: Dictionary = {}
const _CAMPOS_SALVOS := ["pontuacao", "moedas_total", "inimigos_total", "nivel", "xp", "bonus_dano",
	"mult_cadencia", "mult_recarga", "mult_velocidade", "mult_alcance", "projeteis_extra", "vida_maxima"]


func _ready() -> void:
	_carregar()


# ---------- fluxo da campanha ----------

## Abre a tela de seleção de classe; o jogo começa na fase indicada.
func escolher_classe(fase := 0) -> void:
	fase_escolhida = fase
	Transicao.trocar_cena(CENA_SELECAO)


func novo_jogo(fase_inicial := 0, id_classe := "guerreiro") -> void:
	classe = CLASSES[id_classe]
	fase_atual = fase_inicial
	pontuacao = 0
	vida_maxima = classe.vida_maxima
	vidas = classe.vida_inicial
	moedas_total = 0
	inimigos_total = 0
	tempo_total = 0.0
	resumo_fase = {}
	venceu = false
	nivel = 1
	xp = 0
	bonus_dano = 0
	mult_cadencia = 1.0
	mult_recarga = 1.0
	mult_velocidade = 1.0
	mult_alcance = 1.0
	projeteis_extra = 0
	Transicao.trocar_cena(CENA_INTRO)


## Chamado pela tela de introdução quando o jogador aperta "começar".
func iniciar_fase_atual() -> void:
	_inicio_fase = {}
	for campo in _CAMPOS_SALVOS:
		_inicio_fase[campo] = get(campo)
	_inicio_fase["vidas"] = vidas
	Transicao.trocar_cena(FASES[fase_atual])


func concluir_fase(resumo: Dictionary) -> void:
	resumo_fase = resumo
	fase_atual += 1
	if fase_atual >= FASES.size():
		venceu = true
		_registrar_recorde()
		Transicao.trocar_cena(CENA_FINAL)
		return
	fase_maxima_liberada = maxi(fase_maxima_liberada, fase_atual)
	_salvar()
	Transicao.trocar_cena(CENA_INTRO)


func perder() -> void:
	venceu = false
	_registrar_recorde()
	Transicao.trocar_cena(CENA_FINAL)


## Recomeça a fase em que o jogador perdeu, com tudo como estava quando ela começou.
func tentar_novamente() -> void:
	for campo in _inicio_fase:
		set(campo, _inicio_fase[campo])
	vidas = maxi(_inicio_fase.get("vidas", classe.vida_inicial), classe.vida_inicial)
	resumo_fase = {}
	Transicao.trocar_cena(CENA_INTRO)


func voltar_ao_menu() -> void:
	Transicao.trocar_cena(CENA_MENU)


# ---------- experiência ----------

func xp_para_proximo_nivel() -> int:
	return 6 + nivel * 6


## Soma experiência e devolve quantos níveis o jogador subiu.
func ganhar_xp(quantidade: int) -> int:
	xp += quantidade
	var subiu := 0
	while xp >= xp_para_proximo_nivel():
		xp -= xp_para_proximo_nivel()
		nivel += 1
		subiu += 1
	return subiu


# ---------- recorde e opções ----------

func _registrar_recorde() -> void:
	novo_recorde = pontuacao > recorde
	if novo_recorde:
		recorde = pontuacao
	_salvar()


func alternar_musica() -> void:
	musica_ligada = not musica_ligada
	Sons.atualizar_volume_musica()
	_salvar()


func alternar_sons() -> void:
	sons_ligados = not sons_ligados
	_salvar()


func _salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "recorde", recorde)
	cfg.set_value("progresso", "fase_maxima", fase_maxima_liberada)
	cfg.set_value("opcoes", "musica", musica_ligada)
	cfg.set_value("opcoes", "sons", sons_ligados)
	cfg.save(CAMINHO_SAVE)


func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO_SAVE) != OK:
		return
	recorde = cfg.get_value("progresso", "recorde", 0)
	fase_maxima_liberada = cfg.get_value("progresso", "fase_maxima", 0)
	musica_ligada = cfg.get_value("opcoes", "musica", true)
	sons_ligados = cfg.get_value("opcoes", "sons", true)
