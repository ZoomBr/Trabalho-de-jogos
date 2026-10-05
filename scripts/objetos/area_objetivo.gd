extends Area2D
## Portal de saída ou bandeira final: avisa a fase quando o jogador encosta.
## O portal pode começar desativado (escondido) até o chefe da fase cair.

signal alcancado

var _usado := false


func _ready() -> void:
	$Animacao.play("default")
	body_entered.connect(_on_body_entered)


func desativar() -> void:
	visible = false
	set_deferred("monitoring", false)


func ativar() -> void:
	visible = true
	set_deferred("monitoring", true)
	scale = Vector2(0.1, 0.1)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sons.tocar("portal")


func _on_body_entered(corpo: Node2D) -> void:
	if not _usado and corpo.is_in_group("jogador"):
		_usado = true
		alcancado.emit()
