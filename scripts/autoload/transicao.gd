extends CanvasLayer
## Autoload "Transicao": escurece a tela, troca de cena e clareia de novo (fade).

const DURACAO := 0.35

var _ocupado := false
var _pendente := ""  # troca pedida durante outra transição

@onready var cortina: ColorRect = $Cortina


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cortina.color.a = 0.0
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE


func trocar_cena(caminho: String) -> void:
	if _ocupado:
		_pendente = caminho
		return
	_ocupado = true
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP  # bloqueia cliques durante o fade
	var entrada := create_tween()
	entrada.tween_property(cortina, "color:a", 1.0, DURACAO)
	await entrada.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(caminho)
	await get_tree().process_frame
	await get_tree().process_frame
	var saida := create_tween()
	saida.tween_property(cortina, "color:a", 0.0, DURACAO)
	await saida.finished
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupado = false
	if _pendente != "":
		var proximo := _pendente
		_pendente = ""
		trocar_cena(proximo)


func esta_ocupado() -> bool:
	return _ocupado
