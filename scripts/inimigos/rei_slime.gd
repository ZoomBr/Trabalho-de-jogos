extends Chefe
## Chefe final: Rei Slime. Ataques:
##  0 RAJADA    - anéis de gosma em todas as direções;
##  1 INVESTIDA - pisca e avança rápido; fica tonto se bater na parede;
##  2 INVOCAR   - chama slimes roxos para ajudar;
##  3 SALTO     - marca o chão onde o jogador está, pula e cai com onda de choque;
##  4 CHUVA     - (só na fúria) marca vários pontos e faz chover gosma neles.

const CENA_GOSMA := preload("res://cenas/objetos/projetil_chefe.tscn")
const CENA_LACAIO := preload("res://cenas/inimigos/slime_perseguidor.tscn")

var _lacaios: Array[Node2D] = []
var _investindo := false
var _direcao := Vector2.ZERO


func _movimento(_delta: float) -> Vector2:
	if _investindo:
		return _direcao * (260.0 if em_furia else 210.0)
	if _ocupado:
		return Vector2.ZERO
	return global_position.direction_to(_jogador.global_position) * velocidade_andar


func _atacar() -> void:
	match sortear_ataque(5 if em_furia else 4):
		0: await _rajada()
		1: await _investida()
		2: _invocar()
		3: await _salto()
		4: await _chuva()


func _rajada() -> void:
	var ondas := 3 if em_furia else 2
	var qtd := 16 if em_furia else 12
	for onda in ondas:
		var deslocamento := (TAU / qtd) * 0.5 * (onda % 2)
		for i in qtd:
			atirar(CENA_GOSMA, Vector2.from_angle(TAU * i / qtd + deslocamento), 75.0 if em_furia else 60.0)
		Sons.tocar("chefe_tiro")
		animacao.scale = Vector2(1.2, 0.8)
		create_tween().tween_property(animacao, "scale", Vector2.ONE, 0.25)
		if not await esperar(0.45):
			return


func _investida() -> void:
	avisar(0.7)
	if not await esperar(0.7):
		return
	_direcao = global_position.direction_to(_jogador.global_position)
	_investindo = true
	for i in 45:
		await get_tree().physics_frame
		if morrendo or not is_inside_tree():
			return
		if get_slide_collision_count() > 0:
			_jogador.camera.tremer(5.0, 0.3)
			Sons.tocar("portao", -4.0)
			break
	_investindo = false
	await esperar(0.9)


func _invocar() -> void:
	_lacaios = _lacaios.filter(func(l): return is_instance_valid(l))
	if _lacaios.size() >= 3:
		return
	Sons.tocar("chefe_rugido", -6.0, 0.2)
	var qtd := 3 if em_furia else 2
	for i in qtd:
		var lacaio := CENA_LACAIO.instantiate()
		lacaio.global_position = global_position + Vector2.from_angle(TAU * i / qtd + randf()) * 28.0
		lacaio.raio_visao = 400.0
		lacaio.raio_desistir = 500.0
		_lacaios.append(lacaio)
		invocou.emit(lacaio)


func _salto() -> void:
	var destino := _jogador.global_position
	area_de_aviso(destino, 26.0, 0.9)
	# sobe (fica intocável no ar)
	collision_layer = 0
	area_dano.set_deferred("monitoring", false)
	var sobe := create_tween()
	sobe.tween_property(animacao, "position:y", -60.0, 0.35).set_ease(Tween.EASE_OUT)
	sobe.parallel().tween_property(animacao, "modulate:a", 0.4, 0.35)
	if not await esperar(0.5):
		return
	global_position = destino + Vector2(0, -4)
	var desce := create_tween()
	desce.tween_property(animacao, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
	desce.parallel().tween_property(animacao, "modulate:a", 1.0, 0.25)
	if not await esperar(0.3):
		return
	collision_layer = 4
	area_dano.set_deferred("monitoring", true)
	onda_de_choque(70.0)
	await esperar(0.5)


func _chuva() -> void:
	Sons.tocar("chefe_rugido", -4.0)
	for i in 7:
		var ponto := _jogador.global_position + Vector2(randf_range(-50, 50), randf_range(-40, 40))
		if i == 0:
			ponto = _jogador.global_position
		area_de_aviso(ponto, 16.0, 0.9)
		if not await esperar(0.15):
			return
	await esperar(0.8)
