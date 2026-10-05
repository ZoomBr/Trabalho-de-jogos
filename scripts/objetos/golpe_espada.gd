extends Area2D
## Corte de espada do Guerreiro: aparece na frente do jogador, acerta uma vez
## todos os inimigos dentro do arco e ainda rebate gosmas e flechas inimigas.

var dano := 2
var direcao := Vector2.RIGHT
var escala := 1.0


func _ready() -> void:
	rotation = direcao.angle()
	position = direcao * 6.0
	scale = Vector2(escala, escala)
	$Animacao.play("default")
	# espera a física registrar as sobreposições e então aplica o golpe
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var origem: Vector2 = get_parent().global_position
	for corpo in get_overlapping_bodies():
		if corpo.has_method("receber_dano"):
			corpo.receber_dano(dano, origem, false, 45.0)
	for area in get_overlapping_areas():
		if area.is_in_group("projetil_inimigo"):
			area.destruir()
	await get_tree().create_timer(0.15, false).timeout
	queue_free()
