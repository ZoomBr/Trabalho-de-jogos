extends Area2D
## Item coletável genérico: moeda, chave ou coração.
## Quando o jogador encosta, avisa a fase (sinal "coletado") e some com um efeito.

signal coletado(item: Area2D)

enum Tipo { MOEDA, CHAVE, CORACAO }

@export var tipo: Tipo = Tipo.MOEDA
## Itens que caem de inimigos "pulam" ao aparecer.
@export var surgir_pulando := false

var _coletado := false

@onready var animacao: AnimatedSprite2D = $Animacao


func _ready() -> void:
	add_to_group("coletaveis")
	body_entered.connect(_on_body_entered)
	animacao.play("default")
	if surgir_pulando:
		monitoring = false
		animacao.position.y = -10.0
		var pulo := create_tween()
		pulo.tween_property(animacao, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		pulo.tween_callback(_liberar_coleta)
	else:
		_flutuar()


func _liberar_coleta() -> void:
	monitoring = true
	_flutuar()


func _flutuar() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(animacao, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(animacao, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(corpo: Node2D) -> void:
	if _coletado or not corpo.is_in_group("jogador"):
		return
	_coletado = true
	coletado.emit(self)
	set_deferred("monitoring", false)
	var sumir := create_tween().set_parallel()
	sumir.tween_property(animacao, "position:y", -12.0, 0.25)
	sumir.tween_property(animacao, "modulate:a", 0.0, 0.25)
	sumir.chain().tween_callback(queue_free)
