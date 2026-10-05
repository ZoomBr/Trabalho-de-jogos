extends StaticBody2D
## Portão/porta trancada: bloqueia a passagem até o jogador juntar as chaves.

const CENA_POEIRA := preload("res://cenas/efeitos/efeito_morte.tscn")


func _ready() -> void:
	add_to_group("portoes")


func abrir() -> void:
	$Colisao.set_deferred("disabled", true)
	var poeira := CENA_POEIRA.instantiate()
	poeira.global_position = global_position
	poeira.color = Color("c0cbdc")
	get_parent().add_child(poeira)
	var tween := create_tween().set_parallel()
	tween.tween_property($Sprite, "scale:y", 0.0, 0.5)
	tween.tween_property($Sprite, "position:y", -8.0, 0.5)
	tween.chain().tween_callback(queue_free)
