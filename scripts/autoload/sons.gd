extends Node
## Autoload "Sons": toca efeitos sonoros e músicas de qualquer lugar do jogo.
## Uso: Sons.tocar("moeda")  |  Sons.tocar_musica("fase1")

const PASTA_SFX := "res://audio/sfx/%s.wav"
const PASTA_MUSICA := "res://audio/musica/%s.wav"
const QTD_CANAIS := 10
const VOLUME_MUSICA_DB := -8.0

var _canais: Array[AudioStreamPlayer] = []
var _proximo := 0
var _cache: Dictionary = {}
var _musica: AudioStreamPlayer
var _musica_atual := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in QTD_CANAIS:
		var canal := AudioStreamPlayer.new()
		add_child(canal)
		_canais.append(canal)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	_musica.finished.connect(_musica.play)  # repete a música em loop
	atualizar_volume_musica()


func tocar(nome: String, volume_db := 0.0, variacao_tom := 0.08) -> void:
	if not Global.sons_ligados:
		return
	var canal := _canais[_proximo]
	_proximo = (_proximo + 1) % QTD_CANAIS
	canal.stream = _carregar(PASTA_SFX % nome)
	canal.volume_db = volume_db
	canal.pitch_scale = 1.0 + randf_range(-variacao_tom, variacao_tom)
	canal.play()


## Toca uma música em loop. Tocar a mesma música de novo não reinicia a faixa.
func tocar_musica(nome: String) -> void:
	if nome == _musica_atual and _musica.playing:
		return
	_musica_atual = nome
	_musica.stream = _carregar(PASTA_MUSICA % nome)
	_musica.play()


## Toca uma faixa curta (vinheta) sem loop, parando a música atual.
func tocar_vinheta(nome: String) -> void:
	parar_musica()
	tocar(nome, 0.0, 0.0)


func parar_musica() -> void:
	_musica_atual = ""
	_musica.stop()


func atualizar_volume_musica() -> void:
	_musica.volume_db = VOLUME_MUSICA_DB if Global.musica_ligada else -80.0


func _carregar(caminho: String) -> AudioStream:
	if not _cache.has(caminho):
		_cache[caminho] = load(caminho)
	return _cache[caminho]
