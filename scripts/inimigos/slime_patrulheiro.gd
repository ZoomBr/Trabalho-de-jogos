extends Inimigo
## Slime verde: patrulha em linha reta e dá meia-volta ao percorrer a
## distância definida ou ao bater em alguma coisa.

@export var direcao := Vector2.RIGHT
## Distância (em pixels) percorrida antes de dar meia-volta.
@export var distancia := 96.0

var _origem := Vector2.ZERO


func _iniciar() -> void:
	_origem = global_position


func _calcular_velocidade(_delta: float) -> Vector2:
	return direcao * velocidade


func _depois_de_mover() -> void:
	if global_position.distance_to(_origem) >= distancia or is_on_wall():
		direcao = -direcao
		_origem = global_position
