extends Area2D
## Projétil inimigo (gosma, flecha de esqueleto, pedra do golem, espírito da bruxa).
## - "girar": o sprite gira enquanto voa (gosma e pedra);
## - "perseguir": o projétil vai curvando na direção do jogador (espírito).

@export var velocidade := 80.0
@export var girar := true
@export var perseguir := false
@export var curva := 2.2

var direcao := Vector2.RIGHT
var _jogador: Node2D


func _ready() -> void:
	add_to_group("projetil_inimigo")
	body_entered.connect(_on_body_entered)
	$TimerVida.timeout.connect(queue_free)
	_jogador = get_tree().get_first_node_in_group("jogador")
	if not girar:
		rotation = direcao.angle()


func _physics_process(delta: float) -> void:
	if perseguir and is_instance_valid(_jogador):
		var desejada := global_position.direction_to(_jogador.global_position)
		var giro := clampf(direcao.angle_to(desejada), -curva * delta, curva * delta)
		direcao = direcao.rotated(giro)
	position += direcao * velocidade * delta
	if girar:
		$Sprite.rotation += delta * 8.0
	else:
		rotation = direcao.angle()


func _on_body_entered(corpo: Node2D) -> void:
	if corpo.has_method("levar_dano"):
		corpo.levar_dano(global_position)
	queue_free()


## Chamado quando a espada do Guerreiro rebate o projétil.
func destruir() -> void:
	set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ZERO, 0.1)
	t.tween_callback(queue_free)
