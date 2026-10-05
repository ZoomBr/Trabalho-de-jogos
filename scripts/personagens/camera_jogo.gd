extends Camera2D
## Câmera que segue o jogador (é filha dele) e sabe "tremer" em impactos.

var _forca := 0.0
var _duracao := 0.0
var _tempo := 0.0


func tremer(forca: float, duracao: float) -> void:
	_forca = maxf(_forca, forca)
	_duracao = maxf(duracao, 0.01)
	_tempo = duracao


func _process(delta: float) -> void:
	if _tempo <= 0.0:
		offset = Vector2.ZERO
		return
	_tempo -= delta
	var intensidade := _forca * (_tempo / _duracao)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * intensidade
	if _tempo <= 0.0:
		_forca = 0.0


## Limita a câmera ao retângulo do mapa (em pixels).
func limitar(area: Rect2i) -> void:
	limit_left = area.position.x
	limit_top = area.position.y
	limit_right = area.end.x
	limit_bottom = area.end.y
	reset_smoothing()
